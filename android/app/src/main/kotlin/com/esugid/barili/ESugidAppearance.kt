package com.esugid.barili

import android.content.ComponentCallbacks
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration

/** Native emergency windows share Flutter's saved theme and semantic colors. */
class ESugidAppearance(private val context: Context) : AutoCloseable {
    data class Colors(
        val isDark: Boolean,
        val background: Int,
        val surface: Int,
        val textPrimary: Int,
        val textSecondary: Int,
        val error: Int,
        val errorSurface: Int,
        val errorSolid: Int,
        val onAccent: Int,
    )

    private val preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    private val bindings = mutableListOf<(Colors) -> Unit>()
    private val preferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == "flutter.esugid_theme_mode" || key == "flutter.esugid_dark_mode") refresh()
    }
    private val configurationListener = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) = refresh()
        override fun onLowMemory() = Unit
    }

    init {
        preferences.registerOnSharedPreferenceChangeListener(preferenceListener)
        context.registerComponentCallbacks(configurationListener)
    }

    fun bind(apply: (Colors) -> Unit) {
        bindings.add(apply)
        apply(colors())
    }

    fun clearBindings() = bindings.clear()

    private fun refresh() {
        val palette = colors()
        bindings.toList().forEach { it(palette) }
    }

    private fun colors(): Colors {
        val saved = preferences.all
        val systemDark = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
            Configuration.UI_MODE_NIGHT_YES
        val isDark = when (saved["flutter.esugid_theme_mode"]) {
            "light" -> false
            "dark" -> true
            "system" -> systemDark
            else -> saved["flutter.esugid_dark_mode"] as? Boolean ?: systemDark
        }
        val configuration = Configuration(context.resources.configuration).apply {
            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                if (isDark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
        }
        val resources = context.createConfigurationContext(configuration).resources
        @Suppress("DEPRECATION")
        fun color(id: Int) = resources.getColor(id)
        return Colors(
            isDark,
            color(R.color.esugid_background),
            color(R.color.esugid_surface),
            color(R.color.esugid_text_primary),
            color(R.color.esugid_text_secondary),
            color(R.color.esugid_error),
            color(R.color.esugid_error_surface),
            color(R.color.esugid_error_solid),
            color(R.color.esugid_on_accent),
        )
    }

    override fun close() {
        preferences.unregisterOnSharedPreferenceChangeListener(preferenceListener)
        context.unregisterComponentCallbacks(configurationListener)
        bindings.clear()
    }
}
