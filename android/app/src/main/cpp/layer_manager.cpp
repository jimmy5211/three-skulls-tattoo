#include "layer_manager.h"
#include <android/log.h>
#include <algorithm>
#include <stdexcept>
#include <cstring>

#define LOG_TAG "TSK_Layer"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace tsk {

// ── GLSL shaders de composición ────────────────────────────────────────
// FIX: #version DEBE ser el primer token — sin \n previo (algunos drivers
// de Android budget lo rechazan si hay whitespace antes de #version).

static const char* kCompositeVert =
"#version 300 es\n"
"precision highp float;\n"
"layout(location = 0) in vec2 a_pos;\n"
"layout(location = 1) in vec2 a_uv;\n"
"out vec2 v_uv;\n"
"void main() {\n"
"    v_uv = a_pos * 0.5 + 0.5;\n"
"    gl_Position = vec4(a_pos, 0.0, 1.0);\n"
"}\n";

static const char* kCompositeFrag =
"#version 300 es\n"
"precision highp float;\n"
"precision mediump int;\n"
"uniform sampler2D u_src;\n"
"uniform sampler2D u_dst;\n"
"uniform float     u_opacity;\n"
"uniform int       u_blendMode;\n"
"layout(location = 0) out vec4 fragColor;\n"
"in vec2 v_uv;\n"
"\n"
"vec4 blend_normal(vec4 src, vec4 dst) {\n"
"    float a = src.a * u_opacity;\n"
"    return vec4(src.rgb * a + dst.rgb * (1.0 - a), dst.a + a * (1.0 - dst.a));\n"
"}\n"
"\n"
"vec4 blend_multiply(vec4 src, vec4 dst) {\n"
"    vec3 b = src.rgb * dst.rgb;\n"
"    float a = src.a * u_opacity;\n"
"    return vec4(mix(dst.rgb, b, a), dst.a + a * (1.0 - dst.a));\n"
"}\n"
"\n"
"vec4 blend_screen(vec4 src, vec4 dst) {\n"
"    vec3 b = 1.0 - (1.0 - src.rgb) * (1.0 - dst.rgb);\n"
"    float a = src.a * u_opacity;\n"
"    return vec4(mix(dst.rgb, b, a), dst.a + a * (1.0 - dst.a));\n"
"}\n"
"\n"
"void main() {\n"
"    vec4 src = texture(u_src, v_uv);\n"
"    vec4 dst = texture(u_dst, v_uv);\n"
"    if      (u_blendMode == -1) { fragColor = src; }\n"
"    else if (u_blendMode == 0) fragColor = blend_normal(src, dst);\n"
"    else if (u_blendMode == 1) fragColor = blend_multiply(src, dst);\n"
"    else if (u_blendMode == 2) fragColor = blend_screen(src, dst);\n"
"    else                       fragColor = blend_normal(src, dst);\n"
"}\n";

// ── Quad (fullscreen triangle pair) ───────────────────────────────────

static const float kQuadVerts[] = {
    // x      y     u     v
    -1.0f, -1.0f,  0.0f, 0.0f,
     1.0f, -1.0f,  1.0f, 0.0f,
    -1.0f,  1.0f,  0.0f, 1.0f,
     1.0f,  1.0f,  1.0f, 1.0f,
};

// ─────────────────────────────────────────────────────────────────────

LayerManager::LayerManager(int canvasW, int canvasH)
    : canvasW_(canvasW), canvasH_(canvasH) {}

LayerManager::~LayerManager() { destroy(); }

bool LayerManager::init() {
    // Limpiar errores GL previos antes de inicializar
    while (glGetError() != GL_NO_ERROR) {}

    if (!initShaders()) {
        LOGE("Failed to init composite shaders (GL error: 0x%X)", glGetError());
        return false;
    }

    // Crear quad VAO/VBO
    glGenVertexArrays(1, &quadVAO_);
    glGenBuffers(1, &quadVBO_);
    glBindVertexArray(quadVAO_);
    glBindBuffer(GL_ARRAY_BUFFER, quadVBO_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(kQuadVerts), kQuadVerts, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4*sizeof(float), (void*)(2*sizeof(float)));
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        LOGE("GL error after VAO setup: 0x%X", err);
        return false;
    }

    LOGI("LayerManager initialized (%dx%d)", canvasW_, canvasH_);
    return true;
}

void LayerManager::destroy() {
    for (auto& l : layers_) destroyLayerFBO(*l);
    layers_.clear();
    destroyCompositeFBOs();
    if (compositeProgram_) { glDeleteProgram(compositeProgram_); compositeProgram_ = 0; }
    if (quadVBO_) { glDeleteBuffers(1, &quadVBO_); quadVBO_ = 0; }
    if (quadVAO_) { glDeleteVertexArrays(1, &quadVAO_); quadVAO_ = 0; }
}

