#pragma once
#include <GLES3/gl3.h>
#include <vector>
#include "drawing_engine.h"

namespace tsk {

class StrokeEngine {
public:
    StrokeEngine() = default;
    ~StrokeEngine() { destroy(); }

    bool init();
    void destroy();

    void beginStroke(const Point& p, const BrushParams& brush,
                     const Color& color, int canvasW, int canvasH);
    bool addPoint(const Point& p);
    void endStroke();
    void cancelStroke();

    bool isActive() const { return active_; }

    // Renderiza UN stamp en (x,y) sin afectar lastPoint_ ni accDist_.
    void stampAt(float x, float y);

    // Aplica el stroke buffer (máscara GL_MAX) al layer FBO con dstOut+opacity.
    // Llamado desde DrawingEngine::endStroke() para el borrador limpio.
    void compositeStrokeToLayer(GLuint layerFBO);

    int  loadBrushTexture(const uint8_t* rgba, int w, int h);
    void unloadBrushTexture(int id);

    void setSymmetry(bool enabled, int axis = 0) {
        symmetryEnabled_ = enabled;
        symmetryAxis_    = axis;
    }

private:
    bool   active_   = false;
    GLuint layerFBO_ = 0;

    BrushParams brush_;
    Color       color_     = {0,0,0,1};
    int         canvasW_   = 1;
    int         canvasH_   = 1;
    Point       lastPoint_  = {};
    float       accDist_    = 0.0f;
    float       lastSpeed_  = 0.0f;
    std::vector<Point> pointBuf_; // buffer Catmull-Rom (4 últimos puntos)
    // Historial de 4 puntos para Catmull-Rom + suavizado
    Point       pts_[4]     = {};
    int         ptsCount_   = 0;
    Point       smoothPrev_ = {};

    bool symmetryEnabled_ = false;
    int  symmetryAxis_    = 0;

    GLuint strokeProgram_   = 0;
    GLuint eraserProgram_   = 0;
    GLuint quadVAO_         = 0;
    GLuint quadVBO_         = 0;
    GLuint defaultBrushTex_ = 0;

    GLuint strokeFBO_        = 0;
    GLuint strokeTex_        = 0;
    int    strokeW_          = 0;
    int    strokeH_          = 0;
    GLuint compositeProgram_ = 0;

    // Texturas orgánicas generadas internamente — sin depender de archivos externos
    GLuint airbrushTex_   = 0;
    GLuint charcoalTex_   = 0;
    GLuint inkTex_        = 0;
    GLuint pencilTex_     = 0;
    GLuint glowTex_       = 0;
    GLuint watercolorTex_ = 0;

    struct BrushTexEntry { int id; GLuint tex; int w, h; };
    std::vector<BrushTexEntry> brushTextures_;
    int nextBrushTexId_ = 1;

    void renderStamp(const Point& p, float diameterOverride = -1.0f);
    void renderStampAt(float x, float y, float pressure, float diameter, float rotation = 0.0f);
    GLuint getGrainTexture() const;

    bool   ensureStrokeFBO(int w, int h);
    Point  smoothPoint(const Point& prev, const Point& curr) const;
    void   emitSegment(const Point& a, const Point& b, float size);
    void   destroyStrokeFBO();
    bool   initCompositeShader();

    void   generateDefaultBrushTex();
    GLuint compileShader(GLenum type, const char* src);
    GLuint linkProgram(GLuint v, GLuint f);
    bool   initShaders();
    bool   initQuad();
    GLuint getBrushTexture() const;
    GLuint getBrushTextureForCategory() const;
};

} // namespace tsk
