#include "stroke_engine.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>

#define LOG_TAG "TSK_Stroke"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace tsk {

// ── GLSL shaders ──────────────────────────────────────────────────────
// FIX: #version debe ser el primer token — sin \n previo.
// Usar string literals concatenadas en lugar de raw strings con \n inicial.

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
"    // distance-based hardness: edge0->edge1 controls sharpness\n"
"    vec2  center = vec2(0.5, 0.5);\n"
"    float dist   = distance(v_uv, center);\n"
"    float h      = clamp(pow(u_hardness, 2.2), 0.001, 1.0);\n"
"    float edge0  = 0.5 * (1.0 - h);\n"
"    float edge1  = 0.5;\n"
"    float alpha  = 1.0 - smoothstep(edge0, edge1, dist);\n"
"    // Multiply by brush texture for non-circular brush shapes\n"
"    float mask   = texture(u_brush, v_uv).a;\n"
"    fragColor = vec4(u_color.rgb, u_color.a * alpha * mask);\n"
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
"    vec2  center = vec2(0.5, 0.5);\n"
"    float dist   = distance(v_uv, center);\n"
"    float h      = clamp(pow(u_hardness, 2.2), 0.001, 1.0);\n"
"    float edge0  = 0.5 * (1.0 - h);\n"
"    float edge1  = 0.5;\n"
"    float alpha  = 1.0 - smoothstep(edge0, edge1, dist);\n"
"    float mask   = texture(u_brush, v_uv).a;\n"
"    fragColor = vec4(0.0, 0.0, 0.0, u_opacity * alpha * mask);\n"
"}\n";

// ── Quad vertices (-0.5..0.5 con UV 0..1) ────────────────────────────

static const float kQuad[] = {
    -0.5f, -0.5f,  0.0f, 0.0f,
     0.5f, -0.5f,  1.0f, 0.0f,
    -0.5f,  0.5f,  0.0f, 1.0f,
     0.5f,  0.5f,  1.0f, 1.0f,
};

// ─────────────────────────────────────────────────────────────────────

bool StrokeEngine::init() {
    // Limpiar errores GL previos
    while (glGetError() != GL_NO_ERROR) {}

    if (!initShaders()) { LOGE("StrokeEngine: initShaders failed"); return false; }
    if (!initQuad())    { LOGE("StrokeEngine: initQuad failed");    return false; }
    generateDefaultBrushTex();
    LOGI("StrokeEngine initialized");
    return true;
}

void StrokeEngine::destroy() {
    if (strokeProgram_)   { glDeleteProgram(strokeProgram_);        strokeProgram_   = 0; }
    if (eraserProgram_)   { glDeleteProgram(eraserProgram_);        eraserProgram_   = 0; }
    if (quadVBO_)         { glDeleteBuffers(1, &quadVBO_);          quadVBO_         = 0; }
    if (quadVAO_)         { glDeleteVertexArrays(1, &quadVAO_);     quadVAO_         = 0; }
    if (defaultBrushTex_) { glDeleteTextures(1, &defaultBrushTex_); defaultBrushTex_ = 0; }
    for (auto& e : brushTextures_) glDeleteTextures(1, &e.tex);
    brushTextures_.clear();
}

void StrokeEngine::beginStroke(const Point& p, const BrushParams& brush,
                                const Color& color, int cw, int ch) {
    brush_     = brush;
    color_     = color;
    canvasW_   = cw;
    canvasH_   = ch;
    lastPoint_ = p;
    accDist_   = 0.0f;
    active_    = true;
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
        float t       = (dist - (accDist_ - spacing)) / std::max(dist, 0.001f);
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

// ── Render un stamp ────────────────────────────────────────────────────

void StrokeEngine::renderStamp(const Point& p, float diameterOverride) {
    float diameter = diameterOverride > 0 ? diameterOverride : brush_.size;
    diameter *= (0.7f + p.pressure * 0.3f);

    GLuint prog = brush_.isEraser ? eraserProgram_ : strokeProgram_;
    glUseProgram(prog);

    if (brush_.isEraser) {
        glBlendFuncSeparate(GL_ZERO, GL_ONE,
                            GL_ZERO, GL_ONE_MINUS_SRC_ALPHA);
    } else {
        glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA,
                            GL_ONE,       GL_ONE_MINUS_SRC_ALPHA);
    }
    glEnable(GL_BLEND);

    glUniform2f(glGetUniformLocation(prog, "u_center"),     p.x, p.y);
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
}