// PERF FIX: crear FBOs cacheados una sola vez en lugar de cada frame.
bool LayerManager::initCompositeFBOs(int w, int h) {
    if (cachedFBOW_ == w && cachedFBOH_ == h &&
        accumFBO_ != 0 && pingFBO_ != 0) return true; // ya OK

    destroyCompositeFBOs();

    auto makeFBO = [](GLuint& fbo, GLuint& tex, int w, int h) -> bool {
        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0,
                     GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glBindTexture(GL_TEXTURE_2D, 0);
        glGenFramebuffers(1, &fbo);
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D, tex, 0);
        GLenum st = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        return st == GL_FRAMEBUFFER_COMPLETE;
    };

    if (!makeFBO(accumFBO_, accumTex_, w, h)) return false;
    if (!makeFBO(pingFBO_,  pingTex_,  w, h)) return false;

    cachedFBOW_ = w;
    cachedFBOH_ = h;
    LOGI("Composite FBOs cached: %dx%d", w, h);
    return true;
}

void LayerManager::destroyCompositeFBOs() {
    if (accumFBO_) { glDeleteFramebuffers(1, &accumFBO_); accumFBO_ = 0; }
    if (accumTex_) { glDeleteTextures(1,    &accumTex_);  accumTex_ = 0; }
    if (pingFBO_)  { glDeleteFramebuffers(1, &pingFBO_);  pingFBO_  = 0; }
    if (pingTex_)  { glDeleteTextures(1,    &pingTex_);   pingTex_  = 0; }
    cachedFBOW_ = cachedFBOH_ = 0;
}

int LayerManager::createLayer(const std::string& name) {
    auto layer = std::make_unique<Layer>();
    layer->id     = nextId_++;
    layer->name   = name.empty() ? ("Layer " + std::to_string(layer->id)) : name;
    layer->width  = canvasW_;
    layer->height = canvasH_;

    if (!createLayerFBO(*layer)) {
        LOGE("Failed to create FBO for layer %d", layer->id);
        return -1;
    }
    // Capa nueva = transparente
    glBindFramebuffer(GL_FRAMEBUFFER, layer->fbo);
    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    int id = layer->id;
    layers_.push_back(std::move(layer));

    if (activeLayerId_ < 0) activeLayerId_ = id;
    LOGI("Layer %d created", id);
    return id;
}

void LayerManager::deleteLayer(int id) {
    auto it = std::find_if(layers_.begin(), layers_.end(),
        [id](const auto& l){ return l->id == id; });
    if (it == layers_.end()) return;
    destroyLayerFBO(**it);
    layers_.erase(it);
    if (activeLayerId_ == id && !layers_.empty()) {
        activeLayerId_ = layers_.back()->id;
    }
}

Layer* LayerManager::getLayer(int id) {
    for (auto& l : layers_) if (l->id == id) return l.get();
    return nullptr;
}

void LayerManager::setActiveLayerId(int id) {
    if (getLayer(id)) activeLayerId_ = id;
}

Layer* LayerManager::activeLayer() { return getLayer(activeLayerId_); }

void LayerManager::bindActiveLayer() {
    auto* l = activeLayer();
    if (l) {
        glBindFramebuffer(GL_FRAMEBUFFER, l->fbo);
        glViewport(0, 0, l->width, l->height);
    }
}

