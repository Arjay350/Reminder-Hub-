import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_models.dart';
import 'hive_service.dart';
import 'widget_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Notification Channel Constants
  // ---------------------------------------------------------------------------
  static const String channelIdReminders = 'reminder_hub_scheduled';
  static const String channelNameReminders = 'Scheduled Reminders';
  static const String channelDescReminders =
      'Offline scheduled notifications for reminders and tasks';

  static const String channelIdClasses = 'reminder_hub_classes';
  static const String channelNameClasses = 'Class Timetable';
  static const String channelDescClasses =
      'Offline school class and lecture alerts';

  static const String channelIdBills = 'reminder_hub_bills';
  static const String channelNameBills = 'Bills & Payments';
  static const String channelDescBills = 'Offline bill due date alerts';

  static const String channelIdGeneral = 'reminder_hub_general';
  static const String channelNameGeneral = 'General Alerts';
  static const String channelDescGeneral =
      'General offline app alerts, resets, and gas notifications';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      // 1. Initialize local timezone
      tz.initializeTimeZones();
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        final String timeZoneName = tzInfo.identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint(
          'NotificationService: Local timezone configured -> $timeZoneName',
        );
      } catch (e) {
        debugPrint('Could not get local timezone, fallback used: $e');
        try {
          tz.setLocalLocation(tz.getLocation('UTC'));
        } catch (_) {}
      }

      // 2. Initialize notification settings
      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_notification',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      // 3. Create high-priority Android notification channels
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelIdReminders,
              channelNameReminders,
              description: channelDescReminders,
              importance: Importance.max,
              enableVibration: true,
              enableLights: true,
            ),
          );

          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelIdClasses,
              channelNameClasses,
              description: channelDescClasses,
              importance: Importance.max,
              enableVibration: true,
              enableLights: true,
            ),
          );

          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelIdBills,
              channelNameBills,
              description: channelDescBills,
              importance: Importance.high,
              enableVibration: true,
            ),
          );

          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelIdGeneral,
              channelNameGeneral,
              description: channelDescGeneral,
              importance: Importance.high,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Permissions & Exact Alarm Capabilities
  // ---------------------------------------------------------------------------

  /// Checks if POST_NOTIFICATIONS permission is granted on Android 13+ (API 33+).
  Future<bool> isNotificationPermissionGranted() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          final enabled = await androidPlugin.areNotificationsEnabled();
          if (enabled != null) return enabled;
        }
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('isNotificationPermissionGranted error: $e');
      return false;
    }
  }

  /// Request POST_NOTIFICATIONS permission on Android 13+.
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          if (granted != null) return granted;
        }
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('requestNotificationPermission error: $e');
      return false;
    }
  }

  /// Checks whether exact alarm scheduling is allowed by Android (API 31+ / Android 12+).
  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.scheduleExactAlarm.status;
        return status.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('canScheduleExactAlarms error: $e');
      return true;
    }
  }

  /// Requests or navigates to Exact Alarms & Reminders permission settings.
  Future<bool> requestExactAlarmsPermission() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.scheduleExactAlarm.request();
        if (status.isGranted) return true;
        await openExactAlarmSettings();
        final recheck = await Permission.scheduleExactAlarm.status;
        return recheck.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('requestExactAlarmsPermission error: $e');
      return false;
    }
  }

  /// Directly opens Android "Alarms & Reminders" system settings page for the app.
  Future<void> openExactAlarmSettings() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          final reqResult = await androidPlugin.requestExactAlarmsPermission();
          if (reqResult == false) {
            await openAppSettings();
          }
        } else {
          await openAppSettings();
        }
      }
    } catch (e) {
      debugPrint('openExactAlarmSettings error: $e');
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }

  /// Opens the App Notification Settings page.
  Future<void> openAppNotificationSettings() async {
    if (kIsWeb) return;
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('openAppNotificationSettings error: $e');
    }
  }

  /// Standard combined permission request called on app startup.
  Future<bool> requestPermissions() async {
    final notificationsGranted = await requestNotificationPermission();
    final exactAlarmsGranted = await canScheduleExactAlarms();

    // Exact alarms use a separate Android settings permission. Do not open
    // settings automatically during startup; the reminder editor exposes the
    // existing "Enable" action when this capability is unavailable.
    debugPrint(
      'Notification permissions: notifications=$notificationsGranted, '
      'exactAlarms=$exactAlarmsGranted',
    );
    return notificationsGranted && exactAlarmsGranted;
  }

  // ---------------------------------------------------------------------------
  // Deterministic Notification ID Management
  // ---------------------------------------------------------------------------

  /// Derives a stable, positive 31-bit int from a string key so notifications
  /// can be cancelled or updated deterministically across restarts without colliding.
  int _idFromUuid(String uuid) {
    return uuid.hashCode & 0x7FFFFFFF;
  }

  // ---------------------------------------------------------------------------
  // Core Scheduling Engine (Offline / Local)
  // ---------------------------------------------------------------------------

  /// Immediately shows a local notification.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String channelId = channelIdReminders,
    String channelName = channelNameReminders,
    String channelDescription = channelDescReminders,
    String? payload,
  }) async {
    await init();
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      color: const Color(0xFF6366F1),
      enableVibration: true,
      playSound: true,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('showNotification error: $e');
    }
  }

  /// Schedules an offline notification using AlarmManager with automatic
  /// exact / inexact fallback and timezone support.
  Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String channelId = channelIdReminders,
    String channelName = channelNameReminders,
    String channelDescription = channelDescReminders,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    await init();
    if (kIsWeb) return false;

    final notificationsGranted = await isNotificationPermissionGranted();
    if (!notificationsGranted) {
      debugPrint('Cannot schedule notification id=$id: notifications disabled');
      return false;
    }

    final now = DateTime.now();
    // For one-time notifications, never schedule in the past
    if (matchDateTimeComponents == null && scheduledDate.isBefore(now)) {
      debugPrint(
        'Skipping past one-time notification id=$id at $scheduledDate',
      );
      return false;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      color: const Color(0xFF6366F1),
      enableVibration: true,
      playSound: true,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    final exactAlarmsGranted = await canScheduleExactAlarms();
    final preferredScheduleMode = exactAlarmsGranted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint(
      'Scheduling notification id=$id using '
      '${exactAlarmsGranted ? "exact" : "inexact"} alarm mode',
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        notificationDetails,
        androidScheduleMode: preferredScheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint(
        'Preferred alarm scheduling failed for id=$id ($e). Retrying inexact...',
      );
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchDateTimeComponents,
          payload: payload,
        );
        return true;
      } catch (fallbackError) {
        debugPrint('Failed to schedule notification id=$id: $fallbackError');
        return false;
      }
    }
  }

  /// Cancels an active or scheduled notification by its deterministic integer ID.
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('cancelNotification error: $e');
    }
  }

  /// Records a successful financial log and schedules one reminder for the
  /// following hour of inactivity.
  /// Cancels all scheduled local notifications.
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll error: $e');
    }
  }

  /// Cancels all possible notification IDs associated with an item's UUID string.
  Future<void> cancelNotificationForId(String uuid) async {
    if (kIsWeb) return;
    // Cancel primary notification
    await cancelNotification(_idFromUuid(uuid));
    // Cancel renewal notification (if AI account)
    await cancelNotification(_idFromUuid('${uuid}_renewal'));
    // Cancel any 7-day recurring class sub-alarms
    for (int day = 1; day <= 7; day++) {
      await cancelNotification(_idFromUuid('${uuid}_$day'));
    }
  }

  // ---------------------------------------------------------------------------
  // Feature-Specific Scheduling
  // ---------------------------------------------------------------------------

  /// Schedules a local notification for a [Reminder].
  /// Accurately handles:
  /// - One-time ("None")
  /// - Daily ("Daily" -> `DateTimeComponents.time`)
  /// - Weekly ("Weekly" -> `DateTimeComponents.dayOfWeekAndTime`)
  /// - Monthly ("Monthly" -> `DateTimeComponents.dayOfMonthAndTime` with safe day clamping)
  /// - Yearly ("Yearly" -> `DateTimeComponents.dateAndTime` with leap-year clamping)
  /// - Custom reminder offsets (e.g. "15 minutes", "45 minutes", "1 hour", "Custom: 30 minutes")
  Future<void> scheduleReminderNotification(Reminder reminder) async {
    if (kIsWeb || reminder.completed) return;

    final id = _idFromUuid(reminder.id);
    await cancelNotification(id);

    final parts = reminder.time.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = parts.length > 1
        ? (int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        : 0;

    final eventDateTime = DateTime(
      reminder.date.year,
      reminder.date.month,
      reminder.date.day,
      hour,
      minute,
    );

    final notifyAt = _applyReminderBefore(
      eventDateTime,
      reminder.reminderBefore,
    );
    final now = DateTime.now();

    DateTime scheduledDate = notifyAt;
    DateTimeComponents? matchComponents;

    final repeatMode = reminder.repeat.trim().toLowerCase();

    switch (repeatMode) {
      case 'daily':
        matchComponents = DateTimeComponents.time;
        var nextOccurrence = notifyAt;
        while (nextOccurrence.isBefore(now)) {
          nextOccurrence = nextOccurrence.add(const Duration(days: 1));
        }
        scheduledDate = nextOccurrence;
        break;

      case 'weekly':
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
        var nextOccurrence = notifyAt;
        while (nextOccurrence.isBefore(now)) {
          nextOccurrence = nextOccurrence.add(const Duration(days: 7));
        }
        scheduledDate = nextOccurrence;
        break;

      case 'monthly':
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
        scheduledDate = _calculateNextMonthlyDate(
          notifyAt,
          notifyAt.day,
          notifyAt.hour,
          notifyAt.minute,
          notifyAt.second,
        );
        break;

      case 'yearly':
        matchComponents = DateTimeComponents.dateAndTime;
        scheduledDate = _calculateNextYearlyDate(
          notifyAt,
          notifyAt.month,
          notifyAt.day,
          notifyAt.hour,
          notifyAt.minute,
          notifyAt.second,
        );
        break;

      default:
        // One-time reminder ('None' or single occurrence)
        matchComponents = null;
        scheduledDate = notifyAt;
        if (scheduledDate.isBefore(now)) {
          debugPrint(
            'One-time reminder "${reminder.title}" date is in the past ($scheduledDate). Skipping.',
          );
          return;
        }
        break;
    }

    final reminderLabel =
        reminder.reminderBefore == 'At time' ||
            reminder.reminderBefore == 'At start'
        ? 'due now'
        : '${reminder.reminderBefore} before';

    await scheduleNotification(
      id: id,
      title: reminder.title,
      body: reminder.description.isNotEmpty
          ? reminder.description
          : '${reminder.category} reminder — $reminderLabel',
      scheduledDate: scheduledDate,
      channelId: channelIdReminders,
      channelName: channelNameReminders,
      channelDescription: channelDescReminders,
      matchDateTimeComponents: matchComponents,
      payload: 'reminder:${reminder.id}',
    );
  }

  /// Schedules recurring school class timetable notifications.
  /// Generates dedicated alarms for each weekday in `schoolClass.daysOfWeek` (1..7).
  Future<void> scheduleSchoolClassNotification(SchoolClass schoolClass) async {
    if (kIsWeb || schoolClass.daysOfWeek.isEmpty) return;

    final now = DateTime.now();

    // Cancel all 7 potential day alarms for this class first
    for (int day = 1; day <= 7; day++) {
      await cancelNotification(_idFromUuid('${schoolClass.id}_$day'));
    }

    for (final dayOfWeek in schoolClass.daysOfWeek) {
      if (dayOfWeek < 1 || dayOfWeek > 7) continue;

      // Calculate days until the next occurrence of dayOfWeek (1=Mon ... 7=Sun)
      int daysUntil = (dayOfWeek - now.weekday) % 7;
      if (daysUntil < 0) daysUntil += 7;

      DateTime targetDate = DateTime(now.year, now.month, now.day + daysUntil);
      DateTime classStartTime = _parseTimeOnDate(
        targetDate,
        schoolClass.startTime,
      );
      DateTime notifyAt = _applyReminderBefore(
        classStartTime,
        schoolClass.reminderBefore,
      );

      // If today's reminder time has already passed, schedule for next week
      if (notifyAt.isBefore(now)) {
        targetDate = targetDate.add(const Duration(days: 7));
        classStartTime = _parseTimeOnDate(targetDate, schoolClass.startTime);
        notifyAt = _applyReminderBefore(
          classStartTime,
          schoolClass.reminderBefore,
        );
      }

      final id = _idFromUuid('${schoolClass.id}_$dayOfWeek');

      await scheduleNotification(
        id: id,
        title: 'Class Starting: ${schoolClass.subject}',
        body:
            '${schoolClass.room.isNotEmpty ? "Room ${schoolClass.room} • " : ""}${schoolClass.timeRange}${schoolClass.teacher.isNotEmpty ? " • ${schoolClass.teacher}" : ""}',
        scheduledDate: notifyAt,
        channelId: channelIdClasses,
        channelName: channelNameClasses,
        channelDescription: channelDescClasses,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'school_class:${schoolClass.id}',
      );
    }
  }

  /// Schedules a one-time bill due date notification for the current occurrence.
  ///
  /// Because the recurring-bill lifecycle advances [bill.dueDate] after each
  /// payment and immediately re-calls this method for the new occurrence, we
  /// always use a **one-time** alarm (no [DateTimeComponents] repeat).
  /// This guarantees exactly one active notification per bill at any time and
  /// prevents duplicate or stale recurring alarms.
  Future<void> scheduleBillNotification(Bill bill) async {
    if (kIsWeb) return;

    final id = _idFromUuid(bill.id);
    // Cancel any existing notification for this bill before scheduling the new one.
    await cancelNotification(id);

    // Paid bills do not need a due-date alarm. Recurring bills become unpaid
    // again at their configured reminder window through Bill.getDisplayStatus.
    if (bill.paid) return;

    final now = DateTime.now();
    DateTime notifyAt = _applyBillReminderSchedule(
      bill.dueDate,
      bill.reminderSchedule,
    );

    if (notifyAt.isBefore(now)) {
      // The preferred reminder time has already passed. Check if the bill is
      // already overdue — if so, skip (nothing useful to schedule). If the bill
      // is still unpaid and not yet overdue, fire an immediate heads-up instead.
      final dueDay = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      if (today.isAfter(dueDay)) {
        debugPrint(
          'Bill "${bill.name}" is overdue and reminder time ($notifyAt) is in the past. Skipping.',
        );
        return;
      }
      // Bill is still upcoming — fire in ~1 minute as an immediate heads-up.
      debugPrint(
        'Bill "${bill.name}" reminder time ($notifyAt) is past; scheduling immediate heads-up.',
      );
      notifyAt = now.add(const Duration(minutes: 1));
    }

    await scheduleNotification(
      id: id,
      title: 'Bill Due: ${bill.name}',
      body:
          'Amount: ${bill.amount.toStringAsFixed(2)} — Due on ${_formatDate(bill.dueDate)}',
      scheduledDate: notifyAt,
      channelId: channelIdBills,
      channelName: channelNameBills,
      channelDescription: channelDescBills,
      // null = one-time; no DateTimeComponents repeat needed because the
      // recurring-bill lifecycle advances dueDate and reschedules explicitly.
      matchDateTimeComponents: null,
      payload: 'bill:${bill.id}',
    );
  }

  /// Schedules exact reset time notification for AI Account & renewal reminder.
  Future<void> scheduleAIResetNotification(AIAccount account) async {
    if (kIsWeb) return;

    final id = _idFromUuid(account.id);
    final renewalId = _idFromUuid('${account.id}_renewal');
    await cancelNotification(id);
    await cancelNotification(renewalId);

    final now = DateTime.now();

    // 1. Reset Date & Time Notification
    final sched = account.resetSchedule.trim().toLowerCase();
    DateTime resetDateTime = _parseTimeOnDate(
      account.resetDate,
      account.resetTime,
    );

    DateTime targetDateTime = resetDateTime;
    DateTimeComponents? resetComponents;

    if (sched == 'daily') {
      while (!targetDateTime.isAfter(now)) {
        targetDateTime = targetDateTime.add(const Duration(days: 1));
      }
      resetComponents = DateTimeComponents.time;
    } else if (sched == 'weekly') {
      while (!targetDateTime.isAfter(now)) {
        targetDateTime = targetDateTime.add(const Duration(days: 7));
      }
      resetComponents = DateTimeComponents.dayOfWeekAndTime;
    } else if (sched == 'monthly') {
      targetDateTime = _calculateNextMonthlyDate(
        targetDateTime,
        targetDateTime.day,
        targetDateTime.hour,
        targetDateTime.minute,
      );
      resetComponents = DateTimeComponents.dayOfMonthAndTime;
    } else {
      // Default / 'none' / 'exact date/time' / 'once':
      // One-time notification for the exact date and time specified by the user.
      // Do not repeat daily, and do not roll forward if the date has passed.
      resetComponents = null;
      if (targetDateTime.isBefore(now)) {
        debugPrint(
          'scheduleAIResetNotification: exact reset date/time is in the past ($targetDateTime). Notification skipped.',
        );
        return;
      }
    }

    if (targetDateTime.isAfter(now)) {
      await scheduleNotification(
        id: id,
        title: 'AI Usage Reset: ${account.service}',
        body:
            '${account.accountName} usage limit reset at ${account.resetTime}',
        scheduledDate: targetDateTime,
        channelId: channelIdGeneral,
        channelName: channelNameGeneral,
        channelDescription: channelDescGeneral,
        matchDateTimeComponents: resetComponents,
        payload: 'ai_reset:${account.id}',
      );
      debugPrint(
        'scheduleAIResetNotification: id=$id sched="$sched" '
        'components=$resetComponents at $targetDateTime',
      );
    } else {
      debugPrint(
        'scheduleAIResetNotification: skipped (in the past) '
        'id=$id sched="$sched" at $targetDateTime',
      );
    }

    // 2. Renewal Notification (Paid Plans)
    if (!account.isFreePlan) {
      DateTime notifyRenewalAt = DateTime(
        account.renewalDate.year,
        account.renewalDate.month,
        account.renewalDate.day - 1,
        9,
        0,
      );
      if (notifyRenewalAt.isBefore(now)) {
        notifyRenewalAt = _calculateNextMonthlyDate(
          notifyRenewalAt,
          notifyRenewalAt.day,
          9,
          0,
        );
      }

      if (notifyRenewalAt.isAfter(now)) {
        await scheduleNotification(
          id: renewalId,
          title: 'AI Subscription Renewal: ${account.service}',
          body:
              '${account.accountName} (${account.plan}) renews on ${_formatDate(account.renewalDate)}',
          scheduledDate: notifyRenewalAt,
          channelId: channelIdBills,
          channelName: channelNameBills,
          channelDescription: channelDescBills,
          payload: 'ai_renewal:${account.id}',
        );
      }
    }
  }

  int _birthdayNotificationId(String birthdayId, String suffix) {
    return _idFromUuid('${birthdayId}_$suffix');
  }

  Future<void> cancelBirthdayNotifications(Birthday birthday) async {
    if (kIsWeb) return;
    await cancelNotification(_birthdayNotificationId(birthday.id, '7DAY'));
    await cancelNotification(_birthdayNotificationId(birthday.id, '1DAY'));
    await cancelNotification(_birthdayNotificationId(birthday.id, 'DAYOF'));
  }

  Future<void> scheduleBirthdayNotifications(Birthday birthday) async {
    if (kIsWeb) return;

    await cancelBirthdayNotifications(birthday);

    final nextBirthday = birthday.nextBirthdayDate;
    final birthdayDate = DateTime(
      nextBirthday.year,
      nextBirthday.month,
      nextBirthday.day,
    );
    final now = DateTime.now();

    if (birthday.remind7DaysBefore) {
      final target = birthdayDate.subtract(const Duration(days: 7));
      final scheduled = _parseTimeOnDate(target, birthday.reminderTime);
      if (scheduled.isAfter(now)) {
        final age = birthday.turningAgeFor(scheduled);
        await scheduleNotification(
          id: _birthdayNotificationId(birthday.id, '7DAY'),
          title: '🎁 ${birthday.name}\'s birthday is in 1 week!',
          body: age == null
              ? 'Time to plan a gift.'
              : 'Turning $age — Time to plan a gift.',
          scheduledDate: scheduled,
          channelId: channelIdGeneral,
          channelName: channelNameGeneral,
          channelDescription: channelDescGeneral,
          payload: 'birthday:${birthday.id}:7day',
        );
      }
    }

    if (birthday.remind1DayBefore) {
      final target = birthdayDate.subtract(const Duration(days: 1));
      final scheduled = _parseTimeOnDate(target, birthday.reminderTime);
      if (scheduled.isAfter(now)) {
        await scheduleNotification(
          id: _birthdayNotificationId(birthday.id, '1DAY'),
          title: '🎉 ${birthday.name}\'s birthday is tomorrow!',
          body: 'Get ready to celebrate!',
          scheduledDate: scheduled,
          channelId: channelIdGeneral,
          channelName: channelNameGeneral,
          channelDescription: channelDescGeneral,
          payload: 'birthday:${birthday.id}:1day',
        );
      }
    }

    if (birthday.remindOnDay) {
      final scheduled = _parseTimeOnDate(birthdayDate, birthday.reminderTime);
      if (scheduled.isAfter(now)) {
        await scheduleNotification(
          id: _birthdayNotificationId(birthday.id, 'DAYOF'),
          title: '🎂 Today is ${birthday.name}\'s birthday!',
          body: "Don't forget to greet them!",
          scheduledDate: scheduled,
          channelId: channelIdGeneral,
          channelName: channelNameGeneral,
          channelDescription: channelDescGeneral,
          payload: 'birthday:${birthday.id}:day',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Reschedule All (Reboot & App Startup Synchronization)
  // ---------------------------------------------------------------------------

  /// Idempotently re-reads all local data from Hive and reconciles all active
  /// alarms and notifications. Called upon app startup, resume, and after device reboot.
  Future<void> rescheduleAll() async {
    if (kIsWeb) return;

    final hive = HiveService.instance;
    await hive.ensureInitialized();

    final notificationsGranted = await isNotificationPermissionGranted();
    if (!notificationsGranted) {
      debugPrint(
        'NotificationService.rescheduleAll: Notification permission not granted, skipping alarm reconciliation',
      );
      return;
    }

    try {
      await cancelAll();
    } catch (e) {
      debugPrint('NotificationService.rescheduleAll: cancelAll error: $e');
    }

    // 1. Reminders
    try {
      for (final reminder in hive.getReminders()) {
        try {
          await scheduleReminderNotification(reminder);
        } catch (itemErr) {
          debugPrint(
            'NotificationService.rescheduleAll: Error scheduling reminder ${reminder.id}: $itemErr',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'NotificationService.rescheduleAll: Reminders reconciliation error: $e',
      );
    }

    // 2. School Class Timetable
    try {
      for (final schoolClass in hive.getSchoolClasses()) {
        try {
          await scheduleSchoolClassNotification(schoolClass);
        } catch (itemErr) {
          debugPrint(
            'NotificationService.rescheduleAll: Error scheduling school class ${schoolClass.id}: $itemErr',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'NotificationService.rescheduleAll: School classes reconciliation error: $e',
      );
    }

    // 3. Bills
    try {
      for (final bill in hive.getBills()) {
        try {
          await scheduleBillNotification(bill);
        } catch (itemErr) {
          debugPrint(
            'NotificationService.rescheduleAll: Error scheduling bill ${bill.id}: $itemErr',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'NotificationService.rescheduleAll: Bills reconciliation error: $e',
      );
    }

    // 4. AI Account Resets & Renewals
    try {
      for (final account in hive.getAIAccounts()) {
        try {
          await scheduleAIResetNotification(account);
        } catch (itemErr) {
          debugPrint(
            'NotificationService.rescheduleAll: Error scheduling AI account ${account.id}: $itemErr',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'NotificationService.rescheduleAll: AI accounts reconciliation error: $e',
      );
    }

    // 5. Birthdays
    try {
      for (final birthday in hive.getBirthdays()) {
        try {
          await scheduleBirthdayNotifications(birthday);
        } catch (itemErr) {
          debugPrint(
            'NotificationService.rescheduleAll: Error scheduling birthday ${birthday.id}: $itemErr',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'NotificationService.rescheduleAll: Birthdays reconciliation error: $e',
      );
    }

    // Update widgets
    try {
      await WidgetService.instance.updateSchoolWidget();
    } catch (e) {
      debugPrint('WidgetService.updateSchoolWidget error: $e');
    }
    try {
      await WidgetService.instance.updateBillsWidget();
    } catch (e) {
      debugPrint('WidgetService.updateBillsWidget error: $e');
    }

    debugPrint(
      'NotificationService: All offline reminders reconciled successfully.',
    );
  }

  // ---------------------------------------------------------------------------
  // Helper & Calculation Utilities
  // ---------------------------------------------------------------------------

  /// Parses reminder offset strings like "At time", "At start", "5 minutes", "10 minutes",
  /// "15 minutes", "30 minutes", "45 minutes", "1 hour", "2 hours", "1 day", "2 days", "1 week",
  /// or custom strings like "Custom: 45 minutes" or "45 mins".
  DateTime _applyReminderBefore(DateTime eventTime, String reminderBefore) {
    final clean = reminderBefore.trim().toLowerCase();
    if (clean.isEmpty ||
        clean == 'at time' ||
        clean == 'at start' ||
        clean == 'at class time' ||
        clean == 'on time' ||
        clean == 'none') {
      return eventTime;
    }

    if (clean == '5 minutes' ||
        clean == '5 minutes before' ||
        clean == '5 mins') {
      return eventTime.subtract(const Duration(minutes: 5));
    }
    if (clean == '10 minutes' ||
        clean == '10 minutes before' ||
        clean == '10 mins') {
      return eventTime.subtract(const Duration(minutes: 10));
    }
    if (clean == '15 minutes' ||
        clean == '15 minutes before' ||
        clean == '15 mins') {
      return eventTime.subtract(const Duration(minutes: 15));
    }
    if (clean == '30 minutes' ||
        clean == '30 minutes before' ||
        clean == '30 mins') {
      return eventTime.subtract(const Duration(minutes: 30));
    }
    if (clean == '45 minutes' ||
        clean == '45 minutes before' ||
        clean == '45 mins') {
      return eventTime.subtract(const Duration(minutes: 45));
    }
    if (clean == '1 hour' || clean == '1 hour before' || clean == '1 hr') {
      return eventTime.subtract(const Duration(hours: 1));
    }
    if (clean == '2 hours' || clean == '2 hours before' || clean == '2 hrs') {
      return eventTime.subtract(const Duration(hours: 2));
    }
    if (clean == '1 day' || clean == '1 day before') {
      return eventTime.subtract(const Duration(days: 1));
    }
    if (clean == '2 days' || clean == '2 days before') {
      return eventTime.subtract(const Duration(days: 2));
    }
    if (clean == '3 days' || clean == '3 days before') {
      return eventTime.subtract(const Duration(days: 3));
    }
    if (clean == '1 week' || clean == '1 week before' || clean == '7 days') {
      return eventTime.subtract(const Duration(days: 7));
    }

    // Generic regex extractor: e.g. "45 minutes", "2 hours", "3 days"
    final numMatch = RegExp(
      r'(\d+)\s*(minute|min|hour|hr|day|week)',
    ).firstMatch(clean);
    if (numMatch != null) {
      final val = int.tryParse(numMatch.group(1) ?? '') ?? 0;
      final unit = numMatch.group(2) ?? '';
      if (unit.startsWith('min')) {
        return eventTime.subtract(Duration(minutes: val));
      } else if (unit.startsWith('h') || unit.startsWith('hr')) {
        return eventTime.subtract(Duration(hours: val));
      } else if (unit.startsWith('d')) {
        return eventTime.subtract(Duration(days: val));
      } else if (unit.startsWith('w')) {
        return eventTime.subtract(Duration(days: val * 7));
      }
    }

    // If just a number e.g. "45"
    final justNum = int.tryParse(clean.replaceAll(RegExp(r'[^0-9]'), ''));
    if (justNum != null && justNum > 0) {
      return eventTime.subtract(Duration(minutes: justNum));
    }

    return eventTime;
  }

  /// Parses bill reminder schedule and returns notification DateTime at 9:00 AM.
  DateTime _applyBillReminderSchedule(DateTime dueDate, String schedule) {
    final clean = schedule.trim().toLowerCase();
    DateTime base = dueDate;
    if (clean == 'same day' ||
        clean == 'at due date' ||
        clean == 'at time' ||
        clean == 'none') {
      base = dueDate;
    } else if (clean == '1 day before' || clean == '1 day') {
      base = dueDate.subtract(const Duration(days: 1));
    } else if (clean == '2 days before' || clean == '2 days') {
      base = dueDate.subtract(const Duration(days: 2));
    } else if (clean == '3 days before' || clean == '3 days') {
      base = dueDate.subtract(const Duration(days: 3));
    } else if (clean == '5 days before' || clean == '5 days') {
      base = dueDate.subtract(const Duration(days: 5));
    } else if (clean == '1 week before' ||
        clean == '1 week' ||
        clean == '7 days') {
      base = dueDate.subtract(const Duration(days: 7));
    } else {
      final match = RegExp(r'(\d+)\s*day').firstMatch(clean);
      if (match != null) {
        final days = int.tryParse(match.group(1) ?? '1') ?? 1;
        base = dueDate.subtract(Duration(days: days));
      } else {
        base = dueDate.subtract(const Duration(days: 1));
      }
    }
    return DateTime(base.year, base.month, base.day, 9, 0);
  }

  /// Safely creates a DateTime, clamping day to the last valid day of that month.
  /// E.g. Feb 31 -> Feb 28 (or Feb 29 in leap years), Apr 31 -> Apr 30.
  DateTime _clampedDate(
    int year,
    int month,
    int targetDay,
    int hour,
    int minute, [
    int second = 0,
  ]) {
    final maxDay = DateTime(year, month + 1, 0).day;
    final validDay = targetDay.clamp(1, maxDay);
    return DateTime(year, month, validDay, hour, minute, second);
  }

  /// Finds the next future monthly occurrence for target day and time.
  DateTime _calculateNextMonthlyDate(
    DateTime baseDate,
    int targetDay,
    int hour,
    int minute, [
    int second = 0,
  ]) {
    final now = DateTime.now();
    var year = baseDate.year;
    var month = baseDate.month;

    var candidate = _clampedDate(year, month, targetDay, hour, minute, second);
    while (!candidate.isAfter(now)) {
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
      candidate = _clampedDate(year, month, targetDay, hour, minute, second);
    }
    return candidate;
  }

  /// Finds the next future yearly occurrence for target month/day and time.
  DateTime _calculateNextYearlyDate(
    DateTime baseDate,
    int targetMonth,
    int targetDay,
    int hour,
    int minute, [
    int second = 0,
  ]) {
    final now = DateTime.now();
    var year = baseDate.year;

    var candidate = _clampedDate(
      year,
      targetMonth,
      targetDay,
      hour,
      minute,
      second,
    );
    while (!candidate.isAfter(now)) {
      year++;
      candidate = _clampedDate(
        year,
        targetMonth,
        targetDay,
        hour,
        minute,
        second,
      );
    }
    return candidate;
  }

  /// Parses a time string (e.g. "08:00 AM", "10:00 PM", "14:30") and combines it with a base date.
  DateTime _parseTimeOnDate(DateTime date, String timeStr) {
    int hour = 9;
    int minute = 0;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final numPart = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = numPart.split(':');
      hour = int.parse(parts[0]);
      if (parts.length > 1) {
        minute = int.parse(parts[1]);
      }
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
    } catch (_) {
      hour = 9;
      minute = 0;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Helper to format date strings for notification bodies.
  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
