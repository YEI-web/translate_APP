package com.omnitranslate.omnitranslate

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

class OverlayService : Service() {
    companion object {
        @Volatile
        var isRunning: Boolean = false
            private set

        private const val NOTIFICATION_ID = 7301
    }

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private var params: WindowManager.LayoutParams? = null
    private var expanded = false

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.ensureChannels(this)
        startAsForeground()
        if (!canDrawOverlays()) {
            stopSelf()
            return
        }
        isRunning = true
        showCollapsedBubble()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (overlayView == null && canDrawOverlays()) showCollapsedBubble()
        return START_STICKY
    }

    override fun onDestroy() {
        removeOverlay()
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startAsForeground() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NotificationHelper.OVERLAY_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentTitle("月影翻译 悬浮翻译")
            .setContentText("点悬浮球可打开截图、语音等快捷操作")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun showCollapsedBubble() {
        removeOverlay()
        expanded = false
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val size = dp(56)
        val bubble = TextView(this).apply {
            text = "译"
            textSize = 21f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            elevation = dp(8).toFloat()
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(77, 114, 255))
            }
            setOnTouchListener(DragTouchListener())
        }

        val layoutParams = baseLayoutParams(size, size).apply {
            x = resources.displayMetrics.widthPixels - dp(76)
            y = dp(180)
        }
        params = layoutParams
        overlayView = bubble
        windowManager.addView(bubble, layoutParams)
    }

    private fun showExpandedPanel() {
        val oldParams = params
        removeOverlay()
        expanded = true
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), dp(10), dp(10), dp(10))
            elevation = dp(10).toFloat()
            background = GradientDrawable().apply {
                cornerRadius = dp(18).toFloat()
                setColor(Color.rgb(34, 36, 43))
            }
            addView(TextView(context).apply {
                text = "月影翻译"
                textSize = 14f
                setTextColor(Color.WHITE)
                setPadding(dp(8), dp(4), dp(8), dp(8))
            })
            addView(actionButton("打开翻译器") { launchAction("show_main_window") })
            addView(actionButton("截图翻译") { launchAction("screen_translate") })
            addView(actionButton("语音翻译") { launchAction("voice_translate") })
            addView(actionButton("收起") { showCollapsedBubble() })
            addView(actionButton("关闭悬浮球") { stopSelf() })
        }

        val layoutParams = baseLayoutParams(WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT).apply {
            x = oldParams?.x ?: resources.displayMetrics.widthPixels - dp(220)
            y = oldParams?.y ?: dp(180)
        }
        params = layoutParams
        overlayView = panel
        windowManager.addView(panel, layoutParams)
    }

    private fun actionButton(label: String, action: () -> Unit): Button {
        return Button(this).apply {
            text = label
            isAllCaps = false
            setOnClickListener { action() }
        }
    }

    private fun baseLayoutParams(width: Int, height: Int): WindowManager.LayoutParams {
        val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        return WindowManager.LayoutParams(
            width,
            height,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
    }

    private fun removeOverlay() {
        overlayView?.let {
            try {
                if (::windowManager.isInitialized) windowManager.removeView(it)
            } catch (_: Throwable) {
            }
        }
        overlayView = null
    }

    private inner class DragTouchListener : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            val layoutParams = params ?: return false
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = layoutParams.x
                    startY = layoutParams.y
                    touchX = event.rawX
                    touchY = event.rawY
                    return true
                }

                MotionEvent.ACTION_MOVE -> {
                    layoutParams.x = startX + (event.rawX - touchX).toInt()
                    layoutParams.y = startY + (event.rawY - touchY).toInt()
                    windowManager.updateViewLayout(view, layoutParams)
                    return true
                }

                MotionEvent.ACTION_UP -> {
                    val dx = abs(event.rawX - touchX)
                    val dy = abs(event.rawY - touchY)
                    if (dx < dp(8) && dy < dp(8)) showExpandedPanel()
                    return true
                }
            }
            return false
        }
    }

    private fun launchAction(action: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra(MainActivity.EXTRA_NATIVE_ACTION, action)
        }
        startActivity(intent)
        showCollapsedBubble()
    }

    private fun canDrawOverlays(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
