#include "drawing_engine.h"
#include "layer_manager.h"
#include "stroke_engine.h"
#include <android/log.h>
#include <deque>
#include <functional>

#define LOG_TAG "TSK_Engine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace tsk {

// ── Command pattern para undo/redo ─────────────────────────────────────
// Cada operación guarda solo los píxeles afectados (ROI), no toda la capa.

struct Command {
    int     layerId;
    int     x, y, w, h;           // región afectada (bounding box del trazo)
    std::vector<uint8_t> before;   // píxeles RGBA antes del trazo
    std::vector<uint8_t> after;    // píxeles RGBA después

    void captureRegion(GLuint fbo, int cx, int cy, int cw, int ch,
                       int canvasW, int canvasH,
                       std::vector<uint8_t>& buf) {
        // Clamp a bounds del canvas
        int x0 = std::max(0, cx - cw/2 - 4);
        int y0 = std::max(0, cy - ch/2 - 4);
        int x1 = std::min(canvasW,  cx + cw/2 + 4);
        int y1 = std::min(canvasH, cy + ch/2 + 4);
        x = x0; y = y0; w = x1-x0; h = y1-y0;
        if (w <= 0 || h <= 0) return;
        buf.resize(w * h * 4);
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glReadPixels(x, y, w, h, GL_RGBA, GL_UNSIGNED_BYTE, buf.data());
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

    void restoreRegion(GLuint fbo, const std::vector<uint8_t>& buf) {
        if (buf.empty() || w <= 0 || h <= 0) return;
        GLuint tex;
        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, buf.data());
        // Copiar texture → FBO en la región correcta
        // (usamos glBlitFramebuffer vía un FBO temporal)
        GLuint tmpFBO;
        glGenFramebuffers(1, &tmpFBO);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, tmpFBO);
        glFramebufferTexture2D(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fbo);
        glBlitFramebuffer(0, 0, w, h,
                          x, y, x+w, y+h,
                          GL_COLOR_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glDeleteFramebuffers(1, &tmpFBO);
        glDeleteTextures(1, &tex);
    }
};

// ── Impl (detalles privados del engine) ────────────────────────────────

// Error string global para diagnóstico
static std::string g_lastError = "no error";

struct DrawingEngine::Impl {
    EGLDisplay   eglDisplay = EGL_NO_DISPLAY;
    EGLContext   eglContext = EGL_NO_CONTEXT;
    EGLContext   ownContext = EGL_NO_CONTEXT;
    EGLSurface   ownSurface= EGL_NO_SURFACE;

    EngineConfig cfg;
    int          viewW = 0, viewH = 0;

    std::unique_ptr<LayerManager> layerMgr;
    std::unique_ptr<StrokeEngine> strokeEng;

    // Texture destino (el que Flutter muestra)
    GLuint outputTexture = 0;
    GLuint outputFBO     = 0;

    // Background
    Color background = {1,1,1,1};

    // Undo/Redo
    int maxUndoSteps = 20;
    std::deque<Command> undoStack;
    std::deque<Command> redoStack;
    Command pendingCmd;          // captura "before" al inicio del trazo
    bool    capturingStroke = false;

    // Bounding box acumulado del trazo actual
    float strokeMinX = 1e9f, strokeMinY = 1e9f;
    float strokeMaxX =-1e9f, strokeMaxY =-1e9f;

    void updateStrokeBB(const Point& p, float radius) {
        strokeMinX = std::min(strokeMinX, p.x - radius);
        strokeMinY = std::min(strokeMinY, p.y - radius);
        strokeMaxX = std::max(strokeMaxX, p.x + radius);
        strokeMaxY = std::max(strokeMaxY, p.y + radius);
    }

    bool makeCurrent() {
        EGLContext ctx = eglGetCurrentContext();
        if (ctx == EGL_NO_CONTEXT) {
            g_lastError = "no_egl_context";
            LOGE("makeCurrent: no EGL context");
            return false;
        }
        EGLSurface surf = eglGetCurrentSurface(EGL_DRAW);
        if (surf == EGL_NO_SURFACE) {
            g_lastError = "no_egl_surface";
            LOGE("makeCurrent: no EGL surface");
            return false;
        }
        return true;
    }

