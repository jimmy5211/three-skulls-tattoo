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

struct DrawingEngine::Impl {
    EGLDisplay   eglDisplay = EGL_NO_DISPLAY;
    EGLContext   eglContext = EGL_NO_CONTEXT;
    EGLContext   ownContext = EGL_NO_CONTEXT; // nuestro propio context compartido
    EGLSurface   ownSurface= EGL_NO_SURFACE; // pbuffer surface

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
        return eglMakeCurrent(eglDisplay, ownSurface, ownSurface, ownContext) == EGL_TRUE;
    }

    void doneCurrent() {
        eglMakeCurrent(eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    }
};

// ── Singleton ──────────────────────────────────────────────────────────

DrawingEngine& DrawingEngine::get() {
    static DrawingEngine instance;
    return instance;
}

// ── Init ───────────────────────────────────────────────────────────────

bool DrawingEngine::init(EGLDisplay display, EGLContext sharedContext,
                          int width, int height, GLuint targetTextureId,
                          const EngineConfig& cfg) {
    impl_ = std::make_unique<Impl>();
    impl_->cfg      = cfg;
    impl_->viewW    = width;
    impl_->viewH    = height;
    impl_->eglDisplay = display;
    impl_->eglContext = sharedContext;
    impl_->maxUndoSteps = cfg.maxUndoSteps;

    // ── Crear nuestro propio contexto EGL compartido ──────────
    EGLint ctxAttribs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    impl_->ownContext = eglCreateContext(display, eglGetCurrentConfig(display) == EGL_NO_CONFIG_KHR
        ? nullptr : eglGetCurrentConfig(display),
        sharedContext, ctxAttribs);

    if (impl_->ownContext == EGL_NO_CONTEXT) {
        // fallback: intentar sin config específica
        EGLint cfgAttribs[] = {
            EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
            EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
            EGL_RED_SIZE,   8, EGL_GREEN_SIZE, 8,
            EGL_BLUE_SIZE,  8, EGL_ALPHA_SIZE, 8,
            EGL_NONE
        };
        EGLConfig cfg_egl; EGLint n;
        eglChooseConfig(display, cfgAttribs, &cfg_egl, 1, &n);
        impl_->ownContext = eglCreateContext(display, cfg_egl, sharedContext, ctxAttribs);
        if (impl_->ownContext == EGL_NO_CONTEXT) {
            LOGE("Failed to create EGL context: %d", eglGetError());
            return false;
        }
    }

    // ── PBuffer surface (offscreen) ───────────────────────────
    EGLint pbAttribs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    EGLConfig eglCfg; EGLint n;
    EGLint cfgAttribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
        EGL_NONE
    };
    eglChooseConfig(display, cfgAttribs, &eglCfg, 1, &n);
    impl_->ownSurface = eglCreatePbufferSurface(display, eglCfg, pbAttribs);
    if (impl_->ownSurface == EGL_NO_SURFACE) {
        LOGE("Failed to create PBuffer surface");
    }

    // ── Activar contexto ──────────────────────────────────────
    if (!impl_->makeCurrent()) {
        LOGE("Failed to make EGL context current");
        return false;
    }

    // ── Output texture & FBO ──────────────────────────────────
    impl_->outputTexture = targetTextureId;
    glGenFramebuffers(1, &impl_->outputFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, impl_->outputFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, targetTextureId, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        LOGE("Output FBO incomplete");
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        return false;
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    // ── Subsistemas ───────────────────────────────────────────
    impl_->layerMgr  = std::make_unique<LayerManager>(cfg.canvasWidth, cfg.canvasHeight);
    impl_->strokeEng = std::make_unique<StrokeEngine>();

    if (!impl_->layerMgr->init())  { LOGE("LayerManager init failed");  return false; }
    if (!impl_->strokeEng->init()) { LOGE("StrokeEngine init failed"); return false; }

    // Crear capa inicial
    impl_->layerMgr->createLayer("Layer 1");

    impl_->doneCurrent();
    ready_ = true;
    LOGI("DrawingEngine initialized: canvas=%dx%d",
         cfg.canvasWidth, cfg.canvasHeight);
    return true;
}

// ── Render ─────────────────────────────────────────────────────────────

void DrawingEngine::render() {
    if (!ready_) return;
    if (!impl_->makeCurrent()) return;

    glViewport(0, 0, impl_->cfg.canvasWidth, impl_->cfg.canvasHeight);
    impl_->layerMgr->composite(
        impl_->outputFBO, impl_->outputTexture,
        impl_->cfg.canvasWidth, impl_->cfg.canvasHeight,
        impl_->background
    );
    glFlush();
    impl_->doneCurrent();

    if (onFrameReady) onFrameReady();
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
    if (impl_->ownContext != EGL_NO_CONTEXT)
        eglDestroyContext(impl_->eglDisplay, impl_->ownContext);
    if (impl_->ownSurface != EGL_NO_SURFACE)
        eglDestroySurface(impl_->eglDisplay, impl_->ownSurface);
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
