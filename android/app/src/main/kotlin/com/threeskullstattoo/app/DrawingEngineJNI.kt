package com.threeskullstattoo.app

import android.opengl.EGL14
import android.opengl.EGLExt
import android.opengl.GLES30
import android.os.Handler
import android.os.HandlerThread
import android.util.Log

/**
 * Motor C++ - Arquitectura Offscreen FBO.
 * Sin SurfaceTexture, sin WindowSurface, sin DPR.
 * C++ renderiza a FBO offscreen → jniExportPixels → ByteArray → Dart.
 */
object DrawingEngineJNI {

    private const val TAG = "TSK_KT"

    private val glThread = HandlerThread("TSK-GL").also { it.start() }
    val glHandler = Handler(glThread.looper)

    private var eglDisplay     = EGL14.EGL_NO_DISPLAY
    private var eglContext     = EGL14.EGL_NO_CONTEXT
    private var eglConfig      : android.opengl.EGLConfig? = null
    private var pbufferSurface = EGL14.EGL_NO_SURFACE

    var initialized = false
        private set

    private var _lastSetupError = "not_started"
    fun getLastError(): String = _lastSetupError

    // ── Setup ──────────────────────────────────────────────────────────────

    fun setup(
        canvasW: Int, canvasH: Int,
        maxUndoSteps: Int = 20,
        onReady: (ok: Boolean) -> Unit
    ) {
        if (!nativeLibLoaded) {
            _lastSetupError = "native_lib_not_loaded"
            notifyMain(false, onReady); return
        }

        glHandler.post {
            try {
                _lastSetupError = "egl_init"
                if (!initEGL()) {
                    _lastSetupError = "egl_init_failed (0x${EGL14.eglGetError().toString(16)})"
                    Log.e(TAG, _lastSetupError)
                    notifyMain(false, onReady); return@post
                }

                _lastSetupError = "egl_make_current"
                if (!EGL14.eglMakeCurrent(eglDisplay, pbufferSurface, pbufferSurface, eglContext)) {
                    _lastSetupError = "egl_make_current_failed"
                    notifyMain(false, onReady); return@post
                }
                Log.i(TAG, "EGL PBuffer active. GL=${GLES30.glGetString(GLES30.GL_VERSION)}")

                _lastSetupError = "jni_init"
                val disp = EGL14.eglGetCurrentDisplay().nativeHandle
                val ctx  = EGL14.eglGetCurrentContext().nativeHandle

                val code = try {
                    jniInit(disp, ctx, canvasW, canvasH, 0, canvasW, canvasH, maxUndoSteps)
                } catch (t: Throwable) {
                    _lastSetupError = "jni_init_threw: $t"
                    notifyMain(false, onReady); return@post
                }

                val name = when(code) {
                    0 -> "OK"; 1 -> "NO_CTX"; 2 -> "NO_SURF"
                    3 -> "LAYER_FAIL"; 4 -> "STROKE_FAIL"; else -> "ERR($code)"
                }
                Log.i(TAG, "jniInit: $name canvas=${canvasW}x${canvasH}")

                if (code != 0) {
                    _lastSetupError = "jni_init_failed: $name"
                    notifyMain(false, onReady); return@post
                }

                _lastSetupError = "ok"
                initialized = true
                notifyMain(true, onReady)
            } catch (t: Throwable) {
                _lastSetupError = "crashed: $t"
                Log.e(TAG, _lastSetupError)
                notifyMain(false, onReady)
            }
        }
    }

    private fun notifyMain(ok: Boolean, cb: (Boolean) -> Unit) =
        Handler(android.os.Looper.getMainLooper()).post { cb(ok) }

    private fun notifyBytes(b: ByteArray?, cb: (ByteArray?) -> Unit) =
        Handler(android.os.Looper.getMainLooper()).post { cb(b) }

    // ── Stroke lifecycle ───────────────────────────────────────────────────

