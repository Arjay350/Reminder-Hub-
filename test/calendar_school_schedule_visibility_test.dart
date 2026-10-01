import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';

void main() {
  group('Calendar School Schedule Visibility Settings & Model Tests', () {
    test('AppSettings defaults hideSchoolScheduleInCalendar to false', () {
      final settings = AppSettings(
        themeMode: 'System',
        notificationTime: '09:00 AM',
        currency: '₱',
        appLock: false,
        biometricEnabled: false,
      );
      expect(settings.hideSchoolScheduleInCalendar, isFalse);
    });

    test('AppSettings handles json serialization roundtrip', () {
      final settings = AppSettings(
        themeMode: 'Dark',
        userName: 'Alex',
        nameSetupCompleted: true,
        notificationTime: '08:00 AM',
        currency: '₱',
        appLock: true,
        biometricEnabled: true,
        hideSchoolScheduleInCalendar: true,
      );

      final json = settings.toJson();
      expect(json['hideSchoolScheduleInCalendar'], isTrue);

      final restored = AppSettings.fromJson(json);
      expect(restored.hideSchoolScheduleInCalendar, isTrue);
      expect(restored.themeMode, 'Dark');
      expect(restored.userName, 'Alex');
    });

    test('AppSettings handles legacy JSON without hideSchoolScheduleInCalendar safely', () {
      final legacyJson = {
        'themeMode': 'Light',
        'userName': 'Sam',
        'notificationTime': '09:00 AM',
        'currency': '\$',
        'appLock': false,
        'biometricEnabled': false,
      };

      final restored = AppSettings.fromJson(legacyJson);
      expect(restored.hideSchoolScheduleInCalendar, isFalse);
    });

    test('AppSettings copyWith properly toggles hideSchoolScheduleInCalendar', () {
      final settings = AppSettings(
        themeMode: 'System',
        notificationTime: '09:00 AM',
        currency: '₱',
        appLock: false,
        biometricEnabled: false,
        hideSchoolScheduleInCalendar: false,
      );

      final updated = settings.copyWith(hideSchoolScheduleInCalendar: true);
      expect(updated.hideSchoolScheduleInCalendar, isTrue);

      final toggledBack = updated.copyWith(hideSchoolScheduleInCalendar: false);
      expect(toggledBack.hideSchoolScheduleInCalendar, isFalse);
    });
  });
}
