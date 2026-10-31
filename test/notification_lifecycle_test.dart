import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/services/hive_service.dart';
import 'package:reminder_hub/services/notification_service.dart';

import 'helpers/mock_notifications_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final helper = MockNotificationsHelper();
  final notificationService = NotificationService.instance;
  final hive = HiveService.instance;
  late Directory tempDir;

  setUp(() async {
    helper.setUp();
    notificationService.resetForTesting();
    await hive.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp('notification_test_');
    await hive.init(directoryPath: tempDir.path);
  });

  tearDown(() async {
    helper.tearDown();
    notificationService.resetForTesting();
    await hive.resetForTesting();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('NotificationService Initialization & Failure Handling', () {
    test(
      'Successful init configures timezone, channels and marks initialized',
      () async {
        expect(notificationService.isInitialized, isFalse);
        await notificationService.init();
        expect(notificationService.isInitialized, isTrue);
        expect(helper.timezoneLog, isNotEmpty);
        expect(
          helper.notificationsLog.any((c) => c.method == 'initialize'),
          isTrue,
        );
      },
    );

    test(
      'Concurrent initialization calls share one plugin initialization',
      () async {
        await Future.wait([
          notificationService.init(),
          notificationService.init(),
          notificationService.init(),
        ]);

        expect(notificationService.isInitialized, isTrue);
        expect(
          helper.notificationsLog.where((call) => call.method == 'initialize'),
          hasLength(1),
        );
      },
    );

    test(
      'Plugin initialization failure throws and preserves isInitialized == false',
      () async {
        helper.shouldFailInitialize = true;
        expect(
          () async => await notificationService.init(),
          throwsA(isA<StateError>()),
        );
        expect(notificationService.isInitialized, isFalse);
      },
    );

    test(
      'Timezone lookup failure is visible and prevents notification initialization',
      () async {
        helper.shouldThrowOnTimezone = true;

        await expectLater(
          notificationService.init(),
          throwsA(isA<PlatformException>()),
        );

        expect(notificationService.isInitialized, isFalse);
        expect(
          helper.notificationsLog.any((call) => call.method == 'initialize'),
          isFalse,
        );
      },
    );

    test(
      'scheduleNotification safely fails when initialization cannot succeed',
      () async {
        helper.shouldFailInitialize = true;
        final success = await notificationService.scheduleNotification(
          id: 1234,
          title: 'Test Title',
          body: 'Test Body',
          scheduledDate: DateTime.now().add(const Duration(hours: 2)),
        );
        expect(success, isFalse);
      },
    );

    test(
      'startup reconciliation initializes before querying notification APIs',
      () async {
        expect(notificationService.isInitialized, isFalse);
        await hive.saveReminder(
          Reminder(
            id: 'init-order',
            title: 'Initialization order',
            category: 'Personal',
            description: '',
            date: DateTime.now().add(const Duration(days: 3)),
            time: '09:00 AM',
            repeat: 'None',
            reminderBefore: 'At time',
            priority: 'Medium',
            notes: '',
            completed: false,
          ),
        );

        await notificationService.rescheduleAll();

        expect(notificationService.isInitialized, isTrue);
        final initializeIndex = helper.notificationsLog.indexWhere(
          (call) => call.method == 'initialize',
        );
        final scheduleIndex = helper.notificationsLog.indexWhere(
          (call) => call.method == 'zonedSchedule',
        );
        expect(initializeIndex, greaterThanOrEqualTo(0));
        expect(scheduleIndex, greaterThan(initializeIndex));
      },
    );
  });

  group('Notification Lifecycle & CRUD Verification', () {
    test(
      'Scheduling a reminder registers a deterministic notification',
      () async {
        await notificationService.init();
        final reminder = Reminder(
          id: 'rem-lifecycle-1',
          title: 'Team Meeting',
          category: 'Work',
          description: 'Sync on sprint backlog',
          date: DateTime.now().add(const Duration(days: 2)),
          time: '10:00 AM',
          repeat: 'None',
          reminderBefore: '15 minutes',
          priority: 'High',
          notes: '',
          completed: false,
        );

        await notificationService.scheduleReminderNotification(reminder);

        final scheduled = helper.scheduledNotifications.values;
        expect(scheduled, isNotEmpty);
        final entry = scheduled.first;
        expect(entry['title'], 'Team Meeting');
        expect(entry['body'], contains('Sync on sprint backlog'));
        expect(entry['payload'], 'reminder:${reminder.id}');
      },
    );

    test(
      'Editing a reminder replaces previous notification without duplicates',
      () async {
        await notificationService.init();
        final initialReminder = Reminder(
          id: 'rem-edit-1',
          title: 'Initial Title',
          category: 'Work',
          description: 'Original note',
          date: DateTime.now().add(const Duration(days: 3)),
          time: '02:00 PM',
          repeat: 'None',
          reminderBefore: 'At time',
          priority: 'Low',
          notes: '',
          completed: false,
        );
        await notificationService.scheduleReminderNotification(initialReminder);
        expect(helper.scheduledNotifications.length, 1);
        expect(
          helper.scheduledNotifications.values.first['title'],
          'Initial Title',
        );

        // Edit reminder
        final editedReminder = initialReminder.copyWith(
          title: 'Updated Meeting Title',
          description: 'New agenda items',
        );
        await notificationService.scheduleReminderNotification(editedReminder);

        // Still exactly one notification with the updated content
        expect(helper.scheduledNotifications.length, 1);
        expect(
          helper.scheduledNotifications.values.first['title'],
          'Updated Meeting Title',
        );
        expect(
          helper.scheduledNotifications.values.first['body'],
          contains('New agenda items'),
        );
      },
    );

    test('Deleting a reminder cancels its scheduled notification', () async {
      await notificationService.init();
      final reminder = Reminder(
        id: 'rem-delete-1',
        title: 'To Be Deleted',
        category: 'Personal',
        description: '',
        date: DateTime.now().add(const Duration(days: 1)),
        time: '09:00 AM',
        repeat: 'None',
        reminderBefore: 'None',
        priority: 'Medium',
        notes: '',
        completed: false,
      );
      await notificationService.scheduleReminderNotification(reminder);
      expect(helper.scheduledNotifications.length, 1);

      await notificationService.cancelNotificationForId(reminder.id);
      expect(helper.scheduledNotifications, isEmpty);
    });

    test(
      'Repeated startup reconciliation (rescheduleAll) is idempotent and creates NO duplicates',
      () async {
        await notificationService.init();

        // Seed Hive with reminders
        for (int i = 1; i <= 3; i++) {
          await hive.saveReminder(
            Reminder(
              id: 'recon-$i',
              title: 'Task $i',
              category: 'Personal',
              description: '',
              date: DateTime.now().add(Duration(days: i + 1)),
              time: '11:00 AM',
              repeat: 'None',
              reminderBefore: 'None',
              priority: 'Medium',
              notes: '',
              completed: false,
            ),
          );
        }

        // Reconcile 1st time
        await notificationService.rescheduleAll();
        expect(helper.scheduledNotifications.length, 3);

        // Reconcile 2nd time
        await notificationService.rescheduleAll();
        expect(
          helper.scheduledNotifications.length,
          3,
          reason: 'Duplicate alarms must not be created',
        );

        // Reconcile 3rd time
        await notificationService.rescheduleAll();
        expect(helper.scheduledNotifications.length, 3);
      },
    );
  });
}
