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
 *
 * UNDO/REDO: stack de snapshots en Kotlin (ByteArray por layer activo).
 * Antes de cada beginStroke se guarda jniExportPixels() como checkpoint.
 * Undo/redo ROI-based en C++ (Command struct con before/after pixels).
 *
 * SIMETRÍA: jniSetSymmetry() activa el espejo en StrokeEngine C++.
 * Cada stamp se duplica horizontalmente sin overhead en Dart.
 */
object DrawingEngineJNI {

    private const val TAG     = "TSK_KT"
    private const val MAX_UNDO = 20

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

    // Canvas size
    private var canvasW = 1080
    private var canvasH = 1920

    // ── Setup ──────────────────────────────────────────────────────────────

    fun setup(
        canvasW: Int, canvasH: Int,
        maxUndoSteps: Int = MAX_UNDO,
        onReady: (ok: Boolean) -> Unit
    ) {
        this.canvasW = canvasW
        this.canvasH = canvasH

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

                initialized = true
                _lastSetupError = "ok"
                notifyMain(true, onReady)

            } catch (t: Throwable) {
                _lastSetupError = "setup_threw: $t"
                Log.e(TAG, _lastSetupError, t)
                notifyMain(false, onReady)
            }
        }
    }

    private fun notifyMain(ok: Boolean, cb: (Boolean) -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post { cb(ok) }
    }

    private fun notifyBytes(bytes: ByteArray?, cb: (ByteArray?) -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post { cb(bytes) }
    }

    private fun ensureCurrent() {
        if (EGL14.eglGetCurrentContext() == EGL14.EGL_NO_CONTEXT) {
            EGL14.eglMakeCurrent(eglDisplay, pbufferSurface, pbufferSurface, eglContext)
        }
    }

    // ── Stroke lifecycle ───────────────────────────────────────────────────

    fun beginStroke(
        layerId: Int, x: Float, y: Float, pressure: Float,
        size: Float, opacity: Float, hardness: Float, spacing: Float,
        isEraser: Boolean, brushTexId: Int, colorARGB: Int,
        // Parámetros .tskbrush (valores default = comportamiento anterior)
        spacingBase: Float = 0.04f, spacingVelocity: Float = 0.001f,
        spacingMinPx: Float = 1.0f, jitterPos: Float = 0.03f,
        jitterSize: Float = 0.02f,  jitterRot: Float = 6.28f,
        followStroke: Boolean = true, flow: Float = 0.55f, grainDepth: Float = 0.0f
    ) = glHandler.post {
        if (!initialized) return@post
        ensureCurrent()

        // Aplicar parámetros dinámicos del pincel ANTES de beginStroke
        jniSetBrushDynParams(
            spacingBase, spacingVelocity, spacingMinPx,
            jitterPos, jitterSize, jitterRot,
            followStroke, flow, grainDepth
        )
        jniBeginStroke(
            layerId, x, y, pressure, size, opacity, hardness, spacing,
            isEraser, brushTexId, colorARGB
        )
    }

    // Configura parámetros dinámicos sin iniciar trazo (útil para preview)
    fun setBrushDynParams(
        spacingBase: Float = 0.04f, spacingVelocity: Float = 0.001f,
        spacingMinPx: Float = 1.0f, jitterPos: Float = 0.03f,
        jitterSize: Float = 0.02f,  jitterRot: Float = 6.28f,
        followStroke: Boolean = true, flow: Float = 0.55f, grainDepth: Float = 0.0f
    ) = glHandler.post {
        if (!initialized) return@post
        ensureCurrent()
        jniSetBrushDynParams(
            spacingBase, spacingVelocity, spacingMinPx,
            jitterPos, jitterSize, jitterRot,
            followStroke, flow, grainDepth
        )
    }

    fun addPoint(x: Float, y: Float, pressure: Float = 1f) =
        glHandler.post { if (initialized) jniAddPoint(x, y, pressure) }

    fun endStrokeAndExport(onDone: (ByteArray?) -> Unit) {
        glHandler.post {
            if (!initialized) { notifyBytes(null, onDone); return@post }
            ensureCurrent()
            jniEndStroke()
            notifyBytes(jniExportPixels(), onDone)
        }
    }

    fun cancelStroke() = glHandler.post { if (initialized) jniCancelStroke() }

    // Stamp directo sin interpolación — para espejo del borrador.
    fun stampAt(x: Float, y: Float) =
        glHandler.post { if (initialized) jniStampAt(x, y) }

    fun exportCanvas(onDone: (ByteArray?) -> Unit) {
        glHandler.post {
            notifyBytes(if (initialized) jniExportPixels() else null, onDone)
        }
    }

    // ── Historial (stack Kotlin + restore C++) ─────────────────────────────

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

    // ── Simetría ──────────────────────────────────────────────────────────
    // Activa/desactiva el espejo en StrokeEngine C++.
    // axis: 0=horizontal (espejo en X), 1=vertical (espejo en Y).
    fun setSymmetry(enabled: Boolean, axis: Int = 0) =
        glHandler.post { if (initialized) jniSetSymmetry(enabled, axis) }

    // ── Capas ──────────────────────────────────────────────────────────────

    fun addLayer(name: String): Int = if (initialized) jniAddLayer(name) else -1
    fun removeLayer(id: Int)   = glHandler.post { if (initialized) jniRemoveLayer(id) }
    fun setActiveLayer(id: Int)= glHandler.post { if (initialized) jniSetActiveLayer(id) }
    fun setLayerOpacity(id: Int, o: Float) = glHandler.post { if (initialized) jniSetLayerOpacity(id, o) }
    fun setLayerVisible(id: Int, v: Boolean) = glHandler.post { if (initialized) jniSetLayerVisible(id, v) }

    fun clearLayer(id: Int, onDone: (ByteArray?) -> Unit) = glHandler.post {
        if (initialized) jniClearLayer(id)
        notifyBytes(if (initialized) jniExportPixels() else null, onDone)
    }

    // ── Canvas ─────────────────────────────────────────────────────────────

    fun setBackground(colorARGB: Int, onDone: (ByteArray?) -> Unit) = glHandler.post {
        ensureCurrent()
        if (initialized) jniSetBackground(colorARGB)
        notifyBytes(if (initialized) jniExportPixels() else null, onDone)
    }

    fun setCanvasSize(w: Int, h: Int) {
        canvasW = w; canvasH = h
        glHandler.post {
            ensureCurrent()
            if (initialized) jniSetCanvasSize(w, h)
        }
    }

    fun eraseRegion(layerId: Int, x: Float, y: Float, w: Float, h: Float) =
        glHandler.post { if (initialized) jniEraseRegion(layerId, x, y, w, h) }

    // ── Brush textures ──────────────────────────────────────────────────────

    fun loadBrushTexture(data: ByteArray, w: Int, h: Int, onDone: (Int) -> Unit) {
        glHandler.post {
            ensureCurrent() // FIX: GL context debe estar activo para glGenTextures/glTexImage2D
            val id = if (initialized) jniLoadBrushTexture(data, w, h) else -1
            Log.i(TAG, "loadBrushTexture: ${w}x${h} → texId=$id")
            android.os.Handler(android.os.Looper.getMainLooper()).post { onDone(id) }
        }
    }

    fun unloadBrushTexture(id: Int) =
        glHandler.post { if (initialized) jniUnloadBrushTexture(id) }

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
    @JvmStatic private external fun jniStampAt(x: Float, y: Float)
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
    @JvmStatic private external fun jniEraseRegion(layerId: Int, x: Float, y: Float, w: Float, h: Float)
    @JvmStatic          external fun jniExportPixels(): ByteArray?
    @JvmStatic private external fun jniLoadBrushTexture(data: ByteArray, w: Int, h: Int): Int
    @JvmStatic private external fun jniUnloadBrushTexture(id: Int)
    // NUEVO: simetría
    @JvmStatic private external fun jniSetSymmetry(enabled: Boolean, axis: Int)
    // NUEVO: parámetros dinámicos .tskbrush
    @JvmStatic private external fun jniSetBrushDynParams(
        spacingBase: Float, spacingVelocity: Float, spacingMinPx: Float,
        jitterPos: Float, jitterSize: Float, jitterRot: Float,
        followStroke: Boolean, flow: Float, grainDepth: Float
    )
}
