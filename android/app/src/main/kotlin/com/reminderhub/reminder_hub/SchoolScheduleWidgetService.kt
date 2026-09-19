package com.reminderhub.reminder_hub

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class SchoolScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return SchoolScheduleRemoteViewsFactory(applicationContext, intent)
    }
}

class SchoolScheduleRemoteViewsFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val classItems = mutableListOf<WidgetClassModel>()
    private var todayWeekday = 1

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    override fun onDestroy() {
        classItems.clear()
    }

    override fun getCount(): Int = classItems.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= classItems.size) {
            return RemoteViews(context.packageName, R.layout.school_schedule_widget_item)
        }

        val item = classItems[position]
        val views = RemoteViews(context.packageName, R.layout.school_schedule_widget_item)

        // Time Range
        views.setTextViewText(R.id.widget_item_time, "${item.startTime} – ${item.endTime}")
        // Subject
        views.setTextViewText(R.id.widget_item_subject, item.subject)

        // Details formatting (Room, Teacher, Mode)
        val detailsParts = mutableListOf<String>()
        if (item.courseCode.isNotEmpty()) {
            detailsParts.add(item.courseCode)
        }
        if (item.room.isNotEmpty()) {
            detailsParts.add("Room: ${item.room}")
        } else if (item.learningMode.isNotEmpty()) {
            detailsParts.add(item.learningMode)
        }
        if (item.teacher.isNotEmpty()) {
            detailsParts.add(item.teacher)
        }
        val detailsText = if (detailsParts.isNotEmpty()) detailsParts.joinToString(" • ") else "Class Session"
        views.setTextViewText(R.id.widget_item_details, detailsText)

        // Learning Mode / Status Badge
        val modeShort = when {
            item.learningMode.contains("Async", ignoreCase = true) -> "ASYNC"
            item.learningMode.contains("Online", ignoreCase = true) || item.learningMode.contains("Sync", ignoreCase = true) -> "ONLINE"
            item.room.isNotEmpty() -> "F2F"
            else -> "CLASS"
        }
        views.setTextViewText(R.id.widget_item_badge, modeShort)

        // Configure icons & styles based on status
        when (item.status) {
            ClassState.COMPLETED -> {
                views.setViewVisibility(R.id.widget_item_check_icon, View.VISIBLE)
                views.setViewVisibility(R.id.widget_item_clock_icon, View.GONE)
                views.setViewVisibility(R.id.widget_item_dot_icon, View.GONE)

                views.setTextColor(R.id.widget_item_time, Color.parseColor("#22C55E")) // Green
                views.setTextColor(R.id.widget_item_subject, Color.parseColor("#94A3B8")) // Muted
                views.setInt(R.id.widget_item_badge, "setBackgroundResource", R.drawable.widget_badge_done)
                views.setTextColor(R.id.widget_item_badge, Color.parseColor("#94A3B8"))
            }
            ClassState.CURRENT -> {
                views.setViewVisibility(R.id.widget_item_check_icon, View.GONE)
                views.setViewVisibility(R.id.widget_item_clock_icon, View.VISIBLE)
                views.setViewVisibility(R.id.widget_item_dot_icon, View.GONE)

                views.setTextColor(R.id.widget_item_time, Color.parseColor("#22C55E")) // Green
                views.setTextColor(R.id.widget_item_subject, Color.parseColor("#FFFFFF"))
                views.setInt(R.id.widget_item_badge, "setBackgroundResource", R.drawable.widget_badge_current)
                views.setTextColor(R.id.widget_item_badge, Color.parseColor("#FFFFFF"))
            }
            ClassState.UPCOMING -> {
                views.setViewVisibility(R.id.widget_item_check_icon, View.GONE)
                views.setViewVisibility(R.id.widget_item_clock_icon, View.GONE)
                views.setViewVisibility(R.id.widget_item_dot_icon, View.VISIBLE)

                views.setTextColor(R.id.widget_item_time, Color.parseColor("#A78BFA")) // Purple
                views.setTextColor(R.id.widget_item_subject, Color.parseColor("#FFFFFF"))
                views.setInt(R.id.widget_item_badge, "setBackgroundResource", R.drawable.widget_badge_next)
                views.setTextColor(R.id.widget_item_badge, Color.parseColor("#C4B5FD"))
            }
        }

        // Fill-in Intent for interactivity (opening MainActivity with school_schedule route)
        val fillInIntent = Intent().apply {
            putExtra("route", "/school_schedule")
            putExtra("class_id", item.id)
            putExtra("subject", item.subject)
        }
        views.setOnClickFillInIntent(R.id.widget_item_root, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    private fun loadData() {
        classItems.clear()
        val prefs = context.getSharedPreferences(SchoolScheduleWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        val rawJson = prefs.getString(SchoolScheduleWidgetProvider.KEY_TODAY_WIDGET_DATA, null) ?: return

        try {
            val json = JSONObject(rawJson)
            val cal = Calendar.getInstance()
            todayWeekday = SchoolScheduleWidgetProvider.getReminderHubWeekday(cal)
            val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

            // Read Day Class Modes
            val dayModesObj = json.optJSONObject("dayModes")
            val dayMode = dayModesObj?.optString(todayWeekday.toString(), "") ?: ""

            val classesArray = json.optJSONArray("allClasses")
                ?: json.optJSONArray("classes")
                ?: JSONArray()

            val todayList = mutableListOf<WidgetClassModel>()

            for (i in 0 until classesArray.length()) {
                val cObj = classesArray.getJSONObject(i)
                val daysArr = cObj.optJSONArray("daysOfWeek") ?: JSONArray()
                var occursToday = false
                for (d in 0 until daysArr.length()) {
                    if (daysArr.getInt(d) == todayWeekday) {
                        occursToday = true
                        break
                    }
                }

                // If daysOfWeek wasn't present or empty, check if this object is directly in today's classes
                if (!occursToday && !cObj.has("daysOfWeek")) {
                    occursToday = true
                }

                if (occursToday) {
                    val id = cObj.optString("id", "")
                    val subject = cObj.optString("subject", "")
                    val courseCode = cObj.optString("courseCode", "")
                    val teacher = cObj.optString("teacher", "")
                    val room = cObj.optString("room", "")
                    val startTime = cObj.optString("startTime", "08:00 AM")
                    val endTime = cObj.optString("endTime", "10:00 AM")
                    val colorValue = cObj.optLong("colorValue", 0xFF14B8A6)

                    val startMin = SchoolScheduleWidgetProvider.parseTimeToMinutes(startTime)
                    val endMin = SchoolScheduleWidgetProvider.parseTimeToMinutes(endTime)

                    val status = when {
                        nowMinutes >= endMin -> ClassState.COMPLETED
                        nowMinutes >= startMin -> ClassState.CURRENT
                        else -> ClassState.UPCOMING
                    }

                    todayList.add(
                        WidgetClassModel(
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
                    )
                }
            }

            // Sort classes chronologically by start time
            todayList.sortBy { it.startMinutes }
            classItems.addAll(todayList)
        } catch (_: Exception) {
            // Ignore parse errors gracefully
        }
    }
}

enum class ClassState {
    COMPLETED,
    CURRENT,
    UPCOMING
}

data class WidgetClassModel(
    val id: String,
    val subject: String,
    val courseCode: String,
    val teacher: String,
    val room: String,
    val startTime: String,
    val endTime: String,
    val startMinutes: Int,
    val endMinutes: Int,
    val status: ClassState,
    val learningMode: String,
    val colorValue: Long
)
