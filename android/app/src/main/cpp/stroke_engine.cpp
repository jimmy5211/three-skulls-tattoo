#include "stroke_engine.h"
#include <android/log.h>
#include <cmath>
#include <cstdlib>
#include <algorithm>

#define LOG_TAG "TSK_Stroke"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace tsk {

// ── GLSL: vertex con rotación UV ─────────────────────────────────────────────
// u_rotation rota la textura alrededor del centro del stamp → naturalidad real
static const char* kStrokeVert =
"#version 300 es\n"
"precision highp float;\n"
"layout(location = 0) in vec2 a_pos;\n"
"layout(location = 1) in vec2 a_uv;\n"
"uniform vec2  u_center;\n"
"uniform float u_diameter;\n"
"uniform vec2  u_canvasSize;\n"
"uniform float u_rotation;\n"   // radianes — jitter por stamp
"out vec2 v_uv;\n"
"void main() {\n"
"    // Rotar el quad alrededor de su centro\n"
"    float c = cos(u_rotation), s = sin(u_rotation);\n"
"    vec2 rpos = vec2(c*a_pos.x - s*a_pos.y,\n"
"                    s*a_pos.x + c*a_pos.y);\n"
"    vec2 pos = u_center + rpos * u_diameter;\n"
"    vec2 ndc = (pos / u_canvasSize) * 2.0 - 1.0;\n"
"    gl_Position = vec4(ndc, 0.0, 1.0);\n"
"    // Rotar también las UVs para que la textura gire con el quad\n"
"    vec2 uv = a_uv - 0.5;\n"
"    v_uv = vec2(c*uv.x - s*uv.y, s*uv.x + c*uv.y) + 0.5;\n"
"}\n";

// ── GLSL: fragment con grano secundario ──────────────────────────────────────
// u_grain es la textura de grano (papel/carbón/tela).
// u_grainDepth controla cuánto grano se mezcla: 0=sin grano, 1=grano total.
static const char* kStrokeFrag =
"#version 300 es\n"
"precision highp float;\n"
"uniform sampler2D u_brush;\n"   // shape PNG (alpha mask)
"uniform sampler2D u_grain;\n"   // grain PNG (texture roller)
"uniform vec4      u_color;\n"
"uniform float     u_hardness;\n"
"uniform float     u_grainDepth;\n"  // 0..1
"uniform vec2      u_grainScale;\n"  // escala del grano en canvas
"uniform vec2      u_canvasPos;\n"   // posición del stamp en canvas (para anchoring)
"layout(location = 0) out vec4 fragColor;\n"
"in vec2 v_uv;\n"
"void main() {\n"
"    float mask = texture(u_brush, v_uv).a;\n"
"    float h    = min(u_hardness, 0.999);\n"
"    float edge = 0.5 * h;\n"
"    float soft = smoothstep(edge, 1.0 - edge, mask);\n"
"    // Grano: anchored en canvas (grain UVs = posición canvas, no stamp)\n"
"    vec2 grainUV = fract(u_canvasPos * u_grainScale);\n"
"    float grain  = texture(u_grain, grainUV).r;\n"
"    // Mezclar grano multiplicativamente: grano oscuro → más transparente\n"
"    float grainMask = mix(1.0, grain, u_grainDepth);\n"
"    float finalAlpha = u_color.a * soft * grainMask;\n"
"    fragColor = vec4(u_color.rgb, finalAlpha);\n"
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

static const char* kCompositeVert =
"#version 300 es\n"
"precision highp float;\n"
"layout(location = 0) in vec2 a_pos;\n"
"layout(location = 1) in vec2 a_uv;\n"
"out vec2 v_uv;\n"
"void main() {\n"
"    gl_Position = vec4(a_pos * 2.0, 0.0, 1.0);\n"
"    v_uv = a_uv;\n"
"}\n";

