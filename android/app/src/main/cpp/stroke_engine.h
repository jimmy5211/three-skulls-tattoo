#pragma once
#include <GLES3/gl3.h>
#include <vector>
#include "drawing_engine.h"

namespace tsk {

// ── Motor de trazos — renderiza stamps de pincel en GPU ───────────────

class StrokeEngine {
public:
    StrokeEngine() = default;
    ~StrokeEngine() { destroy(); }

    bool init();
    void destroy();

    // Iniciar un trazo nuevo
    void beginStroke(const Point& p, const BrushParams& brush,
                     const Color& color, int canvasW, int canvasH);

    // Agregar punto (se generan stamps automáticamente por spacing)
    // Devuelve true si se renderizó al menos un stamp
    bool addPoint(const Point& p);

    // Terminar el trazo (finaliza stamps pendientes)
    void endStroke();
    void cancelStroke();

    bool isActive() const { return active_; }

    // Cargar textura de pincel (RGBA, w×h)
    // Devuelve texture ID interno
    int  loadBrushTexture(const uint8_t* rgba, int w, int h);
    void unloadBrushTexture(int id);

private:
    bool   active_    = false;
    GLuint layerFBO_  = 0;  // FBO del layer activo, guardado en beginStroke

    // Parámetros del trazo actual
    BrushParams brush_;
    Color       color_     = {0,0,0,1};
    int         canvasW_   = 1;
    int         canvasH_   = 1;
    Point       lastPoint_ = {};
    float       accDist_   = 0.0f;  // distancia acumulada para spacing

    // GL resources
    GLuint strokeProgram_  = 0;
    GLuint eraserProgram_  = 0;
    GLuint quadVAO_        = 0;
    GLuint quadVBO_        = 0;
    GLuint defaultBrushTex_= 0;  // círculo gaussiano pre-generado

    // Stroke buffer temporal — stamps se acumulan aquí con GL_MAX
    // Se composita sobre el layer FBO en endStroke() para preservar hardness
    GLuint strokeFBO_      = 0;
    GLuint strokeTex_      = 0;
    int    strokeW_        = 0;
    int    strokeH_        = 0;

    // Composite shader (quad fullscreen para blit strokeFBO → layerFBO)
    GLuint compositeProgram_ = 0;

    // Brush texture cache
    struct BrushTexEntry { int id; GLuint tex; int w, h; };
    std::vector<BrushTexEntry> brushTextures_;
    int nextBrushTexId_ = 1;

    // Render un stamp en el strokeFBO (buffer temporal)
    void renderStamp(const Point& p, float diameterOverride = -1.0f);

    // Crea/recrea el strokeFBO si el tamaño cambió
    bool ensureStrokeFBO(int w, int h);
    // Destruye el strokeFBO
    void destroyStrokeFBO();
    // Blitea strokeFBO → layerFBO con normal alpha blending
    void compositeStrokeToLayer(GLuint layerFBO);
    // Inicia el composite shader
    bool initCompositeShader();

    // Genera el circulo gaussiano default (64×64 RGBA)
    void generateDefaultBrushTex();

    GLuint compileShader(GLenum type, const char* src);
    GLuint linkProgram(GLuint v, GLuint f);
    bool   initShaders();
    bool   initQuad();

    GLuint getBrushTexture() const;
};

} // namespace tsk
