package com.esugid.barili

import android.content.Context
import android.media.MediaPlayer
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

object EmergencyAlarmController {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var currentEmergencyId: String? = null

    @Synchronized
    fun start(context: Context, emergencyId: String) {
        if (currentEmergencyId == emergencyId && player?.isPlaying == true) return
        stop()
        val createdPlayer = MediaPlayer.create(context.applicationContext, R.raw.esugid_emergency_alert)
            ?: return
        createdPlayer.isLooping = true
        createdPlayer.setOnErrorListener { _, what, extra ->
            Log.e("ESugidEmergency", "Alarm playback failed what=$what extra=$extra")
            stop(emergencyId)
            true
        }
        createdPlayer.start()
        player = createdPlayer
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 450, 180, 450, 180, 850)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
        currentEmergencyId = emergencyId
        Log.i("ESugidEmergency", "Visible alarm loop started id=$emergencyId")
    }

    @Synchronized
    fun stop(emergencyId: String? = null) {
        if (emergencyId != null && currentEmergencyId != null && currentEmergencyId != emergencyId) return
        player?.runCatching { stop() }
        player?.release()
        player = null
        vibrator?.cancel()
        vibrator = null
        currentEmergencyId = null
    }
}
