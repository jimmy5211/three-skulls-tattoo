#include <jni.h>
#include <android/log.h>
#include <EGL/egl.h>
#include "drawing_engine.h"

#define LOG_TAG "TSK_JNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace tsk;

// Prefijo jni en nombre Kotlin → función C++ con jni prefix
#define JNINAME(name) Java_com_threeskullstattoo_app_DrawingEngineJNI_##name

extern "C" {

// ── Init / Destroy ─────────────────────────────────────────────────────

// Error codes for jniInit return value:
// 0 = success
// 1 = no EGL context on GL thread
// 2 = no EGL surface on GL thread
// 3 = layer manager init failed (shader compile error)
// 4 = stroke engine init failed (shader compile error)
// 5 = unknown init error
JNIEXPORT jint JNICALL
JNINAME(jniInit)(JNIEnv*, jclass,
                 jlong eglDisplay, jlong sharedContext,
                 jint width, jint height, jint textureId,
                 jint canvasW, jint canvasH, jint maxUndo) {
    EngineConfig cfg;
    cfg.canvasWidth  = canvasW;
    cfg.canvasHeight = canvasH;
    cfg.maxUndoSteps = maxUndo;

    // Log GL state before init
    EGLContext ctx = eglGetCurrentContext();
    EGLSurface surf = eglGetCurrentSurface(EGL_DRAW);
    LOGI("jniInit: ctx=%p surf=%p canvas=%dx%d",
         (void*)ctx, (void*)surf, canvasW, canvasH);
    if (ctx == EGL_NO_CONTEXT)  { LOGE("jniInit ERR 1: no EGL context");  return 1; }
    if (surf == EGL_NO_SURFACE) { LOGE("jniInit ERR 2: no EGL surface");  return 2; }

    const char* glVer = (const char*)glGetString(GL_VERSION);
    const char* glRen = (const char*)glGetString(GL_RENDERER);
    LOGI("GL_VERSION:  %s", glVer ? glVer : "null");
    LOGI("GL_RENDERER: %s", glRen ? glRen : "null");

    int result = DrawingEngine::get().initWithCode(
        (EGLDisplay)(intptr_t)eglDisplay,
        (EGLContext)(intptr_t)sharedContext,
        width, height, (GLuint)textureId, cfg
    );
    LOGI("jniInit result: %d", result);
    return result;
}

JNIEXPORT void JNICALL
JNINAME(jniDestroy)(JNIEnv*, jclass) {
    DrawingEngine::get().destroy();
}

JNIEXPORT void JNICALL
JNINAME(jniRender)(JNIEnv*, jclass) {
    DrawingEngine::get().render();
}

// ── Stroke ─────────────────────────────────────────────────────────────

JNIEXPORT void JNICALL
JNINAME(jniBeginStroke)(JNIEnv*, jclass,
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
    LOGI("beginStroke: hardness=%.3f size=%.1f opacity=%.3f isEraser=%d", hardness, size, opacity, isEraser);
    brush.spacing  = spacing;
    brush.isEraser = (bool)isEraser;
    brush.brushTextureId = brushTexId;
    Color color = Color::fromARGB((uint32_t)colorARGB);
    DrawingEngine::get().beginStroke(layerId, p, brush, color);
}

JNIEXPORT void JNICALL
JNINAME(jniAddPoint)(JNIEnv*, jclass,
                     jfloat x, jfloat y, jfloat pressure) {
    DrawingEngine::get().addPoint({x, y, pressure});
}

JNIEXPORT void JNICALL
JNINAME(jniEndStroke)(JNIEnv*, jclass) {
    DrawingEngine::get().endStroke();
}

JNIEXPORT void JNICALL
JNINAME(jniCancelStroke)(JNIEnv*, jclass) {
    DrawingEngine::get().cancelStroke();
}

// ── History ────────────────────────────────────────────────────────────

JNIEXPORT void JNICALL
JNINAME(jniUndo)(JNIEnv*, jclass) { DrawingEngine::get().undo(); }

JNIEXPORT void JNICALL
JNINAME(jniRedo)(JNIEnv*, jclass) { DrawingEngine::get().redo(); }

JNIEXPORT jboolean JNICALL
JNINAME(jniCanUndo)(JNIEnv*, jclass) {
    return DrawingEngine::get().canUndo() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
JNINAME(jniCanRedo)(JNIEnv*, jclass) {
    return DrawingEngine::get().canRedo() ? JNI_TRUE : JNI_FALSE;
}

// ── Layers ─────────────────────────────────────────────────────────────

JNIEXPORT jint JNICALL
JNINAME(jniAddLayer)(JNIEnv* env, jclass, jstring jname) {
    const char* name = env->GetStringUTFChars(jname, nullptr);
    int id = DrawingEngine::get().addLayer(name ? name : "");
    if (name) env->ReleaseStringUTFChars(jname, name);
    return id;
}

JNIEXPORT void JNICALL
JNINAME(jniRemoveLayer)(JNIEnv*, jclass, jint id) {
    DrawingEngine::get().removeLayer(id);
}

JNIEXPORT void JNICALL
JNINAME(jniSetActiveLayer)(JNIEnv*, jclass, jint id) {
    DrawingEngine::get().setActiveLayer(id);
}

JNIEXPORT void JNICALL
JNINAME(jniSetLayerOpacity)(JNIEnv*, jclass, jint id, jfloat opacity) {
    DrawingEngine::get().setLayerOpacity(id, opacity);
}

JNIEXPORT void JNICALL
JNINAME(jniSetLayerVisible)(JNIEnv*, jclass, jint id, jboolean visible) {
    DrawingEngine::get().setLayerVisible(id, (bool)visible);
}

JNIEXPORT void JNICALL
JNINAME(jniClearLayer)(JNIEnv*, jclass, jint id) {
    DrawingEngine::get().clearLayer(id);
}

// ── Canvas ─────────────────────────────────────────────────────────────

JNIEXPORT void JNICALL
JNINAME(jniSetBackground)(JNIEnv*, jclass, jint colorARGB) {
    DrawingEngine::get().setBackground(Color::fromARGB((uint32_t)colorARGB));
}

JNIEXPORT void JNICALL
JNINAME(jniSetCanvasSize)(JNIEnv*, jclass, jint w, jint h) {
    DrawingEngine::get().setCanvasSize(w, h);
}

// ── Export ─────────────────────────────────────────────────────────────

JNIEXPORT jbyteArray JNICALL
JNINAME(jniExportPixels)(JNIEnv* env, jclass) {
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
JNINAME(jniLoadBrushTexture)(JNIEnv* env, jclass,
                              jbyteArray data, jint w, jint h) {
    jsize len = env->GetArrayLength(data);
    std::vector<uint8_t> buf(len);
    env->GetByteArrayRegion(data, 0, len,
                            reinterpret_cast<jbyte*>(buf.data()));
    return DrawingEngine::get().loadBrushTexture(buf.data(), w, h);
}

JNIEXPORT void JNICALL
JNINAME(jniUnloadBrushTexture)(JNIEnv*, jclass, jint id) {
    DrawingEngine::get().unloadBrushTexture(id);
}

// ── Diagnóstico ────────────────────────────────────────────────────────
// Expone el g_lastError de C++ (contiene canvasSize del último beginStroke)
// al lado Kotlin/Dart para diagnóstico desde el Motor GPU dialog.

JNIEXPORT jstring JNICALL
JNINAME(jniGetLastError)(JNIEnv* env, jclass) {
    const char* err = DrawingEngine::get().getLastError();
    return env->NewStringUTF(err ? err : "null");
}

} // extern "C"
