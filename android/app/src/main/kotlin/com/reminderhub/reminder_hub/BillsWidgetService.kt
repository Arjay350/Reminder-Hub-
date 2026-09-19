package com.reminderhub.reminder_hub

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class BillsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return BillsRemoteViewsFactory(applicationContext, intent)
    }
}

class BillsRemoteViewsFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val billItems = mutableListOf<WidgetBillModel>()

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    override fun onDestroy() {
        billItems.clear()
    }

    override fun getCount(): Int = billItems.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= billItems.size) {
            return RemoteViews(context.packageName, R.layout.bills_widget_item)
        }

        val item = billItems[position]
        val views = RemoteViews(context.packageName, R.layout.bills_widget_item)

        // Status Dot
        val statusDotRes = when (item.status) {
            WidgetBillStatus.OVERDUE -> R.drawable.widget_status_dot_overdue
            WidgetBillStatus.PAID -> R.drawable.widget_status_dot_paid
            WidgetBillStatus.UPCOMING -> R.drawable.widget_status_dot_upcoming
            else -> R.drawable.widget_status_dot_unpaid
        }
        views.setInt(R.id.widget_item_status_dot, "setBackgroundResource", statusDotRes)

        // Name
        views.setTextViewText(R.id.widget_item_name, item.name)

        // Details: amount + due
        val details = "₱${String.format("%.2f", item.amount)} • Due ${item.dueDate}"
        views.setTextViewText(R.id.widget_item_details, details)

        // Status Badge
        val (badgeText, badgeRes) = when (item.status) {
            WidgetBillStatus.OVERDUE -> "OVERDUE" to R.drawable.widget_badge_overdue
            WidgetBillStatus.PAID -> "PAID" to R.drawable.widget_badge_paid
            WidgetBillStatus.UPCOMING -> "UPCOMING" to R.drawable.widget_badge_next
            else -> "UNPAID" to R.drawable.widget_badge_unpaid
        }
        views.setTextViewText(R.id.widget_item_status_badge, badgeText)
        views.setInt(R.id.widget_item_status_badge, "setBackgroundResource", badgeRes)

        // Amount
        views.setTextViewText(R.id.widget_item_amount, "₱${String.format("%.2f", item.amount)}")

        // Fill-in Intent for interactivity
        val fillInIntent = Intent().apply {
            putExtra("route", "/bills")
            putExtra("bill_id", item.id)
            putExtra("bill_name", item.name)
        }
        views.setOnClickFillInIntent(R.id.widget_item_root, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    private fun parseIsoDate(iso: String): java.util.Date? {
        return try {
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

    private fun recomputeStatus(bObj: JSONObject): WidgetBillStatus {
        try {
            val rawIso = bObj.optString("rawDueDateIso", "")
            val dueIso = bObj.optString("dueDateIso", rawIso)
            val advanceDays = bObj.optInt("advanceDays", 1)
            val paid = bObj.optBoolean("paid", false)
            val isRecurring = bObj.optBoolean("isRecurring", false)
            val storedStr = bObj.optString("status", "unpaid")
            val isoToParse = if (rawIso.isNotEmpty()) rawIso else dueIso
            if (isoToParse.isEmpty()) return statusFromString(storedStr)

            val dueDate = parseIsoDate(isoToParse) ?: return statusFromString(storedStr)
            val calDue = Calendar.getInstance().apply { time = dueDate }
            val calActivation = (calDue.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -advanceDays) }
            val calToday = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
            val calDueDay = Calendar.getInstance().apply { time = dueDate; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
            val calActDay = Calendar.getInstance().apply { time = calActivation.time; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }

            if (isRecurring) {
                if (calToday.before(calActDay)) {
                    if (storedStr == "paid") return WidgetBillStatus.PAID
                    return WidgetBillStatus.UPCOMING
                }
                if (paid) return WidgetBillStatus.PAID
                if (calToday.after(calDueDay)) return WidgetBillStatus.OVERDUE
                return WidgetBillStatus.UNPAID
            } else {
                if (paid) return WidgetBillStatus.PAID
                if (calToday.after(calDueDay)) return WidgetBillStatus.OVERDUE
                if (calToday.before(calActDay)) return WidgetBillStatus.UPCOMING
                return WidgetBillStatus.UNPAID
            }
        } catch (_: Exception) {
            return statusFromString(bObj.optString("status", "unpaid"))
        }
    }

    private fun statusFromString(s: String): WidgetBillStatus {
        return when (s) {
            "paid" -> WidgetBillStatus.PAID
            "overdue" -> WidgetBillStatus.OVERDUE
            "upcoming" -> WidgetBillStatus.UPCOMING
            else -> WidgetBillStatus.UNPAID
        }
    }

    private fun loadData() {
        billItems.clear()
        val prefs = context.getSharedPreferences(BillsWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        val rawJson = prefs.getString(BillsWidgetProvider.KEY_BILLS_WIDGET_DATA, null) ?: return

        try {
            val json = JSONObject(rawJson)
            val billsArray = json.optJSONArray("bills") ?: JSONArray()

            for (i in 0 until billsArray.length()) {
                val bObj = billsArray.getJSONObject(i)
                val id = bObj.optString("id", "")
                val name = bObj.optString("name", "")
                val amount = bObj.optDouble("amount", 0.0)
                val dueDate = bObj.optString("dueDate", "")
                val repeat = bObj.optString("repeat", "None")

                val status = recomputeStatus(bObj)

                billItems.add(
                    WidgetBillModel(
                        id = id,
                        name = name,
                        amount = amount,
                        dueDate = dueDate,
                        status = status,
                        repeat = repeat
                    )
                )
            }

            // Sort: Overdue first, then Unpaid, then Upcoming, then Paid
            billItems.sortWith(compareBy<WidgetBillModel> { it.status.priority }
                .thenBy { it.dueDate })
        } catch (_: Exception) {
            // Ignore parse errors gracefully
        }
    }
}

enum class WidgetBillStatus(val priority: Int) {
    OVERDUE(0),
    UNPAID(1),
    UPCOMING(2),
    PAID(3),
}

data class WidgetBillModel(
    val id: String,
    val name: String,
    val amount: Double,
    val dueDate: String,
    val status: WidgetBillStatus,
    val repeat: String,
)
