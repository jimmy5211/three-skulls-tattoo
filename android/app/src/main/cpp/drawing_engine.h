#pragma once
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <android/native_window.h>
#include <cstdint>
#include <vector>
#include <memory>
#include <functional>

namespace tsk {

// ── Tipos básicos ──────────────────────────────────────────────────────

struct Point {
    float x, y;
    float pressure = 1.0f;   // 0.0–1.0 (stylus / touch)
    float tilt     = 0.0f;   // ángulo del stylus en grados
};

struct Color {
    float r, g, b, a;
    Color(float r=0,float g=0,float b=0,float a=1): r(r),g(g),b(b),a(a) {}
    static Color fromARGB(uint32_t argb) {
        return {
            ((argb >> 16) & 0xFF) / 255.0f,
            ((argb >>  8) & 0xFF) / 255.0f,
            ((argb >>  0) & 0xFF) / 255.0f,
            ((argb >> 24) & 0xFF) / 255.0f,
        };
    }
};

struct BrushParams {
    float size     = 20.0f;  // diámetro en canvas units
    float opacity  = 1.0f;   // 0.0–1.0
    float hardness = 1.0f;   // 0.0=suave, 1.0=duro
    float spacing  = 0.1f;   // fracción del diámetro entre stamps
    bool  isEraser = false;
    int   brushTextureId = -1; // -1 = circular por defecto
};

enum class BlendMode : int {
    Normal     = 0,
    Multiply   = 1,
    Screen     = 2,
    Overlay    = 3,
    HardLight  = 4,
    SoftLight  = 5,
    ColorDodge = 6,
    ColorBurn  = 7,
};

// ── Configuración del motor ────────────────────────────────────────────

struct EngineConfig {
    int   canvasWidth  = 1080;
    int   canvasHeight = 1920;
    int   maxLayers    = 16;
    int   maxUndoSteps = 20;
    float pixelDensity = 2.0f;  // dpi / 160
};

// ── Interfaz principal del motor ───────────────────────────────────────

class DrawingEngine {
public:
    // Singleton seguro por contexto
    static DrawingEngine& get();

    // ── Ciclo de vida ──────────────────────────────────────────
    bool init(EGLDisplay display, EGLContext sharedContext,
              int width, int height, GLuint targetTextureId,
              const EngineConfig& cfg = {});
    void resize(int width, int height);
    void destroy();
    bool isReady() const { return ready_; }
    static const char* getLastError();  // diagnóstico

    // ── Renderizado ────────────────────────────────────────────
    // Composita todas las capas y actualiza el texture para Flutter
    void render();

    // ── Stroke lifecycle ──────────────────────────────────────
    void beginStroke(int layerId, const Point& p, const BrushParams& brush,
                     const Color& color);
    void addPoint(const Point& p);
    void endStroke();
    void cancelStroke();

    // ── Capas ──────────────────────────────────────────────────
    int  addLayer(const std::string& name = "");
    void removeLayer(int layerId);
    void setActiveLayer(int layerId);
    void setLayerOpacity(int layerId, float opacity);
    void setLayerBlendMode(int layerId, BlendMode mode);
    void setLayerVisible(int layerId, bool visible);
    void moveLayer(int fromIndex, int toIndex);
    void mergeLayerDown(int layerId);
    void flattenAllLayers();
    std::vector<int> getLayerIds() const;

    // ── Historial ──────────────────────────────────────────────
    void undo();
    void redo();
    bool canUndo() const;
    bool canRedo() const;

    // ── Canvas ─────────────────────────────────────────────────
    void clearLayer(int layerId);
    void setBackground(const Color& color);
    void setCanvasSize(int w, int h);

    // ── Exportación ────────────────────────────────────────────
    // Devuelve RGBA raw del canvas compuesto (corre en GL thread)
    std::vector<uint8_t> exportPixels(int* outWidth, int* outHeight);

    // ── Brush textures ─────────────────────────────────────────
    int  loadBrushTexture(const uint8_t* rgba, int w, int h);
    void unloadBrushTexture(int id);

    // Callback para indicarle a Flutter que hay un frame nuevo
    std::function<void()> onFrameReady;

private:
    DrawingEngine() = default;
    ~DrawingEngine() { destroy(); }
    DrawingEngine(const DrawingEngine&) = delete;
    DrawingEngine& operator=(const DrawingEngine&) = delete;

    bool ready_ = false;

    // implementación privada (pimpl)
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace tsk
