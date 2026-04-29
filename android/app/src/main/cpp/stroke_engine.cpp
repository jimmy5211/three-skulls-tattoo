#include "stroke_engine.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>

#define LOG_TAG "TSK_Stroke"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace tsk {

static const char* kStrokeVert =
"#version 300 es\n"
"precision highp float;\n"
"layout(location = 0) in vec2 a_pos;\n"
"layout(location = 1) in vec2 a_uv;\n"
"uniform vec2  u_center;\n"
"uniform float u_diameter;\n"
"uniform vec2  u_canvasSize;\n"
"out vec2 v_uv;\n"
"void main() {\n"
"    vec2 pos = u_center + a_pos * u_diameter;\n"
"    vec2 ndc = (pos / u_canvasSize) * 2.0 - 1.0;\n"
"    gl_Position = vec4(ndc, 0.0, 1.0);\n"
"    v_uv = a_uv;\n"
"}\n";

static const char* kStrokeFrag =
"#version 300 es\n"
"precision highp float;\n"
"uniform sampler2D u_brush;\n"
"uniform vec4      u_color;\n"
"uniform float     u_hardness;\n"
"layout(location = 0) out vec4 fragColor;\n"
"in vec2 v_uv;\n"
"void main() {\n"
"    float mask = texture(u_brush, v_uv).a;\n"
"    float h    = min(u_hardness, 0.999);\n"
"    float edge = 0.5 * h;\n"
"    float soft = smoothstep(edge, 1.0 - edge, mask);\n"
"    fragColor  = vec4(u_color.rgb, u_color.a * soft);\n"
"}\n";

static const char* kEraserFrag =
"#version 300 es\n"
"precision highp float;\n"
"uniform sampler2D u_brush;\n"
"uniform float     u_opacity;\n"
"uniform float     u_hardness;\n"
"layout(location = 0) out vec4 fragColor;\n"
"in vec2 v_uv;\n"
"void main() {\n"
"    float mask = texture(u_brush, v_uv).a;\n"
"    float h    = min(u_hardness, 0.999);\n"
"    float edge = 0.5 * h;\n"
"    float soft = smoothstep(edge, 1.0 - edge, mask);\n"
"    fragColor  = vec4(0.0, 0.0, 0.0, u_opacity * soft);\n"
"}\n";

static const float kQuad[] = {
    -0.5f, -0.5f,  0.0f, 0.0f,
     0.5f, -0.5f,  1.0f, 0.0f,
    -0.5f,  0.5f,  0.0f, 1.0f,
     0.5f,  0.5f,  1.0f, 1.0f,
};

bool StrokeEngine::init() {
    while (glGetError() != GL_NO_ERROR) {}
    if (!initShaders()) { LOGE("StrokeEngine: initShaders failed"); return false; }
    if (!initQuad())    { LOGE("StrokeEngine: initQuad failed");    return false; }
    generateDefaultBrushTex();
    LOGI("StrokeEngine initialized");
    return true;
}

void StrokeEngine::destroy() {
    destroyStrokeFBO();
    if (strokeProgram_)    { glDeleteProgram(strokeProgram_);    strokeProgram_    = 0; }
    if (eraserProgram_)    { glDeleteProgram(eraserProgram_);    eraserProgram_    = 0; }
    if (compositeProgram_) { glDeleteProgram(compositeProgram_); compositeProgram_ = 0; }
    if (quadVBO_)          { glDeleteBuffers(1, &quadVBO_);      quadVBO_          = 0; }
    if (quadVAO_)          { glDeleteVertexArrays(1, &quadVAO_); quadVAO_          = 0; }
    if (defaultBrushTex_)  { glDeleteTextures(1, &defaultBrushTex_); defaultBrushTex_ = 0; }
    for (auto& e : brushTextures_) glDeleteTextures(1, &e.tex);
    brushTextures_.clear();
}

bool StrokeEngine::ensureStrokeFBO(int, int) { return true; }
void StrokeEngine::destroyStrokeFBO() {
    if (strokeTex_) { glDeleteTextures(1, &strokeTex_);     strokeTex_ = 0; }
    if (strokeFBO_) { glDeleteFramebuffers(1, &strokeFBO_); strokeFBO_ = 0; }
    strokeW_ = strokeH_ = 0;
}
void StrokeEngine::compositeStrokeToLayer(GLuint) {}
bool StrokeEngine::initCompositeShader() { return true; }

