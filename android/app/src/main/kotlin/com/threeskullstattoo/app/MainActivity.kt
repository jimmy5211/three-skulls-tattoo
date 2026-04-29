package com.threeskullstattoo.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CH = "tsk/drawing_engine"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, CH).setMethodCallHandler { call, result ->
            when (call.method) {

                // ── Init ──────────────────────────────────────────────
                "init" -> {
                    val canvasW = call.argument<Int>("canvasW") ?: 1080
                    val canvasH = call.argument<Int>("canvasH") ?: 1920
                    val maxUndo = call.argument<Int>("maxUndo") ?: 20
                    DrawingEngineJNI.setup(
                        canvasW = canvasW,
                        canvasH = canvasH,
                        maxUndoSteps = maxUndo,
                        onReady = { ok -> result.success(ok) }
                    )
                }

                "destroy" -> { DrawingEngineJNI.destroy(); result.success(null) }

                // ── Stroke lifecycle ──────────────────────────────────
                "beginStroke" -> {
                    DrawingEngineJNI.beginStroke(
                        layerId    = call.argument<Int>("layerId")!!,
                        x          = (call.argument<Double>("x")!!).toFloat(),
                        y          = (call.argument<Double>("y")!!).toFloat(),
                        pressure   = (call.argument<Double>("pressure") ?: 1.0).toFloat(),
                        size       = (call.argument<Double>("size")!!).toFloat(),
                        opacity    = (call.argument<Double>("opacity")!!).toFloat(),
                        hardness   = (call.argument<Double>("hardness")!!).toFloat(),
                        spacing    = (call.argument<Double>("spacing") ?: 0.1).toFloat(),
                        isEraser   = call.argument<Boolean>("isEraser") ?: false,
                        brushTexId = call.argument<Int>("brushTexId") ?: -1,
                        colorARGB  = (call.argument<Any>("colorARGB") as? Number)?.toInt() ?: 0xFF000000.toInt()
                    )
                    result.success(null)
                }

                "addPoint" -> {
                    DrawingEngineJNI.addPoint(
                        x        = (call.argument<Double>("x")!!).toFloat(),
                        y        = (call.argument<Double>("y")!!).toFloat(),
                        pressure = (call.argument<Double>("pressure") ?: 1.0).toFloat()
                    )
                    result.success(null)
                }

                // endStroke devuelve ByteArray RGBA del canvas completo
                "endStrokeAndExport" -> DrawingEngineJNI.endStrokeAndExport { bytes ->
                    result.success(bytes)
                }

                "cancelStroke" -> { DrawingEngineJNI.cancelStroke(); result.success(null) }

                // exportCanvas sin modificar historial
                "exportCanvas" -> DrawingEngineJNI.exportCanvas { bytes ->
                    result.success(bytes)
                }

                // ── Historial (devuelven ByteArray del nuevo estado) ──
                "undo" -> DrawingEngineJNI.undo { bytes -> result.success(bytes) }
                "redo" -> DrawingEngineJNI.redo { bytes -> result.success(bytes) }
                "canUndo" -> result.success(DrawingEngineJNI.canUndo())
                "canRedo" -> result.success(DrawingEngineJNI.canRedo())

                // ── Capas ─────────────────────────────────────────────
                "addLayer" -> {
                    val name = call.argument<String>("name") ?: ""
                    result.success(DrawingEngineJNI.addLayer(name))
                }
                "removeLayer"    -> { DrawingEngineJNI.removeLayer(call.argument<Int>("id")!!);     result.success(null) }
                "setActiveLayer" -> { DrawingEngineJNI.setActiveLayer(call.argument<Int>("id")!!);  result.success(null) }
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

                // clearLayer devuelve ByteArray
                "clearLayer" -> DrawingEngineJNI.clearLayer(call.argument<Int>("id")!!) { bytes ->
                    result.success(bytes)
                }

                // ── Canvas ────────────────────────────────────────────
                "setBackground" -> DrawingEngineJNI.setBackground(
                    (call.argument<Any>("colorARGB") as? Number)?.toInt() ?: 0xFFFFFFFF.toInt()
                ) { bytes -> result.success(bytes) }

                "setCanvasSize" -> {
                    DrawingEngineJNI.setCanvasSize(call.argument<Int>("w")!!, call.argument<Int>("h")!!)
                    result.success(null)
                }

                // ── Export ────────────────────────────────────────────
                "exportPixels" -> DrawingEngineJNI.exportCanvas { bytes -> result.success(bytes) }

                "eraseRegion" -> {
                    val lid = call.argument<Int>("layerId")!!
                    val x = (call.argument<Any>("x") as Number).toFloat()
                    val y = (call.argument<Any>("y") as Number).toFloat()
                    val w = (call.argument<Any>("w") as Number).toFloat()
                    val h = (call.argument<Any>("h") as Number).toFloat()
                    DrawingEngineJNI.eraseRegion(lid, x, y, w, h) { bytes -> result.success(bytes) }
                }

                // ── Brush textures ────────────────────────────────────
                "loadBrushTexture" -> {
                    val data = call.argument<ByteArray>("data")!!
                    result.success(DrawingEngineJNI.loadBrushTexture(data,
                        call.argument<Int>("w")!!, call.argument<Int>("h")!!))
                }
                "unloadBrushTexture" -> {
                    DrawingEngineJNI.unloadBrushTexture(call.argument<Int>("id")!!)
                    result.success(null)
                }

                // ── Diagnóstico ───────────────────────────────────────
                "getLastError" -> result.success(DrawingEngineJNI.getLastError())

                "setSymmetry" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val axis    = call.argument<Int>("axis") ?: 0
                    DrawingEngineJNI.setSymmetry(enabled, axis)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
