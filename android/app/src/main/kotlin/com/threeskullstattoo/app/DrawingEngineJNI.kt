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

/**
 * Puente Kotlin ↔ C++ motor de dibujo.
 *
 * ARQUITECTURA CORRECTA:
 * 1. Flutter crea un SurfaceTexture entry (GL_TEXTURE_EXTERNAL_OES)
 * 2. Kotlin crea una EGL WindowSurface desde ese SurfaceTexture.Surface
 * 3. C++ renderiza al framebuffer 0 (la window surface) — NO a una texture custom
 * 4. Kotlin llama eglSwapBuffers → Flutter actualiza el Texture widget
 */
object DrawingEngineJNI {

    private const val TAG = "TSK_KT"

    private val glThread = HandlerThread("TSK-GL").also { it.start() }
    val glHandler = Handler(glThread.looper)

    // EGL state
    private var eglDisplay  = EGL14.EGL_NO_DISPLAY
    private var eglContext  = EGL14.EGL_NO_CONTEXT
    private var eglConfig   : android.opengl.EGLConfig? = null
    private var windowSurface = EGL14.EGL_NO_SURFACE  // render target principal
    private var pbufferSurface = EGL14.EGL_NO_SURFACE // para init antes de window

    // Flutter texture
    private var textureEntry : TextureRegistry.SurfaceTextureEntry? = null
    private var surfaceTex   : SurfaceTexture? = null
    private var surface      : Surface? = null

    var textureId: Long = -1L
        private set