void LayerManager::unbindLayer() {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void LayerManager::setLayerOpacity(int id, float o) {
    if (auto* l = getLayer(id)) l->opacity = std::max(0.0f, std::min(1.0f, o));
}

void LayerManager::setLayerVisible(int id, bool v) {
    if (auto* l = getLayer(id)) l->visible = v;
}

void LayerManager::setLayerBlendMode(int id, BlendMode m) {
    if (auto* l = getLayer(id)) l->blendMode = m;
}

void LayerManager::clearLayer(int id) {
    auto* l = getLayer(id);
    if (!l) return;
    glBindFramebuffer(GL_FRAMEBUFFER, l->fbo);
    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void LayerManager::moveLayer(int fromIdx, int toIdx) {
    if (fromIdx < 0 || fromIdx >= (int)layers_.size()) return;
    if (toIdx   < 0 || toIdx   >= (int)layers_.size()) return;
    if (fromIdx == toIdx) return;
    auto tmp = std::move(layers_[fromIdx]);
    layers_.erase(layers_.begin() + fromIdx);
    layers_.insert(layers_.begin() + toIdx, std::move(tmp));
}

void LayerManager::composite(GLuint destFBO, GLuint destTexture,
                              int destW, int destH,
                              const Color& background) {
                              ) {
    // PERF FIX: reusar FBOs cacheados en lugar de crear/destruir cada frame.
    if (!initCompositeFBOs(destW, destH)) { LOGE("composite: FBO cache failed"); return; }

    // -- 1. Limpiar accumFBO con el fondo
    glBindFramebuffer(GL_FRAMEBUFFER, accumFBO_);
    glViewport(0, 0, destW, destH);
    glClearColor(background.r, background.g, background.b, background.a);
    glClear(GL_COLOR_BUFFER_BIT);

    // -- 2. Compositar capas
    glUseProgram(compositeProgram_);
    glBindVertexArray(quadVAO_);
    glDisable(GL_DEPTH_TEST);

    GLint uSrc  = glGetUniformLocation(compositeProgram_, "u_src");
    GLint uDst  = glGetUniformLocation(compositeProgram_, "u_dst");
    GLint uOpa  = glGetUniformLocation(compositeProgram_, "u_opacity");
    GLint uBlnd = glGetUniformLocation(compositeProgram_, "u_blendMode");

    GLuint currentAccum = accumTex_;
    GLuint currentFBO   = accumFBO_;
    GLuint nextAccum    = pingTex_;
    GLuint nextFBO      = pingFBO_;

    for (auto& layerPtr : layers_) {
        auto& layer = *layerPtr;
        if (!layer.visible || !layer.isValid()) continue;
        glBindFramebuffer(GL_FRAMEBUFFER, nextFBO);
        glViewport(0, 0, destW, destH);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, layer.texture);
        glUniform1i(uSrc, 0);
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, currentAccum);
        glUniform1i(uDst, 1);
        glUniform1f(uOpa,  layer.opacity);
        glUniform1i(uBlnd, static_cast<int>(layer.blendMode));
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        std::swap(currentAccum, nextAccum);
        std::swap(currentFBO,   nextFBO);
    }

    glBindVertexArray(0);
    glActiveTexture(GL_TEXTURE0);

    // -- 3. Blit resultado al outputFBO
    // Arquitectura offscreen: destFBO = outputFBO (nunca FBO 0).
    // Blit simple 1:1 — sin DPR, sin scaled blit, sin driver issues.
    glBindFramebuffer(GL_READ_FRAMEBUFFER, currentFBO);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, destFBO);
    if (destTexture != 0)
        glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D, destTexture, 0);
    glBlitFramebuffer(0, 0, destW, destH, 0, 0, destW, destH,
                      GL_COLOR_BUFFER_BIT, GL_NEAREST);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    // NO borrar FBOs -- estan cacheados
}

void LayerManager::resize(int newW, int newH) {
    canvasW_ = newW; canvasH_ = newH;
    for (auto& l : layers_) {
        destroyLayerFBO(*l);
        l->width  = newW;
        l->height = newH;
        createLayerFBO(*l);
        clearLayer(l->id);
    }
}

// ── Helpers privados ───────────────────────────────────────────────────

bool LayerManager::createLayerFBO(Layer& layer) {
    glGenTextures(1, &layer.texture);
    glBindTexture(GL_TEXTURE_2D, layer.texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8,
                 layer.width, layer.height, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glGenFramebuffers(1, &layer.fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, layer.fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, layer.texture, 0);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);

    if (status != GL_FRAMEBUFFER_COMPLETE) {
        LOGE("FBO incomplete: 0x%X", status);
        return false;
    }
    return true;
}

void LayerManager::destroyLayerFBO(Layer& layer) {
    if (layer.fbo)     { glDeleteFramebuffers(1, &layer.fbo);    layer.fbo     = 0; }
    if (layer.texture) { glDeleteTextures(1, &layer.texture);    layer.texture = 0; }
}

GLuint LayerManager::compileShader(GLenum type, const char* src) {
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

GLuint LayerManager::linkProgram(GLuint vert, GLuint frag) {
    GLuint p = glCreateProgram();
    glAttachShader(p, vert);
    glAttachShader(p, frag);
    glLinkProgram(p);
    glDeleteShader(vert);
    glDeleteShader(frag);
    GLint ok = 0;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        char buf[512];
        glGetProgramInfoLog(p, sizeof(buf), nullptr, buf);
        LOGE("Program link FAILED: %s", buf);
        glDeleteProgram(p);
        return 0;
    }
    LOGI("Shader program linked OK");
    return p;
}

bool LayerManager::initShaders() {
    LOGI("Compiling composite shaders...");
    GLuint v = compileShader(GL_VERTEX_SHADER,   kCompositeVert);
    if (!v) { LOGE("Vertex shader failed"); return false; }
    GLuint f = compileShader(GL_FRAGMENT_SHADER, kCompositeFrag);
    if (!f) { glDeleteShader(v); LOGE("Fragment shader failed"); return false; }
    compositeProgram_ = linkProgram(v, f);
    if (!compositeProgram_) { LOGE("Program link failed"); return false; }
    LOGI("Composite shaders ready (program=%u)", compositeProgram_);
    return true;
}

} // namespace tsk
