import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/services/hive_service.dart';
import 'package:reminder_hub/services/notification_service.dart';
import 'package:reminder_hub/services/reminder_completion_service.dart';
import 'package:reminder_hub/widgets/reminder_dialog.dart';

import 'helpers/mock_notifications_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final notifications = MockNotificationsHelper();
  late Directory tempDir;

  setUp(() async {
    notifications.setUp();
    NotificationService.instance.resetForTesting();
    await HiveService.instance.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp('reminder_test_');
    await HiveService.instance.init(directoryPath: tempDir.path);
    await HiveService.instance.clearAll();
  });

  tearDown(() async {
    notifications.tearDown();
    NotificationService.instance.resetForTesting();
    await HiveService.instance.clearAll();
    await HiveService.instance.resetForTesting();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Reminder Model & Recurrence Logic', () {
    test('parses valid legacy and 24-hour reminder times exactly', () {
      final conversions = {
        '12:00 AM': const TimeOfDay(hour: 0, minute: 0),
        '12:00 PM': const TimeOfDay(hour: 12, minute: 0),
        '01:00 AM': const TimeOfDay(hour: 1, minute: 0),
        '03:00 PM': const TimeOfDay(hour: 15, minute: 0),
        '11:59 PM': const TimeOfDay(hour: 23, minute: 59),
        '15:30': const TimeOfDay(hour: 15, minute: 30),
      };

      for (final entry in conversions.entries) {
        expect(Reminder.parseTime(entry.key), entry.value);
      }
    });

    testWidgets('monthly reminder editor preserves its day anchor and time', (
      tester,
    ) async {
      final reminder = Reminder(
        id: 'monthly-31',
        title: 'Month-end reminder',
        category: 'Personal',
        description: '',
        date: DateTime(2025, 2, 28),
        time: '15:00',
        repeat: 'Monthly',
        reminderBefore: 'At time',
        priority: 'Medium',
        notes: '',
        completed: false,
        targetDayOfMonth: 31,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReminderDialog(reminder: reminder)),
        ),
      );
      await tester.pump();
      expect(reminder.targetDayOfMonth, 31);
      expect(reminder.dueDateTime, DateTime(2025, 2, 28, 15));
      expect(
        reminder.calculateNextOccurrence(DateTime(2025, 2, 28)),
        DateTime(2025, 3, 31, 15),
      );
      expect(find.text('Update Reminder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('rejects malformed or ambiguous reminder times without fallback', () {
      for (final value in ['3:00', '24:00', '12:60 PM', 'noon']) {
        expect(Reminder.parseTime(value), isNull);
        final reminder = Reminder(
          id: 'invalid-time',
          title: 'Invalid time',
          category: 'Personal',
          description: '',
          date: DateTime(2026, 1, 1),
          time: value,
          repeat: 'None',
          reminderBefore: 'At time',
          priority: 'Low',
          notes: '',
          completed: false,
        );
        expect(() => reminder.dueDateTime, throwsFormatException);
      }
    });

    test(
      'One-time reminder dueDateTime parsing and calculateNextOccurrence',
      () {
        final reminder = Reminder(
          id: 'rem-1',
          title: 'Doctor Appointment',
          category: 'Personal',
          description: 'Annual checkup',
          date: DateTime(2026, 10, 25),
          time: '02:30 PM',
          repeat: 'None',
          reminderBefore: '15 minutes',
          priority: 'High',
          notes: 'Bring insurance card',
          completed: false,
        );

        expect(reminder.isRecurring, isFalse);
        expect(reminder.dueDateTime, DateTime(2026, 10, 25, 14, 30));
        expect(
          reminder.calculateNextOccurrence(DateTime(2026, 10, 25)),
          DateTime(2026, 10, 25),
        );
      },
    );

    test('Daily recurrence advances properly', () {
      final daily = Reminder(
        id: 'rem-daily',
        title: 'Take vitamins',
        category: 'Personal',
        description: '',
        date: DateTime(2026, 10, 20),
        time: '08:00 AM',
        repeat: 'Daily',
        reminderBefore: 'At time',
        priority: 'Medium',
        notes: '',
        completed: false,
      );

      final next = daily.calculateNextOccurrence(DateTime(2026, 10, 20, 10, 0));
      expect(next, DateTime(2026, 10, 21, 8, 0));
    });

    test('Weekly recurrence advances by 7 days', () {
      final weekly = Reminder(
        id: 'rem-weekly',
        title: 'Weekly Team Sync',
        category: 'Work',
        description: '',
        date: DateTime(2026, 10, 21),
        time: '10:00 AM',
        repeat: 'Weekly',
        reminderBefore: '10 minutes',
        priority: 'Medium',
        notes: '',
        completed: false,
      );

      final next = weekly.calculateNextOccurrence(
        DateTime(2026, 10, 21, 11, 0),
      );
      expect(next, DateTime(2026, 10, 28, 10, 0));
    });

    test(
      'Monthly recurrence preserves anchor day through month boundaries (Jan 31 -> Feb 28 -> Mar 31)',
      () {
        final monthly = Reminder(
          id: 'rem-monthly-31',
          title: 'End of month review',
          category: 'Work',
          description: '',
          date: DateTime(2026, 1, 31),
          time: '05:00 PM',
          repeat: 'Monthly',
          reminderBefore: '1 hour',
          priority: 'High',
          notes: '',
          completed: false,
          targetDayOfMonth: 31,
        );

        // Advance from Jan 31 to Feb
        final febOccurrence = monthly.calculateNextOccurrence(
          DateTime(2026, 1, 31, 18, 0),
        );
        expect(febOccurrence.year, 2026);
        expect(febOccurrence.month, 2);
        expect(
          febOccurrence.day,
          28,
        ); // Clamped to max day of Feb in non-leap year

        // Carry anchorDay forward to next occurrence in March
        final updatedForFeb = monthly.copyWith(
          date: febOccurrence,
          targetDayOfMonth: 31,
        );
        final marOccurrence = updatedForFeb.calculateNextOccurrence(
          DateTime(2026, 2, 28, 18, 0),
        );
        expect(marOccurrence.year, 2026);
        expect(marOccurrence.month, 3);
        expect(marOccurrence.day, 31); // Preserved 31st!
      },
    );

    test('Yearly recurrence advances to next year', () {
      final yearly = Reminder(
        id: 'rem-yearly',
        title: 'Car Registration',
        category: 'Bills',
        description: '',
        date: DateTime(2026, 5, 15),
        time: '09:00 AM',
        repeat: 'Yearly',
        reminderBefore: '1 week',
        priority: 'High',
        notes: '',
        completed: false,
      );

      final next = yearly.calculateNextOccurrence(DateTime(2026, 5, 15, 10, 0));
      expect(next, DateTime(2027, 5, 15, 9, 0));
    });
  });

  group('Reminder Completion & History Service Workflow', () {
    test(
      'Completing a one-time reminder marks it complete and creates history record',
      () async {
        final hive = HiveService.instance;
        final reminder = Reminder(
          id: 'rem-one-time-1',
          title: 'Submit Expense Report',
          category: 'Work',
          description: 'Q3 travel expenses',
          date: DateTime(2026, 10, 20),
          time: '03:00 PM',
          repeat: 'None',
          reminderBefore: '30 minutes',
          priority: 'High',
          notes: 'Keep receipts',
          completed: false,
        );

        await hive.saveReminder(reminder);

        final success = await ReminderCompletionService.instance
            .completeReminder(reminder);
        expect(success, isTrue);

        // Verify reminder state in Hive
        final storedReminders = hive.getReminders();
        final updated = storedReminders.firstWhere((r) => r.id == reminder.id);
        expect(updated.completed, isTrue);

        // Verify history record created
        final history = hive.getReminderHistory();
        expect(history.length, 1);
        final record = history.first;
        expect(record.reminderId, reminder.id);
        expect(record.title, 'Submit Expense Report');
        expect(record.category, 'Work');
        expect(record.originalDueDate, reminder.dueDateTime);
        expect(record.repeat, 'None');
      },
    );

    test(
      'Completing recurring reminder advances date, keeps completed false, logs history',
      () async {
        final hive = HiveService.instance;
        final daily = Reminder(
          id: 'rem-daily-sync',
          title: 'Daily Standup',
          category: 'Work',
          description: '',
          date: DateTime(2026, 10, 20),
          time: '09:30 AM',
          repeat: 'Daily',
          reminderBefore: '5 minutes',
          priority: 'Medium',
          notes: '',
          completed: false,
        );

        await hive.saveReminder(daily);

        final success = await ReminderCompletionService.instance
            .completeReminder(daily);
        expect(success, isTrue);

        // Verify reminder was updated with advanced date and completed = false
        final stored = hive.getReminders().firstWhere((r) => r.id == daily.id);
        expect(stored.completed, isFalse);
        expect(stored.date.isAfter(DateTime(2026, 10, 20, 9, 0)), isTrue);

        // Verify history has exactly 1 entry
        final history = hive.getReminderHistory();
        expect(history.length, 1);
        expect(history.first.reminderId, daily.id);
        expect(history.first.title, 'Daily Standup');
      },
    );

    test(
      'Rapid repeated completion invocations are debounced and do not create duplicate history',
      () async {
        final hive = HiveService.instance;
        final reminder = Reminder(
          id: 'rem-debounce-test',
          title: 'Water Plants',
          category: 'Household',
          description: '',
          date: DateTime(2026, 10, 20),
          time: '04:00 PM',
          repeat: 'None',
          reminderBefore: 'At time',
          priority: 'Low',
          notes: '',
          completed: false,
        );
        await hive.saveReminder(reminder);

        // Trigger multiple concurrent completions
        final results = await Future.wait([
          ReminderCompletionService.instance.completeReminder(reminder),
          ReminderCompletionService.instance.completeReminder(reminder),
          ReminderCompletionService.instance.completeReminder(reminder),
        ]);

        // Exactly one should succeed
        expect(results.where((res) => res).length, 1);

        // History must have exactly 1 record
        final history = hive.getReminderHistory();
        expect(history.length, 1);
      },
    );

    test('Uncompleting a one-time reminder reverts status', () async {
      final hive = HiveService.instance;
      final reminder = Reminder(
        id: 'rem-uncomplete-test',
        title: 'Feed Cat',
        category: 'Personal',
        description: '',
        date: DateTime(2026, 10, 20),
        time: '06:00 PM',
        repeat: 'None',
        reminderBefore: 'At time',
        priority: 'High',
        notes: '',
        completed: true,
      );
      await hive.saveReminder(reminder);

      final success = await ReminderCompletionService.instance
          .uncompleteReminder(reminder);
      expect(success, isTrue);

      final stored = hive.getReminders().firstWhere((r) => r.id == reminder.id);
      expect(stored.completed, isFalse);
    });
  });

  group('Dashboard Query & Filtering Correctness', () {
    test(
      'Completed one-time reminders do NOT appear in active overdue or upcoming lists',
      () async {
        final hive = HiveService.instance;
        final now = DateTime(2026, 10, 20, 14, 0);

        final overdueCompleted = Reminder(
          id: 'rem-od-done',
          title: 'Past Overdue Reminder (Done)',
          category: 'General',
          description: '',
          date: DateTime(2026, 10, 19),
          time: '10:00 AM',
          repeat: 'None',
          reminderBefore: 'None',
          priority: 'Medium',
          notes: '',
          completed: true,
        );

        final overduePending = Reminder(
          id: 'rem-od-pending',
          title: 'Past Overdue Reminder (Pending)',
          category: 'General',
          description: '',
          date: DateTime(2026, 10, 19),
          time: '10:00 AM',
          repeat: 'None',
          reminderBefore: 'None',
          priority: 'Medium',
          notes: '',
          completed: false,
        );

        final todayEarlierPending = Reminder(
          id: 'rem-today-earlier',
          title: 'Today Earlier Reminder (Pending)',
          category: 'General',
          description: '',
          date: DateTime(2026, 10, 20),
          time: '09:00 AM',
          repeat: 'None',
          reminderBefore: 'None',
          priority: 'Medium',
          notes: '',
          completed: false,
        );

        final futurePending = Reminder(
          id: 'rem-future',
          title: 'Future Reminder (Pending)',
          category: 'General',
          description: '',
          date: DateTime(2026, 10, 20),
          time: '06:00 PM',
          repeat: 'None',
          reminderBefore: 'None',
          priority: 'Medium',
          notes: '',
          completed: false,
        );

        await hive.saveReminder(overdueCompleted);
        await hive.saveReminder(overduePending);
        await hive.saveReminder(todayEarlierPending);
        await hive.saveReminder(futurePending);

        final all = hive.getReminders();

        // Overdue query: must exclude completed, and include all pending past dueDateTime
        final overdue = all
            .where((r) => !r.completed && r.dueDateTime.isBefore(now))
            .toList();
        expect(
          overdue.map((r) => r.id),
          containsAll(['rem-od-pending', 'rem-today-earlier']),
        );
        expect(overdue.map((r) => r.id), isNot(contains('rem-od-done')));
        expect(overdue.map((r) => r.id), isNot(contains('rem-future')));

        // Future / Up next query: must exclude completed, and include only dueDateTime after now
        final future = all
            .where((r) => !r.completed && r.dueDateTime.isAfter(now))
            .toList();
        expect(future.length, 1);
        expect(future.first.id, 'rem-future');
      },
    );
  });

  group('Reminder Completion History Isolation & Deletion', () {
    test(
      'Deleting a history record does NOT delete or alter active reminders',
      () async {
        final hive = HiveService.instance;
        final active = Reminder(
          id: 'rem-recurring-active',
          title: 'Weekly Groceries',
          category: 'Household',
          description: '',
          date: DateTime(2026, 10, 24),
          time: '10:00 AM',
          repeat: 'Weekly',
          reminderBefore: 'At time',
          priority: 'Medium',
          notes: '',
          completed: false,
        );
        await hive.saveReminder(active);

        final record = ReminderHistoryRecord(
          id: 'hist-rec-1',
          reminderId: active.id,
          title: active.title,
          category: active.category,
          originalDueDate: DateTime(2026, 10, 17, 10, 0),
          completedAt: DateTime(2026, 10, 17, 11, 0),
          repeat: 'Weekly',
        );
        await hive.saveReminderHistoryRecord(record);

        expect(hive.getReminderHistory().length, 1);
        expect(hive.getReminders().length, 1);

        // Delete the history record
        await hive.deleteReminderHistoryRecord(record.id);

        expect(hive.getReminderHistory(), isEmpty);
        // Active reminder remains completely intact!
        final activeStored = hive.getReminders();
        expect(activeStored.length, 1);
        expect(activeStored.first.id, active.id);
        expect(activeStored.first.completed, isFalse);
      },
    );

    test(
      'Clear all history removes all completion records without deleting active reminders',
      () async {
        final hive = HiveService.instance;
        await hive.saveReminder(
          Reminder(
            id: 'rem-active-1',
            title: 'Active Reminder',
            category: 'Personal',
            description: '',
            date: DateTime(2026, 10, 25),
            time: '09:00 AM',
            repeat: 'None',
            reminderBefore: 'None',
            priority: 'Low',
            notes: '',
            completed: false,
          ),
        );

        for (int i = 0; i < 5; i++) {
          await hive.saveReminderHistoryRecord(
            ReminderHistoryRecord(
              id: 'hist-$i',
              reminderId: 'rem-active-1',
              title: 'Active Reminder occurrence $i',
              category: 'Personal',
              originalDueDate: DateTime(2026, 10, i + 1),
              completedAt: DateTime(2026, 10, i + 1, 12, 0),
            ),
          );
        }

        expect(hive.getReminderHistory().length, 5);
        expect(hive.getReminders().length, 1);

        await hive.clearReminderHistory();

        expect(hive.getReminderHistory(), isEmpty);
        expect(hive.getReminders().length, 1);
      },
    );
  });
}