void StrokeEngine::beginStroke(const Point& p, const BrushParams& brush,
                                const Color& color, int cw, int ch) {
    brush_     = brush;
    color_     = color;
    canvasW_   = cw;
    canvasH_   = ch;
    lastPoint_ = p;
    accDist_   = 0.0f;
    active_    = true;
    GLint currentFBO = 0;
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &currentFBO);
    layerFBO_ = (GLuint)currentFBO;
    renderStamp(p);
}

bool StrokeEngine::addPoint(const Point& p) {
    if (!active_) return false;

    float dx   = p.x - lastPoint_.x;
    float dy   = p.y - lastPoint_.y;
    float dist = std::sqrt(dx*dx + dy*dy);
    accDist_  += dist;

    float spacing = std::max(1.0f, brush_.size * brush_.spacing);
    bool  rendered = false;

    while (accDist_ >= spacing) {
        float t = (dist - (accDist_ - spacing)) / std::max(dist, 0.001f);
        Point stamp;
        stamp.x        = lastPoint_.x + dx * t;
        stamp.y        = lastPoint_.y + dy * t;
        stamp.pressure = lastPoint_.pressure + (p.pressure - lastPoint_.pressure) * t;
        renderStamp(stamp);
        accDist_ -= spacing;
        rendered  = true;
    }

    lastPoint_ = p;
    return rendered;
}

void StrokeEngine::endStroke()    { active_ = false; }
void StrokeEngine::cancelStroke() { active_ = false; }

// ── Stamp principal + espejo ──────────────────────────────────────────

void StrokeEngine::renderStamp(const Point& p, float diameterOverride) {
    float diameter = diameterOverride > 0 ? diameterOverride : brush_.size;
    diameter *= (0.7f + p.pressure * 0.3f);

    renderStampAt(p.x, p.y, p.pressure, diameter);

    if (symmetryEnabled_) {
        float mx, my;
        if (symmetryAxis_ == 0) {
            mx = (float)canvasW_ - p.x;
            my = p.y;
        } else {
            mx = p.x;
            my = (float)canvasH_ - p.y;
        }
        renderStampAt(mx, my, p.pressure, diameter);
    }
}

// ── Renderiza un stamp en (x,y) con blend correcto ─────────────────────
// RGB: src-over normal. Alpha: GL_MAX → sin acumulación "perlada".

void StrokeEngine::renderStampAt(float x, float y, float /*pressure*/, float diameter) {
    GLuint prog = brush_.isEraser ? eraserProgram_ : strokeProgram_;
    glUseProgram(prog);

    glEnable(GL_BLEND);
    if (brush_.isEraser) {
        glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
        glBlendFuncSeparate(GL_ZERO, GL_ONE,
                            GL_ZERO, GL_ONE_MINUS_SRC_ALPHA);
    } else {
        glBlendEquationSeparate(GL_FUNC_ADD, GL_MAX);
        glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA,
                            GL_ONE,       GL_ONE);
    }

    glUniform2f(glGetUniformLocation(prog, "u_center"),     x, y);
    glUniform1f(glGetUniformLocation(prog, "u_diameter"),   diameter);
    glUniform2f(glGetUniformLocation(prog, "u_canvasSize"), (float)canvasW_, (float)canvasH_);
    glUniform1f(glGetUniformLocation(prog, "u_hardness"),   brush_.hardness);

    if (brush_.isEraser) {
        glUniform1f(glGetUniformLocation(prog, "u_opacity"), color_.a);
    } else {
        glUniform4f(glGetUniformLocation(prog, "u_color"),
                    color_.r, color_.g, color_.b, color_.a);
    }

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, getBrushTexture());
    glUniform1i(glGetUniformLocation(prog, "u_brush"), 0);

    glBindVertexArray(quadVAO_);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);

    glDisable(GL_BLEND);
    glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
}

