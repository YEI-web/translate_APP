package com.omnitranslate.omnitranslate

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

object NotificationHelper {
    const val OVERLAY_CHANNEL = "omnitranslate_overlay"
    const val CAPTURE_CHANNEL = "omnitranslate_capture"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                OVERLAY_CHANNEL,
                "月影翻译 悬浮翻译",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "保持悬浮翻译球运行"
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                CAPTURE_CHANNEL,
                "月影翻译 屏幕翻译",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "在用户授权后抓取一次屏幕图像用于 OCR 翻译"
            },
        )
    }
}
