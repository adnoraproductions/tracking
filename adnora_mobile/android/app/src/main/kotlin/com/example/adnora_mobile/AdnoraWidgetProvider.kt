package com.example.adnora_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.SystemClock
import android.widget.RemoteViews
import android.content.Intent
import android.app.PendingIntent
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class AdnoraWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Tapping anywhere opens the app
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                setOnClickPendingIntent(R.id.card_left, pendingIntent)
                setOnClickPendingIntent(R.id.card_right, pendingIntent)

                // Read live data
                val status = widgetData.getString("status", "offline") ?: "offline"
                val workedSeconds = widgetData.getInt("workedSeconds", 0)
                val targetMessage = widgetData.getString("targetMessage", "") ?: ""
                val firstIn = widgetData.getString("firstIn", "-") ?: "-"
                val lastOut = widgetData.getString("lastOut", "-") ?: "-"

                setTextViewText(R.id.widget_remaining, targetMessage)
                setTextViewText(R.id.widget_first_in, firstIn)
                setTextViewText(R.id.widget_last_out, lastOut)

                // Update Status Text
                when (status) {
                    "working" -> {
                        setTextViewText(R.id.widget_status_pill, "Working")
                    }
                    "on_break" -> {
                        setTextViewText(R.id.widget_status_pill, "On Break")
                    }
                    else -> {
                        setTextViewText(R.id.widget_status_pill, "Offline")
                    }
                }

                // Update Chronometer
                if (status == "working") {
                    setChronometer(R.id.widget_chronometer, SystemClock.elapsedRealtime() - (workedSeconds * 1000L), null, true)
                } else {
                    setChronometer(R.id.widget_chronometer, SystemClock.elapsedRealtime() - (workedSeconds * 1000L), null, false)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