GLuint StrokeEngine::getBrushTexture() const {
    if (brush_.brushTextureId >= 0)
        for (auto& e : brushTextures_)
            if (e.id == brush_.brushTextureId) return e.tex;
    return defaultBrushTex_;
}

int StrokeEngine::loadBrushTexture(const uint8_t* rgba, int w, int h) {
    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    int id = nextBrushTexId_++;
    brushTextures_.push_back({id, tex, w, h});
    return id;
}

void StrokeEngine::unloadBrushTexture(int id) {
    auto it = std::find_if(brushTextures_.begin(), brushTextures_.end(),
        [id](const auto& e){ return e.id == id; });
    if (it != brushTextures_.end()) {
        glDeleteTextures(1, &it->tex);
        brushTextures_.erase(it);
    }
}

void StrokeEngine::generateDefaultBrushTex() {
    constexpr int SIZE = 64;
    constexpr float CENTER = SIZE / 2.0f, RADIUS = SIZE / 2.0f;
    std::vector<uint8_t> pixels(SIZE * SIZE * 4);
    for (int y = 0; y < SIZE; y++) {
        for (int x = 0; x < SIZE; x++) {
            float dx = (x + 0.5f) - CENTER, dy = (y + 0.5f) - CENTER;
            float d  = std::sqrt(dx*dx + dy*dy) / RADIUS;
            float a  = std::max(0.0f, std::min(1.0f, std::exp(-4.0f * d * d)));
            int i = (y * SIZE + x) * 4;
            pixels[i+0] = pixels[i+1] = pixels[i+2] = 255;
            pixels[i+3] = (uint8_t)(a * 255);
        }
    }
    glGenTextures(1, &defaultBrushTex_);
    glBindTexture(GL_TEXTURE_2D, defaultBrushTex_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, SIZE, SIZE, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    LOGI("Default brush texture generated (%dx%d)", SIZE, SIZE);
}

bool StrokeEngine::initShaders() {
    LOGI("Compiling stroke shaders...");
    auto make = [&](const char* v, const char* f) -> GLuint {
        GLuint vs = compileShader(GL_VERTEX_SHADER, v);
        GLuint fs = compileShader(GL_FRAGMENT_SHADER, f);
        if (!vs || !fs) { if (vs) glDeleteShader(vs); if (fs) glDeleteShader(fs); return 0; }
        return linkProgram(vs, fs);
    };
    strokeProgram_ = make(kStrokeVert, kStrokeFrag);
    if (!strokeProgram_) return false;
    LOGI("Stroke program OK (%u)", strokeProgram_);
    eraserProgram_ = make(kStrokeVert, kEraserFrag);
    if (!eraserProgram_) return false;
    LOGI("Eraser program OK (%u)", eraserProgram_);
    compositeProgram_ = 0;
    return true;
}

bool StrokeEngine::initQuad() {
    glGenVertexArrays(1, &quadVAO_);
    glGenBuffers(1, &quadVBO_);
    glBindVertexArray(quadVAO_);
    glBindBuffer(GL_ARRAY_BUFFER, quadVBO_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(kQuad), kQuad, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)(2*sizeof(float)));
    glBindVertexArray(0); glBindBuffer(GL_ARRAY_BUFFER, 0);
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) { LOGE("GL error after quad setup: 0x%X", err); return false; }
    return true;
}

GLuint StrokeEngine::compileShader(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    if (!s) { LOGE("glCreateShader returned 0"); return 0; }
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok = 0; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char buf[1024]; GLsizei len = 0;
        glGetShaderInfoLog(s, sizeof(buf), &len, buf);
        LOGE("Shader compile FAILED (type=0x%X):\n%s", type, buf);
        glDeleteShader(s); return 0;
    }
    return s;
}

GLuint StrokeEngine::linkProgram(GLuint v, GLuint f) {
    GLuint p = glCreateProgram();
    glAttachShader(p, v); glAttachShader(p, f);
    glLinkProgram(p);
    glDeleteShader(v); glDeleteShader(f);
    GLint ok = 0; glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        char buf[512]; glGetProgramInfoLog(p, sizeof(buf), nullptr, buf);
        LOGE("Program link FAILED: %s", buf);
        glDeleteProgram(p); return 0;
    }
    return p;
}

} // namespace tsk