    void doneCurrent() {
        // No-op: Kotlin gestiona EGL
        // eglSwapBuffers se llama desde Kotlin después de render()
    }
};

// ── Singleton ──────────────────────────────────────────────────────────

DrawingEngine& DrawingEngine::get() {
    static DrawingEngine instance;
    return instance;
}

// FIX: destructor definido en .cpp — Impl debe estar completo al destruir
DrawingEngine::~DrawingEngine() { destroy(); }

// Accesible desde JNI para reportar el último error al Flutter
const char* DrawingEngine::getLastError() {
    return g_lastError.c_str();
}

#define INIT_FAIL(msg) do {     g_lastError = std::string(msg);     LOGE("INIT_FAIL: %s", msg);     return false; } while(0)

// ── Init ───────────────────────────────────────────────────────────────

bool DrawingEngine::init(EGLDisplay display, EGLContext sharedContext,
                          int width, int height, GLuint targetTextureId,
                          const EngineConfig& cfg) {
    impl_ = std::make_unique<Impl>();
    impl_->cfg        = cfg;
    impl_->viewW      = width;
    impl_->viewH      = height;
    impl_->eglDisplay = display;
    impl_->eglContext = sharedContext; // contexto de Kotlin (ya activo en GL thread)
    impl_->maxUndoSteps = cfg.maxUndoSteps;

    // ── Estrategia: reusar el contexto EGL ya activo de Kotlin ────────
    // Kotlin ya creó un EGL context y lo hizo current en el GL thread.
    // En lugar de crear otro contexto compartido (propenso a crashes),
    // usamos el mismo contexto — todo corre en el mismo GL thread.
    impl_->ownContext = sharedContext;   // mismo contexto
    impl_->ownSurface = eglGetCurrentSurface(EGL_DRAW); // superficie ya activa

    // Verificar que hay un contexto activo
    EGLContext currentCtx = eglGetCurrentContext();
    if (currentCtx == EGL_NO_CONTEXT) {
        LOGE("No EGL context is current on this thread");
        return false;
    }
    LOGI("Reusing Kotlin EGL context: %p", (void*)currentCtx);

    // makeCurrent es trivial porque ya estamos en el contexto correcto
    // Solo verificamos que podemos usar el contexto

    // ── Output render target = FBO 0 (la WindowSurface de Kotlin) ──
    // No usamos FBO custom ni textura custom.
    // Kotlin crea una EGL WindowSurface del SurfaceTexture de Flutter.
    // El motor C++ renderiza al framebuffer 0 que ES esa window surface.
    // eglSwapBuffers (llamado desde Kotlin) actualiza el Texture widget.
    impl_->outputTexture = 0; // no se usa
    impl_->outputFBO     = 0; // framebuffer 0 = window surface
    LOGI("Using WindowSurface (FBO 0) — canvas=%dx%d",
         cfg.canvasWidth, cfg.canvasHeight);

    // Verificar que tenemos un contexto GL activo
    GLenum glErr = glGetError();
    LOGI("GL context active, initial error: 0x%X", glErr);

    // ── Subsistemas ───────────────────────────────────────────
    impl_->layerMgr  = std::make_unique<LayerManager>(cfg.canvasWidth, cfg.canvasHeight);
    impl_->strokeEng = std::make_unique<StrokeEngine>();

    if (!impl_->layerMgr->init())  { g_lastError = "layer_manager_init_failed"; LOGE("LayerManager init failed"); return false; }
    if (!impl_->strokeEng->init()) { g_lastError = "stroke_engine_init_failed"; LOGE("StrokeEngine init failed"); return false; }

    // Crear capa inicial
    impl_->layerMgr->createLayer("Layer 1");

    impl_->doneCurrent();
    ready_ = true;
    LOGI("DrawingEngine initialized: canvas=%dx%d",
         cfg.canvasWidth, cfg.canvasHeight);
    return true;
}

