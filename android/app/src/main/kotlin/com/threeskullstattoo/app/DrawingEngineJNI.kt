package com.threeskullstattoo.app

import android.opengl.EGL14
import android.opengl.EGLExt
import android.opengl.GLES30
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import io.flutter.view.TextureRegistry

/**
 * Puente Kotlin ↔ C++ motor de dibujo.
 * Las funciones públicas (sin prefijo) corren en el GL thread.
 * Las funciones JNI (prefijo jni) son las declaraciones extern "C" del C++.
 */
object DrawingEngineJNI {

    private const val TAG = "TSK_KT"

    // ── GL Thread dedicado ────────────────────────────────────────────
    private val glThread = HandlerThread("TSK-GL").also { it.start() }
    private val glHandler = Handler(glThread.looper)

    // ── EGL state ─────────────────────────────────────────────────────
    private var eglDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface = EGL14.EGL_NO_SURFACE

    // ── Flutter Texture ───────────────────────────────────────────────
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var glTextureId: Int = 0
    var textureId: Long = -1L
        private set

    var initialized = false
        private set

    var onFrameAvailable: (() -> Unit)? = null

    // ═══════════════════════════════════════════════════════════════
    // SETUP
    // ═══════════════════════════════════════════════════════════════

    fun setup(
        textureRegistry: TextureRegistry,
        canvasW: Int, canvasH: Int,
        maxUndoSteps: Int = 20,
        onReady: (textureId: Long) -> Unit
    ) {
        if (!nativeLibLoaded) {
            Log.e(TAG, "Native library not loaded, skipping setup")
            return
        }
        glHandler.post {
            try {
                if (!initEGL()) { Log.e(TAG, "EGL init failed"); return@post }

            // Registrar texture en Flutter
            val entry = textureRegistry.createSurfaceTexture()
            textureEntry = entry
            textureId = entry.id()

            // Crear GL texture 2D para el canvas
            val ids = IntArray(1)
            GLES30.glGenTextures(1, ids, 0)
            glTextureId = ids[0]
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, glTextureId)
            // GL_RGBA8 (sized internal format) es necesario para FBO en OpenGL ES 3.0
            GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA8,
                canvasW, canvasH, 0, GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, null)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)

            // Pasar el display y contexto actual al motor C++
            // El motor C++ reutilizará el mismo contexto (ya activo en este thread)
            val display = EGL14.eglGetCurrentDisplay()
            val context = EGL14.eglGetCurrentContext()
            
            if (display == EGL14.EGL_NO_DISPLAY || context == EGL14.EGL_NO_CONTEXT) {
                Log.e(TAG, "No active EGL context on GL thread — cannot init native engine")
                initialized = false
                return@post
            }

            val ok = try {
                jniInit(
                    display.nativeHandle, context.nativeHandle,
                    canvasW, canvasH, glTextureId,
                    canvasW, canvasH, maxUndoSteps
                )
            } catch (t: Throwable) {
                Log.e(TAG, "jniInit threw: $t")
                false
            }
            initialized = ok
            Log.i(TAG, "DrawingEngine init: $ok  textureId=$textureId")

