package com.esugid.barili

import android.app.Activity
import android.content.Intent
import android.graphics.drawable.ColorDrawable
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.lang.ref.WeakReference

class EmergencyAlertActivity : Activity() {
    companion object {
        private var activeActivity = WeakReference<EmergencyAlertActivity>(null)

        fun finishActive(emergencyId: String) {
            activeActivity.get()?.takeIf { it.referenceId == emergencyId }?.run {
                EmergencyAlarmService.stop(this, emergencyId)
                finish()
            }
        }
    }

    private var notificationId = 0
    private var referenceId = ""
    private lateinit var appearance: ESugidAppearance

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appearance = ESugidAppearance(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        activeActivity = WeakReference(this)
        render(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        render(intent)
    }

    private fun render(intent: Intent) {
        appearance.clearBindings()
        appearance.bind { colors ->
            window.setBackgroundDrawable(ColorDrawable(colors.background))
            window.statusBarColor = colors.background
            window.navigationBarColor = colors.background
            @Suppress("DEPRECATION")
            val lightBars = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR else 0
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                (window.decorView.systemUiVisibility and lightBars.inv()) or
                    if (colors.isDark) 0 else lightBars
        }
        notificationId = intent.getIntExtra("notificationId", 0)
        referenceId = intent.getStringExtra("referenceId") ?: "emergency"
        if (EmergencyActionReceiver.isDoNotRemind(this, referenceId)) {
            dismissNotification()
            stopAlarm()
            finish()
            return
        }
        val title = intent.getStringExtra("title") ?: "Emergency Alert"
        val body = intent.getStringExtra("body")
            ?: "Open E-Sugid for current emergency information."

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(36), dp(24), dp(28))
            appearance.bind { setBackgroundColor(it.background) }
        }
        val scroll = ScrollView(this).apply {
            isFillViewport = true
            addView(root)
        }

        root.addView(TextView(this).apply {
            text = "!"
            gravity = Gravity.CENTER
            textSize = 42f
            appearance.bind { setTextColor(it.onAccent) }
            setTypeface(typeface, Typeface.BOLD)
            background = android.graphics.drawable.GradientDrawable().apply {
                shape = android.graphics.drawable.GradientDrawable.OVAL
                appearance.bind { setColor(it.errorSolid) }
            }
        }, LinearLayout.LayoutParams(dp(82), dp(82)).apply { bottomMargin = dp(22) })

        root.addView(TextView(this).apply {
            text = "E-SUGID EMERGENCY ALERT"
            gravity = Gravity.CENTER
            textSize = 14f
            letterSpacing = 0.12f
            appearance.bind { setTextColor(it.error) }
            setTypeface(typeface, Typeface.BOLD)
        })
        root.addView(TextView(this).apply {
            text = title
            gravity = Gravity.CENTER
            textSize = 27f
            appearance.bind { setTextColor(it.textPrimary) }
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, dp(14), 0, dp(12))
        })
        root.addView(TextView(this).apply {
            text = body
            gravity = Gravity.CENTER
            textSize = 17f
            appearance.bind { setTextColor(it.textSecondary) }
            setLineSpacing(0f, 1.25f)
        })

        val spacer = View(this)
        root.addView(spacer, LinearLayout.LayoutParams(1, 0, 1f))

        root.addView(Button(this).apply {
            text = "VIEW ALERT"
            isAllCaps = false
            textSize = 15f
            appearance.bind { setTextColor(it.onAccent) }
            setTypeface(typeface, Typeface.BOLD)
            appearance.bind { backgroundTintList = android.content.res.ColorStateList.valueOf(it.errorSolid) }
            setOnClickListener {
                dismissNotification()
                stopAlarm()
                startActivity(Intent(this@EmergencyAlertActivity, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("notificationType", "emergency_alert")
                    putExtra("referenceId", referenceId)
                    putExtra("emergencyId", referenceId)
                    putExtra("alertId", referenceId)
                    putExtra("route", "/emergency")
                })
                finish()
            }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(56)).apply {
            topMargin = dp(28)
        })
        root.addView(Button(this).apply {
            text = "DISMISS"
            isAllCaps = false
            textSize = 15f
            appearance.bind {
                setTextColor(it.textSecondary)
                backgroundTintList = android.content.res.ColorStateList.valueOf(it.surface)
            }
            setOnClickListener {
                dismissNotification()
                stopAlarm()
                getSharedPreferences("esugid_emergency_actions", MODE_PRIVATE)
                    .edit()
                    .putString("lastSilencedEmergencyId", referenceId)
                    .putLong("lastSilencedAt", System.currentTimeMillis())
                    .apply()
                finish()
            }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(52)).apply {
            topMargin = dp(8)
        })
        root.addView(Button(this).apply {
            text = "DON'T REMIND AGAIN"
            isAllCaps = false
            textSize = 14f
            appearance.bind {
                setTextColor(it.error)
                backgroundTintList = android.content.res.ColorStateList.valueOf(it.errorSurface)
            }
            setOnClickListener {
                dismissNotification()
                stopAlarm()
                EmergencyActionReceiver.recordDoNotRemind(this@EmergencyAlertActivity, referenceId)
                finish()
            }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(48)).apply {
            topMargin = dp(8)
        })
        setContentView(scroll)
        // Also covers the finite-sound fallback if Android disallows the service.
        EmergencyAlarmController.start(this, referenceId)
    }

    private fun dismissNotification() {
        if (notificationId != 0) EmergencyNotification.cancel(this, notificationId)
    }

    private fun stopAlarm() {
        EmergencyAlarmService.stop(this, referenceId)
    }

    override fun onBackPressed() {
        dismissNotification()
        stopAlarm()
        super.onBackPressed()
    }

    override fun onDestroy() {
        appearance.close()
        if (activeActivity.get() === this) activeActivity.clear()
        super.onDestroy()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