// ── initWithCode ───────────────────────────────────────────────────────
// Wraps init() and returns a numeric error code for JNI diagnostics

int DrawingEngine::initWithCode(EGLDisplay display, EGLContext sharedContext,
                                 int width, int height, GLuint targetTextureId,
                                 const EngineConfig& cfg) {
    // Check EGL state before calling init
    EGLContext ctx  = eglGetCurrentContext();
    EGLSurface surf = eglGetCurrentSurface(EGL_DRAW);
    if (ctx  == EGL_NO_CONTEXT)  { g_lastError = "no_egl_context"; return 1; }
    if (surf == EGL_NO_SURFACE)  { g_lastError = "no_egl_surface"; return 2; }

    impl_ = std::make_unique<Impl>();
    impl_->cfg        = cfg;
    impl_->eglDisplay = display;
    impl_->eglContext = sharedContext;
    impl_->maxUndoSteps = cfg.maxUndoSteps;
    impl_->outputFBO     = 0;
    impl_->outputTexture = 0;

    LOGI("initWithCode: canvas=%dx%d  physSurface=%dx%d",
         cfg.canvasWidth, cfg.canvasHeight, width, height);

    // Init LayerManager
    impl_->layerMgr = std::make_unique<LayerManager>(cfg.canvasWidth, cfg.canvasHeight);
    if (!impl_->layerMgr->init()) {
        g_lastError = "layer_manager_init_failed";
        LOGE("LayerManager init FAILED");
        return 3;
    }

    // Init StrokeEngine
    impl_->strokeEng = std::make_unique<StrokeEngine>();
    if (!impl_->strokeEng->init()) {
        g_lastError = "stroke_engine_init_failed";
        LOGE("StrokeEngine init FAILED");
        return 4;
    }

    // Create initial layer
    impl_->layerMgr->createLayer("Layer 1");

    ready_ = true;
    g_lastError = "init_ok";
    LOGI("initWithCode: SUCCESS");
    return 0;
}

// ── Render ─────────────────────────────────────────────────────────────

void DrawingEngine::render() {
    if (!ready_) return;
    if (!impl_->makeCurrent()) return;

    // FIX DPR: viewW/viewH = dimensiones fisicas del EGL surface (del Kotlin eglQuerySurface).
    // canvasW/canvasH = canvas logico = usado en u_canvasSize del shader.
    // El blit escala canvasLogico → physico, llenando el surface completo.
    // Esto evita el scale factor en el SurfaceTexture transform matrix de Flutter.
    int cW = impl_->cfg.canvasWidth;
    int cH = impl_->cfg.canvasHeight;
    int surfW = (impl_->viewW > cW) ? impl_->viewW : cW;
    int surfH = (impl_->viewH > cH) ? impl_->viewH : cH;

    glViewport(0, 0, surfW, surfH);

    impl_->layerMgr->composite(
        0, 0,
        cW, cH,
        impl_->background,
        surfW, surfH
    );
    glFlush();
    impl_->doneCurrent();
}

// ── Stroke lifecycle ────────────────────────────────────────────────────

void DrawingEngine::beginStroke(int layerId, const Point& p,
                                  const BrushParams& brush, const Color& color) {
    if (!ready_) return;
    if (!impl_->makeCurrent()) return;

    auto* layer = impl_->layerMgr->getLayer(layerId);
    if (!layer) { impl_->doneCurrent(); return; }

    // Capturar estado "antes" para undo
    impl_->pendingCmd = Command{};
    impl_->pendingCmd.layerId = layerId;
    impl_->strokeMinX = p.x; impl_->strokeMinY = p.y;
    impl_->strokeMaxX = p.x; impl_->strokeMaxY = p.y;
    impl_->capturingStroke = true;

    impl_->layerMgr->bindActiveLayer();
    impl_->strokeEng->beginStroke(p, brush, color,
                                   impl_->cfg.canvasWidth, impl_->cfg.canvasHeight);
    impl_->layerMgr->unbindLayer();
    impl_->updateStrokeBB(p, brush.size * 0.5f);

    impl_->doneCurrent();
}

