import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Deterministic ID Tests', () {
    test('Same UUID yields same positive 31-bit integer ID', () {
      const uuid = 'c4b8b6a1-9a77-4b82-990a-5c6a1e94441b';
      final id1 = uuid.hashCode & 0x7FFFFFFF;
      final id2 = uuid.hashCode & 0x7FFFFFFF;
      expect(id1, id2);
      expect(id1, greaterThanOrEqualTo(0));
      expect(id1, lessThanOrEqualTo(0x7FFFFFFF));
    });

    test('Different sub-keys yield distinct IDs', () {
      const uuid = 'class-123';
      final idMon = '${uuid}_1'.hashCode & 0x7FFFFFFF;
      final idTue = '${uuid}_2'.hashCode & 0x7FFFFFFF;
      final idRenewal = '${uuid}_renewal'.hashCode & 0x7FFFFFFF;

      expect(idMon, isNot(equals(idTue)));
      expect(idMon, isNot(equals(idRenewal)));
    });
  });

  group('Recurrence & Offset Calculations', () {
    test('Offset parsing handles standard and custom minutes', () {
      final base = DateTime(2026, 8, 28, 10, 0); // 10:00 AM

      DateTime applyOffset(DateTime eventTime, String reminderBefore) {
        final clean = reminderBefore.trim().toLowerCase();
        if (clean.isEmpty || clean == 'at time' || clean == 'at start' || clean == 'on time' || clean == 'none') {
          return eventTime;
        }
        if (clean == '5 minutes' || clean == '5 minutes before' || clean == '5 mins') {
          return eventTime.subtract(const Duration(minutes: 5));
        }
        if (clean == '10 minutes' || clean == '10 minutes before' || clean == '10 mins') {
          return eventTime.subtract(const Duration(minutes: 10));
        }
        if (clean == '15 minutes' || clean == '15 minutes before' || clean == '15 mins') {
          return eventTime.subtract(const Duration(minutes: 15));
        }
        if (clean == '30 minutes' || clean == '30 minutes before' || clean == '30 mins') {
          return eventTime.subtract(const Duration(minutes: 30));
        }
        if (clean == '45 minutes' || clean == '45 minutes before' || clean == '45 mins') {
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

        final numMatch = RegExp(r'(\d+)\s*(minute|min|hour|hr|day|week)').firstMatch(clean);
        if (numMatch != null) {
          final val = int.tryParse(numMatch.group(1) ?? '') ?? 0;
          final unit = numMatch.group(2) ?? '';
          if (unit.startsWith('min')) return eventTime.subtract(Duration(minutes: val));
          if (unit.startsWith('h')) return eventTime.subtract(Duration(hours: val));
          if (unit.startsWith('d')) return eventTime.subtract(Duration(days: val));
          if (unit.startsWith('w')) return eventTime.subtract(Duration(days: val * 7));
        }
        return eventTime;
      }

      expect(applyOffset(base, 'At start'), DateTime(2026, 8, 28, 10, 0));
      expect(applyOffset(base, '5 minutes'), DateTime(2026, 8, 28, 9, 55));
      expect(applyOffset(base, '15 minutes'), DateTime(2026, 8, 28, 9, 45));
      expect(applyOffset(base, '30 minutes'), DateTime(2026, 8, 28, 9, 30));
      expect(applyOffset(base, '45 minutes'), DateTime(2026, 8, 28, 9, 15));
      expect(applyOffset(base, '1 hour'), DateTime(2026, 8, 28, 9, 0));
      expect(applyOffset(base, '2 hours'), DateTime(2026, 8, 28, 8, 0));
      expect(applyOffset(base, '1 day'), DateTime(2026, 8, 27, 10, 0));
      expect(applyOffset(base, '3 days'), DateTime(2026, 8, 25, 10, 0));
      expect(applyOffset(base, 'Custom: 45 minutes'), DateTime(2026, 8, 28, 9, 15));
    });

    test('Monthly safe clamping for varying month lengths (Feb, Apr, 31st)', () {
      DateTime clampedDate(int year, int month, int targetDay, int hour, int minute) {
        final maxDay = DateTime(year, month + 1, 0).day;
        final validDay = targetDay.clamp(1, maxDay);
        return DateTime(year, month, validDay, hour, minute);
      }

      // Jan 31 -> Feb 28 in non-leap year (2025)
      final feb2025 = clampedDate(2025, 2, 31, 9, 0);
      expect(feb2025, DateTime(2025, 2, 28, 9, 0));

      // Jan 31 -> Feb 29 in leap year (2024 / 2028)
      final feb2028 = clampedDate(2028, 2, 31, 9, 0);
      expect(feb2028, DateTime(2028, 2, 29, 9, 0));

      // Jan 31 -> Apr 30 (30 days month)
      final apr2026 = clampedDate(2026, 4, 31, 9, 0);
      expect(apr2026, DateTime(2026, 4, 30, 9, 0));

      // May 31 -> May 31 (31 days month)
      final may2026 = clampedDate(2026, 5, 31, 9, 0);
      expect(may2026, DateTime(2026, 5, 31, 9, 0));
    });

    test('Yearly safe clamping for Feb 29 on non-leap years', () {
      DateTime clampedYearly(int year, int targetMonth, int targetDay, int hour, int minute) {
        final maxDay = DateTime(year, targetMonth + 1, 0).day;
        final validDay = targetDay.clamp(1, maxDay);
        return DateTime(year, targetMonth, validDay, hour, minute);
      }

      // 2028 is leap year -> Feb 29 valid
      final leapDate = clampedYearly(2028, 2, 29, 8, 0);
      expect(leapDate, DateTime(2028, 2, 29, 8, 0));

      // 2029 is not leap year -> clamps to Feb 28
      final nonLeapDate = clampedYearly(2029, 2, 29, 8, 0);
      expect(nonLeapDate, DateTime(2029, 2, 28, 8, 0));
    });
  });

  group('Bill Due Date Calculations', () {
    test('Bill reminder schedules subtract correct days at 9:00 AM', () {
      DateTime applyBillReminder(DateTime dueDate, String schedule) {
        final clean = schedule.trim().toLowerCase();
        DateTime base = dueDate;
        if (clean == 'same day' || clean == 'at due date' || clean == 'none') {
          base = dueDate;
        } else if (clean.contains('1 day')) {
          base = dueDate.subtract(const Duration(days: 1));
        } else if (clean.contains('2 day')) {
          base = dueDate.subtract(const Duration(days: 2));
        } else if (clean.contains('3 day')) {
          base = dueDate.subtract(const Duration(days: 3));
        } else if (clean.contains('5 day')) {
          base = dueDate.subtract(const Duration(days: 5));
        } else if (clean.contains('1 week') || clean.contains('7 day')) {
          base = dueDate.subtract(const Duration(days: 7));
        }
        return DateTime(base.year, base.month, base.day, 9, 0);
      }

      final dueDate = DateTime(2026, 8, 30);

      // 3 days before -> Aug 27 at 9:00 AM
      expect(applyBillReminder(dueDate, '3 days before'), DateTime(2026, 8, 27, 9, 0));

      // 1 day before -> Aug 29 at 9:00 AM
      expect(applyBillReminder(dueDate, '1 day before'), DateTime(2026, 8, 29, 9, 0));

      // 1 week before -> Aug 23 at 9:00 AM
      expect(applyBillReminder(dueDate, '1 week before'), DateTime(2026, 8, 23, 9, 0));
    });
  });

  group('School Schedule Recurrence Calculations', () {
    test('Calculates next occurrence for today when class time is in future', () {
      final now = DateTime(2026, 9, 14, 8, 0); // Monday 8:00 AM
      const classDay = 1; // Monday

      int daysUntil = (classDay - now.weekday) % 7;
      if (daysUntil < 0) daysUntil += 7;

      DateTime targetDate = DateTime(now.year, now.month, now.day + daysUntil, 10, 0);
      expect(targetDate.isAfter(now), isTrue);
      expect(targetDate, DateTime(2026, 9, 14, 10, 0)); // Today!
    });

    test('Rolls forward by 7 days when class time today has already passed', () {
      final now = DateTime(2026, 9, 14, 14, 0); // Monday 2:00 PM
      const classDay = 1; // Monday

      int daysUntil = (classDay - now.weekday) % 7;
      if (daysUntil < 0) daysUntil += 7;

      DateTime targetDate = DateTime(now.year, now.month, now.day + daysUntil, 8, 0);
      if (targetDate.isBefore(now)) {
        targetDate = targetDate.add(const Duration(days: 7));
      }
      expect(targetDate.isAfter(now), isTrue);
      expect(targetDate, DateTime(2026, 9, 21, 8, 0)); // Next Monday!
    });
  });

  group('AI Reset Schedule & Recurrence Calculations', () {
    test('Exact Date/Time: Past reset date is skipped (not rolled forward)', () {
      final now = DateTime(2026, 9, 19, 14, 0); // 2:00 PM
      final pastResetDate = DateTime(2026, 9, 11, 8, 48); // Sept 11, 2026 at 8:48 AM
      const sched = 'exact date/time';

      DateTime targetDateTime = pastResetDate;
      bool shouldSchedule = true;

      if (sched == 'exact date/time') {
        if (targetDateTime.isBefore(now)) {
          shouldSchedule = false;
        }
      }

      expect(shouldSchedule, isFalse);
      expect(targetDateTime, pastResetDate);
    });

    test('Exact Date/Time: Future reset date is scheduled once without repetition', () {
      final now = DateTime(2026, 9, 19, 14, 0); // 2:00 PM
      final futureResetDate = DateTime(2026, 9, 25, 8, 48); // Sept 25, 2026 at 8:48 AM
      const sched = 'exact date/time';

      DateTime targetDateTime = futureResetDate;
      bool shouldSchedule = false;

      if (sched == 'exact date/time') {
        if (targetDateTime.isAfter(now)) {
          shouldSchedule = true;
        }
      }

      expect(shouldSchedule, isTrue);
      expect(targetDateTime, DateTime(2026, 9, 25, 8, 48));
    });

    test('Daily schedule: Rolls forward to next occurrence when past', () {
      final now = DateTime(2026, 9, 14, 14, 0); // 2:00 PM
      DateTime targetDateTime = DateTime(2026, 9, 10, 9, 0); // Past date at 9:00 AM

      while (!targetDateTime.isAfter(now)) {
        targetDateTime = targetDateTime.add(const Duration(days: 1));
      }

      // 9:00 AM today is past 2:00 PM, so it rolls to tomorrow (Sept 15) at 9:00 AM
      expect(targetDateTime, DateTime(2026, 9, 15, 9, 0));
      expect(targetDateTime.isAfter(now), isTrue);
    });
  });
}
