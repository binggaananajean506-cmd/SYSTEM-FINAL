package com.esugid.barili

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.ActivityManager
import android.util.Log

class EmergencyMessageReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.google.android.c2dm.intent.RECEIVE") return
        val type = (intent.getStringExtra("notificationType")
            ?: intent.getStringExtra("type"))?.trim()?.lowercase()
        val stopEmergencyId = intent.getStringExtra("emergencyId")
            ?: intent.getStringExtra("alertId")
        if (type == "emergency_stop" && !stopEmergencyId.isNullOrBlank()) {
            EmergencyAlarmService.stop(context, stopEmergencyId)
            EmergencyAlertActivity.finishActive(stopEmergencyId)
            val notificationId = stopEmergencyId.hashCode() and Int.MAX_VALUE
            EmergencyNotification.cancel(context, notificationId)
            Log.i("ESugidEmergency", "Emergency stopped id=$stopEmergencyId")
            return
        }
        val severity = intent.getStringExtra("severity")?.trim()?.lowercase()
        if (type !in setOf("emergency", "emergency_alert") ||
            severity !in setOf(null, "emergency", "critical")) {
            Log.d("ESugidEmergency", "Ignoring FCM broadcast type=$type")
            return
        }

        val referenceId = intent.getStringExtra("emergencyId")
            ?: intent.getStringExtra("alertId")
            ?: intent.getStringExtra("google.message_id")
            ?: System.currentTimeMillis().toString()
        val directEmergencyId = intent.getStringExtra("emergencyId") ?: intent.getStringExtra("alertId")
        if (EmergencyActionReceiver.isDoNotRemind(context, referenceId) ||
            (!directEmergencyId.isNullOrBlank() && EmergencyActionReceiver.isDoNotRemind(context, directEmergencyId))) {
            Log.i("ESugidEmergency", "FCM broadcast suppressed by do-not-remind id=$referenceId")
            return
        }
        val title = intent.getStringExtra("title") ?: "E-Sugid Emergency Alert"
        val body = intent.getStringExtra("body")
            ?: "Open E-Sugid for current emergency information."
        if (isAppForeground()) {
            // Flutter's foreground listener owns the visible in-app alert. The
            // native receiver remains the reliable path for background/terminated
            // delivery without displaying the same emergency twice.
            Log.i("ESugidEmergency", "Foreground emergency delegated to Flutter id=$referenceId")
            return
        }
        Log.i("ESugidEmergency", "Received emergency FCM broadcast referenceId=$referenceId")
        try {
            EmergencyAlarmService.start(context, referenceId, title, body)
        } catch (error: RuntimeException) {
            // Android may downgrade a high-priority FCM and reject background service starts.
            Log.w("ESugidEmergency", "Continuous alarm unavailable; showing finite notification", error)
            EmergencyNotification.show(context, title, body, referenceId)
        }
    }

    private fun isAppForeground(): Boolean {
        val processState = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(processState)
        return processState.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND ||
            processState.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
    }
}