            // SIEMPRE notificar — si ok=false el Dart recibe -1 y usa fallback
            val idToReturn = if (ok) textureId else -1L
            Handler(android.os.Looper.getMainLooper()).post { onReady(idToReturn) }

            } catch (t: Throwable) {
                Log.e(TAG, "Native engine setup crashed: $t")
                initialized = false
                // Notificar fallo para que Dart no quede en timeout
                Handler(android.os.Looper.getMainLooper()).post { onReady(-1L) }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // PUBLIC API — corren en GL thread
    // ═══════════════════════════════════════════════════════════════

    fun render()       = glHandler.post { if (initialized) jniRender() }
    fun destroy()      { glHandler.post { jniDestroy(); destroyEGL(); initialized = false } }

    // ── Stroke ──────────────────────────────────────────────────────

    fun beginStroke(
        layerId: Int, x: Float, y: Float, pressure: Float,
        size: Float, opacity: Float, hardness: Float, spacing: Float,
        isEraser: Boolean, brushTexId: Int, colorARGB: Int
    ) = glHandler.post {
        if (initialized) jniBeginStroke(
            layerId, x, y, pressure,
            size, opacity, hardness, spacing,
            isEraser, brushTexId, colorARGB
        )
    }

    fun addPoint(x: Float, y: Float, pressure: Float = 1f) =
        glHandler.post { if (initialized) jniAddPoint(x, y, pressure) }

    fun endStroke()    = glHandler.post { if (initialized) jniEndStroke() }
    fun cancelStroke() = glHandler.post { if (initialized) jniCancelStroke() }

    // ── History ──────────────────────────────────────────────────────

    fun undo()     = glHandler.post { if (initialized) jniUndo() }
    fun redo()     = glHandler.post { if (initialized) jniRedo() }
    fun canUndo(): Boolean = initialized && jniCanUndo()
    fun canRedo(): Boolean = initialized && jniCanRedo()

    // ── Layers ───────────────────────────────────────────────────────

    fun addLayer(name: String): Int =
        if (initialized) jniAddLayer(name) else -1

    fun removeLayer(id: Int)            = glHandler.post { if (initialized) jniRemoveLayer(id) }
    fun setActiveLayer(id: Int)         = glHandler.post { if (initialized) jniSetActiveLayer(id) }
    fun setLayerOpacity(id: Int, o: Float) = glHandler.post { if (initialized) jniSetLayerOpacity(id, o) }
    fun setLayerVisible(id: Int, v: Boolean) = glHandler.post { if (initialized) jniSetLayerVisible(id, v) }
    fun clearLayer(id: Int)             = glHandler.post { if (initialized) jniClearLayer(id) }

    // ── Canvas ───────────────────────────────────────────────────────

    fun setBackground(colorARGB: Int)   = glHandler.post { if (initialized) jniSetBackground(colorARGB) }
    fun setCanvasSize(w: Int, h: Int)   = glHandler.post { if (initialized) jniSetCanvasSize(w, h) }

    // ── Export ───────────────────────────────────────────────────────

    fun exportPixels(): ByteArray? = if (initialized) jniExportPixels() else null

    // ── Brush textures ───────────────────────────────────────────────

    fun loadBrushTexture(data: ByteArray, w: Int, h: Int): Int =
        if (initialized) jniLoadBrushTexture(data, w, h) else -1

    fun unloadBrushTexture(id: Int) =
        glHandler.post { if (initialized) jniUnloadBrushTexture(id) }

    // ═══════════════════════════════════════════════════════════════
    // EGL helpers
    // ═══════════════════════════════════════════════════════════════

    private fun initEGL(): Boolean {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) return false

        val ver = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, ver, 0, ver, 1)) return false

        val cfgAttribs = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGLExt.EGL_OPENGL_ES3_BIT_KHR,
            EGL14.EGL_SURFACE_TYPE,    EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_RED_SIZE,   8, EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE,  8, EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
        val n = IntArray(1)
        if (!EGL14.eglChooseConfig(eglDisplay, cfgAttribs, 0, configs, 0, 1, n, 0) || n[0] == 0)
            return false

        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, ctxAttribs, 0)
        if (eglContext == EGL14.EGL_NO_CONTEXT) {
            Log.e(TAG, "eglCreateContext failed: ${EGL14.eglGetError()}")
            return false
        }

        val pbAttribs = intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreatePbufferSurface(eglDisplay, configs[0], pbAttribs, 0)
        if (eglSurface == EGL14.EGL_NO_SURFACE) return false

        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) return false

        Log.i(TAG, "EGL OK: ${GLES30.glGetString(GLES30.GL_VERSION)}")
        return true
    }

    private fun destroyEGL() {
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, eglSurface)
            if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        eglSurface = EGL14.EGL_NO_SURFACE
    }

    // ═══════════════════════════════════════════════════════════════
    // JNI DECLARATIONS — prefijo "jni" para evitar ambigüedad
    // Implementadas en jni_bridge.cpp como JNINAME(jniXxx)
    // ═══════════════════════════════════════════════════════════════

    private val nativeLibLoaded: Boolean = try {
        System.loadLibrary("three_skulls_engine")
        Log.i("TSK_KT", "Native library loaded OK")
        true
    } catch (t: Throwable) {
        Log.e("TSK_KT", "Failed to load native library: $t")
        false
    }

    @JvmStatic private external fun jniInit(eglDisplay: Long, sharedCtx: Long, w: Int, h: Int, texId: Int, canvasW: Int, canvasH: Int, maxUndo: Int): Boolean
    @JvmStatic private external fun jniDestroy()
    @JvmStatic private external fun jniRender()

    @JvmStatic private external fun jniBeginStroke(layerId: Int, x: Float, y: Float, pressure: Float, size: Float, opacity: Float, hardness: Float, spacing: Float, isEraser: Boolean, brushTexId: Int, colorARGB: Int)
    @JvmStatic private external fun jniAddPoint(x: Float, y: Float, pressure: Float)
    @JvmStatic private external fun jniEndStroke()
    @JvmStatic private external fun jniCancelStroke()

    @JvmStatic private external fun jniUndo()
    @JvmStatic private external fun jniRedo()
    @JvmStatic private external fun jniCanUndo(): Boolean
    @JvmStatic private external fun jniCanRedo(): Boolean

    @JvmStatic private external fun jniAddLayer(name: String): Int
    @JvmStatic private external fun jniRemoveLayer(id: Int)
    @JvmStatic private external fun jniSetActiveLayer(id: Int)
    @JvmStatic private external fun jniSetLayerOpacity(id: Int, opacity: Float)
    @JvmStatic private external fun jniSetLayerVisible(id: Int, visible: Boolean)
    @JvmStatic private external fun jniClearLayer(id: Int)

    @JvmStatic private external fun jniSetBackground(colorARGB: Int)
    @JvmStatic private external fun jniSetCanvasSize(w: Int, h: Int)

    @JvmStatic private external fun jniExportPixels(): ByteArray?
    @JvmStatic private external fun jniLoadBrushTexture(data: ByteArray, w: Int, h: Int): Int
    @JvmStatic private external fun jniUnloadBrushTexture(id: Int)
}