void DrawingEngine::addPoint(const Point& p) {
    if (!ready_ || !impl_->strokeEng->isActive()) return;
    if (!impl_->makeCurrent()) return;

    impl_->layerMgr->bindActiveLayer();
    impl_->strokeEng->addPoint(p);
    impl_->layerMgr->unbindLayer();

    if (impl_->capturingStroke)
        impl_->updateStrokeBB(p, impl_->strokeEng ? 10.0f : 10.0f);

    impl_->doneCurrent();
}

void DrawingEngine::endStroke() {
    if (!ready_) return;
    if (!impl_->makeCurrent()) return;

    impl_->strokeEng->endStroke();

    // Guardar en undo stack
    if (impl_->capturingStroke) {
        auto* layer = impl_->layerMgr->getLayer(impl_->pendingCmd.layerId);
        if (layer) {
            auto& cmd = impl_->pendingCmd;
            float midX = (impl_->strokeMinX + impl_->strokeMaxX) * 0.5f;
            float midY = (impl_->strokeMinY + impl_->strokeMaxY) * 0.5f;
            float bbW  =  impl_->strokeMaxX - impl_->strokeMinX;
            float bbH  =  impl_->strokeMaxY - impl_->strokeMinY;
            // captureRegion usa int
            cmd.captureRegion(layer->fbo,
                (int)midX, (int)midY, (int)(bbW+4), (int)(bbH+4),
                impl_->cfg.canvasWidth, impl_->cfg.canvasHeight,
                cmd.after);
            impl_->undoStack.push_back(std::move(cmd));
            while ((int)impl_->undoStack.size() > impl_->maxUndoSteps)
                impl_->undoStack.pop_front();
            impl_->redoStack.clear();
        }
        impl_->capturingStroke = false;
    }

    impl_->doneCurrent();
    render();
}

void DrawingEngine::cancelStroke() {
    if (!ready_) return;
    impl_->strokeEng->cancelStroke();
    impl_->capturingStroke = false;
}

// ── Undo / Redo ────────────────────────────────────────────────────────

void DrawingEngine::undo() {
    if (!ready_ || impl_->undoStack.empty()) return;
    if (!impl_->makeCurrent()) return;

    auto cmd = std::move(impl_->undoStack.back());
    impl_->undoStack.pop_back();

    auto* layer = impl_->layerMgr->getLayer(cmd.layerId);
    if (layer) {
        // Capturar after (para redo)
        cmd.captureRegion(layer->fbo,
            cmd.x + cmd.w/2, cmd.y + cmd.h/2, cmd.w, cmd.h,
            impl_->cfg.canvasWidth, impl_->cfg.canvasHeight,
            cmd.after);
        cmd.restoreRegion(layer->fbo, cmd.before);
    }

    impl_->redoStack.push_back(std::move(cmd));
    impl_->doneCurrent();
    render();
}

void DrawingEngine::redo() {
    if (!ready_ || impl_->redoStack.empty()) return;
    if (!impl_->makeCurrent()) return;

    auto cmd = std::move(impl_->redoStack.back());
    impl_->redoStack.pop_back();

    auto* layer = impl_->layerMgr->getLayer(cmd.layerId);
    if (layer) cmd.restoreRegion(layer->fbo, cmd.after);

    impl_->undoStack.push_back(std::move(cmd));
    impl_->doneCurrent();
    render();
}

bool DrawingEngine::canUndo() const {
    return ready_ && !impl_->undoStack.empty();
}
bool DrawingEngine::canRedo() const {
    return ready_ && !impl_->redoStack.empty();
}

// ── Capas ───────────────────────────────────────────────────────────────

int  DrawingEngine::addLayer(const std::string& name) {
    if (!ready_) return -1;
    if (!impl_->makeCurrent()) return -1;
    int id = impl_->layerMgr->createLayer(name);
    impl_->doneCurrent();
    render();
    return id;
}

void DrawingEngine::removeLayer(int id) {
    if (!ready_) return;
    if (!impl_->makeCurrent()) return;
    impl_->layerMgr->deleteLayer(id);
    impl_->doneCurrent();
    render();
}