static const char* kCompositeEraserFrag =
"#version 300 es\n"
"precision highp float;\n"
"uniform sampler2D u_mask;\n"
"uniform float     u_opacity;\n"
"layout(location = 0) out vec4 fragColor;\n"
"in vec2 v_uv;\n"
"void main() {\n"
"    float mask = texture(u_mask, v_uv).a;\n"
"    fragColor = vec4(0.0, 0.0, 0.0, mask * u_opacity);\n"
"}\n";

static const float kQuad[] = {
    -0.5f, -0.5f,  0.0f, 0.0f,
     0.5f, -0.5f,  1.0f, 0.0f,
    -0.5f,  0.5f,  0.0f, 1.0f,
     0.5f,  0.5f,  1.0f, 1.0f,
};

// ── RNG simple determinista (no necesita stdlib rand para reproducibilidad) ──
static uint32_t s_seed = 12345;
static float fastRand() {
    s_seed ^= s_seed << 13;
    s_seed ^= s_seed >> 17;
    s_seed ^= s_seed << 5;
    return (s_seed & 0x7FFFFFFF) / (float)0x7FFFFFFF;
}
static float randRange(float lo, float hi) { return lo + fastRand() * (hi - lo); }

// ─────────────────────────────────────────────────────────────────────────────

bool StrokeEngine::init() {
    while (glGetError() != GL_NO_ERROR) {}
    if (!initShaders()) { LOGE("StrokeEngine: initShaders failed"); return false; }
    if (!initQuad())    { LOGE("StrokeEngine: initQuad failed");    return false; }
    generateDefaultBrushTex();
    LOGI("StrokeEngine initialized (with rotation + grain support)");
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

bool StrokeEngine::ensureStrokeFBO(int w, int h) {
    if (strokeFBO_ && strokeW_ == w && strokeH_ == h) return true;
    destroyStrokeFBO();
    glGenFramebuffers(1, &strokeFBO_);
    glGenTextures(1, &strokeTex_);
    glBindTexture(GL_TEXTURE_2D, strokeTex_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glBindFramebuffer(GL_FRAMEBUFFER, strokeFBO_);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, strokeTex_, 0);
    strokeW_ = w; strokeH_ = h;
    return glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
}
void StrokeEngine::destroyStrokeFBO() {
    if (strokeTex_) { glDeleteTextures(1, &strokeTex_);     strokeTex_ = 0; }
    if (strokeFBO_) { glDeleteFramebuffers(1, &strokeFBO_); strokeFBO_ = 0; }
    strokeW_ = strokeH_ = 0;
}
void StrokeEngine::compositeStrokeToLayer(GLuint layerFBO) {
    if (!compositeProgram_ || !strokeFBO_ || !strokeTex_) return;
    glBindFramebuffer(GL_FRAMEBUFFER, layerFBO);
    glViewport(0, 0, strokeW_, strokeH_);
    glUseProgram(compositeProgram_);
    glEnable(GL_BLEND);
    glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
    glBlendFuncSeparate(GL_ZERO, GL_ONE, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, strokeTex_);
    glUniform1i(glGetUniformLocation(compositeProgram_, "u_mask"), 0);
    glUniform1f(glGetUniformLocation(compositeProgram_, "u_opacity"), color_.a);
    glBindVertexArray(quadVAO_);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);
    glDisable(GL_BLEND);
}
bool StrokeEngine::initCompositeShader() {
    GLuint cv = compileShader(GL_VERTEX_SHADER,   kCompositeVert);
    GLuint cf = compileShader(GL_FRAGMENT_SHADER, kCompositeEraserFrag);
    if (!cv || !cf) { if (cv) glDeleteShader(cv); if (cf) glDeleteShader(cf); return false; }
    compositeProgram_ = linkProgram(cv, cf);
    return compositeProgram_ != 0;
}

