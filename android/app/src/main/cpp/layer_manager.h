#pragma once
#include <GLES3/gl3.h>
#include <vector>
#include <string>
#include <memory>
#include "drawing_engine.h"

namespace tsk {

// ── Una capa = un framebuffer con su texture RGBA8 ─────────────────────

struct Layer {
    int       id        = -1;
    std::string name;
    GLuint    fbo       = 0;   // framebuffer object
    GLuint    texture   = 0;   // GL_RGBA8 texture
    float     opacity   = 1.0f;
    BlendMode blendMode = BlendMode::Normal;
    bool      visible   = true;
    bool      locked    = false;
    int       width     = 0;
    int       height    = 0;

    bool isValid() const { return fbo != 0 && texture != 0; }
};

// ── Compositor de capas ────────────────────────────────────────────────

class LayerManager {
public:
    explicit LayerManager(int canvasW, int canvasH);
    ~LayerManager();

    // Lifecycle
    bool init();
    void destroy();

    // Gestión de capas
    int  createLayer(const std::string& name = "");
    void deleteLayer(int id);
    void setActiveLayerId(int id);
    int  getActiveLayerId() const { return activeLayerId_; }
    Layer* getLayer(int id);
    const std::vector<std::unique_ptr<Layer>>& getLayers() const { return layers_; }

    // Propiedades
    void setLayerOpacity(int id, float opacity);
    void setLayerVisible(int id, bool visible);
    void setLayerBlendMode(int id, BlendMode mode);
    void moveLayer(int fromIndex, int toIndex);

    // Operaciones
    void clearLayer(int id);
    void mergeDown(int id);
    void flattenAll();

    // Resize
    void resize(int newW, int newH);

    // Composita todas las capas visible en el FBO destino
    // destFBO=0 = pantalla
    void composite(GLuint destFBO, GLuint destTexture,
                   int destW, int destH,
                   const Color& background);

    // Acceso directo para dibujar en capa activa
    Layer* activeLayer();
    void   bindActiveLayer();
    void   unbindLayer();

private:
    int canvasW_, canvasH_;
    int nextId_ = 0;
    int activeLayerId_ = -1;
    std::vector<std::unique_ptr<Layer>> layers_;

    // Shader de composición
    GLuint compositeProgram_ = 0;
    GLuint quadVAO_ = 0, quadVBO_ = 0;

    bool initShaders();
    bool createLayerFBO(Layer& layer);
    void destroyLayerFBO(Layer& layer);
    GLuint compileShader(GLenum type, const char* src);
    GLuint linkProgram(GLuint vert, GLuint frag);
};

} // namespace tsk
