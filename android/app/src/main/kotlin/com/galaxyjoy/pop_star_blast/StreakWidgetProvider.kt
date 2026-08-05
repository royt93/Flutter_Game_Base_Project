package com.galaxyjoy.pop_star_blast

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class StreakWidgetProvider : HomeWidgetProvider() {

    companion object {
        // Phải khớp chính xác StorageKeys.widgetStreakKey/widgetCoinsKey trong
        // lib/core/storage_service.dart — Kotlin không import được hằng số Dart
        // nên chỉ đồng bộ được tên, đổi 1 bên phải đổi cả 2.
        private const val KEY_STREAK = "streak"
        private const val KEY_COINS = "coins"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.streak_widget_layout).apply {
                val streak = widgetData.getInt(KEY_STREAK, 0)
                val coins = widgetData.getInt(KEY_COINS, 0)
                setTextViewText(R.id.widget_streak_value, streak.toString())
                setTextViewText(R.id.widget_coin_value, coins.toString())
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
