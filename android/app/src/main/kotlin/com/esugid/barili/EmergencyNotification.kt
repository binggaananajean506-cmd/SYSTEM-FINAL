package com.esugid.barili

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

object EmergencyNotification {
    private const val TAG = "ESugidEmergency"
    // Version 2 intentionally replaces the previously installed alarm-style
    // channel, whose sound and DND/full-screen behavior were incorrect.
    const val CHANNEL_ID = "esugid_emergency_alerts_v2"
    const val LOOP_CHANNEL_ID = "esugid_emergency_alerts_loop_v1"

    fun show(
        context: Context,
        title: String,
        body: String,
        referenceId: String,
        allowFullScreen: Boolean = true,
    ) {
        if (EmergencyActionReceiver.isDoNotRemind(context, referenceId)) {
            Log.i(TAG, "Notification show suppressed by do-not-remind id=$referenceId")
            return
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(
            referenceId.hashCode() and Int.MAX_VALUE,
            build(context, title, body, referenceId, silent = false, allowFullScreen = allowFullScreen),
        )
    }

    fun build(
        context: Context,
        title: String,
        body: String,
        referenceId: String,
        silent: Boolean,
        allowFullScreen: Boolean = true,
    ): Notification {
        createChannel(context)
        val notificationId = referenceId.hashCode() and Int.MAX_VALUE
        val alarmScreenIntent = Intent(context, EmergencyAlertActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("notificationId", notificationId)
            putExtra("referenceId", referenceId)
            putExtra("title", title.take(120))
            putExtra("body", body.take(500))
        }
        val fullScreenIntent = PendingIntent.getActivity(
            context,
            notificationId + 1,
            alarmScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val dismissIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 2,
            Intent(context, EmergencyActionReceiver::class.java).apply {
                action = EmergencyActionReceiver.ACTION_DISMISS
                putExtra("notificationId", notificationId)
                putExtra("referenceId", referenceId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val viewIntent = PendingIntent.getActivity(
            context,
            notificationId + 3,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("notificationType", "emergency_alert")
                putExtra("referenceId", referenceId)
                putExtra("emergencyId", referenceId)
                putExtra("alertId", referenceId)
                putExtra("route", "/emergency")
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val dontRemindIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 4,
            Intent(context, EmergencyActionReceiver::class.java).apply {
                action = EmergencyActionReceiver.ACTION_DONT_REMIND
                putExtra("notificationId", notificationId)
                putExtra("referenceId", referenceId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmSound = Uri.parse(
            "android.resource://${context.packageName}/raw/esugid_emergency_alert",
        )
        val builder = NotificationCompat.Builder(context, if (silent) LOOP_CHANNEL_ID else CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title.take(120))
            .setContentText(body.take(240))
            .setStyle(NotificationCompat.BigTextStyle().bigText(body.take(500)))
            .setContentIntent(viewIntent)
            .setDeleteIntent(dismissIntent)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setColor(0xFFB42318.toInt())
            .setOngoing(silent)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(0, "DISMISS", dismissIntent)
            .addAction(0, "VIEW ALERT", viewIntent)
            .addAction(0, "DON'T REMIND AGAIN", dontRemindIntent)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O && !silent) {
            builder.setSound(alarmSound)
            builder.setVibrate(longArrayOf(0, 450, 180, 450, 180, 850))
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val fullScreenAllowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            manager.canUseFullScreenIntent()
        } else {
            true
        }
        // Keep the full-screen intent attached even when access is currently
        // denied: Android then presents its expanded heads-up fallback.
        if (allowFullScreen) builder.setFullScreenIntent(fullScreenIntent, true)
        Log.i(
            TAG,
            "Notification built channel=${if (silent) LOOP_CHANNEL_ID else CHANNEL_ID} " +
                "fullScreen=${allowFullScreen && fullScreenAllowed} emergencyId=$referenceId",
        )
        return builder.build()
    }

    fun cancel(context: Context, notificationId: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(notificationId)
    }

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val sound = Uri.parse(
            "android.resource://${context.packageName}/raw/esugid_emergency_alert",
        )
        val audio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(
            CHANNEL_ID,
            "E-SUGID Emergency Alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Urgent emergency alerts issued through E-SUGID."
            setSound(sound, audio)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 450, 180, 450, 180, 850)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val loopChannel = NotificationChannel(
            LOOP_CHANNEL_ID,
            "E-SUGID Ringing Emergency Alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Emergency alerts that keep ringing until viewed or dismissed."
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannels(listOf(channel, loopChannel))
    }
}