    fun beginStroke(
        layerId: Int, x: Float, y: Float, pressure: Float,
        size: Float, opacity: Float, hardness: Float, spacing: Float,
        isEraser: Boolean, brushTexId: Int, colorARGB: Int
    ) = glHandler.post {
        if (initialized) jniBeginStroke(
            layerId, x, y, pressure, size, opacity, hardness, spacing,
            isEraser, brushTexId, colorARGB
        )
    }

    fun addPoint(x: Float, y: Float, pressure: Float = 1f) =
        glHandler.post {
            if (!initialized) return@post
            ensureCurrent()  // FIX: sin esto el contexto EGL se pierde entre posts
            jniAddPoint(x, y, pressure)
        }

    /** Termina el trazo y devuelve el canvas completo como RGBA. */
    fun endStrokeAndExport(onDone: (ByteArray?) -> Unit) {
        glHandler.post {
            if (!initialized) { notifyBytes(null, onDone); return@post }
            ensureCurrent()
            jniEndStroke()
            notifyBytes(jniExportPixels(), onDone)
        }
    }

    fun cancelStroke() = glHandler.post { if (!initialized) return@post; ensureCurrent(); jniCancelStroke() }

    /** Exporta el canvas actual sin modificar el historial. */
    fun exportCanvas(onDone: (ByteArray?) -> Unit) {
        glHandler.post {
            if (!initialized) { notifyBytes(null, onDone); return@post }
            ensureCurrent()
            notifyBytes(jniExportPixels(), onDone)
        }
    }

    // ── Historial ─────────────────────────────────────────────────────────

    fun undo(onDone: (ByteArray?) -> Unit) = glHandler.post {
        if (!initialized) { notifyBytes(null, onDone); return@post }
        ensureCurrent()
        jniUndo()
        notifyBytes(jniExportPixels(), onDone)
    }

    fun redo(onDone: (ByteArray?) -> Unit) = glHandler.post {
        if (!initialized) { notifyBytes(null, onDone); return@post }
        ensureCurrent()
        jniRedo()
        notifyBytes(jniExportPixels(), onDone)
    }

    fun canUndo(): Boolean = initialized && jniCanUndo()
    fun canRedo(): Boolean = initialized && jniCanRedo()

    // ── Capas ──────────────────────────────────────────────────────────────

    fun addLayer(name: String): Int = if (initialized) jniAddLayer(name) else -1
    fun removeLayer(id: Int)   = glHandler.post { if (!initialized) return@post; ensureCurrent(); jniRemoveLayer(id) }
    fun setActiveLayer(id: Int)= glHandler.post { if (!initialized) return@post; ensureCurrent(); jniSetActiveLayer(id) }
    fun setLayerOpacity(id: Int, o: Float) = glHandler.post { if (!initialized) return@post; ensureCurrent(); jniSetLayerOpacity(id, o) }
    fun setLayerVisible(id: Int, v: Boolean) = glHandler.post { if (!initialized) return@post; ensureCurrent(); jniSetLayerVisible(id, v) }

    fun clearLayer(id: Int, onDone: (ByteArray?) -> Unit) = glHandler.post {
        if (!initialized) { notifyBytes(null, onDone); return@post }
        ensureCurrent()
        jniClearLayer(id)
        notifyBytes(jniExportPixels(), onDone)
    }

    // ── Canvas ─────────────────────────────────────────────────────────────

    fun setBackground(colorARGB: Int, onDone: (ByteArray?) -> Unit) = glHandler.post {
        ensureCurrent()
        if (initialized) jniSetBackground(colorARGB)
        notifyBytes(if (initialized) jniExportPixels() else null, onDone)
    }

    fun setCanvasSize(w: Int, h: Int) = glHandler.post { if (!initialized) return@post; ensureCurrent(); jniSetCanvasSize(w, h) }

    fun loadBrushTexture(data: ByteArray, w: Int, h: Int): Int =
        if (initialized) jniLoadBrushTexture(data, w, h) else -1
    fun unloadBrushTexture(id: Int) = glHandler.post { if (initialized) jniUnloadBrushTexture(id) }

