package com.reminderhub.reminder_hub

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val WIDGET_CHANNEL = "com.reminderhub.reminder_hub/school_widget"
    private val BILLS_WIDGET_CHANNEL = "com.reminderhub.reminder_hub/bills_widget"
    private var pendingLaunchRoute: String? = null
    private var widgetChannelReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleLaunchIntent(intent)
    }

    private fun handleLaunchIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")
        val action = intent?.action
        if (route != null || action == "com.reminderhub.ACTION_OPEN_SCHEDULE" || action == "com.reminderhub.ACTION_OPEN_BILLS") {
            val targetRoute = route ?: when (action) {
                "com.reminderhub.ACTION_OPEN_BILLS" -> "/bills"
                else -> "/school_schedule"
            }
            pendingLaunchRoute = targetRoute
            if (widgetChannelReady) {
                flutterEngine?.let { engine ->
                    MethodChannel(engine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
                        .invokeMethod("onNavigateTo", mapOf("route" to targetRoute))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannelReady = true

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchRoute" -> {
                    val route = pendingLaunchRoute
                    pendingLaunchRoute = null
                    result.success(route)
                }
                "updateWidget" -> {
                    val arguments = call.arguments as? Map<String, Any>
                    SchoolScheduleWidgetProvider.updateAllWidgets(applicationContext, arguments)
                    result.success(true)
                }
                "updateTimetableWidget" -> {
                    val arguments = call.arguments as? Map<String, Any>
                    WeeklyTimetableWidgetProvider.updateAllWidgets(applicationContext, arguments)
                    result.success(true)
                }
                "updateAllWidgets" -> {
                    val arguments = call.arguments as? Map<String, Any>
                    val todayPayload = arguments?.get("today") as? Map<String, Any>
                    val timetablePayload = arguments?.get("timetable") as? Map<String, Any>
                    SchoolScheduleWidgetProvider.updateAllWidgets(applicationContext, todayPayload)
                    WeeklyTimetableWidgetProvider.updateAllWidgets(applicationContext, timetablePayload)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Bills Widget Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BILLS_WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateAllWidgets" -> {
                    val arguments = call.arguments as? Map<String, Any>
                    BillsWidgetProvider.updateAllWidgets(applicationContext, arguments)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
