package com.threeskullstattoo.app

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.GLES30
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import io.flutter.view.TextureRegistry

/**
 * Puente entre Kotlin y el motor C++ de dibujo.
 *
 * Flujo:
 * 1. Flutter crea un Texture widget con textureId
 * 2. Esta clase inicializa EGL en un thread dedicado
 * 3. El motor C++ recibe el EGLContext compartido y el textureId
 * 4. Al terminar un stroke, C++ llama onFrameReady → markFrameAvailable
 * 5. Flutter muestra el frame actualizado automáticamente
 */
object DrawingEngineJNI {

    private const val TAG = "TSK_KT"

    // ── GL Thread ──────────────────────────────────────────────────────
    private val glThread = HandlerThread("TSK-GL-Thread").also { it.start() }
    private val glHandler = Handler(glThread.looper)

    // ── EGL ────────────────────────────────────────────────────────────
    private var eglDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface = EGL14.EGL_NO_SURFACE

    // ── Flutter Texture ────────────────────────────────────────────────
    private var flutterTexture: TextureRegistry.SurfaceTextureEntry? = null
    private var surfaceTexture: SurfaceTexture? = null
    private var glTexture: Int = 0
    var textureId: Long = -1L
        private set

    // ── State ──────────────────────────────────────────────────────────
    private var initialized = false
    var onFrameAvailable: (() -> Unit)? = null

    // ── Setup principal ────────────────────────────────────────────────

    fun setup(
        textureRegistry: TextureRegistry,
        canvasW: Int, canvasH: Int,
        maxUndoSteps: Int = 20,
        onReady: (textureId: Long) -> Unit
    ) {
        glHandler.post {
            // 1. Crear EGL display + context
            if (!initEGL()) {
                Log.e(TAG, "EGL init failed")
                return@post
            }

            // 2. Registrar texture en Flutter
            val entry = textureRegistry.createSurfaceTexture()
            flutterTexture = entry
            surfaceTexture = entry.surfaceTexture()
            textureId = entry.id()

            // 3. Obtener GL texture ID del SurfaceTexture
            // SurfaceTexture.getExternalTextureId() no existe directamente,
            // necesitamos crear un GL_TEXTURE_EXTERNAL_OES
            val texIds = IntArray(1)
            GLES30.glGenTextures(1, texIds, 0)
            glTexture = texIds[0]
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, glTexture)
            GLES30.glTexImage2D(
                GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA,
                canvasW, canvasH, 0,
                GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, null
            )
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)

            // 4. Inicializar motor C++
            val eglDisplayPtr = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            val ok = nativeInit(
                eglDisplayPtr.nativeHandle,
                eglContext.nativeHandle,
                canvasW, canvasH, glTexture,
                canvasW, canvasH, maxUndoSteps
            )