    // ── Destroy ────────────────────────────────────────────────────────────

    /** Asegura que el contexto EGL esté activo en el GL thread. */
    private fun ensureCurrent() {
        if (eglDisplay != EGL14.EGL_NO_DISPLAY &&
            pbufferSurface != EGL14.EGL_NO_SURFACE &&
            eglContext != EGL14.EGL_NO_CONTEXT) {
            EGL14.eglMakeCurrent(eglDisplay, pbufferSurface, pbufferSurface, eglContext)
        }
    }

    fun destroy() {
        glHandler.post {
            if (initialized) jniDestroy()
            initialized = false
            destroyEGL()
        }
    }

    // ── EGL helpers (solo PBuffer) ─────────────────────────────────────────

    private fun initEGL(): Boolean {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) return false

        val ver = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, ver, 0, ver, 1)) return false

        val cfgAttribs = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGLExt.EGL_OPENGL_ES3_BIT_KHR,
            EGL14.EGL_SURFACE_TYPE,    EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
        val n = IntArray(1)
        if (!EGL14.eglChooseConfig(eglDisplay, cfgAttribs, 0, configs, 0, 1, n, 0) || n[0] == 0)
            return false
        eglConfig = configs[0]

        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, EGL14.EGL_NO_CONTEXT, ctxAttribs, 0)
        if (eglContext == EGL14.EGL_NO_CONTEXT) return false

        val pbAttribs = intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE)
        pbufferSurface = EGL14.eglCreatePbufferSurface(eglDisplay, eglConfig, pbAttribs, 0)
        if (pbufferSurface == EGL14.EGL_NO_SURFACE) return false

        Log.i(TAG, "EGL v${ver[0]}.${ver[1]} OK (PBuffer only)")
        return true
    }

    private fun destroyEGL() {
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (pbufferSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, pbufferSurface)
            if (eglContext     != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        pbufferSurface = EGL14.EGL_NO_SURFACE
    }

    // ── JNI ────────────────────────────────────────────────────────────────

    private val nativeLibLoaded: Boolean = try {
        System.loadLibrary("three_skulls_engine"); true
    } catch (t: Throwable) { Log.e(TAG, "loadLibrary failed: $t"); false }

    @JvmStatic private external fun jniInit(d: Long, c: Long, w: Int, h: Int, t: Int, cW: Int, cH: Int, u: Int): Int
    @JvmStatic private external fun jniDestroy()
    @JvmStatic private external fun jniBeginStroke(lid: Int, x: Float, y: Float, p: Float, sz: Float, op: Float, hd: Float, sp: Float, er: Boolean, bt: Int, col: Int)
    @JvmStatic private external fun jniAddPoint(x: Float, y: Float, p: Float)
    @JvmStatic private external fun jniEndStroke()
    @JvmStatic private external fun jniCancelStroke()
    @JvmStatic private external fun jniUndo()
    @JvmStatic private external fun jniRedo()
    @JvmStatic private external fun jniCanUndo(): Boolean
    @JvmStatic private external fun jniCanRedo(): Boolean
    @JvmStatic private external fun jniAddLayer(name: String): Int
    @JvmStatic private external fun jniRemoveLayer(id: Int)
    @JvmStatic private external fun jniSetActiveLayer(id: Int)
    @JvmStatic private external fun jniSetLayerOpacity(id: Int, o: Float)
    @JvmStatic private external fun jniSetLayerVisible(id: Int, v: Boolean)
    @JvmStatic private external fun jniClearLayer(id: Int)
    @JvmStatic private external fun jniSetBackground(col: Int)
    @JvmStatic private external fun jniSetCanvasSize(w: Int, h: Int)
    @JvmStatic external fun jniExportPixels(): ByteArray?
    @JvmStatic private external fun jniLoadBrushTexture(data: ByteArray, w: Int, h: Int): Int
    @JvmStatic private external fun jniUnloadBrushTexture(id: Int)
}
