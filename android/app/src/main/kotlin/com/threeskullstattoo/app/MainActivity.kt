package com.threeskullstattoo.app

import android.os.Bundle
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CH_ENGINE  = "tsk/drawing_engine"   // comandos: init, undo, layers…
        private const val CH_TOUCH   = "tsk/touch_events"     // eventos de touch en tiempo real
    }

    // ── EventChannel sink para touch ──────────────────────────────────
    private var touchEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val texRegistry = flutterEngine.renderer

        // ── MethodChannel: comandos al motor ──────────────────────────
        MethodChannel(messenger, CH_ENGINE).setMethodCallHandler { call, result ->
            when (call.method) {

                "init" -> {
                    val canvasW    = call.argument<Int>("canvasW")    ?: 1080
                    val canvasH    = call.argument<Int>("canvasH")    ?: 1920
                    val maxUndo    = call.argument<Int>("maxUndo")    ?: 20

                    DrawingEngineJNI.setup(
                        textureRegistry = texRegistry,
                        canvasW = canvasW,
                        canvasH = canvasH,
                        maxUndoSteps = maxUndo,
                        onReady = { textureId ->
                            // Frame callback → notificar Flutter
                            DrawingEngineJNI.onFrameAvailable = {
                                runOnUiThread {
                                    // El Texture widget se actualiza automáticamente
                                    // cuando el SurfaceTexture hace updateTexImage()
                                }
                            }
                            result.success(textureId)
                        }
                    )
                }

                "destroy"        -> { DrawingEngineJNI.destroy(); result.success(null) }

                "undo"           -> { DrawingEngineJNI.undo();    result.success(null) }
                "redo"           -> { DrawingEngineJNI.redo();    result.success(null) }
                "canUndo"        -> result.success(DrawingEngineJNI.canUndo())
                "canRedo"        -> result.success(DrawingEngineJNI.canRedo())

                "addLayer"       -> {
                    val name = call.argument<String>("name") ?: ""
                    result.success(DrawingEngineJNI.addLayer(name))
                }
                "removeLayer"    -> {
                    DrawingEngineJNI.removeLayer(call.argument<Int>("id")!!)
                    result.success(null)
                }
                "setActiveLayer" -> {
                    DrawingEngineJNI.setActiveLayer(call.argument<Int>("id")!!)
                    result.success(null)
                }
                "setLayerOpacity"-> {
                    DrawingEngineJNI.setLayerOpacity(
                        call.argument<Int>("id")!!,
                        (call.argument<Double>("opacity")!!).toFloat()
                    )
                    result.success(null)
                }
                "setLayerVisible"-> {
                    DrawingEngineJNI.setLayerVisible(
                        call.argument<Int>("id")!!,
                        call.argument<Boolean>("visible")!!
                    )
                    result.success(null)
                }
                "clearLayer"     -> {
                    DrawingEngineJNI.clearLayer(call.argument<Int>("id")!!)
                    result.success(null)
                }

                "setBackground"  -> {
                    DrawingEngineJNI.setBackground(call.argument<Int>("colorARGB")!!)
                    result.success(null)
                }
                "setCanvasSize"  -> {
                    DrawingEngineJNI.setCanvasSize(
                        call.argument<Int>("w")!!,
                        call.argument<Int>("h")!!
                    )
                    result.success(null)
                }

                "exportPixels"   -> result.success(DrawingEngineJNI.exportPixels())

                "loadBrushTexture" -> {
                    val data = call.argument<ByteArray>("data")!!
                    val w    = call.argument<Int>("w")!!
                    val h    = call.argument<Int>("h")!!
                    result.success(DrawingEngineJNI.loadBrushTexture(data, w, h))
                }
                "unloadBrushTexture" -> {
                    DrawingEngineJNI.unloadBrushTexture(call.argument<Int>("id")!!)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // ── EventChannel: touch events → C++ engine ───────────────────
        // Flutter envía los eventos de touch aquí para minimizar latencia.
        // Se usa EventChannel en lugar de MethodChannel para evitar el
        // overhead de roundtrip por cada punto del trazo.
        EventChannel(messenger, CH_TOUCH).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    touchEventSink = sink
                }
                override fun onCancel(args: Any?) {
                    touchEventSink = null
                }
            }
        )
    }

    // ── Touch forwarding al motor C++ ──────────────────────────────────
    // Flutter no pasa events en raw por defecto, así que desde el lado Dart
    // los eventos se envían a través de MethodChannel/EventChannel.
    // Esta función es llamada desde el FlutterView como hook adicional.
    fun forwardTouchEvent(
        type: String,
        x: Float, y: Float, pressure: Float,
        layerId: Int,
        size: Float, opacity: Float, hardness: Float, spacing: Float,
        isEraser: Boolean, brushTexId: Int, colorARGB: Int
    ) {
        when (type) {
            "begin" -> DrawingEngineJNI.beginStroke(
                layerId, x, y, pressure,
                size, opacity, hardness, spacing,
                isEraser, brushTexId, colorARGB
            )
            "move"  -> DrawingEngineJNI.addPoint(x, y, pressure)
            "end"   -> DrawingEngineJNI.endStroke()
            "cancel"-> DrawingEngineJNI.cancelStroke()
        }
    }
}