            initialized = ok
            if (ok) {
                Log.i(TAG, "DrawingEngine ready, textureId=$textureId")
                // Notificar Flutter en el main thread
                Handler(android.os.Looper.getMainLooper()).post {
                    onReady(textureId)
                }
            } else {
                Log.e(TAG, "nativeInit failed")
            }
        }
    }

    // ── Frame callback ─────────────────────────────────────────────────

    /**
     * Llamado desde C++ cuando hay un frame listo.
     * Marca el SurfaceTexture para que Flutter actualice el widget.
     */
    @JvmStatic
    fun onFrameReady() {
        surfaceTexture?.updateTexImage()
        flutterTexture?.surfaceTexture()?.let {
            // markFrameAvailable no es accesible directamente en Flutter embedding
            // En su lugar usamos el listener del SurfaceTexture
        }
        onFrameAvailable?.invoke()
    }

    // ── Stroke commands ────────────────────────────────────────────────

    fun beginStroke(
        layerId: Int, x: Float, y: Float, pressure: Float,
        size: Float, opacity: Float, hardness: Float, spacing: Float,
        isEraser: Boolean, brushTexId: Int, colorARGB: Int
    ) = glHandler.post {
        if (initialized) beginStroke(
            layerId, x, y, pressure,
            size, opacity, hardness, spacing,
            isEraser, brushTexId, colorARGB
        )
    }

    fun addPoint(x: Float, y: Float, pressure: Float = 1f) =
        glHandler.post { if (initialized) addPoint(x, y, pressure) }

    fun endStroke() =
        glHandler.post { if (initialized) endStroke() }

    fun cancelStroke() =
        glHandler.post { if (initialized) cancelStroke() }

    // ── History ────────────────────────────────────────────────────────

    fun undo() = glHandler.post { if (initialized) undo() }
    fun redo() = glHandler.post { if (initialized) redo() }
    fun canUndo() = if (initialized) canUndo() else false
    fun canRedo() = if (initialized) canRedo() else false

    // ── Layers ─────────────────────────────────────────────────────────

    fun addLayer(name: String): Int =
        if (initialized) addLayer(name) else -1

    fun removeLayer(id: Int) =
        glHandler.post { if (initialized) removeLayer(id) }

    fun setActiveLayer(id: Int) =
        glHandler.post { if (initialized) setActiveLayer(id) }

    fun setLayerOpacity(id: Int, opacity: Float) =
        glHandler.post { if (initialized) setLayerOpacity(id, opacity) }

    fun setLayerVisible(id: Int, visible: Boolean) =
        glHandler.post { if (initialized) setLayerVisible(id, visible) }

    fun clearLayer(id: Int) =
        glHandler.post { if (initialized) clearLayer(id) }

    // ── Canvas ─────────────────────────────────────────────────────────

    fun setBackground(colorARGB: Int) =
        glHandler.post { if (initialized) setBackground(colorARGB) }

    fun setCanvasSize(w: Int, h: Int) =
        glHandler.post { if (initialized) setCanvasSize(w, h) }

    // ── Export ─────────────────────────────────────────────────────────

    fun exportPixels(): ByteArray? =
        if (initialized) exportPixels() else null

    // ── Cleanup ────────────────────────────────────────────────────────

    fun destroy() {
        glHandler.post {
            nativeDestroy()
            destroyEGL()
            initialized = false
        }
    }

    // ── EGL helpers ────────────────────────────────────────────────────

    private fun initEGL(): Boolean {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (eglDisplay == EGL14.EGL_NO_DISPLAY) {
            Log.e(TAG, "eglGetDisplay failed")
            return false
        }

        val version = IntArray(2)
        if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
            Log.e(TAG, "eglInitialize failed")
            return false
        }

        val configAttribs = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES3_BIT_KHR,
            EGL14.EGL_SURFACE_TYPE,    EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_RED_SIZE,   8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE,  8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_NONE
        )

        val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
        val numConfigs = IntArray(1)
        if (!EGL14.eglChooseConfig(eglDisplay, configAttribs, 0,
                configs, 0, 1, numConfigs, 0) || numConfigs[0] == 0) {
            Log.e(TAG, "eglChooseConfig failed")
            return false
        }

        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, ctxAttribs, 0)
        if (eglContext == EGL14.EGL_NO_CONTEXT) {
            Log.e(TAG, "eglCreateContext failed: ${EGL14.eglGetError()}")
            return false
        }

        val pbAttribs = intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreatePbufferSurface(eglDisplay, configs[0], pbAttribs, 0)
        if (eglSurface == EGL14.EGL_NO_SURFACE) {
            Log.e(TAG, "eglCreatePbufferSurface failed")
            return false
        }

        if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
            Log.e(TAG, "eglMakeCurrent failed")
            return false
        }

        Log.i(TAG, "EGL initialized: OpenGL ES ${GLES30.glGetString(GLES30.GL_VERSION)}")
        return true
    }

    private fun destroyEGL() {
        if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (eglSurface != EGL14.EGL_NO_SURFACE)  EGL14.eglDestroySurface(eglDisplay, eglSurface)
            if (eglContext != EGL14.EGL_NO_CONTEXT)  EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        eglDisplay = EGL14.EGL_NO_DISPLAY
        eglContext = EGL14.EGL_NO_CONTEXT
        eglSurface = EGL14.EGL_NO_SURFACE
    }

    // ── JNI declarations (implementadas en jni_bridge.cpp) ─────────────

    init { System.loadLibrary("three_skulls_engine") }

    @JvmStatic external fun nativeInit(eglDisplay: Long, sharedContext: Long, width: Int, height: Int, textureId: Int, canvasW: Int, canvasH: Int, maxUndo: Int): Boolean
    @JvmStatic external fun nativeDestroy()
    @JvmStatic external fun nativeRender()

    @JvmStatic external fun beginStroke(layerId: Int, x: Float, y: Float, pressure: Float, size: Float, opacity: Float, hardness: Float, spacing: Float, isEraser: Boolean, brushTexId: Int, colorARGB: Int)
    @JvmStatic external fun addPoint(x: Float, y: Float, pressure: Float)
    @JvmStatic external fun endStroke()
    @JvmStatic external fun cancelStroke()

    @JvmStatic external fun undo()
    @JvmStatic external fun redo()
    @JvmStatic external fun canUndo(): Boolean
    @JvmStatic external fun canRedo(): Boolean

    @JvmStatic external fun addLayer(name: String): Int
    @JvmStatic external fun removeLayer(id: Int)
    @JvmStatic external fun setActiveLayer(id: Int)
    @JvmStatic external fun setLayerOpacity(id: Int, opacity: Float)
    @JvmStatic external fun setLayerVisible(id: Int, visible: Boolean)
    @JvmStatic external fun clearLayer(id: Int)

    @JvmStatic external fun setBackground(colorARGB: Int)
    @JvmStatic external fun setCanvasSize(w: Int, h: Int)

    @JvmStatic external fun exportPixels(): ByteArray?
    @JvmStatic external fun loadBrushTexture(data: ByteArray, w: Int, h: Int): Int
    @JvmStatic external fun unloadBrushTexture(id: Int)
}
