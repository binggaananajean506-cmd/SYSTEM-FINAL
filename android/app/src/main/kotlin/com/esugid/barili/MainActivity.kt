package com.esugid.barili

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationChannel: MethodChannel? = null
    private var pendingNotificationPayload: Map<String, String>? = null

    companion object {
        private const val METHOD_CHANNEL = "com.esugid.barili/notifications"
        private const val REGULAR_CHANNEL = "esugid_announcement_regular_v2"
        private const val IMPORTANT_CHANNEL = "esugid_announcement_important_v2"
        private const val URGENT_CHANNEL = "esugid_announcement_urgent_v3"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        stopOpenedEmergency(intent)
    }

    private fun stopOpenedEmergency(source: Intent?) {
        if (source?.getStringExtra("notificationType") != "emergency_alert") return
        val emergencyId = source.getStringExtra("referenceId") ?: return
        EmergencyAlarmService.stop(this, emergencyId)
        EmergencyNotification.cancel(this, emergencyId.hashCode() and Int.MAX_VALUE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannels()
        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).also { channel -> channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showAnnouncementNotification" -> {
                    showAnnouncementNotification(
                        title = call.argument<String>("title") ?: "E-Sugid announcement",
                        body = call.argument<String>("body")
                            ?: "New community information is available.",
                        priority = call.argument<String>("priority") ?: "important",
                        referenceId = call.argument<String>("referenceId") ?: "announcement",
                    )
                    result.success(null)
                }
                "showEmergencyNotification" -> {
                    showEmergencyNotification(
                        title = call.argument<String>("title") ?: "E-Sugid emergency alert",
                        body = call.argument<String>("body")
                            ?: "Emergency information is available.",
                        referenceId = call.argument<String>("referenceId") ?: "emergency",
                    )
                    result.success(null)
                }
                "stopEmergencyAlarm" -> {
                    call.argument<String>("referenceId")?.let { EmergencyAlarmService.stop(this, it) }
                    result.success(null)
                }
                "markEmergencyDoNotRemind" -> {
                    val referenceId = call.argument<String>("referenceId")
                    if (!referenceId.isNullOrBlank()) {
                        EmergencyActionReceiver.recordDoNotRemind(this, referenceId)
                        EmergencyAlarmService.stop(this, referenceId)
                        EmergencyNotification.cancel(this, referenceId.hashCode() and Int.MAX_VALUE)
                    }
                    result.success(null)
                }
                "getInitialNotificationPayload" -> {
                    val payload = pendingNotificationPayload ?: payloadFromIntent(intent)
                    pendingNotificationPayload = null
                    clearNotificationIntent(intent)
                    result.success(payload)
                }
                "consumeEmergencyActions" -> {
                    val preferences = getSharedPreferences("esugid_emergency_actions", MODE_PRIVATE)
                    val silencedId = preferences.getString("lastSilencedEmergencyId", null)
                    val doNotRemindId = preferences.getString("lastDoNotRemindEmergencyId", null)
                    preferences.edit()
                        .remove("lastSilencedEmergencyId")
                        .remove("lastSilencedAt")
                        .remove("lastDoNotRemindEmergencyId")
                        .remove("lastDoNotRemindAt")
                        .apply()
                    val actions = mutableMapOf<String, Any?>()
                    if (silencedId != null) actions["silenced"] = silencedId
                    if (doNotRemindId != null) actions["doNotRemind"] = doNotRemindId
                    result.success(actions)
                }
                "canUseFullScreenIntent" -> {
                    val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        manager.canUseFullScreenIntent()
                    } else {
                        true
                    }
                    result.success(allowed)
                }
                "canDrawEmergencyOverlay" -> result.success(Settings.canDrawOverlays(this))
                "openEmergencyOverlaySettings" -> {
                    try {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    } catch (_: Exception) {
                        openApplicationSettings()
                    }
                    result.success(null)
                }
                "getNotificationDiagnostics" -> {
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val emergencyChannel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        manager.getNotificationChannel(EmergencyNotification.LOOP_CHANNEL_ID)
                    } else {
                        null
                    }
                    val fullScreenAllowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        manager.canUseFullScreenIntent()
                    } else {
                        true
                    }
                    result.success(
                        mapOf(
                            "notificationsEnabled" to manager.areNotificationsEnabled(),
                            "emergencyChannelId" to EmergencyNotification.LOOP_CHANNEL_ID,
                            "emergencyChannelEnabled" to (
                                emergencyChannel == null ||
                                    emergencyChannel.importance != NotificationManager.IMPORTANCE_NONE
                                ),
                            "emergencyChannelImportance" to (
                                emergencyChannel?.importance ?: NotificationManager.IMPORTANCE_HIGH
                                ),
                            "fullScreenAllowed" to fullScreenAllowed,
                        ),
                    )
                }
                "openFullScreenIntentSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        } catch (_: Exception) {
                            openApplicationSettings()
                        }
                    }
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            },
                        )
                    } catch (_: Exception) {
                        openApplicationSettings()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } }
        pendingNotificationPayload = payloadFromIntent(intent)
    }

    private fun openApplicationSettings() {
        startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        stopOpenedEmergency(intent)
        setIntent(intent)
        val payload = payloadFromIntent(intent) ?: return
        val channel = notificationChannel
        if (channel == null) {
            pendingNotificationPayload = payload
        } else {
            channel.invokeMethod("notificationOpened", payload)
            clearNotificationIntent(intent)
        }
    }

    private fun payloadFromIntent(source: Intent?): Map<String, String>? {
        val emergencyId = source?.getStringExtra("referenceId") ?: return null
        val type = source.getStringExtra("notificationType") ?: "emergency_alert"
        val route = source.getStringExtra("route") ?: "/emergency"
        return mapOf(
            "notificationType" to type,
            "type" to type,
            "emergencyId" to emergencyId,
            "alertId" to emergencyId,
            "route" to route,
        )
    }

    private fun clearNotificationIntent(source: Intent?) {
        source?.removeExtra("referenceId")
        source?.removeExtra("notificationType")
        source?.removeExtra("route")
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val defaultSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val notificationAudio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val regular = NotificationChannel(
            REGULAR_CHANNEL,
            "Community announcements",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Regular E-Sugid community announcements"
            setSound(defaultSound, notificationAudio)
            enableVibration(true)
        }
        val important = NotificationChannel(
            IMPORTANT_CHANNEL,
            "Important announcements",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Important E-Sugid announcements"
            setSound(defaultSound, notificationAudio)
            enableVibration(true)
        }
        val urgent = NotificationChannel(
            URGENT_CHANNEL,
            "Urgent announcements",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Urgent E-Sugid announcements"
            setSound(defaultSound, notificationAudio)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 220, 140, 220)
        }
        manager.createNotificationChannels(listOf(regular, important, urgent))
        EmergencyNotification.createChannel(this)
    }

    private fun showAnnouncementNotification(
        title: String,
        body: String,
        priority: String,
        referenceId: String,
    ) {
        val normalizedPriority = priority.lowercase()
        val channelId = when (normalizedPriority) {
            "urgent" -> URGENT_CHANNEL
            "important" -> IMPORTANT_CHANNEL
            else -> REGULAR_CHANNEL
        }
        showNotification(
            title = title,
            body = body,
            referenceId = referenceId,
            channelId = channelId,
            category = NotificationCompat.CATEGORY_STATUS,
            compatPriority = NotificationCompat.PRIORITY_DEFAULT,
            emergency = false,
            useUrgentSound = false,
        )
    }

    private fun showEmergencyNotification(
        title: String,
        body: String,
        referenceId: String,
    ) {
        if (EmergencyActionReceiver.isDoNotRemind(this, referenceId)) {
            return
        }
        // Flutter displays the foreground dialog and owns its looping sound.
        // Keep a heads-up notification, but never stack a native full-screen
        // activity on top of the already-visible Flutter UI.
        EmergencyNotification.show(
            this,
            title,
            body,
            referenceId,
            allowFullScreen = false,
        )
    }

    private fun showNotification(
        title: String,
        body: String,
        referenceId: String,
        channelId: String,
        category: String,
        compatPriority: Int,
        emergency: Boolean,
        useUrgentSound: Boolean,
    ) {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val notificationId = referenceId.hashCode() and Int.MAX_VALUE
        val contentIntent = PendingIntent.getActivity(
            this,
            notificationId,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title.take(120))
            .setContentText(body.take(240))
            .setStyle(NotificationCompat.BigTextStyle().bigText(body.take(240)))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(category)
            .setPriority(compatPriority)
            .setDefaults(if (emergency) NotificationCompat.DEFAULT_LIGHTS else 0)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            builder.setSound(sound)
            builder.setVibrate(
                if (emergency) longArrayOf(0, 350, 180, 350, 180, 600)
                else longArrayOf(0, 180),
            )
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, builder.build())
    }
}
