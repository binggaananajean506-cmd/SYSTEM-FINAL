package com.esugid.barili

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.text.TextUtils
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/** User-opted-in alert surface for an unlocked phone when E-SUGID is in the background. */
class EmergencyAlertOverlay(private val context: Context) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var root: View? = null
    private var appearance: ESugidAppearance? = null

    fun show(
        title: String,
        body: String,
        onView: () -> Unit,
        onDismiss: () -> Unit,
        onDontRemind: (() -> Unit)? = null,
    ) {
        remove()
        if (!Settings.canDrawOverlays(context)) return
        val appearance = ESugidAppearance(context)
        this.appearance = appearance

        val backdrop = FrameLayout(context).apply {
            setBackgroundColor(Color.argb(202, 0, 0, 0))
            isClickable = true
        }
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(26), dp(24), dp(20))
            background = GradientDrawable().apply {
                appearance.bind { setColor(it.surface) }
                cornerRadius = dp(24).toFloat()
            }
            elevation = dp(18).toFloat()
        }
        card.addView(TextView(context).apply {
            text = "E-SUGID EMERGENCY ALERT"
            textSize = 14f
            appearance.bind { setTextColor(it.error) }
            setTypeface(typeface, Typeface.BOLD)
            letterSpacing = 0.08f
        })
        card.addView(TextView(context).apply {
            text = title
            textSize = 24f
            maxLines = 3
            ellipsize = TextUtils.TruncateAt.END
            appearance.bind { setTextColor(it.textPrimary) }
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, dp(14), 0, dp(10))
        })
        card.addView(TextView(context).apply {
            text = body
            textSize = 16f
            maxLines = 8
            ellipsize = TextUtils.TruncateAt.END
            appearance.bind { setTextColor(it.textSecondary) }
            setLineSpacing(0f, 1.2f)
        })
        card.addView(Button(context).apply {
            text = "VIEW ALERT"
            isAllCaps = false
            appearance.bind {
                setTextColor(it.onAccent)
                backgroundTintList = android.content.res.ColorStateList.valueOf(it.errorSolid)
            }
            setOnClickListener { onView() }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(52)).apply {
            topMargin = dp(24)
        })
        card.addView(Button(context).apply {
            text = "DISMISS"
            isAllCaps = false
            appearance.bind {
                setTextColor(it.textSecondary)
                backgroundTintList = android.content.res.ColorStateList.valueOf(it.surface)
            }
            setOnClickListener { onDismiss() }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(48)))
        card.addView(Button(context).apply {
            text = "DON'T REMIND AGAIN"
            isAllCaps = false
            textSize = 14f
            appearance.bind {
                setTextColor(it.error)
                backgroundTintList = android.content.res.ColorStateList.valueOf(it.errorSurface)
            }
            setOnClickListener { onDontRemind?.invoke() ?: onDismiss() }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(46)).apply {
            topMargin = dp(6)
        })
        val width = minOf(context.resources.displayMetrics.widthPixels - dp(40), dp(420))
        backdrop.addView(card, FrameLayout.LayoutParams(width, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER))

        val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT,
        )
        try {
            windowManager.addView(backdrop, params)
        } catch (error: RuntimeException) {
            appearance.close()
            this.appearance = null
            throw error
        }
        root = backdrop
    }

    fun remove() {
        appearance?.close()
        appearance = null
        root?.let { view ->
            // Android may detach an overlay itself when access is revoked.
            runCatching { windowManager.removeView(view) }
        }
        root = null
    }

    private fun dp(value: Int): Int = (value * context.resources.displayMetrics.density).toInt()
}
