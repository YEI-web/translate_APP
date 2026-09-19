package com.omnitranslate.omnitranslate

import android.app.Activity.RESULT_OK
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.BitmapFactory
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.TextRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.omnitranslate/native"
        private const val REQUEST_OVERLAY = 4101
        private const val REQUEST_CAPTURE = 4102
        private const val REQUEST_SPEECH = 4103
        private const val REQUEST_MODEL_IMPORT = 4104

        const val ACTION_CAPTURE_COMPLETE = "com.omnitranslate.omnitranslate.CAPTURE_COMPLETE"
        const val EXTRA_CAPTURE_PATH = "capture_path"
        const val EXTRA_CAPTURE_ERROR = "capture_error"
        const val EXTRA_NATIVE_ACTION = "omnitranslate_native_action"
    }

    private var channel: MethodChannel? = null
    private var pendingInitialText: Map<String, String>? = null
    private var pendingInitialAction: String? = null
    private var overlayPermissionResult: MethodChannel.Result? = null
    private var screenCaptureResult: MethodChannel.Result? = null
    private var speechRecognitionResult: MethodChannel.Result? = null
    private var modelImportResult: MethodChannel.Result? = null
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false

    private val captureReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != ACTION_CAPTURE_COMPLETE) return
            val pending = screenCaptureResult ?: return
            screenCaptureResult = null
            val error = intent.getStringExtra(EXTRA_CAPTURE_ERROR)
            if (!error.isNullOrBlank()) {
                pending.error("capture_failed", error, null)
                bringTaskToFront()
                return
            }
            val path = intent.getStringExtra(EXTRA_CAPTURE_PATH)
            if (path.isNullOrBlank()) {
                pending.success(null)
                bringTaskToFront()
                return
            }
            try {
                val file = File(path)
                val bytes = file.readBytes()
                file.delete()
                pending.success(bytes)
                bringTaskToFront()
            } catch (errorReading: Throwable) {
                pending.error("capture_read_failed", errorReading.message, null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NotificationHelper.ensureChannels(this)
        registerCaptureReceiver()
        initializeTextToSpeech()
        handleIncomingIntent(intent, deliverImmediately = false)
        handleNativeAction(intent, deliverImmediately = false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { methodChannel ->
            methodChannel.setMethodCallHandler(::handleMethodCall)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent, deliverImmediately = true)
        handleNativeAction(intent, deliverImmediately = true)
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(captureReceiver)
        } catch (_: Throwable) {
        }
        overlayPermissionResult?.success(false)
        overlayPermissionResult = null
        screenCaptureResult?.success(null)
        screenCaptureResult = null
        speechRecognitionResult?.success(null)
        speechRecognitionResult = null
        modelImportResult?.success(null)
        modelImportResult = null
        try {
            textToSpeech?.stop()
            textToSpeech?.shutdown()
        } catch (_: Throwable) {
        }
        textToSpeech = null
        channel = null
        super.onDestroy()
    }

    private fun initializeTextToSpeech() {
        textToSpeech = TextToSpeech(applicationContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
        }
    }

    private fun registerCaptureReceiver() {
        val filter = IntentFilter(ACTION_CAPTURE_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(captureReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(captureReceiver, filter)
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInitialText" -> {
                result.success(pendingInitialText)
                pendingInitialText = null
            }

            "getInitialAction" -> {
                result.success(pendingInitialAction)
                pendingInitialAction = null
            }

            "hasOverlayPermission" -> result.success(canDrawOverlays())
            "requestOverlayPermission" -> requestOverlayPermission(result)
            "isOverlayRunning" -> result.success(OverlayService.isRunning)
            "startOverlay" -> startOverlay(result)
            "stopOverlay" -> {
                stopService(Intent(this, OverlayService::class.java))
                result.success(null)
            }

            "captureScreen" -> requestScreenCapture(result)
            "recognizeTextLocal" -> recognizeTextLocal(call.arguments, result)
            "recognizeSpeech" -> requestSpeechRecognition(call, result)
            "importLocalAiModel" -> requestLocalAiModelImport(result)
            "speak" -> speak(call, result)
            "stopSpeaking" -> {
                textToSpeech?.stop()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun canDrawOverlays(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
    }

    private fun requestOverlayPermission(result: MethodChannel.Result) {
        if (canDrawOverlays()) {
            result.success(true)
            return
        }
        if (overlayPermissionResult != null) {
            result.error("overlay_permission_pending", "悬浮窗权限请求正在进行", null)
            return
        }
        overlayPermissionResult = result
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_OVERLAY)
    }

    private fun startOverlay(result: MethodChannel.Result) {
        if (!canDrawOverlays()) {
            result.success(false)
            return
        }
        val intent = Intent(this, OverlayService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        result.success(true)
    }

    private fun requestScreenCapture(result: MethodChannel.Result) {
        if (screenCaptureResult != null) {
            result.error("capture_pending", "已有一个屏幕捕获请求正在进行", null)
            return
        }
        screenCaptureResult = result
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        @Suppress("DEPRECATION")
        startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_CAPTURE)
    }

    private fun recognizeTextLocal(arguments: Any?, result: MethodChannel.Result) {
        val bytes = arguments as? ByteArray
        if (bytes == null || bytes.isEmpty()) {
            result.error("ocr_invalid_image", "OCR 图像为空", null)
            return
        }
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        if (bitmap == null) {
            result.error("ocr_decode_failed", "无法解码截图", null)
            return
        }
        val image = InputImage.fromBitmap(bitmap, 0)
        val recognizers: List<TextRecognizer> = listOf(
            TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build()),
            TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build()),
            TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build()),
            TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS),
        )
        val remaining = AtomicInteger(recognizers.size)
        val candidates = mutableListOf<String>()
        var firstError: Throwable? = null

        recognizers.forEach { recognizer ->
            recognizer.process(image)
                .addOnSuccessListener { recognized ->
                    val text = recognized.text.trim()
                    if (text.isNotEmpty()) {
                        synchronized(candidates) { candidates.add(text) }
                    }
                }
                .addOnFailureListener { error ->
                    synchronized(candidates) {
                        if (firstError == null) firstError = error
                    }
                }
                .addOnCompleteListener {
                    recognizer.close()
                    if (remaining.decrementAndGet() == 0) {
                        bitmap.recycle()
                        val best = synchronized(candidates) {
                            candidates.maxByOrNull { value -> value.count { !it.isWhitespace() } }
                        }
                        if (!best.isNullOrBlank()) {
                            result.success(best)
                        } else if (firstError != null) {
                            result.error("ocr_failed", firstError?.message ?: "本地 OCR 失败", null)
                        } else {
                            result.success("")
                        }
                    }
                }
        }
    }

    private fun requestLocalAiModelImport(result: MethodChannel.Result) {
        if (modelImportResult != null) {
            result.error("model_import_pending", "已有一个模型导入请求正在进行", null)
            return
        }
        modelImportResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/octet-stream", "application/x-gguf", "*/*"))
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_MODEL_IMPORT)
    }

    private fun requestSpeechRecognition(call: MethodCall, result: MethodChannel.Result) {
        if (speechRecognitionResult != null) {
            result.error("speech_pending", "已有一个语音识别请求正在进行", null)
            return
        }
        val languageTag = (call.argument<String>("languageTag") ?: "").trim()
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PROMPT, "说出要翻译的内容")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            if (languageTag.isNotEmpty()) {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageTag)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, languageTag)
            }
        }
        if (intent.resolveActivity(packageManager) == null) {
            result.error("speech_unavailable", "当前设备没有可用的系统语音识别服务", null)
            return
        }
        speechRecognitionResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_SPEECH)
    }

    private fun speak(call: MethodCall, result: MethodChannel.Result) {
        val text = (call.argument<String>("text") ?: "").trim()
        if (text.isEmpty()) {
            result.success(false)
            return
        }
        val engine = textToSpeech
        if (engine == null || !ttsReady) {
            result.error("tts_unavailable", "系统朗读引擎尚未就绪", null)
            return
        }
        val languageTag = (call.argument<String>("languageTag") ?: "").trim()
        val locale = if (languageTag.isEmpty()) Locale.getDefault() else Locale.forLanguageTag(languageTag)
        val languageResult = engine.setLanguage(locale)
        if (languageResult == TextToSpeech.LANG_MISSING_DATA || languageResult == TextToSpeech.LANG_NOT_SUPPORTED) {
            result.error("tts_language_unsupported", "系统朗读引擎不支持该语言：${locale.toLanguageTag()}", null)
            return
        }
        val code = engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "omnitranslate-${System.nanoTime()}")
        result.success(code == TextToSpeech.SUCCESS)
    }

    @Deprecated("Deprecated in Android Activity API but retained for broad Flutter host compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_OVERLAY -> {
                overlayPermissionResult?.success(canDrawOverlays())
                overlayPermissionResult = null
            }

            REQUEST_CAPTURE -> {
                if (resultCode != RESULT_OK || data == null) {
                    screenCaptureResult?.success(null)
                    screenCaptureResult = null
                    return
                }
                val serviceIntent = Intent(this, ScreenCaptureService::class.java).apply {
                    putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, resultCode)
                    putExtra(ScreenCaptureService.EXTRA_RESULT_DATA, data)
                    putExtra(ScreenCaptureService.EXTRA_CAPTURE_DELAY_MS, 550L)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
                window.decorView.postDelayed({ moveTaskToBack(true) }, 80L)
            }

            REQUEST_MODEL_IMPORT -> {
                val pending = modelImportResult
                modelImportResult = null
                if (pending == null) return
                if (resultCode != RESULT_OK || data?.data == null) {
                    pending.success(null)
                    return
                }
                val uri = data.data!!
                Thread {
                    try {
                        val modelsDir = File(filesDir, "models")
                        if (!modelsDir.exists()) modelsDir.mkdirs()
                        val finalFile = File(modelsDir, "Qwen3-0.6B-Q4_0.gguf")
                        val partialFile = File(modelsDir, "Qwen3-0.6B-Q4_0.gguf.importing")
                        contentResolver.openInputStream(uri).use { input ->
                            if (input == null) throw IllegalStateException("无法读取选择的模型文件")
                            partialFile.outputStream().use { output -> input.copyTo(output, 1024 * 1024) }
                        }
                        if (partialFile.length() < 400_000_000L) {
                            partialFile.delete()
                            throw IllegalStateException("选择的文件小于 400 MB，可能不是完整的 Qwen3-0.6B GGUF 模型")
                        }
                        if (finalFile.exists()) finalFile.delete()
                        if (!partialFile.renameTo(finalFile)) {
                            partialFile.copyTo(finalFile, overwrite = true)
                            partialFile.delete()
                        }
                        runOnUiThread {
                            pending.success(mapOf("path" to finalFile.absolutePath, "size" to finalFile.length()))
                        }
                    } catch (error: Throwable) {
                        runOnUiThread {
                            pending.error("model_import_failed", error.message ?: "模型导入失败", null)
                        }
                    }
                }.start()
            }

            REQUEST_SPEECH -> {
                val pending = speechRecognitionResult
                speechRecognitionResult = null
                if (pending == null) return
                if (resultCode != RESULT_OK || data == null) {
                    pending.success(null)
                    return
                }
                val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                pending.success(matches?.firstOrNull()?.trim())
            }
        }
    }

    private fun bringTaskToFront() {
        val reopen = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(reopen)
    }

    private fun handleIncomingIntent(intent: Intent?, deliverImmediately: Boolean) {
        if (intent == null) return
        val payload = when (intent.action) {
            Intent.ACTION_PROCESS_TEXT -> {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()?.trim().orEmpty()
                if (text.isEmpty()) null else mapOf("text" to text, "source" to "process_text")
            }

            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("text/") != true) null
                else {
                    val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim().orEmpty()
                    if (text.isEmpty()) null else mapOf("text" to text, "source" to "share")
                }
            }

            else -> null
        } ?: return

        if (deliverImmediately && channel != null) {
            channel?.invokeMethod("incomingText", payload)
        } else {
            pendingInitialText = payload
        }
    }

    private fun handleNativeAction(intent: Intent?, deliverImmediately: Boolean) {
        val action = intent?.getStringExtra(EXTRA_NATIVE_ACTION)?.trim().orEmpty()
        if (action.isEmpty()) return
        intent?.removeExtra(EXTRA_NATIVE_ACTION)
        if (deliverImmediately && channel != null) {
            channel?.invokeMethod("mobileAction", action)
        } else {
            pendingInitialAction = action
        }
    }
}
