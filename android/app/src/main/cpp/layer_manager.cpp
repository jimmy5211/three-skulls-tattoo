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

static const char* kCompositeVert = R"(
#version 300 es
precision highp float;
layout(location = 0) in vec2 a_pos;
layout(location = 1) in vec2 a_uv;
out vec2 v_uv;
void main() {
    v_uv = a_uv;
    gl_Position = vec4(a_pos, 0.0, 1.0);
}
)";

// Normal blend: dst = src * src.a + dst * (1 - src.a)
static const char* kCompositeFrag = R"(
#version 300 es
precision highp float;
uniform sampler2D u_src;
uniform sampler2D u_dst;
uniform float     u_opacity;
uniform int       u_blendMode;
out vec4 fragColor;
in  vec2 v_uv;

vec4 blend_normal(vec4 src, vec4 dst) {
    float a = src.a * u_opacity;
    return vec4(src.rgb * a + dst.rgb * (1.0 - a), dst.a + a * (1.0 - dst.a));
}

vec4 blend_multiply(vec4 src, vec4 dst) {
    vec3 b = src.rgb * dst.rgb;
    float a = src.a * u_opacity;
    return vec4(mix(dst.rgb, b, a), dst.a + a * (1.0 - dst.a));
}

vec4 blend_screen(vec4 src, vec4 dst) {
    vec3 b = 1.0 - (1.0 - src.rgb) * (1.0 - dst.rgb);
    float a = src.a * u_opacity;
    return vec4(mix(dst.rgb, b, a), dst.a + a * (1.0 - dst.a));
}

void main() {
    vec4 src = texture(u_src, v_uv);
    vec4 dst = texture(u_dst, v_uv);
    if      (u_blendMode == 0) fragColor = blend_normal(src, dst);
    else if (u_blendMode == 1) fragColor = blend_multiply(src, dst);
    else if (u_blendMode == 2) fragColor = blend_screen(src, dst);
    else                       fragColor = blend_normal(src, dst);
}
)";

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
    if (!initShaders()) {
        LOGE("Failed to init composite shaders");
        return false;
    }
    // Crear quad VAO
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
    LOGI("LayerManager initialized (%dx%d)", canvasW_, canvasH_);
    return true;
}

void LayerManager::destroy() {
    for (auto& l : layers_) destroyLayerFBO(*l);
    layers_.clear();
    if (compositeProgram_) { glDeleteProgram(compositeProgram_); compositeProgram_ = 0; }
    if (quadVBO_) { glDeleteBuffers(1, &quadVBO_); quadVBO_ = 0; }
    if (quadVAO_) { glDeleteVertexArrays(1, &quadVAO_); quadVAO_ = 0; }
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
    // ── 1. Crear un FBO temporal para acumular ────────────────
    GLuint accumFBO = 0, accumTex = 0;
    glGenFramebuffers(1, &accumFBO);
    glGenTextures(1, &accumTex);
    glBindTexture(GL_TEXTURE_2D, accumTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, destW, destH, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glBindFramebuffer(GL_FRAMEBUFFER, accumFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, accumTex, 0);
    glViewport(0, 0, destW, destH);

    // ── 2. Fondo ──────────────────────────────────────────────
    glClearColor(background.r, background.g, background.b, background.a);
    glClear(GL_COLOR_BUFFER_BIT);

    // ── 3. Compositar capas de abajo hacia arriba ─────────────
    glUseProgram(compositeProgram_);
    glBindVertexArray(quadVAO_);
    glDisable(GL_DEPTH_TEST);

    GLint uSrc  = glGetUniformLocation(compositeProgram_, "u_src");
    GLint uDst  = glGetUniformLocation(compositeProgram_, "u_dst");
    GLint uOpa  = glGetUniformLocation(compositeProgram_, "u_opacity");
    GLint uBlnd = glGetUniformLocation(compositeProgram_, "u_blendMode");

    for (auto& layerPtr : layers_) {
        auto& layer = *layerPtr;
        if (!layer.visible || !layer.isValid()) continue;

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, layer.texture);
        glUniform1i(uSrc, 0);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, accumTex);
        glUniform1i(uDst, 1);

        glUniform1f(uOpa,  layer.opacity);
        glUniform1i(uBlnd, static_cast<int>(layer.blendMode));

        // Swap: render resultado en destTexture, luego copiar a accumTex
        glBindFramebuffer(GL_FRAMEBUFFER, destFBO);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, destTexture, 0);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        // Copiar destTexture → accumTex para siguiente iteración
        glBindFramebuffer(GL_READ_FRAMEBUFFER, destFBO);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, accumFBO);
        glBlitFramebuffer(0, 0, destW, destH, 0, 0, destW, destH,
                          GL_COLOR_BUFFER_BIT, GL_LINEAR);
        glBindFramebuffer(GL_FRAMEBUFFER, accumFBO);
    }

    // ── 4. Copiar resultado final a destTexture ───────────────
    glBindFramebuffer(GL_READ_FRAMEBUFFER, accumFBO);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, destFBO);
    glBlitFramebuffer(0, 0, destW, destH, 0, 0, destW, destH,
                      GL_COLOR_BUFFER_BIT, GL_LINEAR);

    // ── 5. Cleanup temporal ───────────────────────────────────
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindVertexArray(0);
    glDeleteFramebuffers(1, &accumFBO);
    glDeleteTextures(1, &accumTex);
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
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char buf[512]; glGetShaderInfoLog(s, 512, nullptr, buf);
        LOGE("Shader compile error: %s", buf);
        glDeleteShader(s);
        return 0;
    }
    return s;
}

GLuint LayerManager::linkProgram(GLuint vert, GLuint frag) {
    GLuint p = glCreateProgram();
    glAttachShader(p, vert); glAttachShader(p, frag);
    glLinkProgram(p);
    glDeleteShader(vert); glDeleteShader(frag);
    GLint ok; glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        char buf[512]; glGetProgramInfoLog(p, 512, nullptr, buf);
        LOGE("Program link error: %s", buf);
        glDeleteProgram(p);
        return 0;
    }
    return p;
}

bool LayerManager::initShaders() {
    GLuint v = compileShader(GL_VERTEX_SHADER,   kCompositeVert);
    GLuint f = compileShader(GL_FRAGMENT_SHADER, kCompositeFrag);
    if (!v || !f) return false;
    compositeProgram_ = linkProgram(v, f);
    return compositeProgram_ != 0;
}

} // namespace tsk
