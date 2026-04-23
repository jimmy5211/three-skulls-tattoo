#include <jni.h>
#include <android/log.h>
#include <EGL/egl.h>
#include "drawing_engine.h"

#define LOG_TAG "TSK_JNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace tsk;

// Macro para simplificar los nombres JNI
#define JNINAME(name) Java_com_threeskullstattoo_app_DrawingEngineJNI_##name

extern "C" {

// ── Init / Destroy ─────────────────────────────────────────────────────

JNIEXPORT jboolean JNICALL
JNINAME(nativeInit)(JNIEnv*, jclass,
                    jlong eglDisplay, jlong sharedContext,
                    jint width, jint height, jint textureId,
                    jint canvasW, jint canvasH, jint maxUndo) {
    EngineConfig cfg;
    cfg.canvasWidth  = canvasW;
    cfg.canvasHeight = canvasH;
    cfg.maxUndoSteps = maxUndo;

    auto& eng = DrawingEngine::get();
    eng.onFrameReady = nullptr; // será seteado desde Kotlin

    bool ok = eng.init(
        (EGLDisplay)(intptr_t)eglDisplay,
        (EGLContext)(intptr_t)sharedContext,
        width, height, (GLuint)textureId, cfg
    );
    LOGI("nativeInit: %s", ok ? "OK" : "FAIL");
    return ok ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
JNINAME(nativeDestroy)(JNIEnv*, jclass) {
    DrawingEngine::get().destroy();
}

JNIEXPORT void JNICALL
JNINAME(nativeRender)(JNIEnv*, jclass) {
    DrawingEngine::get().render();
}

// ── Stroke ─────────────────────────────────────────────────────────────

JNIEXPORT void JNICALL
JNINAME(beginStroke)(JNIEnv*, jclass,
                     jint layerId,
                     jfloat x, jfloat y, jfloat pressure,
                     jfloat size, jfloat opacity, jfloat hardness,
                     jfloat spacing, jboolean isEraser, jint brushTexId,
                     jint colorARGB) {
    Point p{x, y, pressure};
    BrushParams brush;
    brush.size     = size;
    brush.opacity  = opacity;
    brush.hardness = hardness;
    brush.spacing  = spacing;
    brush.isEraser = (bool)isEraser;
    brush.brushTextureId = brushTexId;
    Color color = Color::fromARGB((uint32_t)colorARGB);
    DrawingEngine::get().beginStroke(layerId, p, brush, color);
}

JNIEXPORT void JNICALL
JNINAME(addPoint)(JNIEnv*, jclass,
                  jfloat x, jfloat y, jfloat pressure) {
    DrawingEngine::get().addPoint({x, y, pressure});
}

JNIEXPORT void JNICALL
JNINAME(endStroke)(JNIEnv*, jclass) {
    DrawingEngine::get().endStroke();
}

JNIEXPORT void JNICALL
JNINAME(cancelStroke)(JNIEnv*, jclass) {
    DrawingEngine::get().cancelStroke();
}

// ── Historial ──────────────────────────────────────────────────────────

JNIEXPORT void JNICALL
JNINAME(undo)(JNIEnv*, jclass) {
    DrawingEngine::get().undo();
}

JNIEXPORT void JNICALL
JNINAME(redo)(JNIEnv*, jclass) {
    DrawingEngine::get().redo();
}

JNIEXPORT jboolean JNICALL
JNINAME(canUndo)(JNIEnv*, jclass) {
    return DrawingEngine::get().canUndo() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
JNINAME(canRedo)(JNIEnv*, jclass) {
    return DrawingEngine::get().canRedo() ? JNI_TRUE : JNI_FALSE;
}

// ── Capas ──────────────────────────────────────────────────────────────

JNIEXPORT jint JNICALL
JNINAME(addLayer)(JNIEnv* env, jclass, jstring jname) {
    const char* name = env->GetStringUTFChars(jname, nullptr);
    int id = DrawingEngine::get().addLayer(name ? name : "");
    if (name) env->ReleaseStringUTFChars(jname, name);
    return id;
}

JNIEXPORT void JNICALL
JNINAME(removeLayer)(JNIEnv*, jclass, jint id) {
    DrawingEngine::get().removeLayer(id);
}

JNIEXPORT void JNICALL
JNINAME(setActiveLayer)(JNIEnv*, jclass, jint id) {
    DrawingEngine::get().setActiveLayer(id);
}

JNIEXPORT void JNICALL
JNINAME(setLayerOpacity)(JNIEnv*, jclass, jint id, jfloat opacity) {
    DrawingEngine::get().setLayerOpacity(id, opacity);
}

JNIEXPORT void JNICALL
JNINAME(setLayerVisible)(JNIEnv*, jclass, jint id, jboolean visible) {
    DrawingEngine::get().setLayerVisible(id, (bool)visible);
}

JNIEXPORT void JNICALL
JNINAME(clearLayer)(JNIEnv*, jclass, jint id) {
    DrawingEngine::get().clearLayer(id);
}

// ── Canvas ─────────────────────────────────────────────────────────────

JNIEXPORT void JNICALL
JNINAME(setBackground)(JNIEnv*, jclass, jint colorARGB) {
    DrawingEngine::get().setBackground(Color::fromARGB((uint32_t)colorARGB));
}

JNIEXPORT void JNICALL
JNINAME(setCanvasSize)(JNIEnv*, jclass, jint w, jint h) {
    DrawingEngine::get().setCanvasSize(w, h);
}

// ── Export ─────────────────────────────────────────────────────────────

JNIEXPORT jbyteArray JNICALL
JNINAME(exportPixels)(JNIEnv* env, jclass) {
    int w = 0, h = 0;
    auto pixels = DrawingEngine::get().exportPixels(&w, &h);
    if (pixels.empty()) return nullptr;
    jbyteArray arr = env->NewByteArray((jsize)pixels.size());
    env->SetByteArrayRegion(arr, 0, (jsize)pixels.size(),
                            reinterpret_cast<const jbyte*>(pixels.data()));
    return arr;
}

// ── Brush textures ──────────────────────────────────────────────────────

JNIEXPORT jint JNICALL
JNINAME(loadBrushTexture)(JNIEnv* env, jclass,
                           jbyteArray data, jint w, jint h) {
    jsize len = env->GetArrayLength(data);
    std::vector<uint8_t> buf(len);
    env->GetByteArrayRegion(data, 0, len,
                            reinterpret_cast<jbyte*>(buf.data()));
    return DrawingEngine::get().loadBrushTexture(buf.data(), w, h);
}

JNIEXPORT void JNICALL
JNINAME(unloadBrushTexture)(JNIEnv*, jclass, jint id) {
    DrawingEngine::get().unloadBrushTexture(id);
}

} // extern "C"
