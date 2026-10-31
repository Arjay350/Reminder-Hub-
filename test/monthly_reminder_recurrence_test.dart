import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/services/notification_service.dart';

void main() {
  group('Monthly Reminder Recurrence - Anchor Preservation & Offset Tests', () {
    const defaultTime = TimeOfDay(hour: 9, minute: 0);

    test(
      'days 28 through 31 retain their event anchor with zero, one, and multiple-day offsets',
      () {
        final offsets = <String, Duration>{
          'At time': Duration.zero,
          '1 day': const Duration(days: 1),
          '5 days': const Duration(days: 5),
        };

        for (final anchorDay in [28, 29, 30, 31]) {
          for (final year in [2027, 2028]) {
            final eventDay = anchorDay.clamp(1, DateTime(year, 3, 0).day);
            final expectedEvent = DateTime(year, 2, eventDay, 9);
            for (final entry in offsets.entries) {
              final occurrence =
                  NotificationService.calculateNextMonthlyReminderOccurrence(
                    baseDate: DateTime(year, 1, anchorDay),
                    targetDayOfMonth: anchorDay,
                    eventTime: defaultTime,
                    reminderBefore: entry.key,
                    referenceDate: DateTime(year, 2, 1),
                  );

              expect(
                occurrence.eventDate,
                expectedEvent,
                reason: 'anchor=$anchorDay year=$year offset=${entry.key}',
              );
              expect(
                occurrence.notificationDate,
                expectedEvent.subtract(entry.value),
                reason: 'anchor=$anchorDay year=$year offset=${entry.key}',
              );
            }
          }
        }
      },
    );

    group('Event Day 31', () {
      test(
        'Day 31 with 0 offset (At time) across all months including Feb leap and non-leap',
        () {
          // January 2026
          var occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: 'At time',
                referenceDate: DateTime(2026, 1, 15, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 1, 31, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 1, 31, 9, 0));

          // February 2026 (non-leap year -> 28 days)
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: 'At time',
                referenceDate: DateTime(2026, 2, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 2, 28, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 2, 28, 9, 0));

          // February 2028 (leap year -> 29 days)
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2028, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: 'At time',
                referenceDate: DateTime(2028, 2, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2028, 2, 29, 9, 0));
          expect(occurrence.notificationDate, DateTime(2028, 2, 29, 9, 0));

          // March 2026 (MUST return to 31, not drift to 28)
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: 'At time',
                referenceDate: DateTime(2026, 3, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 3, 31, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 3, 31, 9, 0));

          // April 2026 (30 days -> clamped to 30)
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: 'At time',
                referenceDate: DateTime(2026, 4, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 4, 30, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 4, 30, 9, 0));

          // May 2026 (MUST return to 31)
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: 'At time',
                referenceDate: DateTime(2026, 5, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 5, 31, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 5, 31, 9, 0));
        },
      );

      test(
        'Day 31 with 1 day advance offset correctly calculates advance date without altering anchor',
        () {
          // January 2026: event Jan 31 -> notify Jan 30
          var occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2026, 1, 15, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 1, 31, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 1, 30, 9, 0));

          // February 2026 (non-leap, 28 days): event Feb 28 -> notify Feb 27 (NOT 30 or 28)
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2026, 2, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 2, 28, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 2, 27, 9, 0));

          // February 2028 (leap year, 29 days): event Feb 29 -> notify Feb 28
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2028, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2028, 2, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2028, 2, 29, 9, 0));
          expect(occurrence.notificationDate, DateTime(2028, 2, 28, 9, 0));

          // March 2026: event Mar 31 -> notify Mar 30
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2026, 3, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 3, 31, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 3, 30, 9, 0));

          // April 2026: event Apr 30 -> notify Apr 29
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 31),
                targetDayOfMonth: 31,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2026, 4, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 4, 30, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 4, 29, 9, 0));
        },
      );

      test('Day 31 with multiple days advance offset (3 days)', () {
        // January: event Jan 31 -> notify Jan 28
        var occurrence =
            NotificationService.calculateNextMonthlyReminderOccurrence(
              baseDate: DateTime(2026, 1, 31),
              targetDayOfMonth: 31,
              eventTime: defaultTime,
              reminderBefore: '3 days',
              referenceDate: DateTime(2026, 1, 10, 8, 0),
            );
        expect(occurrence.eventDate, DateTime(2026, 1, 31, 9, 0));
        expect(occurrence.notificationDate, DateTime(2026, 1, 28, 9, 0));

        // February (non-leap): event Feb 28 -> notify Feb 25
        occurrence = NotificationService.calculateNextMonthlyReminderOccurrence(
          baseDate: DateTime(2026, 1, 31),
          targetDayOfMonth: 31,
          eventTime: defaultTime,
          reminderBefore: '3 days',
          referenceDate: DateTime(2026, 2, 1, 8, 0),
        );
        expect(occurrence.eventDate, DateTime(2026, 2, 28, 9, 0));
        expect(occurrence.notificationDate, DateTime(2026, 2, 25, 9, 0));

        // March: event Mar 31 -> notify Mar 28
        occurrence = NotificationService.calculateNextMonthlyReminderOccurrence(
          baseDate: DateTime(2026, 1, 31),
          targetDayOfMonth: 31,
          eventTime: defaultTime,
          reminderBefore: '3 days',
          referenceDate: DateTime(2026, 3, 1, 8, 0),
        );
        expect(occurrence.eventDate, DateTime(2026, 3, 31, 9, 0));
        expect(occurrence.notificationDate, DateTime(2026, 3, 28, 9, 0));
      });
    });

    group('Event Day 30', () {
      test(
        'Day 30 across February leap/non-leap and return to 30 in March',
        () {
          // February 2026 (non-leap): clamped to 28
          var occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 30),
                targetDayOfMonth: 30,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2026, 2, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 2, 28, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 2, 27, 9, 0));

          // February 2028 (leap year): clamped to 29
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2028, 1, 30),
                targetDayOfMonth: 30,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2028, 2, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2028, 2, 29, 9, 0));
          expect(occurrence.notificationDate, DateTime(2028, 2, 28, 9, 0));

          // March 2026: returns to 30
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 30),
                targetDayOfMonth: 30,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2026, 3, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 3, 30, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 3, 29, 9, 0));
        },
      );
    });

    group('Event Day 29', () {
      test('Day 29 across February leap and non-leap years', () {
        // Feb 2026 non-leap -> clamped to 28
        var occurrence =
            NotificationService.calculateNextMonthlyReminderOccurrence(
              baseDate: DateTime(2026, 1, 29),
              targetDayOfMonth: 29,
              eventTime: defaultTime,
              reminderBefore: 'At time',
              referenceDate: DateTime(2026, 2, 1, 8, 0),
            );
        expect(occurrence.eventDate, DateTime(2026, 2, 28, 9, 0));

        // Feb 2028 leap -> exact 29
        occurrence = NotificationService.calculateNextMonthlyReminderOccurrence(
          baseDate: DateTime(2028, 1, 29),
          targetDayOfMonth: 29,
          eventTime: defaultTime,
          reminderBefore: 'At time',
          referenceDate: DateTime(2028, 2, 1, 8, 0),
        );
        expect(occurrence.eventDate, DateTime(2028, 2, 29, 9, 0));

        // March 2026 -> returns to 29
        occurrence = NotificationService.calculateNextMonthlyReminderOccurrence(
          baseDate: DateTime(2026, 1, 29),
          targetDayOfMonth: 29,
          eventTime: defaultTime,
          reminderBefore: 'At time',
          referenceDate: DateTime(2026, 3, 1, 8, 0),
        );
        expect(occurrence.eventDate, DateTime(2026, 3, 29, 9, 0));
      });
    });

    group('Event Day 28', () {
      test('Day 28 never clamps in any month', () {
        for (int m = 1; m <= 12; m++) {
          final occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 28),
                targetDayOfMonth: 28,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2026, m, 1, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, m, 28, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, m, 27, 9, 0));
        }
      });
    });

    group('Advance Notification Falling in Previous Month & Year Transitions', () {
      test(
        'Event on 1st of March with 1 day advance notification falls in February',
        () {
          // 2026 (non-leap): March 1 event -> Feb 28 notification
          var occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 1, 1),
                targetDayOfMonth: 1,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2026, 2, 27, 12, 0),
              );
          expect(occurrence.eventDate, DateTime(2026, 3, 1, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 2, 28, 9, 0));

          // 2028 (leap): March 1 event -> Feb 29 notification
          occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2028, 1, 1),
                targetDayOfMonth: 1,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2028, 2, 28, 12, 0),
              );
          expect(occurrence.eventDate, DateTime(2028, 3, 1, 9, 0));
          expect(occurrence.notificationDate, DateTime(2028, 2, 29, 9, 0));
        },
      );

      test(
        'Year transition: Event on January 1 with 1 day advance notification falls in December of preceding year',
        () {
          // Jan 1, 2027 event with 1 day offset -> notify Dec 31, 2026
          final occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 12, 1),
                targetDayOfMonth: 1,
                eventTime: defaultTime,
                reminderBefore: '1 day',
                referenceDate: DateTime(2026, 12, 30, 10, 0),
              );
          expect(occurrence.eventDate, DateTime(2027, 1, 1, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 12, 31, 9, 0));
        },
      );

      test(
        'Year transition: Event on January 2 with 3 days advance notification falls in December',
        () {
          final occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: DateTime(2026, 12, 2),
                targetDayOfMonth: 2,
                eventTime: defaultTime,
                reminderBefore: '3 days',
                referenceDate: DateTime(2026, 12, 29, 8, 0),
              );
          expect(occurrence.eventDate, DateTime(2027, 1, 2, 9, 0));
          expect(occurrence.notificationDate, DateTime(2026, 12, 30, 9, 0));
        },
      );
    });

    group('Repeated Monthly Occurrences & Drift Resistance', () {
      test(
        'scheduled event days recover after February clamps across repeated months',
        () {
          const expectedDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
          var reference = DateTime(2026, 1, 15, 8);

          for (var month = 1; month <= 12; month++) {
            final occurrence =
                NotificationService.calculateNextMonthlyReminderOccurrence(
                  baseDate: DateTime(2026, 1, 31),
                  targetDayOfMonth: 31,
                  eventTime: defaultTime,
                  reminderBefore: '1 day',
                  referenceDate: reference,
                );

            expect(occurrence.eventDate.month, month);
            expect(occurrence.eventDate.day, expectedDays[month - 1]);
            expect(
              occurrence.notificationDate,
              occurrence.eventDate.subtract(const Duration(days: 1)),
            );
            reference = occurrence.notificationDate.add(
              const Duration(seconds: 1),
            );
          }
        },
      );

      test(
        '12-month simulation for Day 31 never drifts because of February clamping',
        () {
          final reminder = Reminder(
            id: 'monthly-31',
            title: 'Month End Report',
            category: 'Work',
            description: '',
            date: DateTime(2026, 1, 31),
            time: '09:00 AM',
            repeat: 'Monthly',
            reminderBefore: '1 day',
            priority: 'High',
            notes: '',
            completed: false,
            targetDayOfMonth: 31,
          );

          final expectedEventDays = [
            31, // Jan
            28, // Feb (clamped)
            31, // Mar (returned to 31!)
            30, // Apr (clamped)
            31, // May (returned to 31!)
            30, // Jun (clamped)
            31, // Jul
            31, // Aug
            30, // Sep
            31, // Oct
            30, // Nov
            31, // Dec
          ];

          var currentReminder = reminder;
          for (int monthIndex = 0; monthIndex < 12; monthIndex++) {
            final month = monthIndex + 1;
            final expectedDay = expectedEventDays[monthIndex];

            expect(
              currentReminder.date.day,
              expectedDay,
              reason: 'Month $month should have event day $expectedDay',
            );
            expect(
              currentReminder.targetDayOfMonth,
              31,
              reason: 'Anchor targetDayOfMonth must remain 31 throughout',
            );

            // Calculate next occurrence for when this month is completed
            final nextDate = currentReminder.calculateNextOccurrence(
              DateTime(2026, month, expectedDay, 10, 0),
            );

            currentReminder = currentReminder.copyWith(
              date: nextDate,
              targetDayOfMonth:
                  currentReminder.targetDayOfMonth ?? currentReminder.date.day,
            );
          }

          // Verify January 2027 returned to 31
          expect(currentReminder.date.year, 2027);
          expect(currentReminder.date.month, 1);
          expect(currentReminder.date.day, 31);
        },
      );

      test(
        'Backward compatibility: Legacy reminder without targetDayOfMonth anchors to date.day',
        () {
          final legacyReminder = Reminder(
            id: 'legacy-31',
            title: 'Legacy Day 31 Reminder',
            category: 'Personal',
            description: '',
            date: DateTime(2026, 1, 31),
            time: '10:00 AM',
            repeat: 'Monthly',
            reminderBefore: 'None',
            priority: 'Low',
            notes: '',
            completed: false,
            targetDayOfMonth: null, // Legacy field absent
          );

          final occurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: legacyReminder.date,
                targetDayOfMonth: legacyReminder.targetDayOfMonth,
                eventTime: const TimeOfDay(hour: 10, minute: 0),
                reminderBefore: legacyReminder.reminderBefore,
                referenceDate: DateTime(2026, 2, 1, 8, 0),
              );

          // Clamps to Feb 28
          expect(occurrence.eventDate, DateTime(2026, 2, 28, 10, 0));

          // When evaluating for March, anchor is preserved
          final marchOccurrence =
              NotificationService.calculateNextMonthlyReminderOccurrence(
                baseDate: legacyReminder.date,
                targetDayOfMonth:
                    legacyReminder.targetDayOfMonth ?? legacyReminder.date.day,
                eventTime: const TimeOfDay(hour: 10, minute: 0),
                reminderBefore: legacyReminder.reminderBefore,
                referenceDate: DateTime(2026, 3, 1, 8, 0),
              );
          expect(marchOccurrence.eventDate, DateTime(2026, 3, 31, 10, 0));
        },
      );
    });
  });
}
