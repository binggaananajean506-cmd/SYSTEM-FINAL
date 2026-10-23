package com.esugid.barili

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class EmergencyActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_DISMISS = "com.esugid.barili.EMERGENCY_DISMISS"
        const val ACTION_DONT_REMIND = "com.esugid.barili.EMERGENCY_DONT_REMIND"
        private const val PREFS_NAME = "esugid_emergency_actions"
        private const val KEY_DO_NOT_REMIND_IDS = "do_not_remind_emergency_ids"

        fun recordDoNotRemind(context: Context, emergencyId: String) {
            val cleanId = emergencyId.trim()
            if (cleanId.isEmpty()) return
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currentSet = prefs.getStringSet(KEY_DO_NOT_REMIND_IDS, emptySet())?.toMutableSet() ?: mutableSetOf()
            currentSet.add(cleanId)
            prefs.edit()
                .putStringSet(KEY_DO_NOT_REMIND_IDS, currentSet)
                .putBoolean("do_not_remind_$cleanId", true)
                .putString("lastDoNotRemindEmergencyId", cleanId)
                .putLong("lastDoNotRemindAt", System.currentTimeMillis())
                .apply()
            Log.i("ESugidEmergency", "Recorded permanent do-not-remind id=$cleanId")
        }

        fun isDoNotRemind(context: Context, emergencyId: String): Boolean {
            val cleanId = emergencyId.trim()
            if (cleanId.isEmpty()) return false
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (prefs.getBoolean("do_not_remind_$cleanId", false)) return true
            val set = prefs.getStringSet(KEY_DO_NOT_REMIND_IDS, null)
            return set?.contains(cleanId) == true
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val emergencyId = intent.getStringExtra("referenceId") ?: return
        val notificationId = intent.getIntExtra("notificationId", 0)
        EmergencyAlarmService.stop(context, emergencyId)
        EmergencyAlertActivity.finishActive(emergencyId)

        if (notificationId != 0) EmergencyNotification.cancel(context, notificationId)

        if (intent.action == ACTION_DONT_REMIND) {
            recordDoNotRemind(context, emergencyId)
            Log.i("ESugidEmergency", "Don't remind action id=$emergencyId")
        } else if (intent.action == ACTION_DISMISS) {
            // Cancelling the Android notification stops any channel sound that
            // is still playing. The durable in-app notification record remains
            // unacknowledged and eligible for reminders.
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString("lastSilencedEmergencyId", emergencyId)
                .putLong("lastSilencedAt", System.currentTimeMillis())
                .apply()
            Log.i("ESugidEmergency", "Dismiss action id=$emergencyId")
        }
    }
}
