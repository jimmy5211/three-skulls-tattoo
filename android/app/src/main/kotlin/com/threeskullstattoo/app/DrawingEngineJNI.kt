package com.threeskullstattoo.app

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLExt
import android.opengl.GLES30
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import io.flutter.view.TextureRegistry

object DrawingEngineJNI {

    private const val TAG = "TSK_KT"

    private val glThread = HandlerThread("TSK-GL").also { it.start() }
    val glHandler = Handler(glThread.looper)

    // EGL state
    private var eglDisplay   = EGL14.EGL_NO_DISPLAY
    private var eglContext   = EGL14.EGL_NO_CONTEXT
    private var eglConfig    : android.opengl.EGLConfig? = null
    private var windowSurface  = EGL14.EGL_NO_SURFACE
    private var pbufferSurface = EGL14.EGL_NO_SURFACE

    // Flutter texture
    private var textureEntry : TextureRegistry.SurfaceTextureEntry? = null
    private var surfaceTex   : SurfaceTexture? = null
    private var surface      : Surface? = null

    var textureId: Long = -1L
        private set

    var initialized = false
        private set

    private var _lastSetupError = "not_started"

    // ═══════════════════════════════════════════════════════════
    // SETUP
    // ═══════════════════════════════════════════════════════════

    fun setup(
        textureRegistry: TextureRegistry,
        canvasW: Int, canvasH: Int,
        maxUndoSteps: Int = 20,
        onReady: (textureId: Long) -> Unit
    ) {
        if (!nativeLibLoaded) {
            _lastSetupError = "native_lib_not_loaded"
            Log.e(TAG, "Native lib not loaded")
            onReady(-1L)
            return
        }

        // FIX: createSurfaceTexture() DEBE llamarse en el main thread.
        _lastSetupError = "creating_surface_texture"
        val entry = try {
            textureRegistry.createSurfaceTexture()
        } catch (t: Throwable) {
            _lastSetupError = "create_surface_texture_failed: $t"
            Log.e(TAG, _lastSetupError)
            onReady(-1L)
            return
        }
        textureEntry = entry
        textureId    = entry.id()
        val st = entry.surfaceTexture()
        surfaceTex   = st
        st.setDefaultBufferSize(canvasW, canvasH)
        Log.i(TAG, "SurfaceTexture created on main thread: id=$textureId canvas=${canvasW}x${canvasH}")
        _lastSetupError = "surface_texture_ok_starting_gl_thread"

        glHandler.post {
            try {
                // ── 1. Init EGL ──────────────────────────────────
                _lastSetupError = "egl_init"
                if (!initEGL()) {
                    _lastSetupError = "egl_init_failed (error=0x${EGL14.eglGetError().toString(16)})"
                    Log.e(TAG, _lastSetupError)
                    notifyMain(-1L, onReady); return@post
                }
                Log.i(TAG, "EGL init OK")

                // ── 2. Crear EGL WindowSurface ───────────────────
                _lastSetupError = "creating_window_surface"
                surface = Surface(st)
                val winAttribs = intArrayOf(EGL14.EGL_NONE)
                windowSurface = EGL14.eglCreateWindowSurface(
                    eglDisplay, eglConfig, surface, winAttribs, 0)

                if (windowSurface == EGL14.EGL_NO_SURFACE) {
                    _lastSetupError = "egl_create_window_surface_failed (error=0x${EGL14.eglGetError().toString(16)})"
                    Log.e(TAG, _lastSetupError)
                    notifyMain(-1L, onReady); return@post
                }
                Log.i(TAG, "WindowSurface created OK")

                // ── 3. Make current ──────────────────────────────
                _lastSetupError = "egl_make_current"
                if (!EGL14.eglMakeCurrent(eglDisplay, windowSurface, windowSurface, eglContext)) {
                    _lastSetupError = "egl_make_current_failed (error=0x${EGL14.eglGetError().toString(16)})"
                    Log.e(TAG, _lastSetupError)
                    notifyMain(-1L, onReady); return@post
                }
                Log.i(TAG, "eglMakeCurrent OK")
                Log.i(TAG, "GL_VERSION:  ${GLES30.glGetString(GLES30.GL_VERSION)}")
                Log.i(TAG, "GL_RENDERER: ${GLES30.glGetString(GLES30.GL_RENDERER)}")

                // ── 4. Init motor C++ ────────────────────────────
                _lastSetupError = "jni_init"
                val dispHandle = EGL14.eglGetCurrentDisplay().nativeHandle
                val ctxHandle  = EGL14.eglGetCurrentContext().nativeHandle

                val errCode = try {
                    jniInit(dispHandle, ctxHandle, canvasW, canvasH, 0,
                            canvasW, canvasH, maxUndoSteps)
                } catch (t: Throwable) {
                    _lastSetupError = "jni_init_threw: $t"
                    Log.e(TAG, _lastSetupError)
                    notifyMain(-1L, onReady); return@post
                }

                val errName = when(errCode) {
                    0    -> "SUCCESS"
                    1    -> "NO_EGL_CONTEXT"
                    2    -> "NO_EGL_SURFACE"
                    3    -> "LAYER_MGR_INIT_FAILED"
                    4    -> "STROKE_ENGINE_INIT_FAILED"
                    else -> "UNKNOWN_CODE($errCode)"
                }
                Log.i(TAG, "jniInit: $errName  textureId=$textureId")

                if (errCode != 0) {
                    _lastSetupError = "jni_init_failed: $errName"
                    Log.e(TAG, "=== C++ ENGINE FAILED: $errName ===")
                    notifyMain(-1L, onReady); return@post
                }

                _lastSetupError = "ok"
                initialized = true
                notifyMain(textureId, onReady)

            } catch (t: Throwable) {
                _lastSetupError = "setup_crashed: $t"
                Log.e(TAG, _lastSetupError)
                initialized = false
                notifyMain(-1L, onReady)
            }
        }
    }