// ── Brush textures ──────────────────────────────────────────────────────

GLuint StrokeEngine::getBrushTexture() const {
    if (brush_.brushTextureId >= 0) {
        for (auto& e : brushTextures_)
            if (e.id == brush_.brushTextureId) return e.tex;
    }
    return defaultBrushTex_;
}

int StrokeEngine::loadBrushTexture(const uint8_t* rgba, int w, int h) {
    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, rgba);
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

// ── Generar círculo gaussiano default 64×64 ────────────────────────────

void StrokeEngine::generateDefaultBrushTex() {
    constexpr int SIZE = 64;
    constexpr float CENTER = SIZE / 2.0f;
    constexpr float RADIUS = SIZE / 2.0f;

    std::vector<uint8_t> pixels(SIZE * SIZE * 4);
    for (int y = 0; y < SIZE; y++) {
        for (int x = 0; x < SIZE; x++) {
            float dx = (x + 0.5f) - CENTER;
            float dy = (y + 0.5f) - CENTER;
            float d  = std::sqrt(dx*dx + dy*dy) / RADIUS;
            float a  = std::exp(-4.0f * d * d);
            a = std::max(0.0f, std::min(1.0f, a));
            int i = (y * SIZE + x) * 4;
            pixels[i+0] = 255;
            pixels[i+1] = 255;
            pixels[i+2] = 255;
            pixels[i+3] = (uint8_t)(a * 255);
        }
    }

    glGenTextures(1, &defaultBrushTex_);
    glBindTexture(GL_TEXTURE_2D, defaultBrushTex_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, SIZE, SIZE, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    LOGI("Default brush texture generated (%dx%d)", SIZE, SIZE);
}

// ── GL helpers ─────────────────────────────────────────────────────────

// FIX: initShaders compila shaders frescos para cada programa.
// linkProgram() borra los shaders después de linkear — no se pueden reusar.
bool StrokeEngine::initShaders() {
    LOGI("Compiling stroke shaders...");

    // Programa de pincel (stroke)
    GLuint sv1 = compileShader(GL_VERTEX_SHADER,   kStrokeVert);
    GLuint sf1 = compileShader(GL_FRAGMENT_SHADER, kStrokeFrag);
    if (!sv1 || !sf1) {
        if (sv1) glDeleteShader(sv1);
        if (sf1) glDeleteShader(sf1);
        return false;
    }
    strokeProgram_ = linkProgram(sv1, sf1); // borra sv1, sf1
    if (!strokeProgram_) return false;
    LOGI("Stroke program linked OK (%u)", strokeProgram_);

    // Programa de borrador (eraser) — compilar vertex de nuevo
    GLuint ev1 = compileShader(GL_VERTEX_SHADER,   kStrokeVert);
    GLuint ef2 = compileShader(GL_FRAGMENT_SHADER, kEraserFrag);
    if (!ev1 || !ef2) {
        if (ev1) glDeleteShader(ev1);
        if (ef2) glDeleteShader(ef2);
        return false;
    }
    eraserProgram_ = linkProgram(ev1, ef2); // borra ev1, ef2
    if (!eraserProgram_) return false;
    LOGI("Eraser program linked OK (%u)", eraserProgram_);

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
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float),
                          (void*)(2*sizeof(float)));
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        LOGE("GL error after quad setup: 0x%X", err);
        return false;
    }
    return true;
}

GLuint StrokeEngine::compileShader(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    if (s == 0) {
        LOGE("glCreateShader returned 0 (GL error: 0x%X)", glGetError());
        return 0;
    }
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char buf[1024];
        GLsizei len = 0;
        glGetShaderInfoLog(s, sizeof(buf), &len, buf);
        LOGE("Shader compile FAILED (type=0x%X):\n%s", type, buf);
        glDeleteShader(s);
        return 0;
    }
    LOGI("Shader compiled OK (type=0x%X)", type);
    return s;
}

GLuint StrokeEngine::linkProgram(GLuint v, GLuint f) {
    GLuint p = glCreateProgram();
    glAttachShader(p, v);
    glAttachShader(p, f);
    glLinkProgram(p);
    glDeleteShader(v);
    glDeleteShader(f);
    GLint ok = 0;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        char buf[512];
        glGetProgramInfoLog(p, sizeof(buf), nullptr, buf);
        LOGE("Program link FAILED: %s", buf);
        glDeleteProgram(p);
        return 0;
    }
    return p;
}

} // namespace tsk
