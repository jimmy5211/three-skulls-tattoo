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
                        colorARGB  = (call.argument<Any>("colorARGB") as? Number)?.toInt() ?: 0xFF000000.toInt(),
                        spacingBase     = (call.argument<Double>("spacingBase")     ?: 0.04).toFloat(),
                        spacingVelocity = (call.argument<Double>("spacingVelocity") ?: 0.001).toFloat(),
                        spacingMinPx    = (call.argument<Double>("spacingMinPx")    ?: 1.0).toFloat(),
                        jitterPos       = (call.argument<Double>("jitterPos")       ?: 0.03).toFloat(),
                        jitterSize      = (call.argument<Double>("jitterSize")      ?: 0.02).toFloat(),
                        jitterRot       = (call.argument<Double>("jitterRot")       ?: 6.28).toFloat(),
                        followStroke    = call.argument<Boolean>("followStroke")    ?: true,
                        flow            = (call.argument<Double>("flow")            ?: 0.55).toFloat(),
                        grainDepth      = (call.argument<Double>("grainDepth")      ?: 0.0).toFloat()
                    )
                    result.success(null)
                }

                "setBrushDynParams" -> {
                    DrawingEngineJNI.setBrushDynParams(
                        spacingBase     = (call.argument<Double>("spacingBase")     ?: 0.04).toFloat(),
                        spacingVelocity = (call.argument<Double>("spacingVelocity") ?: 0.001).toFloat(),
                        spacingMinPx    = (call.argument<Double>("spacingMinPx")    ?: 1.0).toFloat(),
                        jitterPos       = (call.argument<Double>("jitterPos")       ?: 0.03).toFloat(),
                        jitterSize      = (call.argument<Double>("jitterSize")      ?: 0.02).toFloat(),
                        jitterRot       = (call.argument<Double>("jitterRot")       ?: 6.28).toFloat(),
                        followStroke    = call.argument<Boolean>("followStroke")    ?: true,
                        flow            = (call.argument<Double>("flow")            ?: 0.55).toFloat(),
                        grainDepth      = (call.argument<Double>("grainDepth")      ?: 0.0).toFloat()
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

                "endStrokeAndExport" -> DrawingEngineJNI.endStrokeAndExport { bytes ->
                    result.success(bytes)
                }

                "cancelStroke" -> { DrawingEngineJNI.cancelStroke(); result.success(null) }

                "stampAt" -> {
                    val x = (call.argument<Any>("x") as Number).toFloat()
                    val y = (call.argument<Any>("y") as Number).toFloat()
                    DrawingEngineJNI.stampAt(x, y)
                    result.success(null)
                }

                "exportCanvas" -> DrawingEngineJNI.exportCanvas { bytes ->
                    result.success(bytes)
                }

                // ── Historial ─────────────────────────────────────────
                "undo" -> DrawingEngineJNI.undo { bytes -> result.success(bytes) }
                "redo" -> DrawingEngineJNI.redo { bytes -> result.success(bytes) }
                "canUndo" -> result.success(DrawingEngineJNI.canUndo())
                "canRedo" -> result.success(DrawingEngineJNI.canRedo())

                // ── Capas ─────────────────────────────────────────────
                "addLayer" -> {
                    val name = call.argument<String>("name") ?: ""
                    result.success(DrawingEngineJNI.addLayer(name))
                }
                "removeLayer"    -> { DrawingEngineJNI.removeLayer(call.argument<Int>("id")!!);    result.success(null) }
                "setActiveLayer" -> { DrawingEngineJNI.setActiveLayer(call.argument<Int>("id")!!); result.success(null) }
                "setLayerOpacity" -> {
                    DrawingEngineJNI.setLayerOpacity(
                        call.argument<Int>("id")!!,
                        (call.argument<Double>("opacity")!!).toFloat()
                    )
                    result.success(null)
                }
                "setLayerVisible" -> {
                    DrawingEngineJNI.setLayerVisible(
                        call.argument<Int>("id")!!,
                        call.argument<Boolean>("visible")!!
                    )
                    result.success(null)
                }
                "clearLayer" -> DrawingEngineJNI.clearLayer(call.argument<Int>("id")!!) { bytes ->
                    result.success(bytes)
                }

                // ── Canvas ────────────────────────────────────────────
                "setBackground" -> DrawingEngineJNI.setBackground(
                    (call.argument<Any>("colorARGB") as? Number)?.toInt() ?: 0xFFFFFFFF.toInt()
                ) { bytes -> result.success(bytes) }

                "setCanvasSize" -> {
                    DrawingEngineJNI.setCanvasSize(
                        call.argument<Int>("w")!!,
                        call.argument<Int>("h")!!
                    )
                    result.success(null)
                }

                "exportPixels" -> DrawingEngineJNI.exportCanvas { bytes -> result.success(bytes) }

                "eraseRegion" -> {
                    val lid = call.argument<Int>("layerId")!!
                    val x = (call.argument<Any>("x") as Number).toFloat()
                    val y = (call.argument<Any>("y") as Number).toFloat()
                    val w = (call.argument<Any>("w") as Number).toFloat()
                    val h = (call.argument<Any>("h") as Number).toFloat()
                    DrawingEngineJNI.eraseRegion(lid, x, y, w, h)
                    result.success(null)
                }

                // ── Restore layer (para cargar proyectos .tskproject) ─
                "restoreLayer" -> {
                    val layerId = call.argument<Int>("layerId")!!
                    val pixels  = call.argument<ByteArray>("pixels")!!
                    val w       = call.argument<Int>("width")!!
                    val h       = call.argument<Int>("height")!!
                    DrawingEngineJNI.restoreLayer(layerId, pixels, w, h) { bytes ->
                        result.success(bytes)
                    }
                }

                // ── Brush textures ────────────────────────────────────
                "loadBrushTexture" -> {
                    val data = call.argument<ByteArray>("data")!!
                    DrawingEngineJNI.loadBrushTexture(
                        data,
                        call.argument<Int>("w")!!,
                        call.argument<Int>("h")!!
                    ) { id -> result.success(id) }
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

        // ── Canal de optimización de batería ──────────────────────────────────
        MethodChannel(messenger, "com.threeskullstattoo.app/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimization" -> {
                        val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimization" -> {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = android.content.Intent(
                                    android.provider.Settings
                                        .ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    android.net.Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
