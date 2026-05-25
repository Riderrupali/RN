package com.codemagic.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.app.Activity
import android.content.Intent
import android.util.Base64
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.codemagic.app/screen"
    private val SCREEN_CAPTURE_REQUEST = 1001

    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaProjectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestScreenCapture" -> {
                        pendingResult = result
                        val captureIntent = mediaProjectionManager!!.createScreenCaptureIntent()
                        startActivityForResult(captureIntent, SCREEN_CAPTURE_REQUEST)
                    }
                    "getScreenText" -> {
                        // Returns latest captured screen text (set by OCR service)
                        result.success(latestScreenText)
                    }
                    "stopScreenCapture" -> {
                        mediaProjection?.stop()
                        mediaProjection = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_CAPTURE_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                mediaProjection = mediaProjectionManager!!.getMediaProjection(resultCode, data)
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }

    companion object {
        var latestScreenText: String = ""
    }
}
