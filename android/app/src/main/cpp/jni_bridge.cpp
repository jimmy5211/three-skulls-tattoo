#include <jni.h>
#include <android/log.h>
#include <EGL/egl.h>
#include "drawing_engine.h"

#define LOG_TAG "TSK_JNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace tsk;

#define JNINAME(name) Java_com_threeskullstattoo_app_DrawingEngineJNI_##name

extern "C" {

// ── Init / Destroy ─────────────────────────────────────────────────────

JNIEXPORT jint JNICALL
JNINAME(jniInit)(JNIEnv*, jclass,
                 jlong eglDisplay, jlong sharedContext,
                 jint width, jint height, jint textureId,
                 jint canvasW, jint canvasH, jint maxUndo) {
    EngineConfig cfg;
    cfg.canvasWidth  = canvasW;
    cfg.canvasHeight = canvasH;
    cfg.maxUndoSteps = maxUndo;

    EGLContext ctx  = eglGetCurrentContext();
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
    brush.spacing  = spacing;
    brush.isEraser = (bool)isEraser;
    brush.brushTextureId = brushTexId;
    // Aplicar parámetros .tskbrush almacenados por jniSetBrushDynParams
    brush.spacingBase     = g_spacingBase;
    brush.spacingVelocity = g_spacingVelocity;
    brush.spacingMinPx    = g_spacingMinPx;
    brush.jitterPos       = g_jitterPos;
    brush.jitterSize      = g_jitterSize;
    brush.jitterRot       = g_jitterRot;
    brush.followStroke    = g_followStroke;
    brush.flow            = g_flow;
    brush.grainDepth      = g_grainDepth;
    Color color = Color::fromARGB((uint32_t)colorARGB);
    // FIX OPACITY: multiplicar alpha del color por la opacidad del pincel
    color.a *= opacity;
    LOGI("beginStroke: size=%.1f opacity=%.3f hardness=%.3f isEraser=%d",
         size, opacity, hardness, (int)isEraser);
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

// Renderiza un único stamp en (x,y) sin interpolación — para espejo del borrador.
JNIEXPORT void JNICALL
JNINAME(jniStampAt)(JNIEnv*, jclass, jfloat x, jfloat y) {
    if (!DrawingEngine::get().isReady()) return;
    // Accede al strokeEngine a través de DrawingEngine.
    // Implementado en drawing_engine.cpp.
    DrawingEngine::get().stampAt(x, y);
}

// ── History ────────────────────────────────────────────────────────────
// NOTA: jniUndo / jniRedo solo sirven como hooks.
// El stack real de snapshots se maneja en Kotlin (DrawingEngineJNI.kt)
// usando jniExportPixels() + jniRestorePixels() para máximo control
// sin depender del impl_ privado de DrawingEngine.

JNIEXPORT void JNICALL
JNINAME(jniUndo)(JNIEnv*, jclass) {
    // El undo Kotlin llama a jniRestorePixels directamente.
    // Este hook queda para compatibilidad.
    DrawingEngine::get().undo();
}

JNIEXPORT void JNICALL
JNINAME(jniRedo)(JNIEnv*, jclass) {
    DrawingEngine::get().redo();
}

JNIEXPORT jboolean JNICALL
JNINAME(jniCanUndo)(JNIEnv*, jclass) {
    return DrawingEngine::get().canUndo() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
JNINAME(jniCanRedo)(JNIEnv*, jclass) {
    return DrawingEngine::get().canRedo() ? JNI_TRUE : JNI_FALSE;
}

// ── NUEVO: Simetría ────────────────────────────────────────────────────
// enabled=true → cada stamp del StrokeEngine dibuja también el espejo.
// axis: 0=horizontal (espejo X), 1=vertical (espejo Y).
// Implementación en drawing_engine.cpp:
//   void DrawingEngine::setSymmetry(bool enabled, int axis) {
//       if (impl_) impl_->strokeEngine_.setSymmetry(enabled, axis);
//   }

JNIEXPORT void JNICALL
JNINAME(jniSetSymmetry)(JNIEnv*, jclass, jboolean enabled, jint axis) {
    DrawingEngine::get().setSymmetry((bool)enabled, (int)axis);
    LOGI("jniSetSymmetry: enabled=%d axis=%d", (int)enabled, (int)axis);
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

JNIEXPORT void JNICALL
JNINAME(jniEraseRegion)(JNIEnv*, jclass,
                         jint layerId, jfloat x, jfloat y, jfloat w, jfloat h) {
    DrawingEngine::get().eraseRegion(layerId, x, y, w, h);
}


// ── .tskbrush dynamic params ───────────────────────────────────────────
// Llamar ANTES de jniBeginStroke para configurar los parámetros del pincel.
// Permite que el motor use los valores del .tskbrush en lugar de defaults.

// Parámetros dinámicos almacenados globalmente hasta el próximo beginStroke
static float g_spacingBase     = 0.04f;
static float g_spacingVelocity = 0.001f;
static float g_spacingMinPx    = 1.0f;
static float g_jitterPos       = 0.03f;
static float g_jitterSize      = 0.02f;
static float g_jitterRot       = 6.28f;
static bool  g_followStroke    = true;
static float g_flow            = 0.55f;
static float g_grainDepth      = 0.0f;

JNIEXPORT void JNICALL
JNINAME(jniSetBrushDynParams)(JNIEnv*, jclass,
    jfloat spacingBase, jfloat spacingVelocity, jfloat spacingMinPx,
    jfloat jitterPos,   jfloat jitterSize,      jfloat jitterRot,
    jboolean followStroke, jfloat flow,         jfloat grainDepth) {
    g_spacingBase     = spacingBase;
    g_spacingVelocity = spacingVelocity;
    g_spacingMinPx    = spacingMinPx;
    g_jitterPos       = jitterPos;
    g_jitterSize      = jitterSize;
    g_jitterRot       = jitterRot;
    g_followStroke    = (bool)followStroke;
    g_flow            = flow;
    g_grainDepth      = grainDepth;
    LOGI("SetBrushDynParams: spacing=%.3f vel=%.4f jPos=%.3f flow=%.2f",
         spacingBase, spacingVelocity, jitterPos, flow);
}

} // extern "C"
