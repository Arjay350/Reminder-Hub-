package com.reminderhub.reminder_hub

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class WeeklyTimetableWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        ensureMidnightAlarm(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_MIDNIGHT_TICK,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.MY_PACKAGE_REPLACED" -> {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, WeeklyTimetableWidgetProvider::class.java))
                for (id in ids) updateAppWidget(context, mgr, id)
                ensureMidnightAlarm(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        scheduleNextMidnight(context)
    }
    override fun onDisabled(context: Context) {
        cancelMidnightAlarm(context)
    }

    companion object {
        private const val ACTION_MIDNIGHT_TICK = "com.reminderhub.reminder_hub.ACTION_WEEKLY_MIDNIGHT"
        const val PREFS_NAME = "ReminderHubWidgetPrefs"
        const val KEY_TIMETABLE_WIDGET_DATA = "weekly_timetable_widget_payload"

        fun ensureMidnightAlarm(context: Context) {
            val cal = Calendar.getInstance()
            val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            val toMidnight = (24 * 60 - nowMinutes).coerceAtLeast(1)
            scheduleNextMidnight(context, toMidnight)
        }

        private fun scheduleNextMidnight(context: Context, minutesFromNow: Int = -1) {
            val mins = if (minutesFromNow > 0) minutesFromNow else {
                val c = Calendar.getInstance()
                (24 * 60 - (c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE))).coerceAtLeast(1)
            }
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, WeeklyTimetableWidgetProvider::class.java).apply { action = ACTION_MIDNIGHT_TICK }
            val pi = PendingIntent.getBroadcast(context, 401, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val trigger = System.currentTimeMillis() + mins * 60 * 1000L
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                else am.setExact(AlarmManager.RTC_WAKEUP, trigger, pi)
            } catch (_: Exception) { am.set(AlarmManager.RTC_WAKEUP, trigger, pi) }
        }

        private fun cancelMidnightAlarm(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, WeeklyTimetableWidgetProvider::class.java).apply { action = ACTION_MIDNIGHT_TICK }
            val pi = PendingIntent.getBroadcast(context, 401, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            am.cancel(pi)
        }

        fun updateAllWidgets(context: Context, data: Map<String, Any>?) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (data != null) {
                val jsonString = JSONObject(data).toString()
                prefs.edit().putString(KEY_TIMETABLE_WIDGET_DATA, jsonString).apply()
            }

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, WeeklyTimetableWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
            ensureMidnightAlarm(context)
        }

        private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.weekly_timetable_widget)

            // Setup click PendingIntent to launch ReminderHub MainActivity
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                102,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.timetable_widget_root, pendingIntent)

            // Current day of week (Calendar.MONDAY = 2, ..., Calendar.FRIDAY = 6)
            val cal = Calendar.getInstance()
            val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)

            // Set column backgrounds (highlight today)
            views.setInt(
                R.id.col_mon_container,
                "setBackgroundResource",
                if (dayOfWeek == Calendar.MONDAY) R.drawable.widget_timetable_today_col_bg else R.drawable.widget_timetable_col_bg
            )
            views.setInt(
                R.id.col_tue_container,
                "setBackgroundResource",
                if (dayOfWeek == Calendar.TUESDAY) R.drawable.widget_timetable_today_col_bg else R.drawable.widget_timetable_col_bg
            )
            views.setInt(
                R.id.col_wed_container,
                "setBackgroundResource",
                if (dayOfWeek == Calendar.WEDNESDAY) R.drawable.widget_timetable_today_col_bg else R.drawable.widget_timetable_col_bg
            )
            views.setInt(
                R.id.col_thu_container,
                "setBackgroundResource",
                if (dayOfWeek == Calendar.THURSDAY) R.drawable.widget_timetable_today_col_bg else R.drawable.widget_timetable_col_bg
            )
            views.setInt(
                R.id.col_fri_container,
                "setBackgroundResource",
                if (dayOfWeek == Calendar.FRIDAY) R.drawable.widget_timetable_today_col_bg else R.drawable.widget_timetable_col_bg
            )
            views.setInt(
                R.id.col_sat_container,
                "setBackgroundResource",
                if (dayOfWeek == Calendar.SATURDAY) R.drawable.widget_timetable_today_col_bg else R.drawable.widget_timetable_col_bg
            )

            // Read stored payload
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(KEY_TIMETABLE_WIDGET_DATA, null)

            if (rawJson != null) {
                try {
                    val json = JSONObject(rawJson)
                    val headerTitle = json.optString("headerTitle", "WEEKLY TIMETABLE")
                    val subtitle = json.optString("subtitle", "Mon – Sat Schedule")
                    val badgeText = json.optString("badgeText", "Timetable")
                    val footerInfo = json.optString("footerInfo", "Tap to view full timetable")
                    val footerBrand = json.optString("footerBrand", "ReminderHub")
                    val totalClasses = json.optInt("totalClasses", 0)
                    val daysObj = json.optJSONObject("days") ?: JSONObject()
                    val dayModesObj = json.optJSONObject("dayModes") ?: JSONObject()

                    views.setTextViewText(R.id.timetable_header_title, headerTitle)
                    views.setTextViewText(R.id.timetable_subtitle, subtitle)
                    views.setTextViewText(R.id.timetable_badge, badgeText)
                    views.setTextViewText(R.id.timetable_footer_info, footerInfo)
                    views.setTextViewText(R.id.timetable_footer_brand, footerBrand)

                    // Set day mode labels
                    views.setTextViewText(R.id.col_mon_mode, dayModesObj.optString("mon", ""))
                    views.setTextViewText(R.id.col_tue_mode, dayModesObj.optString("tue", ""))
                    views.setTextViewText(R.id.col_wed_mode, dayModesObj.optString("wed", ""))
                    views.setTextViewText(R.id.col_thu_mode, dayModesObj.optString("thu", ""))
                    views.setTextViewText(R.id.col_fri_mode, dayModesObj.optString("fri", ""))
                    views.setTextViewText(R.id.col_sat_mode, dayModesObj.optString("sat", ""))

                    if (totalClasses == 0) {
                        views.setViewVisibility(R.id.timetable_empty_layout, View.VISIBLE)
                        views.setViewVisibility(R.id.timetable_grid_layout, View.GONE)
                    } else {
                        views.setViewVisibility(R.id.timetable_empty_layout, View.GONE)
                        views.setViewVisibility(R.id.timetable_grid_layout, View.VISIBLE)

                        // Bind Monday
                        bindDaySlots(
                            views,
                            daysObj.optJSONArray("mon") ?: JSONArray(),
                            arrayOf(R.id.mon_slot_1, R.id.mon_slot_2, R.id.mon_slot_3, R.id.mon_slot_4, R.id.mon_slot_5),
                            arrayOf(R.id.mon_slot_1_time, R.id.mon_slot_2_time, R.id.mon_slot_3_time, R.id.mon_slot_4_time, R.id.mon_slot_5_time),
                            arrayOf(R.id.mon_slot_1_subj, R.id.mon_slot_2_subj, R.id.mon_slot_3_subj, R.id.mon_slot_4_subj, R.id.mon_slot_5_subj)
                        )

                        // Bind Tuesday
                        bindDaySlots(
                            views,
                            daysObj.optJSONArray("tue") ?: JSONArray(),
                            arrayOf(R.id.tue_slot_1, R.id.tue_slot_2, R.id.tue_slot_3, R.id.tue_slot_4, R.id.tue_slot_5),
                            arrayOf(R.id.tue_slot_1_time, R.id.tue_slot_2_time, R.id.tue_slot_3_time, R.id.tue_slot_4_time, R.id.tue_slot_5_time),
                            arrayOf(R.id.tue_slot_1_subj, R.id.tue_slot_2_subj, R.id.tue_slot_3_subj, R.id.tue_slot_4_subj, R.id.tue_slot_5_subj)
                        )

                        // Bind Wednesday
                        bindDaySlots(
                            views,
                            daysObj.optJSONArray("wed") ?: JSONArray(),
                            arrayOf(R.id.wed_slot_1, R.id.wed_slot_2, R.id.wed_slot_3, R.id.wed_slot_4, R.id.wed_slot_5),
                            arrayOf(R.id.wed_slot_1_time, R.id.wed_slot_2_time, R.id.wed_slot_3_time, R.id.wed_slot_4_time, R.id.wed_slot_5_time),
                            arrayOf(R.id.wed_slot_1_subj, R.id.wed_slot_2_subj, R.id.wed_slot_3_subj, R.id.wed_slot_4_subj, R.id.wed_slot_5_subj)
                        )

                        // Bind Thursday
                        bindDaySlots(
                            views,
                            daysObj.optJSONArray("thu") ?: JSONArray(),
                            arrayOf(R.id.thu_slot_1, R.id.thu_slot_2, R.id.thu_slot_3, R.id.thu_slot_4, R.id.thu_slot_5),
                            arrayOf(R.id.thu_slot_1_time, R.id.thu_slot_2_time, R.id.thu_slot_3_time, R.id.thu_slot_4_time, R.id.thu_slot_5_time),
                            arrayOf(R.id.thu_slot_1_subj, R.id.thu_slot_2_subj, R.id.thu_slot_3_subj, R.id.thu_slot_4_subj, R.id.thu_slot_5_subj)
                        )

                        // Bind Friday
                        bindDaySlots(
                            views,
                            daysObj.optJSONArray("fri") ?: JSONArray(),
                            arrayOf(R.id.fri_slot_1, R.id.fri_slot_2, R.id.fri_slot_3, R.id.fri_slot_4, R.id.fri_slot_5),
                            arrayOf(R.id.fri_slot_1_time, R.id.fri_slot_2_time, R.id.fri_slot_3_time, R.id.fri_slot_4_time, R.id.fri_slot_5_time),
                            arrayOf(R.id.fri_slot_1_subj, R.id.fri_slot_2_subj, R.id.fri_slot_3_subj, R.id.fri_slot_4_subj, R.id.fri_slot_5_subj)
                        )

                        // Bind Saturday
                        bindDaySlots(
                            views,
                            daysObj.optJSONArray("sat") ?: JSONArray(),
                            arrayOf(R.id.sat_slot_1, R.id.sat_slot_2, R.id.sat_slot_3, R.id.sat_slot_4, R.id.sat_slot_5),
                            arrayOf(R.id.sat_slot_1_time, R.id.sat_slot_2_time, R.id.sat_slot_3_time, R.id.sat_slot_4_time, R.id.sat_slot_5_time),
                            arrayOf(R.id.sat_slot_1_subj, R.id.sat_slot_2_subj, R.id.sat_slot_3_subj, R.id.sat_slot_4_subj, R.id.sat_slot_5_subj)
                        )
                    }
                } catch (_: Exception) {
                    views.setViewVisibility(R.id.timetable_empty_layout, View.VISIBLE)
                    views.setViewVisibility(R.id.timetable_grid_layout, View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.timetable_empty_layout, View.VISIBLE)
                views.setViewVisibility(R.id.timetable_grid_layout, View.GONE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun bindDaySlots(
            views: RemoteViews,
            classes: JSONArray,
            slotIds: Array<Int>,
            timeIds: Array<Int>,
            subjIds: Array<Int>
        ) {
            for (i in 0 until 5) {
                if (i < classes.length()) {
                    val c = classes.getJSONObject(i)
                    views.setTextViewText(timeIds[i], c.optString("time", ""))
                    views.setTextViewText(subjIds[i], c.optString("subject", ""))
                    views.setViewVisibility(slotIds[i], View.VISIBLE)
                } else {
                    views.setViewVisibility(slotIds[i], View.GONE)
                }
            }
        }
    }
}
