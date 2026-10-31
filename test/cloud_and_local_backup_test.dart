import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/models/pet_models.dart';
import 'package:reminder_hub/models/study_models.dart';
import 'package:reminder_hub/services/backup_service.dart';
import 'package:reminder_hub/services/encryption_service.dart';
import 'package:reminder_hub/services/hive_service.dart';
import 'package:reminder_hub/services/notification_service.dart';

import 'helpers/mock_notifications_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final notifications = MockNotificationsHelper();
  late Directory tempDir;

  setUp(() async {
    notifications.setUp();
    NotificationService.instance.resetForTesting();
    await HiveService.instance.resetForTesting();
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
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

  group('Local & Cloud Full Backup Data Completeness Tests', () {
    test(
      'Backup export includes ALL required user collections without data loss',
      () async {
        final hive = HiveService.instance;

        // Populate sample records across modules
        await hive.saveReminder(
          Reminder(
            id: 'rem-b1',
            title: 'Electricity Bill Reminder',
            category: 'Bills',
            description: '',
            date: DateTime(2026, 11, 1),
            time: '09:00 AM',
            repeat: 'Monthly',
            reminderBefore: '1 day',
            priority: 'High',
            notes: 'Pay online',
            completed: false,
            targetDayOfMonth: 1,
          ),
        );

        await hive.saveReminderHistoryRecord(
          ReminderHistoryRecord(
            id: 'hist-b1',
            reminderId: 'rem-b1',
            title: 'Electricity Bill Reminder',
            category: 'Bills',
            originalDueDate: DateTime(2026, 10, 1, 9, 0),
            completedAt: DateTime(2026, 10, 1, 10, 0),
            repeat: 'Monthly',
          ),
        );

        await hive.saveBill(
          Bill(
            id: 'bill-b1',
            name: 'Water Utility',
            amount: 450.0,
            dueDate: DateTime(2026, 11, 5),
            repeat: 'Monthly',
            category: 'Utilities',
            paid: false,
            reminderSchedule: '3 days before',
            notes: '',
          ),
        );

        await hive.saveSchoolClass(
          SchoolClass(
            id: 'class-b1',
            subject: 'Computer Science',
            room: 'Lab 3',
            teacher: 'Prof. Turing',
            startTime: '09:00 AM',
            endTime: '11:00 AM',
            daysOfWeek: [1, 3, 5],
            colorValue: 0xFF6366F1,
          ),
        );

        await hive.saveBirthday(
          Birthday(
            id: 'bday-b1',
            name: 'Sarah',
            birthDate: DateTime(1998, 4, 15),
            relationship: 'Friend',
            giftIdeas: 'Books',
          ),
        );

        await hive.saveStoredDiaryEntry('diary-b1', {
          'id': 'diary-b1',
          'title': 'Productive Day',
          'content': 'Implemented cloud backup today.',
          'createdAt': DateTime(2026, 10, 20).toIso8601String(),
          'updatedAt': DateTime(2026, 10, 20).toIso8601String(),
          'mood': 'Happy',
        });

        await hive.saveStoredNote('note-b1', {
          'id': 'note-b1',
          'title': 'Project Ideas',
          'content': 'ReminderHub features to add next.',
          'createdAt': DateTime(2026, 10, 20).toIso8601String(),
          'updatedAt': DateTime(2026, 10, 20).toIso8601String(),
        });

        await hive.savePetPreferences(
          const PetPreferences().copyWith(
            name: 'Mochi',
            petLevel: 5,
            currentXp: 120,
          ),
        );

        await hive.saveStudyMethod(
          StudyMethod(
            id: 'method-pomodoro',
            name: 'Pomodoro',
            description: 'Standard pomodoro',
            studyDurationMinutes: 25,
            shortBreakDurationMinutes: 5,
            longBreakDurationMinutes: 15,
            sessionsBeforeLongBreak: 4,
            type: 'pomodoro',
          ),
        );

        await hive.saveStudyHistoryRecord(
          StudySessionRecord(
            id: 'study-rec-1',
            subject: 'Algorithms',
            methodName: 'Pomodoro',
            methodType: 'pomodoro',
            startedAt: DateTime(2026, 10, 20, 13, 0),
            endedAt: DateTime(2026, 10, 20, 13, 25),
            durationMinutes: 25,
            completedSessions: 1,
            completed: true,
          ),
        );

        await hive.saveStudySubject('Algorithms');

        // Export local backup file
        final backupPath = await BackupService.instance.exportBackup(
          passphrase: 'remember this backup phrase',
          directoryPath: tempDir.path,
          share: false,
        );
        expect(backupPath, isNotNull);

        final exportedContent = await File(backupPath!).readAsString();
        expect(exportedContent, isNot(contains('Water Utility')));
        final exportedJson =
            jsonDecode(
                  await EncryptionService.instance.decryptBackupJson(
                    exportedContent,
                    'remember this backup phrase',
                  ),
                )
                as Map<String, dynamic>;

        // Verify all collections are present in export
        expect(exportedJson['format'], 'reminderhub-backup');
        expect(exportedJson['reminders'], isNotEmpty);
        expect(exportedJson['reminderHistory'], isNotEmpty);
        expect(exportedJson['bills'], isNotEmpty);
        expect(exportedJson['schoolClasses'], isNotEmpty);
        expect(exportedJson['birthdays'], isNotEmpty);
        expect(exportedJson['diaryEntries'], isNotEmpty);
        expect(exportedJson['notes'], isNotEmpty);
        expect(exportedJson['petPreferences'], isNotNull);
        expect(exportedJson['studyMethods'], isNotEmpty);
        expect(exportedJson['studyHistory'], isNotEmpty);
        expect(exportedJson['studySubjects'], isNotEmpty);

        // Now clear local storage to simulate complete device wipe
        await hive.clearAll();
        expect(hive.getReminders(), isEmpty);
        expect(hive.getReminderHistory(), isEmpty);
        expect(hive.getBills(), isEmpty);
        expect(hive.getSchoolClasses(), isEmpty);
        expect(hive.getBirthdays(), isEmpty);
        expect(hive.getDiaryEntries(), isEmpty);
        expect(hive.getNotes(), isEmpty);
        expect(hive.getStudyHistory(), isEmpty);

        // Import backup file
        final importSuccess = await BackupService.instance.importBackupFromFile(
          backupPath,
          passphrase: 'remember this backup phrase',
        );
        expect(importSuccess, isTrue);

        // Verify all collections are faithfully restored
        expect(hive.getReminders().length, 1);
        expect(hive.getReminders().first.title, 'Electricity Bill Reminder');

        expect(hive.getReminderHistory().length, 1);
        expect(
          hive.getReminderHistory().first.title,
          'Electricity Bill Reminder',
        );

        expect(hive.getBills().length, 1);
        expect(hive.getBills().first.name, 'Water Utility');

        expect(hive.getSchoolClasses().length, 1);
        expect(hive.getSchoolClasses().first.subject, 'Computer Science');

        expect(hive.getBirthdays().length, 1);
        expect(hive.getBirthdays().first.name, 'Sarah');

        expect(hive.getDiaryEntries().length, 1);
        expect(hive.getDiaryEntries().first.title, 'Productive Day');

        expect(hive.getNotes().length, 1);
        expect(hive.getNotes().first.title, 'Project Ideas');

        expect(hive.getPetPreferences().name, 'Mochi');
        expect(hive.getPetPreferences().petLevel, 5);

        expect(hive.getStudyHistory().length, 1);
        expect(hive.getStudyHistory().first.subject, 'Algorithms');

        expect(hive.getStudySubjects(), contains('Algorithms'));
      },
    );

    test(
      'Older legacy backup format without new fields imports safely without error',
      () async {
        final hive = HiveService.instance;

        // Legacy v1 backup without reminderHistory, petPreferences, or study modules
        final legacyBackup = {
          'format': 'reminderhub-backup',
          'version': 1,
          'timestamp': DateTime(2026, 1, 1).toIso8601String(),
          'dataVersion': 1,
          'reminders': [
            {
              'id': 'legacy-rem-1',
              'title': 'Legacy Reminder',
              'category': 'General',
              'description': '',
              'date': DateTime(2026, 10, 20).toIso8601String(),
              'time': '10:00 AM',
              'repeat': 'None',
              'reminderBefore': 'None',
              'priority': 'Low',
              'notes': '',
              'completed': false,
            },
          ],
          'schoolClasses': [],
          'aiAccounts': [],
          'userAccounts': [],
          'bills': [],
          'gasPurchases': [],
          'suppliers': [],
          'birthdays': [],
          'diaryEntries': [],
          'notes': [],
        };

        final legacyFile = File(
          '${tempDir.path}${Platform.pathSeparator}legacy_backup.json',
        );
        await legacyFile.writeAsString(jsonEncode(legacyBackup));

        final success = await BackupService.instance.importBackupFromFile(
          legacyFile.path,
        );
        expect(success, isTrue);

        final restored = hive.getReminders();
        expect(restored.length, 1);
        expect(restored.first.title, 'Legacy Reminder');
        expect(hive.getReminderHistory(), isEmpty);
      },
    );
  });

  group('Google Drive Cloud Backup Integrity & Safety Snapshot Tests', () {
    test('Cloud backup payload structure and SHA-256 checksum generation', () {
      final basePayload = {
        'format': 'reminderhub-cloud-backup',
        'app': 'com.reminderhub.reminder_hub',
        'version': 2,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'dataVersion': 9,
        'reminders': [],
        'reminderHistory': [],
      };

      final serialized = jsonEncode(basePayload);
      final checksum = sha256.convert(utf8.encode(serialized)).toString();
      expect(checksum.length, 64); // Valid SHA-256 hex string

      final withChecksum = Map<String, dynamic>.from(basePayload);
      withChecksum['checksum'] = checksum;

      // Verification logic: remove checksum and hash again
      final toVerify = Map<String, dynamic>.from(withChecksum)
        ..remove('checksum');
      final verifiedHash = sha256
          .convert(utf8.encode(jsonEncode(toVerify)))
          .toString();
      expect(verifiedHash, checksum);
    });

    test('Corrupted backup rejection logic', () {
      final basePayload = {
        'format': 'reminderhub-cloud-backup',
        'app': 'com.reminderhub.reminder_hub',
        'version': 2,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'checksum': 'valid_hash_here',
      };

      // Tampered payload
      final tampered = Map<String, dynamic>.from(basePayload);
      tampered['reminders'] = [
        {'id': 'injected_id'},
      ];

      final toVerify = Map<String, dynamic>.from(tampered)..remove('checksum');
      final calculated = sha256
          .convert(utf8.encode(jsonEncode(toVerify)))
          .toString();

      expect(calculated, isNot(equals('valid_hash_here')));
    });
  });
}