    var initialized = false
        private set

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
            Log.e(TAG, "Native lib not loaded")
            onReady(-1L)
            return
        }
        glHandler.post {
            try {
                // ── 1. Init EGL display + context ──────────────────
                if (!initEGL()) {
                    Log.e(TAG, "EGL init failed")
                    notifyMain(-1L, onReady); return@post
                }

                // ── 2. Crear Flutter SurfaceTexture ────────────────
                val entry = textureRegistry.createSurfaceTexture()
                textureEntry = entry
                textureId = entry.id()
                surfaceTex = entry.surfaceTexture()
                surfaceTex!!.setDefaultBufferSize(canvasW, canvasH)

                // ── 3. Crear EGL WindowSurface desde la Surface ────
                surface = Surface(surfaceTex!!)
                val winAttribs = intArrayOf(EGL14.EGL_NONE)
                windowSurface = EGL14.eglCreateWindowSurface(
                    eglDisplay, eglConfig, surface, winAttribs, 0)

                if (windowSurface == EGL14.EGL_NO_SURFACE) {
                    Log.e(TAG, "eglCreateWindowSurface failed: ${EGL14.eglGetError()}")
                    notifyMain(-1L, onReady); return@post
                }

                // ── 4. Hacer current la window surface ─────────────
                if (!EGL14.eglMakeCurrent(eglDisplay, windowSurface, windowSurface, eglContext)) {
                    Log.e(TAG, "eglMakeCurrent(windowSurface) failed: ${EGL14.eglGetError()}")
                    notifyMain(-1L, onReady); return@post
                }
                Log.i(TAG, "WindowSurface current: canvas=${canvasW}x${canvasH}")
                Log.i(TAG, "GL_VERSION: ${GLES30.glGetString(GLES30.GL_VERSION)}")
                Log.i(TAG, "GL_RENDERER: ${GLES30.glGetString(GLES30.GL_RENDERER)}")

                // ── 5. Init motor C++ ──────────────────────────────
                // C++ renderiza al framebuffer 0 (la window surface directamente)
                val dispHandle = EGL14.eglGetCurrentDisplay().nativeHandle
                val ctxHandle  = EGL14.eglGetCurrentContext().nativeHandle

                val ok = try {
                    jniInit(dispHandle, ctxHandle, canvasW, canvasH, 0,
                            canvasW, canvasH, maxUndoSteps)
                } catch (t: Throwable) {
                    Log.e(TAG, "jniInit threw: $t"); false
                }

                Log.i(TAG, "jniInit result: $ok  textureId=$textureId")
                initialized = ok

                notifyMain(if (ok) textureId else -1L, onReady)

            } catch (t: Throwable) {
                Log.e(TAG, "setup crashed: $t")
                initialized = false
                notifyMain(-1L, onReady)
            }
        }
    }

    // Llama eglSwapBuffers para actualizar el SurfaceTexture de Flutter
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
        if (initialized) jniBeginStroke(
            layerId, x, y, pressure,
            size, opacity, hardness, spacing,
            isEraser, brushTexId, colorARGB
        )
    }

    fun addPoint(x: Float, y: Float, pressure: Float = 1f) =
        glHandler.post { if (initialized) jniAddPoint(x, y, pressure) }

    fun endStroke()    = glHandler.post { if (initialized) { jniEndStroke(); swapBuffers() } }
    fun cancelStroke() = glHandler.post { if (initialized) jniCancelStroke() }

    fun undo() = glHandler.post { if (initialized) { jniUndo(); swapBuffers() } }
    fun redo() = glHandler.post { if (initialized) { jniRedo(); swapBuffers() } }
    fun canUndo(): Boolean = initialized && jniCanUndo()
    fun canRedo(): Boolean = initialized && jniCanRedo()

    fun addLayer(name: String): Int = if (initialized) jniAddLayer(name) else -1
    fun removeLayer(id: Int)            = glHandler.post { if (initialized) jniRemoveLayer(id) }
    fun setActiveLayer(id: Int)         = glHandler.post { if (initialized) jniSetActiveLayer(id) }
    fun setLayerOpacity(id: Int, o: Float) = glHandler.post { if (initialized) jniSetLayerOpacity(id, o) }
    fun setLayerVisible(id: Int, v: Boolean) = glHandler.post { if (initialized) jniSetLayerVisible(id, v) }
    fun clearLayer(id: Int)             = glHandler.post { if (initialized) { jniClearLayer(id); swapBuffers() } }
    fun setBackground(colorARGB: Int)   = glHandler.post { if (initialized) { jniSetBackground(colorARGB); swapBuffers() } }
    fun setCanvasSize(w: Int, h: Int)   = glHandler.post {
        if (initialized) {
            jniSetCanvasSize(w, h)
            // Resize la window surface
            surfaceTex?.setDefaultBufferSize(w, h)
            swapBuffers()
        }
    }
    fun exportPixels(): ByteArray? = if (initialized) jniExportPixels() else null
    fun loadBrushTexture(data: ByteArray, w: Int, h: Int): Int =
        if (initialized) jniLoadBrushTexture(data, w, h) else -1
    fun unloadBrushTexture(id: Int) = glHandler.post { if (initialized) jniUnloadBrushTexture(id) }

    // ═══════════════════════════════════════════════════════════
    // EGL helpers
    // ═══════════════════════════════════════════════════════════

    private fun initEGL(): Boolean {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) return false

        val ver = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, ver, 0, ver, 1)) return false

        // Config con WINDOW_BIT para poder crear WindowSurface
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
            Log.e(TAG, "eglChooseConfig failed")
            return false
        }
        eglConfig = configs[0]

        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, EGL14.EGL_NO_CONTEXT, ctxAttribs, 0)
        if (eglContext == EGL14.EGL_NO_CONTEXT) {
            Log.e(TAG, "eglCreateContext failed: ${EGL14.eglGetError()}")
            return false
        }

        // PBuffer temporal para poder hacer GL calls antes de la window surface
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
            if (eglContext     != EGL14.EGL_NO_CONTEXT)  EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        surface?.release()
        eglDisplay    = EGL14.EGL_NO_DISPLAY
        eglContext    = EGL14.EGL_NO_CONTEXT
        windowSurface = EGL14.EGL_NO_SURFACE
    }

    // ═══════════════════════════════════════════════════════════
    // JNI (prefijo jni para evitar ambigüedad con la API pública)
    // ═══════════════════════════════════════════════════════════

    private val nativeLibLoaded: Boolean = try {
        System.loadLibrary("three_skulls_engine"); true
    } catch (t: Throwable) { Log.e(TAG, "loadLibrary failed: $t"); false }

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