    fun swapBuffers() {
        if (windowSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglSwapBuffers(eglDisplay, windowSurface)
        }
    }

    private fun notifyMain(id: Long, cb: (Long) -> Unit) {
        Handler(android.os.Looper.getMainLooper()).post { cb(id) }
    }

    // ═══════════════════════════════════════════════════════════
    // PUBLIC API
    // ═══════════════════════════════════════════════════════════

    fun render() = glHandler.post {
        if (initialized) { jniRender(); swapBuffers() }
    }

    fun destroy() {
        glHandler.post {
            if (initialized) jniDestroy()
            initialized = false
            destroyEGL()
        }
    }

    fun beginStroke(
        layerId: Int, x: Float, y: Float, pressure: Float,
        size: Float, opacity: Float, hardness: Float, spacing: Float,
        isEraser: Boolean, brushTexId: Int, colorARGB: Int
    ) = glHandler.post {
        if (initialized) {
            jniBeginStroke(
                layerId, x, y, pressure,
                size, opacity, hardness, spacing,
                isEraser, brushTexId, colorARGB
            )
            // FIX Fase 2: render el primer stamp inmediatamente
            jniRender(); swapBuffers()
        }
    }

    // FIX Fase 2: render después de cada punto para feedback en tiempo real
    fun addPoint(x: Float, y: Float, pressure: Float = 1f) =
        glHandler.post {
            if (initialized) {
                jniAddPoint(x, y, pressure)
                jniRender()
                swapBuffers()
            }
        }

    fun endStroke()    = glHandler.post { if (initialized) { jniEndStroke(); jniRender(); swapBuffers() } }
    fun cancelStroke() = glHandler.post { if (initialized) jniCancelStroke() }

    fun undo() = glHandler.post { if (initialized) { jniUndo(); swapBuffers() } }
    fun redo() = glHandler.post { if (initialized) { jniRedo(); swapBuffers() } }
    fun canUndo(): Boolean = initialized && jniCanUndo()
    fun canRedo(): Boolean = initialized && jniCanRedo()