void DrawingEngine::setActiveLayer(int id) {
    if (ready_) impl_->layerMgr->setActiveLayerId(id);
}

void DrawingEngine::setLayerOpacity(int id, float o) {
    if (ready_) { impl_->layerMgr->setLayerOpacity(id, o); render(); }
}

void DrawingEngine::setLayerBlendMode(int id, BlendMode m) {
    if (ready_) { impl_->layerMgr->setLayerBlendMode(id, m); render(); }
}

void DrawingEngine::setLayerVisible(int id, bool v) {
    if (ready_) { impl_->layerMgr->setLayerVisible(id, v); render(); }
}

void DrawingEngine::moveLayer(int from, int to) {
    if (!ready_) return;
    if (!impl_->makeCurrent()) return;
    impl_->layerMgr->moveLayer(from, to);
    impl_->doneCurrent();
    render();
}

void DrawingEngine::clearLayer(int id) {
    if (!ready_) return;
    if (!impl_->makeCurrent()) return;
    impl_->layerMgr->clearLayer(id);
    impl_->doneCurrent();
    render();
}

void DrawingEngine::setBackground(const Color& c) {
    if (ready_) { impl_->background = c; render(); }
}

void DrawingEngine::setCanvasSize(int w, int h) {
    if (!ready_) return;
    if (!impl_->makeCurrent()) return;
    impl_->cfg.canvasWidth  = w;
    impl_->cfg.canvasHeight = h;
    impl_->layerMgr->resize(w, h);
    impl_->doneCurrent();
    render();
}

// ── Export ──────────────────────────────────────────────────────────────

std::vector<uint8_t> DrawingEngine::exportPixels(int* outW, int* outH) {
    if (!ready_) return {};
    if (!impl_->makeCurrent()) return {};

    int w = impl_->cfg.canvasWidth;
    int h = impl_->cfg.canvasHeight;
    std::vector<uint8_t> pixels(w * h * 4);

    glBindFramebuffer(GL_FRAMEBUFFER, impl_->outputFBO);
    glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    impl_->doneCurrent();
    if (outW) *outW = w;
    if (outH) *outH = h;
    return pixels;
}

// ── Brush textures ──────────────────────────────────────────────────────

int DrawingEngine::loadBrushTexture(const uint8_t* rgba, int w, int h) {
    if (!ready_) return -1;
    if (!impl_->makeCurrent()) return -1;
    int id = impl_->strokeEng->loadBrushTexture(rgba, w, h);
    impl_->doneCurrent();
    return id;
}

void DrawingEngine::unloadBrushTexture(int id) {
    if (!ready_) return;
    if (!impl_->makeCurrent()) return;
    impl_->strokeEng->unloadBrushTexture(id);
    impl_->doneCurrent();
}

// ── Resize / Destroy ────────────────────────────────────────────────────

void DrawingEngine::resize(int w, int h) {
    if (!ready_) return;
    impl_->viewW = w;
    impl_->viewH = h;
}

void DrawingEngine::destroy() {
    if (!impl_) return;
    if (impl_->makeCurrent()) {
        if (impl_->strokeEng) impl_->strokeEng->destroy();
        if (impl_->layerMgr)  impl_->layerMgr->destroy();
        if (impl_->outputFBO) { glDeleteFramebuffers(1, &impl_->outputFBO); }
        impl_->doneCurrent();
    }
    // Recursos EGL (contexto, superficie) son propiedad de Kotlin — no destruir
    // Solo limpiar recursos GL (FBOs, textures, shaders) que creamos nosotros
    impl_.reset();
    ready_ = false;
    LOGI("DrawingEngine destroyed");
}

// ── getLayerIds ─────────────────────────────────────────────────────────

std::vector<int> DrawingEngine::getLayerIds() const {
    std::vector<int> ids;
    if (!ready_) return ids;
    for (auto& l : impl_->layerMgr->getLayers())
        ids.push_back(l->id);
    return ids;
}

} // namespace tsk
