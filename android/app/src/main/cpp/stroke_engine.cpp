#include "stroke_engine.h"
#include <android/log.h>
#include <cmath>
#include <algorithm>

#define LOG_TAG "TSK_Stroke"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace tsk {

// ── GLSL shaders ──────────────────────────────────────────────────────

// Vertex: transforma el quad al espacio de la posición del stamp
static const char* kStrokeVert = R"(
#version 300 es
precision highp float;
layout(location = 0) in vec2 a_pos;     // -0.5..0.5 quad
layout(location = 1) in vec2 a_uv;      // 0..1 uv
uniform vec2  u_center;    // posición del stamp en canvas (px)
uniform float u_diameter;  // diámetro del stamp en canvas (px)
uniform vec2  u_canvasSize;// tamaño del canvas (px)
out vec2 v_uv;
void main() {
    // Posición del stamp en NDC
    vec2 pos = u_center + a_pos * u_diameter;
    vec2 ndc = (pos / u_canvasSize) * 2.0 - 1.0;
    ndc.y = -ndc.y; // flip Y (OpenGL es bottom-up)
    gl_Position = vec4(ndc, 0.0, 1.0);
    v_uv = a_uv;
}
)";

// Fragment: dibuja el stamp usando brush texture + hardness
static const char* kStrokeFrag = R"(
#version 300 es
precision highp float;
uniform sampler2D u_brush;   // brush texture (alpha mask)
uniform vec4      u_color;   // rgba del pincel
uniform float     u_hardness;// 0.0=suave, 1.0=duro
out vec4 fragColor;
in  vec2 v_uv;
void main() {
    float mask = texture(u_brush, v_uv).a;
    // Ajustar dureza: hardness=1 → sin suavizado, hardness=0 → máximo suavizado
    float edge = mix(0.5, 0.0, u_hardness);
    float soft = smoothstep(edge, 1.0 - edge, mask);
    fragColor  = vec4(u_color.rgb, u_color.a * soft);
}
)";

// Eraser: usa dstOut blend — borra usando el mismo shape
static const char* kEraserFrag = R"(
#version 300 es
precision highp float;
uniform sampler2D u_brush;
uniform float     u_opacity;
uniform float     u_hardness;
out vec4 fragColor;
in  vec2 v_uv;
void main() {
    float mask = texture(u_brush, v_uv).a;
    float edge = mix(0.5, 0.0, u_hardness);
    float soft = smoothstep(edge, 1.0 - edge, mask);
    fragColor  = vec4(0.0, 0.0, 0.0, u_opacity * soft);
}
)";

// ── Quad vertices (-0.5..0.5 con UV 0..1) ────────────────────────────

static const float kQuad[] = {
    -0.5f, -0.5f,  0.0f, 0.0f,
     0.5f, -0.5f,  1.0f, 0.0f,
    -0.5f,  0.5f,  0.0f, 1.0f,
     0.5f,  0.5f,  1.0f, 1.0f,
};

// ─────────────────────────────────────────────────────────────────────

bool StrokeEngine::init() {
    if (!initShaders()) return false;
    if (!initQuad())    return false;
    generateDefaultBrushTex();
    LOGI("StrokeEngine initialized");
    return true;
}

void StrokeEngine::destroy() {
    if (strokeProgram_)   { glDeleteProgram(strokeProgram_);   strokeProgram_  = 0; }
    if (eraserProgram_)   { glDeleteProgram(eraserProgram_);   eraserProgram_  = 0; }
    if (quadVBO_)         { glDeleteBuffers(1, &quadVBO_);      quadVBO_        = 0; }
    if (quadVAO_)         { glDeleteVertexArrays(1, &quadVAO_); quadVAO_        = 0; }
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
    // Presión modula el tamaño (±30%)
    diameter *= (0.7f + p.pressure * 0.3f);

    GLuint prog = brush_.isEraser ? eraserProgram_ : strokeProgram_;
    glUseProgram(prog);

    // Blend: normal para pincel, dstOut para borrador
    if (brush_.isEraser) {
        // Borrar = multiplicar el alpha del destino por 0
        glBlendFuncSeparate(GL_ZERO, GL_ONE,
                            GL_ZERO, GL_ONE_MINUS_SRC_ALPHA);
    } else {
        glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA,
                            GL_ONE,       GL_ONE_MINUS_SRC_ALPHA);
    }
    glEnable(GL_BLEND);

    // Uniforms
    GLint uCenter   = glGetUniformLocation(prog, "u_center");
    GLint uDiam     = glGetUniformLocation(prog, "u_diameter");
    GLint uCanvas   = glGetUniformLocation(prog, "u_canvasSize");
    GLint uHard     = glGetUniformLocation(prog, "u_hardness");
    glUniform2f(uCenter,  p.x, p.y);
    glUniform1f(uDiam,    diameter);
    glUniform2f(uCanvas,  (float)canvasW_, (float)canvasH_);
    glUniform1f(uHard,    brush_.hardness);

    if (brush_.isEraser) {
        GLint uOpa = glGetUniformLocation(prog, "u_opacity");
        glUniform1f(uOpa, color_.a);
    } else {
        GLint uColor = glGetUniformLocation(prog, "u_color");
        glUniform4f(uColor, color_.r, color_.g, color_.b, color_.a);
    }

    // Textura del pincel
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, getBrushTexture());
    glUniform1i(glGetUniformLocation(prog, "u_brush"), 0);

    // Draw
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

// ── Generar círculo gaussiano default 64×64 ────────────────────────────

void StrokeEngine::generateDefaultBrushTex() {
    constexpr int SIZE = 64;
    constexpr float CENTER = SIZE / 2.0f;
    constexpr float RADIUS = SIZE / 2.0f;

    std::vector<uint8_t> pixels(SIZE * SIZE * 4);
    for (int y = 0; y < SIZE; y++) {
        for (int x = 0; x < SIZE; x++) {
            float dx  = (x + 0.5f) - CENTER;
            float dy  = (y + 0.5f) - CENTER;
            float d   = std::sqrt(dx*dx + dy*dy) / RADIUS;
            // Gaussiana suave: e^(-4 * d^2)
            float a   = std::exp(-4.0f * d * d);
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

bool StrokeEngine::initShaders() {
    auto v1 = compileShader(GL_VERTEX_SHADER,   kStrokeVert);
    auto f1 = compileShader(GL_FRAGMENT_SHADER, kStrokeFrag);
    auto f2 = compileShader(GL_FRAGMENT_SHADER, kEraserFrag);
    if (!v1 || !f1 || !f2) return false;

    strokeProgram_ = linkProgram(v1, f1);
    // vertex shader can be reused
    auto v2 = compileShader(GL_VERTEX_SHADER, kStrokeVert);
    eraserProgram_ = linkProgram(v2, f2);
    return strokeProgram_ && eraserProgram_;
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
    glBindVertexArray(0);
    return true;
}

GLuint StrokeEngine::compileShader(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char buf[512]; glGetShaderInfoLog(s, 512, nullptr, buf);
        LOGE("Shader compile error: %s", buf);
        glDeleteShader(s); return 0;
    }
    return s;
}

GLuint StrokeEngine::linkProgram(GLuint v, GLuint f) {
    GLuint p = glCreateProgram();
    glAttachShader(p, v); glAttachShader(p, f);
    glLinkProgram(p);
    glDeleteShader(v); glDeleteShader(f);
    GLint ok; glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        char buf[512]; glGetProgramInfoLog(p, 512, nullptr, buf);
        LOGE("Program link error: %s", buf);
        glDeleteProgram(p); return 0;
    }
    return p;
}

} // namespace tsk