    fun addLayer(name: String): Int = if (initialized) jniAddLayer(name) else -1
    fun removeLayer(id: Int)             = glHandler.post { if (initialized) jniRemoveLayer(id) }
    fun setActiveLayer(id: Int)          = glHandler.post { if (initialized) jniSetActiveLayer(id) }
    fun setLayerOpacity(id: Int, o: Float)    = glHandler.post { if (initialized) jniSetLayerOpacity(id, o) }
    fun setLayerVisible(id: Int, v: Boolean)  = glHandler.post { if (initialized) jniSetLayerVisible(id, v) }
    fun clearLayer(id: Int)              = glHandler.post { if (initialized) { jniClearLayer(id); swapBuffers() } }
    fun setBackground(colorARGB: Int)    = glHandler.post { if (initialized) { jniSetBackground(colorARGB); swapBuffers() } }
    fun setCanvasSize(w: Int, h: Int)    = glHandler.post {
        if (initialized) {
            jniSetCanvasSize(w, h)
            surfaceTex?.setDefaultBufferSize(w, h)
            swapBuffers()
        }
    }
    fun exportPixels(): ByteArray? = if (initialized) jniExportPixels() else null
    fun loadBrushTexture(data: ByteArray, w: Int, h: Int): Int =
        if (initialized) jniLoadBrushTexture(data, w, h) else -1
    fun unloadBrushTexture(id: Int) = glHandler.post { if (initialized) jniUnloadBrushTexture(id) }

    fun getLastError(): String = _lastSetupError

    // ═══════════════════════════════════════════════════════════
    // EGL helpers
    // ═══════════════════════════════════════════════════════════

    private fun initEGL(): Boolean {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) { Log.e(TAG, "eglGetDisplay failed"); return false }

        val ver = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, ver, 0, ver, 1)) {
            Log.e(TAG, "eglInitialize failed: 0x${EGL14.eglGetError().toString(16)}")
            return false
        }

        val cfgAttribs = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGLExt.EGL_OPENGL_ES3_BIT_KHR,
            EGL14.EGL_SURFACE_TYPE,    EGL14.EGL_WINDOW_BIT or EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_RED_SIZE,   8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE,  8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
        val n = IntArray(1)
        if (!EGL14.eglChooseConfig(eglDisplay, cfgAttribs, 0, configs, 0, 1, n, 0) || n[0] == 0) {
            Log.e(TAG, "eglChooseConfig failed: 0x${EGL14.eglGetError().toString(16)}")
            return false
        }
        eglConfig = configs[0]

        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, EGL14.EGL_NO_CONTEXT, ctxAttribs, 0)
        if (eglContext == EGL14.EGL_NO_CONTEXT) {
            Log.e(TAG, "eglCreateContext failed: 0x${EGL14.eglGetError().toString(16)}")
            return false
        }

        val pbAttribs = intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE)
        pbufferSurface = EGL14.eglCreatePbufferSurface(eglDisplay, eglConfig, pbAttribs, 0)
        EGL14.eglMakeCurrent(eglDisplay, pbufferSurface, pbufferSurface, eglContext)

        Log.i(TAG, "EGL initialized: v${ver[0]}.${ver[1]}")
        return true
    }

    private fun destroyEGL() {
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (windowSurface  != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, windowSurface)
            if (pbufferSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, pbufferSurface)
            if (eglContext     != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        surface?.release()
        eglDisplay    = EGL14.EGL_NO_DISPLAY
        eglContext    = EGL14.EGL_NO_CONTEXT
        windowSurface = EGL14.EGL_NO_SURFACE
    }

    // ═══════════════════════════════════════════════════════════
    // JNI
    // ═══════════════════════════════════════════════════════════

    private val nativeLibLoaded: Boolean = try {
        System.loadLibrary("three_skulls_engine"); true
    } catch (t: Throwable) { Log.e(TAG, "loadLibrary failed: $t"); false }

    @JvmStatic private external fun jniInit(eglDisplay: Long, sharedCtx: Long, w: Int, h: Int, texId: Int, canvasW: Int, canvasH: Int, maxUndo: Int): Int
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
