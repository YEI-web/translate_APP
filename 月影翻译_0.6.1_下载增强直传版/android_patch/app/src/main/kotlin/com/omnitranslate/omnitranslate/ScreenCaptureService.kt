package com.omnitranslate.omnitranslate

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class ScreenCaptureService : Service() {
    companion object {
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        const val EXTRA_CAPTURE_DELAY_MS = "capture_delay_ms"
        private const val NOTIFICATION_ID = 7302
    }

    private val captured = AtomicBoolean(false)
    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        NotificationHelper.ensureChannels(this)
        startAsForeground()

        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
        val resultData = parcelableIntent(intent, EXTRA_RESULT_DATA)
        if (resultCode == 0 || resultData == null) {
            finishWithError("屏幕捕获授权数据无效")
            return START_NOT_STICKY
        }

        try {
            val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val mediaProjection = manager.getMediaProjection(resultCode, resultData)
                ?: throw IllegalStateException("无法创建 MediaProjection")
            projection = mediaProjection
            mediaProjection.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    cleanup()
                }
            }, Handler(mainLooper))
            val delayMs = (intent?.getLongExtra(EXTRA_CAPTURE_DELAY_MS, 0L) ?: 0L)
                .coerceIn(0L, 1500L)
            Handler(mainLooper).postDelayed({ captureOnce() }, delayMs)
        } catch (error: Throwable) {
            finishWithError(error.message ?: "无法启动屏幕捕获")
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        cleanup()
        super.onDestroy()
    }

    private fun startAsForeground() {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NotificationHelper.CAPTURE_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentTitle("月影翻译 屏幕翻译")
            .setContentText("正在抓取一次屏幕图像…")
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun captureOnce() {
        val mediaProjection = projection ?: run {
            finishWithError("MediaProjection 未初始化")
            return
        }
        val metrics = resources.displayMetrics
        val width = metrics.widthPixels.coerceAtLeast(1)
        val height = metrics.heightPixels.coerceAtLeast(1)
        val density = metrics.densityDpi

        workerThread = HandlerThread("月影翻译Capture").also { it.start() }
        workerHandler = Handler(workerThread!!.looper)
        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2).also { reader ->
            reader.setOnImageAvailableListener({ available ->
                if (!captured.compareAndSet(false, true)) {
                    available.acquireLatestImage()?.close()
                    return@setOnImageAvailableListener
                }
                val image = available.acquireLatestImage()
                if (image == null) {
                    captured.set(false)
                    return@setOnImageAvailableListener
                }
                try {
                    val bytesPath = saveImage(image, width, height)
                    finishWithPath(bytesPath)
                } catch (error: Throwable) {
                    finishWithError(error.message ?: "屏幕图像转换失败")
                } finally {
                    image.close()
                }
            }, workerHandler)
        }

        virtualDisplay = mediaProjection.createVirtualDisplay(
            "月影翻译ScreenCapture",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader!!.surface,
            null,
            workerHandler,
        )

        workerHandler?.postDelayed({
            if (captured.compareAndSet(false, true)) {
                finishWithError("等待屏幕图像超时")
            }
        }, 3500L)
    }

    private fun saveImage(image: Image, width: Int, height: Int): String {
        val plane = image.planes[0]
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * width
        val bitmapWidth = width + rowPadding / pixelStride
        val paddedBitmap = Bitmap.createBitmap(bitmapWidth, height, Bitmap.Config.ARGB_8888)
        paddedBitmap.copyPixelsFromBuffer(buffer)
        val cropped = Bitmap.createBitmap(paddedBitmap, 0, 0, width, height)
        if (cropped !== paddedBitmap) paddedBitmap.recycle()

        val file = File(cacheDir, "omnitranslate_android_capture_${System.nanoTime()}.png")
        FileOutputStream(file).use { output ->
            if (!cropped.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                throw IllegalStateException("PNG 编码失败")
            }
        }
        cropped.recycle()
        return file.absolutePath
    }

    private fun finishWithPath(path: String) {
        sendBroadcast(
            Intent(MainActivity.ACTION_CAPTURE_COMPLETE)
                .setPackage(packageName)
                .putExtra(MainActivity.EXTRA_CAPTURE_PATH, path),
        )
        cleanupAndStop()
    }

    private fun finishWithError(message: String) {
        sendBroadcast(
            Intent(MainActivity.ACTION_CAPTURE_COMPLETE)
                .setPackage(packageName)
                .putExtra(MainActivity.EXTRA_CAPTURE_ERROR, message),
        )
        cleanupAndStop()
    }

    private fun cleanupAndStop() {
        cleanup()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun cleanup() {
        try {
            virtualDisplay?.release()
        } catch (_: Throwable) {
        }
        virtualDisplay = null
        try {
            imageReader?.close()
        } catch (_: Throwable) {
        }
        imageReader = null
        try {
            projection?.stop()
        } catch (_: Throwable) {
        }
        projection = null
        workerThread?.quitSafely()
        workerThread = null
        workerHandler = null
    }

    @Suppress("DEPRECATION")
    private fun parcelableIntent(intent: Intent?, key: String): Intent? {
        if (intent == null) return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(key, Intent::class.java)
        } else {
            intent.getParcelableExtra(key)
        }
    }
}