void StrokeEngine::beginStroke(const Point& p, const BrushParams& brush,
                                const Color& color, int cw, int ch) {
    brush_     = brush;
    color_     = color;
    canvasW_   = cw;
    canvasH_   = ch;
    lastPoint_ = p;
    accDist_   = 0.0f;
    lastSpeed_ = 0.0f;
    active_    = true;
    s_seed     = (uint32_t)(p.x * 1000 + p.y);  // seed determinista por trazo
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

    // Velocidad → influye en spacing dinámico
    // Alta velocidad → stamps más separados (más natural)
    float speed   = dist;  // px por evento — approx velocidad
    lastSpeed_    = speed * 0.3f + lastSpeed_ * 0.7f;  // smooth
    float dynSpacing = brush_.spacing * (1.0f + lastSpeed_ * 0.015f);
    float spacing = std::max(1.0f, brush_.size * dynSpacing);

    accDist_ += dist;
    bool rendered = false;
    while (accDist_ >= spacing) {
        float t = (dist - (accDist_ - spacing)) / std::max(dist, 0.001f);
        Point stamp;
        stamp.x        = lastPoint_.x + dx * t;
        stamp.y        = lastPoint_.y + dy * t;
        stamp.pressure = lastPoint_.pressure + (p.pressure - lastPoint_.pressure) * t;
        renderStamp(stamp);
        accDist_ -= spacing;
        rendered = true;
    }
    lastPoint_ = p;
    return rendered;
}

void StrokeEngine::endStroke()    { active_ = false; }
void StrokeEngine::cancelStroke() { active_ = false; }

void StrokeEngine::stampAt(float x, float y) {
    if (!active_) return;
    renderStampAt(x, y, 1.0f, brush_.size, 0.0f);
}

// ── Stamp principal: aplica dinámicas (presión, jitter, rotación) ─────────────
void StrokeEngine::renderStamp(const Point& p, float diameterOverride) {
    float diameter = diameterOverride > 0 ? diameterOverride : brush_.size;

    if (!brush_.isEraser) {
        // Presión → tamaño (0.7 base + 0.3 por presión) — idéntico a Procreate
        diameter *= (0.7f + p.pressure * 0.3f);

        // Jitter de tamaño: ±10% variación aleatoria → imperfección natural
        diameter *= (1.0f + randRange(-0.10f, 0.10f));
    }

    // Rotación aleatoria por stamp (0..2π) → texturas irregulares no repiten patrón
    float rotation = randRange(0.0f, 6.2832f);

    renderStampAt(p.x, p.y, p.pressure, diameter, rotation);

    // Espejo (simetría) para pinceles — no para borrador
    if (symmetryEnabled_ && !brush_.isEraser) {
        float mx = symmetryAxis_ == 0 ? (float)canvasW_ - p.x : p.x;
        float my = symmetryAxis_ == 0 ? p.y : (float)canvasH_ - p.y;
        renderStampAt(mx, my, p.pressure, diameter, -rotation);
    }
}

// ── Render un stamp con rotación y grano ──────────────────────────────────────
void StrokeEngine::renderStampAt(float x, float y, float pressure, float diameter, float rotation) {
    GLuint prog = brush_.isEraser ? eraserProgram_ : strokeProgram_;
    glUseProgram(prog);

    glEnable(GL_BLEND);
    if (brush_.isEraser) {
        glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);
        glBlendFuncSeparate(GL_ZERO, GL_ONE, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA);
    } else {
        glBlendEquationSeparate(GL_FUNC_ADD, GL_MAX);
        glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE);
    }

    // Jitter de opacidad: ±8% → elimina "marca de sello" visible
    float opacityJitter = brush_.isEraser ? 1.0f : (1.0f + randRange(-0.08f, 0.08f));
    float finalAlpha    = std::min(1.0f, color_.a * opacityJitter);

    glUniform2f(glGetUniformLocation(prog, "u_center"),     x, y);
    glUniform1f(glGetUniformLocation(prog, "u_diameter"),   diameter);
    glUniform2f(glGetUniformLocation(prog, "u_canvasSize"), (float)canvasW_, (float)canvasH_);
    glUniform1f(glGetUniformLocation(prog, "u_hardness"),   brush_.hardness);
    glUniform1f(glGetUniformLocation(prog, "u_rotation"),   rotation);

    if (brush_.isEraser) {
        glUniform1f(glGetUniformLocation(prog, "u_opacity"), color_.a);
    } else {
        glUniform4f(glGetUniformLocation(prog, "u_color"),
                    color_.r, color_.g, color_.b, finalAlpha);

        // Grano: escala relativa al canvas (1/200 = grain repetido ~200 veces)
        // grainDepth del brush controla intensidad: 0=sin grano, 1=grano total
        glUniform1f(glGetUniformLocation(prog, "u_grainDepth"), brush_.grainDepth);
        glUniform2f(glGetUniformLocation(prog, "u_grainScale"),
                    1.0f / 200.0f, 1.0f / 200.0f);
        glUniform2f(glGetUniformLocation(prog, "u_canvasPos"), x, y);

        // Texture unit 1 = grain
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, getGrainTexture());
        glUniform1i(glGetUniformLocation(prog, "u_grain"), 1);
    }

    // Texture unit 0 = shape
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, getBrushTexture());
    glUniform1i(glGetUniformLocation(prog, "u_brush"), 0);

    glBindVertexArray(quadVAO_);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glBindVertexArray(0);

    glDisable(GL_BLEND);
    glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);

    // Restaurar texture unit 0 como activa por defecto
    glActiveTexture(GL_TEXTURE0);
}

