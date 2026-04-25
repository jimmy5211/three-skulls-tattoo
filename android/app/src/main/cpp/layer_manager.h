#pragma once
#include <GLES3/gl3.h>
#include "drawing_engine.h"
#include <string>
#include <vector>
#include <memory>

namespace tsk {

struct Layer {
    int     id      = -1;
    std::string name;
    GLuint  fbo     = 0;
    GLuint  texture = 0;
    int     width   = 0;
    int     height  = 0;
    float   opacity = 1.0f;
    bool    visible = true;
    BlendMode blendMode = BlendMode::Normal;

    bool isValid() const { return fbo != 0 && texture != 0; }
};

class LayerManager {
public:
    LayerManager(int canvasW, int canvasH);
    ~LayerManager();

    bool init();
    void destroy();

    int  createLayer(const std::string& name = "");
    void deleteLayer(int id);
    Layer* getLayer(int id);
    void setActiveLayerId(int id);
    Layer* activeLayer();
    void bindActiveLayer();
    void unbindLayer();

    void setLayerOpacity(int id, float opacity);
    void setLayerVisible(int id, bool visible);
    void setLayerBlendMode(int id, BlendMode mode);
    void clearLayer(int id);
    void moveLayer(int fromIdx, int toIdx);

    // FIX: surfW/surfH = tamaño real del EGL surface (physW x physH).
    // Final blit usa fullscreen quad para escalar correctamente en cualquier driver.
    void composite(GLuint destFBO, GLuint destTexture,
                   int destW, int destH,
                   const Color& background);
);

    void resize(int newW, int newH);

    const std::vector<std::unique_ptr<Layer>>& getLayers() const { return layers_; }

private:
    int canvasW_, canvasH_;
    int nextId_ = 0;
    int activeLayerId_ = -1;

    std::vector<std::unique_ptr<Layer>> layers_;

    GLuint compositeProgram_ = 0;
    GLuint quadVAO_ = 0;
    GLuint quadVBO_ = 0;

    bool createLayerFBO(Layer& layer);
    void destroyLayerFBO(Layer& layer);
    bool initShaders();
    bool initQuad();
    GLuint compileShader(GLenum type, const char* src);
    GLuint linkProgram(GLuint vert, GLuint frag);
};

} // namespace tsk
