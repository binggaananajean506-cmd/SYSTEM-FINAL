package com.esugid.barili

import android.app.Service
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.content.ContextCompat

/** Keeps a received emergency ringing even when Android shows a heads-up banner instead of the popup. */
class EmergencyAlarmService : Service() {
    companion object {
        private const val ACTION_START = "com.esugid.barili.EMERGENCY_ALARM_START"
        private var activeEmergencyId: String? = null

        fun start(context: Context, emergencyId: String, title: String, body: String) {
            val intent = Intent(context, EmergencyAlarmService::class.java).apply {
                action = ACTION_START
                putExtra("referenceId", emergencyId)
                putExtra("title", title)
                putExtra("body", body)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context, emergencyId: String) {
            EmergencyAlarmController.stop(emergencyId)
            if (activeEmergencyId == emergencyId) {
                context.stopService(Intent(context, EmergencyAlarmService::class.java))
            }
        }
    }

    private val overlay by lazy { EmergencyAlertOverlay(this) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val emergencyId = intent?.getStringExtra("referenceId") ?: return START_NOT_STICKY
        if (intent.action != ACTION_START) return START_NOT_STICKY
        if (EmergencyActionReceiver.isDoNotRemind(this, emergencyId)) {
            Log.i("ESugidEmergency", "EmergencyAlarmService skipped due to do-not-remind id=$emergencyId")
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent.getStringExtra("title") ?: "E-Sugid Emergency Alert"
        val body = intent.getStringExtra("body") ?: "Open E-Sugid for current emergency information."
        val notificationId = emergencyId.hashCode() and Int.MAX_VALUE
        try {
            val notification = EmergencyNotification.build(this, title, body, emergencyId, silent = true)
            startForeground(notificationId, notification)
            activeEmergencyId = emergencyId
            EmergencyAlarmController.start(this, emergencyId)
            val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (!keyguard.isKeyguardLocked) {
                try {
                    overlay.show(
                        title,
                        body,
                        onView = { viewAlert(emergencyId) },
                        onDismiss = { dismissAlert(emergencyId) },
                        onDontRemind = { doNotRemindAlert(emergencyId) },
                    )
                } catch (error: RuntimeException) {
                    // The notification remains available if the OEM refuses overlays.
                    Log.w("ESugidEmergency", "Emergency overlay unavailable", error)
                }
            }
        } catch (error: RuntimeException) {
            Log.e("ESugidEmergency", "Continuous alarm could not start", error)
            EmergencyAlarmController.stop(emergencyId)
            stopSelf()
            EmergencyNotification.show(this, title, body, emergencyId)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        overlay.remove()
        activeEmergencyId?.let(EmergencyAlarmController::stop)
        activeEmergencyId = null
        super.onDestroy()
    }

    private fun viewAlert(emergencyId: String) {
        if (activeEmergencyId != emergencyId) return
        try {
            // The visible overlay allows this user-initiated background launch.
            startActivity(Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("notificationType", "emergency_alert")
                putExtra("referenceId", emergencyId)
                putExtra("emergencyId", emergencyId)
                putExtra("alertId", emergencyId)
                putExtra("route", "/emergency")
            })
        } catch (error: RuntimeException) {
            Log.e("ESugidEmergency", "Could not open emergency details from overlay", error)
        } finally {
            stop(this, emergencyId)
            EmergencyNotification.cancel(this, emergencyId.hashCode() and Int.MAX_VALUE)
        }
    }

    private fun dismissAlert(emergencyId: String) {
        if (activeEmergencyId != emergencyId) return
        getSharedPreferences("esugid_emergency_actions", MODE_PRIVATE)
            .edit()
            .putString("lastSilencedEmergencyId", emergencyId)
            .putLong("lastSilencedAt", System.currentTimeMillis())
            .apply()
        stop(this, emergencyId)
        EmergencyNotification.cancel(this, emergencyId.hashCode() and Int.MAX_VALUE)
    }

    private fun doNotRemindAlert(emergencyId: String) {
        if (activeEmergencyId != emergencyId) return
        EmergencyActionReceiver.recordDoNotRemind(this, emergencyId)
        stop(this, emergencyId)
        EmergencyNotification.cancel(this, emergencyId.hashCode() and Int.MAX_VALUE)
    }
}
