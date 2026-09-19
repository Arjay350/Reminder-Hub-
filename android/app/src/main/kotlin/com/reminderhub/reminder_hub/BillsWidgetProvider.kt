package com.reminderhub.reminder_hub

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class BillsWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            updateAppWidget(context, appWidgetManager, appWidgetId, options)
        }
        ensureAlarmScheduled(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId, newOptions)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_MANUAL_REFRESH,
            ACTION_ALARM_TICK,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.MY_PACKAGE_REPLACED" -> {
                updateAllWidgets(context, null)
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleNextTick(context, 5)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelScheduledTick(context)
    }

    companion object {
        private const val TAG = "BillsWidget"
        const val PREFS_NAME = "ReminderHubWidgetPrefs"
        const val KEY_BILLS_WIDGET_DATA = "bills_widget_payload"
        const val ACTION_MANUAL_REFRESH = "com.reminderhub.reminder_hub.ACTION_BILLS_MANUAL_REFRESH"
        const val ACTION_ALARM_TICK = "com.reminderhub.reminder_hub.ACTION_BILLS_ALARM_TICK"

        fun ensureAlarmScheduled(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(KEY_BILLS_WIDGET_DATA, null)
            val nextMinutes = computeNextTickMinutes(rawJson)
            scheduleNextTick(context, nextMinutes)
        }

        fun updateAllWidgets(context: Context, data: Map<String, Any>?) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (data != null) {
                val jsonString = JSONObject(data).toString()
                prefs.edit().putString(KEY_BILLS_WIDGET_DATA, jsonString).apply()
            }

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, BillsWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            val rawJson = prefs.getString(KEY_BILLS_WIDGET_DATA, null)
            val nextMinutes = computeNextTickMinutes(rawJson)

            for (appWidgetId in appWidgetIds) {
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_bills_list)
                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                updateAppWidget(context, appWidgetManager, appWidgetId, options)
            }

            scheduleNextTick(context, nextMinutes)
        }

        private fun computeNextTickMinutes(rawJson: String?): Int {
            if (rawJson == null) return 60 // no data, check back in 1h

            try {
                val json = JSONObject(rawJson)
                val billsArray = json.optJSONArray("bills") ?: JSONArray()
                if (billsArray.length() == 0) {
                    // No bills, tick at next midnight for day rollover (max 60 min capped loop)
                    val cal = Calendar.getInstance()
                    val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
                    val toMidnight = (24 * 60 - nowMinutes).coerceAtLeast(1)
                    return toMidnight.coerceAtMost(1440)
                }

                val calNow = Calendar.getInstance()
                val todayStart = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
                }

                var minMinutes: Int? = null

                for (i in 0 until billsArray.length()) {
                    val bObj = billsArray.getJSONObject(i)
                    val rawIso = bObj.optString("rawDueDateIso", "")
                    val dueIso = bObj.optString("dueDateIso", rawIso)
                    val advanceDays = bObj.optInt("advanceDays", 1)
                    val isoToParse = if (rawIso.isNotEmpty()) rawIso else dueIso
                    if (isoToParse.isEmpty()) continue

                    val dueDate = parseIsoDate(isoToParse) ?: continue
                    val dueCal = Calendar.getInstance().apply { time = dueDate; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
                    val activationCal = (dueCal.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -advanceDays) }

                    val boundaries = listOf(activationCal, dueCal, (dueCal.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) })

                    for (bCal in boundaries) {
                        // Boundary fires at start of that day (00:00)
                        // If boundary is today or future, compute minutes until that 00:01 next day tick
                        val boundaryMidnight = bCal.timeInMillis
                        val nowMillis = calNow.timeInMillis
                        // If boundary is in future (> now)
                        if (boundaryMidnight > nowMillis) {
                            val diffMinutes = ((boundaryMidnight - nowMillis) / (60 * 1000)).toInt().coerceAtLeast(1)
                            if (minMinutes == null || diffMinutes < minMinutes) minMinutes = diffMinutes
                        } else if (boundaryMidnight == todayStart.timeInMillis) {
                            // Boundary is today - if we passed midnight but not yet handled, schedule next midnight
                            // Actually overdue should be evaluated next midnight
                            continue
                        }
                    }
                    // Also consider next occurrence for recurring: due + 30 days approx activation for next cycle
                    // But BillsScreen advances dueDate immediately, so we handle already via due
                }

                if (minMinutes != null) {
                    // Cap at 1440 but ensure at least 1, if > 60 and no imminent due within hour, schedule at boundary
                    return minMinutes.coerceIn(1, 1440)
                }

                // No imminent boundary, schedule at next midnight
                val nowMinutes = calNow.get(Calendar.HOUR_OF_DAY) * 60 + calNow.get(Calendar.MINUTE)
                val toMidnight = (24 * 60 - nowMinutes).coerceAtLeast(1)
                return toMidnight.coerceAtMost(1440)

            } catch (e: Exception) {
                Log.w(TAG, "computeNextTickMinutes error: $e")
                return 60
            }
        }

        private fun parseIsoDate(iso: String): java.util.Date? {
            return try {
                // Try ISO 8601 with milliseconds
                val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
                fmt.timeZone = TimeZone.getDefault()
                fmt.parse(iso.substringBefore('Z').substringBefore('+'))
            } catch (_: Exception) {
                try {
                    val fmt2 = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                    fmt2.timeZone = TimeZone.getDefault()
                    fmt2.parse(iso.substringBefore('.').substringBefore('Z'))
                } catch (_: Exception) {
                    try {
                        val fmt3 = SimpleDateFormat("MMM dd, yyyy", Locale.US)
                        fmt3.parse(iso)
                    } catch (_: Exception) { null }
                }
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            options: Bundle? = null
        ) {
            val views = RemoteViews(context.packageName, R.layout.bills_widget)

            // Current Date
            val cal = Calendar.getInstance()
            val dayName = getDayName(cal.get(Calendar.DAY_OF_WEEK))
            val formattedDate = "$dayName, ${getMonthShortName(cal.get(Calendar.MONTH))} ${cal.get(Calendar.DAY_OF_MONTH)}"

            // 1. Setup Click PendingIntent on Widget Header & View Bills Button
            val billsIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.reminderhub.ACTION_OPEN_BILLS"
                putExtra("route", "/bills")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val billsPendingIntent = PendingIntent.getActivity(
                context,
                201,
                billsIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_header_bar, billsPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_btn_view_bills, billsPendingIntent)

            // 2. Setup Manual Refresh PendingIntent
            val refreshIntent = Intent(context, BillsWidgetProvider::class.java).apply {
                action = ACTION_MANUAL_REFRESH
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                202,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_refresh, refreshPendingIntent)

            // 3. Setup Scrollable ListView Adapter & PendingIntentTemplate
            val serviceIntent = Intent(context, BillsWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_bills_list, serviceIntent)
            views.setEmptyView(R.id.widget_bills_list, R.id.widget_empty_layout)

            val itemClickIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.reminderhub.ACTION_OPEN_BILLS"
                putExtra("route", "/bills")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val itemClickPendingIntent = PendingIntent.getActivity(
                context,
                203,
                itemClickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_bills_list, itemClickPendingIntent)

            // 4. Parse Bills Data from SharedPreferences - TIME-AWARE RECOMPUTATION
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(KEY_BILLS_WIDGET_DATA, null)

            if (rawJson != null) {
                try {
                    val json = JSONObject(rawJson)
                    val billsArray = json.optJSONArray("bills") ?: JSONArray()
                    val totalBills = json.optInt("totalBills", billsArray.length())

                    // Recompute counts time-aware
                    var unpaidCount = 0
                    var overdueCount = 0
                    var upcomingCount = 0
                    var paidCount = 0
                    for (i in 0 until billsArray.length()) {
                        val bObj = billsArray.getJSONObject(i)
                        val status = recomputeBillStatus(bObj)
                        when (status) {
                            "overdue" -> overdueCount++
                            "unpaid" -> unpaidCount++
                            "upcoming" -> upcomingCount++
                            "paid" -> paidCount++
                        }
                    }

                    // Set Header texts
                    views.setTextViewText(R.id.widget_header_title, "ReminderHub Bills")
                    views.setTextViewText(
                        R.id.widget_date_subtitle,
                        if (totalBills == 0) formattedDate else "$formattedDate • $totalBills ${if (totalBills == 1) "Bill" else "Bills"}"
                    )

                    // Footer
                    val footerText = when {
                        totalBills == 0 -> "No bills tracked"
                        overdueCount > 0 -> "$totalBills Bills • $overdueCount Overdue"
                        unpaidCount > 0 -> "$totalBills Bills • $unpaidCount Unpaid"
                        upcomingCount > 0 -> "$totalBills Bills • $upcomingCount Upcoming"
                        else -> "$totalBills Bills • All Paid"
                    }
                    views.setTextViewText(R.id.widget_footer_info, footerText)
                    views.setTextViewText(R.id.widget_footer_brand, "ReminderHub")

                    // Empty state toggle
                    if (billsArray.length() == 0) {
                        views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_bills_list, View.GONE)
                    } else {
                        views.setViewVisibility(R.id.widget_empty_layout, View.GONE)
                        views.setViewVisibility(R.id.widget_bills_list, View.VISIBLE)
                    }

                } catch (e: Exception) {
                    Log.w(TAG, "updateAppWidget parse error: $e")
                    views.setTextViewText(R.id.widget_header_title, "ReminderHub Bills")
                    views.setTextViewText(R.id.widget_date_subtitle, formattedDate)
                    views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_bills_list, View.GONE)
                }
            } else {
                views.setTextViewText(R.id.widget_header_title, "ReminderHub Bills")
                views.setTextViewText(R.id.widget_date_subtitle, formattedDate)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                views.setViewVisibility(R.id.widget_bills_list, View.GONE)
            }

            // 5. Handle Responsive Sizing
            val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 160
            if (minHeight < 120) {
                views.setViewVisibility(R.id.widget_list_container, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_list_container, View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun recomputeBillStatus(bObj: JSONObject): String {
            try {
                val isRecurring = bObj.optBoolean("isRecurring", false)
                val paid = bObj.optBoolean("paid", false)
                val rawIso = bObj.optString("rawDueDateIso", "")
                val dueIso = bObj.optString("dueDateIso", rawIso)
                val advanceDays = bObj.optInt("advanceDays", 1)
                val storedStatus = bObj.optString("status", "unpaid")
                val isoToParse = if (rawIso.isNotEmpty()) rawIso else dueIso
                if (isoToParse.isEmpty()) return storedStatus

                val dueDate = parseIsoDate(isoToParse) ?: return storedStatus
                val calDue = Calendar.getInstance().apply { time = dueDate }
                val calActivation = (calDue.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -advanceDays) }

                val calToday = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
                val calDueDay = Calendar.getInstance().apply { time = dueDate; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
                val calActDay = Calendar.getInstance().apply { time = calActivation.time; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }

                if (isRecurring) {
                    // Need to know if we have history: if stored status was paid and before activation, keep paid
                    // We infer history by checking storedStatus was paid vs isRecurring paid flag?
                    // For recurring before activation we stored paid=true via display logic, so recompute:
                    if (calToday.before(calActDay)) {
                        // Before activation window => should show previous paid occurrence as PAID
                        // Detect if we had a paid history by checking if raw due is future and storedStatus would be paid
                        // We use: if today before activation => return paid (per Dart logic for recurring with history)
                        // But how to know if history exists? Check if advanceDays matters: if bill has history we would have stored status paid when before window.
                        // Approximate: if isRecurring and today before activation => check if storedStatus == paid then remain paid else upcoming?
                        // Dart logic: if recurring && paymentHistory not empty && today before activation => paid
                        // We don't have paymentHistory size here, so fallback to storedStatus if it was paid, otherwise upcoming
                        if (storedStatus == "paid") return "paid"
                        // If no history, before activation => upcoming
                        return "upcoming"
                    } else {
                        if (paid) return "paid"
                        if (calToday.after(calDueDay)) return "overdue"
                        return "unpaid"
                    }
                } else {
                    if (paid) return "paid"
                    if (calToday.after(calDueDay)) return "overdue"
                    if (calToday.before(calActDay)) return "upcoming"
                    return "unpaid"
                }
            } catch (_: Exception) {
                return bObj.optString("status", "unpaid")
            }
        }

        private fun scheduleNextTick(context: Context, minutesFromNow: Int) {
            val safeMinutes = minutesFromNow.coerceIn(1, 1440)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, BillsWidgetProvider::class.java).apply {
                action = ACTION_ALARM_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                302,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val nowMillis = System.currentTimeMillis()
            val nextMinuteAligned = ((nowMillis / 60000L) + safeMinutes) * 60000L
            val triggerAtMillis = if (nextMinuteAligned > nowMillis) nextMinuteAligned else nowMillis + (safeMinutes * 60000L)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                    } else {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            } catch (e: SecurityException) {
                try {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                } catch (_: Exception) {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            } catch (_: Exception) {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
            Log.d(TAG, "Scheduled next Bills alarm in ${safeMinutes}m")
        }

        private fun cancelScheduledTick(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, BillsWidgetProvider::class.java).apply {
                action = ACTION_ALARM_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                302,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }

        fun getDayName(dayOfWeek: Int): String {
            return when (dayOfWeek) {
                Calendar.MONDAY -> "Monday"
                Calendar.TUESDAY -> "Tuesday"
                Calendar.WEDNESDAY -> "Wednesday"
                Calendar.THURSDAY -> "Thursday"
                Calendar.FRIDAY -> "Friday"
                Calendar.SATURDAY -> "Saturday"
                Calendar.SUNDAY -> "Sunday"
                else -> "Monday"
            }
        }

        fun getMonthShortName(monthIndex: Int): String {
            val months = arrayOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
            return if (monthIndex in 0..11) months[monthIndex] else "Aug"
        }
    }
}