GLuint StrokeEngine::getBrushTexture() const {
    if (brush_.brushTextureId >= 0)
        for (auto& e : brushTextures_)
            if (e.id == brush_.brushTextureId) return e.tex;
    return defaultBrushTex_;
}

GLuint StrokeEngine::getGrainTexture() const {
    // El grainTextureId se almacena como brushTextureId + 1 por convención.
    // Si no hay grain, usar el defaultBrushTex_ (Gaussian = grano invisible).
    int grainId = brush_.grainTextureId;
    if (grainId >= 0)
        for (auto& e : brushTextures_)
            if (e.id == grainId) return e.tex;
    return defaultBrushTex_;  // Gaussian como fallback → sin grano visible
}

int StrokeEngine::loadBrushTexture(const uint8_t* rgba, int w, int h) {
    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);  // grain = repeat
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glBindTexture(GL_TEXTURE_2D, 0);
    int id = nextBrushTexId_++;
    brushTextures_.push_back({id, tex, w, h});
    LOGI("loadBrushTexture: %dx%d → id=%d (total=%zu)", w, h, id, brushTextures_.size());
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

// ── Círculo Gaussian 64×64 por defecto ────────────────────────────────────────
void StrokeEngine::generateDefaultBrushTex() {
    constexpr int S = 64;
    constexpr float C = S / 2.0f, R = S / 2.0f;
    std::vector<uint8_t> px(S * S * 4);
    for (int y = 0; y < S; y++) {
        for (int x = 0; x < S; x++) {
            float dx = (x + 0.5f) - C, dy = (y + 0.5f) - C;
            float d = std::sqrt(dx*dx + dy*dy) / R;
            float a = std::max(0.0f, std::exp(-4.0f * d * d));
            int i = (y * S + x) * 4;
            px[i]=px[i+1]=px[i+2]=255;
            px[i+3] = (uint8_t)(a * 255);
        }
    }
    glGenTextures(1, &defaultBrushTex_);
    glBindTexture(GL_TEXTURE_2D, defaultBrushTex_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, S, S, 0, GL_RGBA, GL_UNSIGNED_BYTE, px.data());
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    LOGI("Default brush Gaussian 64x64 OK");
}

// ── GL helpers ────────────────────────────────────────────────────────────────
bool StrokeEngine::initShaders() {
    LOGI("Compiling stroke shaders (rotation + grain)...");
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
    initCompositeShader();
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
    return glGetError() == GL_NO_ERROR;
}

GLuint StrokeEngine::compileShader(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    if (!s) return 0;
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok = 0; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char buf[1024]; GLsizei len = 0;
        glGetShaderInfoLog(s, sizeof(buf), &len, buf);
        LOGE("Shader FAILED (0x%X):\n%s", type, buf);
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
