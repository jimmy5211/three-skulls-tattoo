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
    bool active_ = false;

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

    // Brush texture cache
    struct BrushTexEntry { int id; GLuint tex; int w, h; };
    std::vector<BrushTexEntry> brushTextures_;
    int nextBrushTexId_ = 1;

    // Render un stamp (círculo/texture) en la posición dada
    void renderStamp(const Point& p, float diameterOverride = -1.0f);

    // Genera el circulo gaussiano default (64×64 RGBA)
    void generateDefaultBrushTex();

    GLuint compileShader(GLenum type, const char* src);
    GLuint linkProgram(GLuint v, GLuint f);
    bool   initShaders();
    bool   initQuad();

    GLuint getBrushTexture() const;
};

} // namespace tsk
