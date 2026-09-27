package com.reminderhub.reminder_hub

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class SchoolScheduleWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            updateAppWidget(context, appWidgetManager, appWidgetId, options)
        }
        // Always ensure alarm chain is running whenever widgets are updated
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
        // First widget placed — kickstart the alarm chain immediately
        scheduleNextAlarm(context, 1)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelScheduledAlarm(context)
    }

    companion object {
        private const val TAG = "SchoolWidget"
        const val PREFS_NAME = "ReminderHubWidgetPrefs"
        const val KEY_TODAY_WIDGET_DATA = "school_widget_payload"
        const val ACTION_MANUAL_REFRESH = "com.reminderhub.reminder_hub.ACTION_MANUAL_REFRESH"
        const val ACTION_ALARM_TICK = "com.reminderhub.reminder_hub.ACTION_ALARM_TICK"

        /**
         * Ensures the alarm chain is always running. Safe to call repeatedly —
         * it reads the timetable data and schedules the next alarm at the
         * appropriate class boundary time.
         */
        fun ensureAlarmScheduled(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(KEY_TODAY_WIDGET_DATA, null)
            val nextTickMinutes = computeNextTickMinutes(rawJson)
            scheduleNextAlarm(context, nextTickMinutes)
        }

        fun updateAllWidgets(context: Context, data: Map<String, Any>?) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (data != null) {
                val jsonString = JSONObject(data).toString()
                prefs.edit().putString(KEY_TODAY_WIDGET_DATA, jsonString).apply()
            }

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, SchoolScheduleWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            // Compute next alarm from data BEFORE updating individual widgets
            val rawJson = prefs.getString(KEY_TODAY_WIDGET_DATA, null)
            val nextTickMinutes = computeNextTickMinutes(rawJson)

            for (appWidgetId in appWidgetIds) {
                // Invalidate RemoteViewsFactory list collection
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_classes_list)

                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                updateAppWidget(context, appWidgetManager, appWidgetId, options)
            }

            // Always reschedule the next alarm — this is the key to real-time updates
            scheduleNextAlarm(context, nextTickMinutes)
        }

        /**
         * Computes how many minutes until the next alarm tick.
         * For real-time widget updates without manual refresh:
         * - During the school day (from 60m before first class through all classes): ticks every 1 minute for live countdowns & instant state changes.
         * - Before the school day window: ticks every 5 minutes.
         * - After all classes today or on free days: ticks every 15 minutes (daytime) or at midnight rollover.
         */
        private fun computeNextTickMinutes(rawJson: String?): Int {
            if (rawJson == null) return 5

            try {
                val json = JSONObject(rawJson)
                val cal = Calendar.getInstance()
                val todayWeekday = getReminderHubWeekday(cal)
                val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

                val allClassesArray = json.optJSONArray("allClasses")
                    ?: json.optJSONArray("classes")
                    ?: JSONArray()

                // Collect all today's class boundaries
                val todayStartTimes = mutableListOf<Int>()
                val todayEndTimes = mutableListOf<Int>()

                for (i in 0 until allClassesArray.length()) {
                    val cObj = allClassesArray.getJSONObject(i)
                    val daysArr = cObj.optJSONArray("daysOfWeek") ?: JSONArray()
                    var occursToday = false
                    for (d in 0 until daysArr.length()) {
                        if (daysArr.getInt(d) == todayWeekday) {
                            occursToday = true
                            break
                        }
                    }
                    if (!occursToday && !cObj.has("daysOfWeek")) {
                        occursToday = true
                    }

                    if (occursToday) {
                        val startMin = parseTimeToMinutes(cObj.optString("startTime", "08:00 AM"))
                        val endMin = parseTimeToMinutes(cObj.optString("endTime", "10:00 AM"))
                        todayStartTimes.add(startMin)
                        todayEndTimes.add(endMin)
                    }
                }

                if (todayStartTimes.isEmpty()) {
                    // Free day / No classes today — tick every 15m during day or at midnight
                    if (nowMinutes in 360..1320) return 15
                    val minutesToMidnight = (24 * 60 - nowMinutes).coerceAtLeast(1)
                    return minutesToMidnight.coerceAtMost(60)
                }

                val earliestStart = todayStartTimes.minOrNull() ?: (8 * 60)
                val latestEnd = todayEndTimes.maxOrNull() ?: (17 * 60)

                // If anywhere within active school day window (from 60m before first class to end of last class):
                // Tick every 1 minute for live real-time countdown & status transitions
                if (nowMinutes in (earliestStart - 60)..latestEnd) {
                    return 1
                }

                // If earlier in the morning before window:
                if (nowMinutes < earliestStart - 60) {
                    val minsUntilWindow = (earliestStart - 60) - nowMinutes
                    return minsUntilWindow.coerceIn(1, 5)
                }

                // If after all classes are done for today:
                if (nowMinutes in 360..1320) return 15
                val minutesToMidnight = (24 * 60 - nowMinutes).coerceAtLeast(1)
                return minutesToMidnight.coerceAtMost(60)
            } catch (e: Exception) {
                Log.w(TAG, "computeNextTickMinutes error: $e")
                return 5
            }
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            options: Bundle? = null
        ) {
            val views = RemoteViews(context.packageName, R.layout.school_schedule_widget)

            // Current Device Date & Time — always fresh
            val cal = Calendar.getInstance()
            val todayWeekday = getReminderHubWeekday(cal)
            val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            val dayName = getDayName(todayWeekday)
            val formattedDate = "$dayName, ${getMonthShortName(cal.get(Calendar.MONTH))} ${cal.get(Calendar.DAY_OF_MONTH)}"

            // 1. Setup Click PendingIntent on "View Schedule" and Widget Header
            val scheduleIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.reminderhub.ACTION_OPEN_SCHEDULE"
                putExtra("route", "/school_schedule")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val schedulePendingIntent = PendingIntent.getActivity(
                context,
                101,
                scheduleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_view_schedule, schedulePendingIntent)
            views.setOnClickPendingIntent(R.id.widget_header_bar, schedulePendingIntent)
            views.setOnClickPendingIntent(R.id.widget_highlight_card, schedulePendingIntent)

            // 2. Setup Manual Refresh PendingIntent
            val refreshIntent = Intent(context, SchoolScheduleWidgetProvider::class.java).apply {
                action = ACTION_MANUAL_REFRESH
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                102,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_refresh, refreshPendingIntent)

            // 3. Setup Scrollable ListView Adapter & PendingIntentTemplate
            val serviceIntent = Intent(context, SchoolScheduleWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_classes_list, serviceIntent)
            views.setEmptyView(R.id.widget_classes_list, R.id.widget_empty_layout)

            val itemClickIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.reminderhub.ACTION_OPEN_SCHEDULE"
                putExtra("route", "/school_schedule")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val itemClickPendingIntent = PendingIntent.getActivity(
                context,
                103,
                itemClickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_classes_list, itemClickPendingIntent)

            // 4. Parse Schedule Data from SharedPreferences
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(KEY_TODAY_WIDGET_DATA, null)

            if (rawJson != null) {
                try {
                    val json = JSONObject(rawJson)

                    // Learning mode for today
                    val dayModesObj = json.optJSONObject("dayModes")
                    val dayMode = dayModesObj?.optString(todayWeekday.toString(), "") ?: ""

                    val allClassesArray = json.optJSONArray("allClasses")
                        ?: json.optJSONArray("classes")
                        ?: JSONArray()

                    val todayClasses = mutableListOf<WidgetClassModel>()
                    val allParsedClasses = mutableListOf<WidgetClassModel>()

                    for (i in 0 until allClassesArray.length()) {
                        val cObj = allClassesArray.getJSONObject(i)
                        val daysArr = cObj.optJSONArray("daysOfWeek") ?: JSONArray()
                        val daysList = mutableListOf<Int>()
                        for (d in 0 until daysArr.length()) {
                            daysList.add(daysArr.getInt(d))
                        }

                        val id = cObj.optString("id", "")
                        val subject = cObj.optString("subject", "")
                        val courseCode = cObj.optString("courseCode", "")
                        val teacher = cObj.optString("teacher", "")
                        val room = cObj.optString("room", "")
                        val startTime = cObj.optString("startTime", "08:00 AM")
                        val endTime = cObj.optString("endTime", "10:00 AM")
                        val colorValue = cObj.optLong("colorValue", 0xFF14B8A6)

                        val startMin = parseTimeToMinutes(startTime)
                        val endMin = parseTimeToMinutes(endTime)

                        // Fresh time-based status calculation using CURRENT time
                        val status = when {
                            nowMinutes >= endMin -> ClassState.COMPLETED
                            nowMinutes >= startMin -> ClassState.CURRENT
                            else -> ClassState.UPCOMING
                        }

                        val model = WidgetClassModel(
                            id = id,
                            subject = subject,
                            courseCode = courseCode,
                            teacher = teacher,
                            room = room,
                            startTime = startTime,
                            endTime = endTime,
                            startMinutes = startMin,
                            endMinutes = endMin,
                            status = status,
                            learningMode = dayMode,
                            colorValue = colorValue
                        )

                        allParsedClasses.add(model)

                        if (daysList.contains(todayWeekday) || (!cObj.has("daysOfWeek") && daysList.isEmpty())) {
                            todayClasses.add(model)
                        }
                    }

                    // Sort chronologically
                    todayClasses.sortBy { it.startMinutes }

                    // Set Header texts
                    views.setTextViewText(R.id.widget_header_title, "SCHOOL")
                    views.setTextViewText(
                        R.id.widget_date_subtitle,
                        if (todayClasses.isEmpty()) formattedDate else "$formattedDate • ${todayClasses.size} ${if (todayClasses.size == 1) "Class" else "Classes"}"
                    )

                    // Find Current Class, Next Class, and Completed Classes
                    val currentClass = todayClasses.firstOrNull { it.status == ClassState.CURRENT }
                    val upcomingClasses = todayClasses.filter { it.status == ClassState.UPCOMING }
                    val nextClass = upcomingClasses.firstOrNull()
                    val completedClasses = todayClasses.filter { it.status == ClassState.COMPLETED }
                    val hasNoMoreClasses = currentClass == null && nextClass == null && todayClasses.isNotEmpty()

                    // Section Title (e.g. Other classes Monday (5):)
                    val otherClassesCount = todayClasses.size - (if (currentClass != null) 1 else 0)
                    views.setTextViewText(
                        R.id.widget_section_title,
                        if (todayClasses.isEmpty()) "Today\'s Schedule:" else "Other classes $dayName ($otherClassesCount):"
                    )

                    // Find Next Day Class (for "No more classes today" or "Free Day")
                    var nextDayFirstClass: WidgetClassModel? = null
                    var nextDayName = ""
                    for (offset in 1..7) {
                        val checkWeekday = ((todayWeekday + offset - 1) % 7) + 1
                        val nextDayList = allParsedClasses.filter {
                            // Find matching day of week
                            for (i in 0 until allClassesArray.length()) {
                                val cObj = allClassesArray.getJSONObject(i)
                                if (cObj.optString("id") == it.id) {
                                    val daysArr = cObj.optJSONArray("daysOfWeek") ?: JSONArray()
                                    for (d in 0 until daysArr.length()) {
                                        if (daysArr.getInt(d) == checkWeekday) return@filter true
                                    }
                                }
                            }
                            false
                        }
                        if (nextDayList.isNotEmpty()) {
                            nextDayFirstClass = nextDayList.minByOrNull { it.startMinutes }
                            nextDayName = getDayName(checkWeekday)
                            break
                        }
                    }

                    // 5. Populate Highlighted Card State
                    when {
                        currentClass != null -> {
                            // ACTIVE CURRENT CLASS (Emerald Green Theme)
                            views.setInt(R.id.widget_highlight_card, "setBackgroundResource", R.drawable.widget_current_class_bg)
                            views.setTextViewText(R.id.widget_status_badge, "CURRENT CLASS")
                            views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_current)
                            views.setTextColor(R.id.widget_status_badge, Color.parseColor("#FFFFFF"))

                            // Time Range
                            views.setTextViewText(R.id.widget_class_time, "${currentClass.startTime} – ${currentClass.endTime}")

                            // Countdown: "Ends in Xm"
                            val remainingMins = (currentClass.endMinutes - nowMinutes).coerceAtLeast(0)
                            views.setTextViewText(R.id.widget_countdown, "Ends in ${formatDuration(remainingMins)}")
                            views.setTextColor(R.id.widget_countdown, Color.parseColor("#22C55E"))
                            views.setViewVisibility(R.id.widget_countdown_container, View.VISIBLE)

                            // Subject Name
                            views.setTextViewText(R.id.widget_class_subject, currentClass.subject)

                            // Room & Teacher Details
                            bindDetailsRow(views, currentClass)
                        }
                        nextClass != null -> {
                            // NEXT UPCOMING CLASS (Purple Theme)
                            views.setInt(R.id.widget_highlight_card, "setBackgroundResource", R.drawable.widget_next_class_bg)
                            views.setTextViewText(R.id.widget_status_badge, "NEXT CLASS")
                            views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_next)
                            views.setTextColor(R.id.widget_status_badge, Color.parseColor("#FFFFFF"))

                            // Time Range
                            views.setTextViewText(R.id.widget_class_time, "${nextClass.startTime} – ${nextClass.endTime}")

                            // Countdown: "Starts in Xm"
                            val untilStartMins = (nextClass.startMinutes - nowMinutes).coerceAtLeast(0)
                            views.setTextViewText(R.id.widget_countdown, "Starts in ${formatDuration(untilStartMins)}")
                            views.setTextColor(R.id.widget_countdown, Color.parseColor("#A78BFA"))
                            views.setViewVisibility(R.id.widget_countdown_container, View.VISIBLE)

                            // Subject Name
                            views.setTextViewText(R.id.widget_class_subject, nextClass.subject)

                            // Room & Teacher Details
                            bindDetailsRow(views, nextClass)
                        }
                        hasNoMoreClasses -> {
                            // NO MORE CLASSES TODAY (Slate / Done Theme)
                            views.setInt(R.id.widget_highlight_card, "setBackgroundResource", R.drawable.widget_no_classes_bg)
                            views.setTextViewText(R.id.widget_status_badge, "NO MORE CLASSES")
                            views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_done)
                            views.setTextColor(R.id.widget_status_badge, Color.parseColor("#94A3B8"))

                            views.setTextViewText(R.id.widget_class_time, "All done for $dayName")
                            views.setTextViewText(R.id.widget_countdown, "Done 🎉")
                            views.setTextColor(R.id.widget_countdown, Color.parseColor("#22C55E"))
                            views.setViewVisibility(R.id.widget_countdown_container, View.VISIBLE)

                            views.setTextViewText(R.id.widget_class_subject, "You\'re done for today 🎉")

                            if (nextDayFirstClass != null) {
                                views.setTextViewText(R.id.widget_class_room, "Next: ${nextDayFirstClass.subject} (${nextDayFirstClass.startTime})")
                                views.setTextViewText(R.id.widget_class_teacher, nextDayName)
                                views.setViewVisibility(R.id.widget_class_room_layout, View.VISIBLE)
                                views.setViewVisibility(R.id.widget_class_teacher_layout, View.VISIBLE)
                            } else {
                                views.setTextViewText(R.id.widget_class_room, "Enjoy your free time!")
                                views.setViewVisibility(R.id.widget_class_room_layout, View.VISIBLE)
                                views.setViewVisibility(R.id.widget_class_teacher_layout, View.GONE)
                            }
                        }
                        else -> {
                            // FREE DAY / NO CLASSES TODAY
                            views.setInt(R.id.widget_highlight_card, "setBackgroundResource", R.drawable.widget_no_classes_bg)
                            views.setTextViewText(R.id.widget_status_badge, "FREE DAY")
                            views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_done)
                            views.setTextColor(R.id.widget_status_badge, Color.parseColor("#94A3B8"))

                            views.setTextViewText(R.id.widget_class_time, "No classes scheduled")
                            views.setViewVisibility(R.id.widget_countdown_container, View.GONE)

                            views.setTextViewText(R.id.widget_class_subject, "No classes for $dayName")

                            if (nextDayFirstClass != null) {
                                views.setTextViewText(R.id.widget_class_room, "Next: ${nextDayFirstClass.subject} on $nextDayName")
                                views.setViewVisibility(R.id.widget_class_room_layout, View.VISIBLE)
                            } else {
                                views.setTextViewText(R.id.widget_class_room, "Tap to view full weekly timetable")
                                views.setViewVisibility(R.id.widget_class_room_layout, View.VISIBLE)
                            }
                            views.setViewVisibility(R.id.widget_class_teacher_layout, View.GONE)
                        }
                    }

                    // Empty state toggle
                    if (todayClasses.isEmpty()) {
                        views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_classes_list, View.GONE)
                    } else {
                        views.setViewVisibility(R.id.widget_empty_layout, View.GONE)
                        views.setViewVisibility(R.id.widget_classes_list, View.VISIBLE)
                    }

                } catch (e: Exception) {
                    Log.w(TAG, "updateAppWidget parse error: $e")
                    views.setTextViewText(R.id.widget_header_title, "SCHOOL")
                    views.setTextViewText(R.id.widget_date_subtitle, formattedDate)
                    views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_classes_list, View.GONE)
                }
            } else {
                views.setTextViewText(R.id.widget_header_title, "SCHOOL")
                views.setTextViewText(R.id.widget_date_subtitle, formattedDate)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                views.setViewVisibility(R.id.widget_classes_list, View.GONE)
            }

            // 6. Handle Responsive Sizing (Small / Medium / Large widgets)
            val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 160
            val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 250
            if (minHeight < 140) {
                // Compact / Small Widget mode
                views.setViewVisibility(R.id.widget_section_header_layout, View.GONE)
                views.setViewVisibility(R.id.widget_list_container, View.GONE)
                views.setViewVisibility(R.id.widget_class_teacher_layout, View.GONE)
            } else {
                // Medium / Large Widget mode (Scrollable List Enabled)
                views.setViewVisibility(R.id.widget_section_header_layout, View.VISIBLE)
                views.setViewVisibility(R.id.widget_list_container, View.VISIBLE)
            }
            if (minWidth < 210) {
                views.setViewVisibility(R.id.widget_btn_view_schedule, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_btn_view_schedule, View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun bindDetailsRow(views: RemoteViews, model: WidgetClassModel) {
            val roomText = when {
                model.room.isNotEmpty() -> "Room: ${model.room}"
                model.learningMode.isNotEmpty() -> model.learningMode
                else -> "Face-to-Face"
            }
            views.setTextViewText(R.id.widget_class_room, roomText)
            views.setViewVisibility(R.id.widget_class_room_layout, View.VISIBLE)

            if (model.teacher.isNotEmpty()) {
                views.setTextViewText(R.id.widget_class_teacher, model.teacher)
                views.setViewVisibility(R.id.widget_class_teacher_layout, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_class_teacher_layout, View.GONE)
            }
        }

        fun parseTimeToMinutes(timeStr: String): Int {
            try {
                val clean = timeStr.trim().uppercase()
                val isPm = clean.contains("PM")
                val isAm = clean.contains("AM")
                val numPart = clean.replace("AM", "").replace("PM", "").trim()
                val parts = numPart.split(":")
                var hour = parts[0].trim().toInt()
                val minute = if (parts.size > 1) parts[1].trim().toInt() else 0
                if (isPm && hour < 12) hour += 12
                if (isAm && hour == 12) hour = 0
                return (hour * 60 + minute).coerceIn(0, 24 * 60 - 1)
            } catch (_: Exception) {
                return 8 * 60
            }
        }

        fun formatDuration(minutes: Int): String {
            if (minutes <= 0) return "0m"
            val h = minutes / 60
            val m = minutes % 60
            return when {
                h > 0 && m > 0 -> "${h}h ${m}m"
                h > 0 -> "${h}h"
                else -> "${m}m"
            }
        }

        fun getReminderHubWeekday(cal: Calendar): Int {
            return when (cal.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> 1
                Calendar.TUESDAY -> 2
                Calendar.WEDNESDAY -> 3
                Calendar.THURSDAY -> 4
                Calendar.FRIDAY -> 5
                Calendar.SATURDAY -> 6
                Calendar.SUNDAY -> 7
                else -> 1
            }
        }

        fun getDayName(weekday: Int): String {
            return when (weekday) {
                1 -> "Monday"
                2 -> "Tuesday"
                3 -> "Wednesday"
                4 -> "Thursday"
                5 -> "Friday"
                6 -> "Saturday"
                7 -> "Sunday"
                else -> "Monday"
            }
        }

        fun getMonthShortName(monthIndex: Int): String {
            val months = arrayOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
            return if (monthIndex in 0..11) months[monthIndex] else "Aug"
        }

        /**
         * Schedules the next alarm at an absolute wall-clock time.
         *
         * Uses RTC_WAKEUP so the device wakes from Doze to fire the alarm.
         * Uses setExactAndAllowWhileIdle on Android M+ for precise delivery.
         * Falls back to setAndAllowWhileIdle if exact alarm permission is missing (Android 12+).
         */
        private fun scheduleNextAlarm(context: Context, minutesFromNow: Int) {
            val safeMinutes = minutesFromNow.coerceAtLeast(1)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, SchoolScheduleWidgetProvider::class.java).apply {
                action = ACTION_ALARM_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                301,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val nowMillis = System.currentTimeMillis()
            val nextMinuteAligned = ((nowMillis / 60000L) + safeMinutes) * 60000L
            val triggerAtMillis = if (nextMinuteAligned > nowMillis) nextMinuteAligned else nowMillis + (safeMinutes * 60000L)

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+ — check exact alarm permission
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                    } else {
                        // Permission not granted — use inexact but Doze-aware alarm
                        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            } catch (e: SecurityException) {
                // Exact alarm not permitted — fallback
                try {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                } catch (_: Exception) {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            } catch (_: Exception) {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
            Log.d(TAG, "Scheduled next alarm in ${safeMinutes}m")
        }

        private fun cancelScheduledAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, SchoolScheduleWidgetProvider::class.java).apply {
                action = ACTION_ALARM_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                301,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }
    }
}
