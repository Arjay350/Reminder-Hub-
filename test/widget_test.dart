import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/services/gas_calculation_service.dart';
import 'package:reminder_hub/services/timetable_calculation_service.dart';
import 'package:reminder_hub/services/widget_service.dart';
import 'package:reminder_hub/widgets/weekly_timetable_widget.dart';
import 'package:reminder_hub/widgets/password_text_field.dart';

void main() {
  group('GasCalculationService Unit Tests', () {
    test('calculateActiveTankDays counts calendar days inclusively', () {
      expect(
        GasCalculationService.calculateActiveTankDays(
          DateTime(2026, 9, 1, 23, 59),
          referenceDate: DateTime(2026, 9, 7, 0, 1),
        ),
        7,
      );
      expect(
        GasCalculationService.calculateActiveTankDays(
          DateTime(2026, 9, 8),
          referenceDate: DateTime(2026, 9, 7),
        ),
        0,
      );
    });

    test(
      'calculateAverageDuration calculates correct average days between orders',
      () {
        final purchases = [
          GasPurchase(
            id: '1',
            tankSize: '11 kg',
            amountPaid: 950.0,
            purchaseDate: DateTime(2026, 3, 5),
          ),
          GasPurchase(
            id: '2',
            tankSize: '11 kg',
            amountPaid: 920.0,
            purchaseDate: DateTime(2026, 1, 10), // 54 days difference
          ),
        ];

        final avg = GasCalculationService.calculateAverageDuration(purchases);
        expect(avg, 54);
      },
    );

    test('completed tank duration stops on the replacement order date', () {
      expect(
        GasCalculationService.calculateCompletedTankDuration(
          DateTime(2026, 1, 10, 23, 59),
          DateTime(2026, 3, 5, 0, 1),
        ),
        54,
      );
    });

    test('future LPG orders are not counted as active days', () {
      expect(
        GasCalculationService.calculateActiveTankDays(
          DateTime(2026, 9, 8),
          referenceDate: DateTime(2026, 9, 7),
        ),
        0,
      );
    });

    test('formatDurationText formats days cleanly into months and days', () {
      expect(
        GasCalculationService.formatDurationText(54),
        '54 days (~1 month, 24 days)',
      );
      expect(GasCalculationService.formatDurationText(15), '15 days');
    });
  });

  group('AIAccount Plan & Reset Logic Tests', () {
    test('AIAccount detects free vs paid plan correctly', () {
      final freeAccount = AIAccount(
        id: 'ai-1',
        service: 'ChatGPT',
        accountName: 'Personal',
        email: 'test@gmail.com',
        username: 'test',
        password: 'password123',
        plan: 'Free',
        resetDate: DateTime(2026, 8, 30),
        resetTime: '10:00 PM',
        notes: '',
      );
      expect(freeAccount.isFreePlan, isTrue);

      final paidAccount = AIAccount(
        id: 'ai-2',
        service: 'ChatGPT',
        accountName: 'Work',
        email: 'work@gmail.com',
        username: 'work_user',
        password: 'securePass!',
        plan: 'Plus',
        resetDate: DateTime(2026, 8, 30),
        resetTime: '10:00 PM',
        renewalDate: DateTime(2026, 9, 15),
        notes: '',
      );
      expect(paidAccount.isFreePlan, isFalse);
    });
  });

  group('SchoolClass Schedule Tests', () {
    test('SchoolClass correctly checks occurrences on days of week', () {
      final mondayWednesdayClass = SchoolClass(
        id: 'class-1',
        subject: 'Database Management',
        room: 'Room 302',
        teacher: 'Prof. Santos',
        daysOfWeek: [1, 3], // Mon, Wed
        startTime: '08:00 AM',
        endTime: '10:00 AM',
      );

      expect(mondayWednesdayClass.occursOnDay(1), isTrue); // Mon
      expect(mondayWednesdayClass.occursOnDay(2), isFalse); // Tue
      expect(mondayWednesdayClass.occursOnDay(3), isTrue); // Wed
      expect(mondayWednesdayClass.occursOnDay(5), isFalse); // Fri
      expect(mondayWednesdayClass.daysFormatted, 'Mon, Wed');
    });

    testWidgets('WeeklySchoolTimetableWidget renders days and classes', (
      tester,
    ) async {
      final classes = [
        SchoolClass(
          id: 'c1',
          subject: 'Database Management',
          room: '302',
          teacher: 'Prof. Santos',
          daysOfWeek: [1], // Monday
          startTime: '08:00 AM',
          endTime: '10:00 AM',
        ),
        SchoolClass(
          id: 'c2',
          subject: 'Systems Analysis',
          room: '201',
          teacher: 'Dr. Cruz',
          daysOfWeek: [3], // Wednesday
          startTime: '01:00 PM',
          endTime: '03:00 PM',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklySchoolTimetableWidget(
              classes: classes,
              onScheduleChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MON'), findsOneWidget);
      expect(find.text('TUE'), findsOneWidget);
      expect(find.text('WED'), findsOneWidget);
      expect(find.text('Database Management'), findsOneWidget);
    });
  });

  group('Password Show/Hide Toggle Tests', () {
    testWidgets('PasswordTextField toggles visibility correctly', (
      tester,
    ) async {
      const MethodChannel authChannel = MethodChannel('plugins.flutter.io/local_auth');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        authChannel,
        (call) async {
          if (call.method == 'isDeviceSupported' ||
              call.method == 'canCheckBiometrics') {
            return false;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PasswordTextField(
              password: 'mypassword123',
              label: 'Password credential',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially obscured
      expect(find.text('••••••••••••'), findsOneWidget);
      expect(find.text('mypassword123'), findsNothing);

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      // Password revealed
      expect(find.text('mypassword123'), findsOneWidget);
      expect(find.text('••••••••••••'), findsNothing);

      // Tap again to hide
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      // Obscured again
      expect(find.text('••••••••••••'), findsOneWidget);
      expect(find.text('mypassword123'), findsNothing);
    });
  });

  group('Android Home-Screen Widget Service Tests', () {
    test('WidgetService can be instantiated and executed cleanly', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Should not throw even in test environment
      expect(
        () async => await WidgetService.instance.updateSchoolWidget(),
        returnsNormally,
      );
    });
  });

  group('TimetableCalculationService Tests', () {
    late TimetableCalculationService service;

    setUp(() {
      service = TimetableCalculationService.instance;
    });

    group('Time Parsing', () {
      test('parseTimeToMinutes correctly parses AM times', () {
        expect(
          TimetableCalculationService.parseTimeToMinutes('8:00 AM'),
          480,
        ); // 8 * 60
        expect(
          TimetableCalculationService.parseTimeToMinutes('11:30 AM'),
          690,
        ); // 11 * 60 + 30
        expect(
          TimetableCalculationService.parseTimeToMinutes('12:00 AM'),
          0,
        ); // midnight
      });

      test('parseTimeToMinutes correctly parses PM times', () {
        expect(
          TimetableCalculationService.parseTimeToMinutes('1:00 PM'),
          780,
        ); // 13 * 60
        expect(
          TimetableCalculationService.parseTimeToMinutes('5:30 PM'),
          1050,
        ); // 17 * 60 + 30
        expect(
          TimetableCalculationService.parseTimeToMinutes('12:00 PM'),
          720,
        ); // noon
        expect(
          TimetableCalculationService.parseTimeToMinutes('11:59 PM'),
          1439,
        ); // 23 * 60 + 59
      });

      test('parseTimeToMinutes handles edge cases', () {
        expect(TimetableCalculationService.parseTimeToMinutes('08:00 AM'), 480);
        expect(TimetableCalculationService.parseTimeToMinutes('8:00 AM'), 480);
        expect(
          TimetableCalculationService.parseTimeToMinutes('  8:00 AM  '),
          480,
        );
      });
    });

    group('Weekly Occurrences', () {
      test('getTotalWeeklyOccurrences counts each class-day combination', () {
        final classes = [
          SchoolClass(
            id: 'c1',
            subject: 'Math',
            daysOfWeek: [1, 3, 5], // Mon, Wed, Fri
            startTime: '08:00 AM',
            endTime: '10:00 AM',
          ),
          SchoolClass(
            id: 'c2',
            subject: 'Physics',
            daysOfWeek: [2, 4], // Tue, Thu
            startTime: '01:00 PM',
            endTime: '03:00 PM',
          ),
          SchoolClass(
            id: 'c3',
            subject: 'Chemistry',
            daysOfWeek: [1], // Mon only
            startTime: '10:00 AM',
            endTime: '11:00 AM',
          ),
        ];

        // Math: 3 days, Physics: 2 days, Chemistry: 1 day = 6 total
        expect(service.getTotalWeeklyOccurrences(classes), 6);
      });

      test('getClassesByDay returns correct counts per day', () {
        final classes = [
          SchoolClass(
            id: 'c1',
            subject: 'Math',
            daysOfWeek: [1, 3, 5],
            startTime: '08:00 AM',
            endTime: '10:00 AM',
          ),
          SchoolClass(
            id: 'c2',
            subject: 'Physics',
            daysOfWeek: [2, 4],
            startTime: '01:00 PM',
            endTime: '03:00 PM',
          ),
        ];

        final counts = service.getClassesByDay(classes);
        expect(counts[1], 1); // Mon
        expect(counts[2], 1); // Tue
        expect(counts[3], 1); // Wed
        expect(counts[4], 1); // Thu
        expect(counts[5], 1); // Fri
        expect(counts[6], 0); // Sat
      });

      test('getAllWeeklyOccurrences returns sorted occurrences', () {
        final classes = [
          SchoolClass(
            id: 'c1',
            subject: 'Math',
            daysOfWeek: [3], // Wed
            startTime: '08:00 AM',
            endTime: '10:00 AM',
          ),
          SchoolClass(
            id: 'c2',
            subject: 'Physics',
            daysOfWeek: [1], // Mon
            startTime: '01:00 PM',
            endTime: '03:00 PM',
          ),
        ];

        final occurrences = service.getAllWeeklyOccurrences(classes);
        expect(occurrences.length, 2);
        // Should be sorted by weekday first (Mon=1, Wed=3)
        expect(occurrences[0].weekday, 1); // Physics on Mon
        expect(occurrences[1].weekday, 3); // Math on Wed
      });
    });

    group('Day Status Calculation', () {
      // Monday, 2026-08-24 at 10:00 AM
      final testTime = DateTime(2026, 8, 24, 10, 0);

      final classes = [
        SchoolClass(
          id: 'c1',
          subject: 'Math 101',
          room: 'Room 101',
          teacher: 'Prof. A',
          daysOfWeek: [1], // Monday
          startTime: '08:00 AM',
          endTime: '10:00 AM',
        ),
        SchoolClass(
          id: 'c2',
          subject: 'Physics 101',
          room: 'Room 202',
          teacher: 'Prof. B',
          daysOfWeek: [1], // Monday
          startTime: '10:30 AM',
          endTime: '12:30 PM',
        ),
        SchoolClass(
          id: 'c3',
          subject: 'Chemistry 101',
          room: 'Room 303',
          teacher: 'Prof. C',
          daysOfWeek: [1], // Monday
          startTime: '01:00 PM',
          endTime: '03:00 PM',
        ),
        SchoolClass(
          id: 'c4',
          subject: 'Biology 101',
          room: 'Room 404',
          teacher: 'Prof. D',
          daysOfWeek: [2], // Tuesday
          startTime: '08:00 AM',
          endTime: '10:00 AM',
        ),
      ];

      test('calculateDayStatus correctly identifies completed classes', () {
        final status = service.calculateDayStatus(classes, testTime);

        // Math 101: 8:00-10:00, current time 10:00 -> completed (at exact end time)
        final mathStatus = status.classes.firstWhere(
          (cs) => cs.schoolClass.id == 'c1',
        );
        expect(mathStatus.status, ClassState.completed);
      });

      test('calculateDayStatus correctly identifies current classes', () {
        // Test at 9:30 AM during Math class
        final duringMath = DateTime(2026, 8, 24, 9, 30);
        final status = service.calculateDayStatus(classes, duringMath);

        final mathStatus = status.classes.firstWhere(
          (cs) => cs.schoolClass.id == 'c1',
        );
        expect(mathStatus.status, ClassState.current);
        expect(mathStatus.timeRemaining, isNotNull);
        expect(
          mathStatus.timeRemaining!.inMinutes,
          30,
        ); // 10:00 - 9:30 = 30 min
      });

      test('calculateDayStatus correctly identifies next upcoming class', () {
        final status = service.calculateDayStatus(classes, testTime);

        // Physics 101: 10:30-12:30, current time 10:00 -> next class
        expect(status.nextClass, isNotNull);
        expect(status.nextClass!.schoolClass.id, 'c2');
        expect(status.nextClass!.status, ClassState.next);
        expect(status.nextClass!.timeUntilStart, isNotNull);
        expect(
          status.nextClass!.timeUntilStart!.inMinutes,
          30,
        ); // 10:30 - 10:00 = 30 min
      });

      test('calculateDayStatus correctly identifies upcoming classes', () {
        final status = service.calculateDayStatus(classes, testTime);

        final chemStatus = status.classes.firstWhere(
          (cs) => cs.schoolClass.id == 'c3',
        );
        expect(chemStatus.status, ClassState.upcoming);
      });

      test('calculateDayStatus returns empty for days with no classes', () {
        // Sunday (weekday 7)
        final sunday = DateTime(2026, 8, 23, 10, 0);
        final status = service.calculateDayStatus(classes, sunday);

        expect(status.classes, isEmpty);
        expect(status.hasNoMoreClasses, isTrue);
        expect(status.nextDayClass, isNotNull);
        expect(
          status.nextDayClass!.schoolClass.id,
          'c1',
        ); // Next day (Mon) first class
      });

      test('calculateDayStatus handles overlapping classes', () {
        final overlappingClasses = [
          SchoolClass(
            id: 'c1',
            subject: 'Networking',
            daysOfWeek: [1],
            startTime: '05:30 PM',
            endTime: '08:30 PM',
          ),
          SchoolClass(
            id: 'c2',
            subject: 'Usable Security',
            daysOfWeek: [1],
            startTime: '06:30 PM',
            endTime: '07:30 PM',
          ),
        ];

        // At 6:45 PM, both classes are active
        final duringOverlap = DateTime(2026, 8, 24, 18, 45);
        final status = service.calculateDayStatus(
          overlappingClasses,
          duringOverlap,
        );

        expect(status.currentClasses.length, 2);
        expect(
          status.currentClasses.any((cs) => cs.schoolClass.id == 'c1'),
          isTrue,
        );
        expect(
          status.currentClasses.any((cs) => cs.schoolClass.id == 'c2'),
          isTrue,
        );
      });

      test('calculateDayStatus handles no more classes today', () {
        // At 9:00 PM, all Monday classes are done
        final lateNight = DateTime(2026, 8, 24, 21, 0);
        final status = service.calculateDayStatus(classes, lateNight);

        expect(status.hasNoMoreClasses, isTrue);
        expect(status.currentClasses, isEmpty);
        expect(status.nextClass, isNull);
        expect(status.nextDayClass, isNotNull);
        expect(status.nextDayClass!.schoolClass.id, 'c4'); // Tuesday's Biology
      });

      test('calculateDayStatus correctly handles exact start time', () {
        // At exactly 10:30 AM when Physics starts
        final exactStart = DateTime(2026, 8, 24, 10, 30);
        final status = service.calculateDayStatus(classes, exactStart);

        final physicsStatus = status.classes.firstWhere(
          (cs) => cs.schoolClass.id == 'c2',
        );
        expect(physicsStatus.status, ClassState.current);
      });

      test('calculateDayStatus correctly handles exact end time', () {
        // At exactly 10:00 AM when Math ends
        final exactEnd = DateTime(2026, 8, 24, 10, 0);
        final status = service.calculateDayStatus(classes, exactEnd);

        final mathStatus = status.classes.firstWhere(
          (cs) => cs.schoolClass.id == 'c1',
        );
        // At exact end time, class should be completed
        expect(mathStatus.status, ClassState.completed);
      });
    });

    group('Weekly Stats', () {
      test('calculateWeeklyStats returns correct total and by-day counts', () {
        final classes = [
          SchoolClass(
            id: 'c1',
            subject: 'Math',
            daysOfWeek: [1, 3, 5], // 3 occurrences
            startTime: '08:00 AM',
            endTime: '10:00 AM',
          ),
          SchoolClass(
            id: 'c2',
            subject: 'Physics',
            daysOfWeek: [2, 4], // 2 occurrences
            startTime: '01:00 PM',
            endTime: '03:00 PM',
          ),
        ];

        final stats = service.calculateWeeklyStats(classes);
        expect(stats.totalOccurrences, 5);
        expect(stats.classesByDay[1], 1);
        expect(stats.classesByDay[2], 1);
        expect(stats.classesByDay[3], 1);
        expect(stats.classesByDay[4], 1);
        expect(stats.classesByDay[5], 1);
        expect(stats.classesByDay[6], 0);
      });
    });

    group('formatCompactTime', () {
      test('formats time strings correctly', () {
        expect(service.formatCompactTime('8:00 AM'), '8:00');
        expect(service.formatCompactTime('08:00 AM'), '8:00');
        expect(service.formatCompactTime('01:30 PM'), '1:30');
        expect(service.formatCompactTime('12:00 PM'), '12:00');
        expect(service.formatCompactTime('12:00 AM'), '12:00');
      });
    });

    group('getDayName', () {
      test('returns correct day names', () {
        expect(TimetableCalculationService.getDayName(1), 'Monday');
        expect(TimetableCalculationService.getDayName(6), 'Saturday');
        expect(TimetableCalculationService.getDayName(7), 'Sunday');
        expect(TimetableCalculationService.getDayName(1, short: true), 'Mon');
        expect(TimetableCalculationService.getDayName(6, short: true), 'Sat');
      });
    });
  });
}
