import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/services/hive_service.dart';
import 'package:reminder_hub/services/timetable_calculation_service.dart';
import 'package:reminder_hub/services/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimetableCalculationService service;

  setUp(() {
    service = TimetableCalculationService.instance;
  });

  group("Today's Schedule Home-Screen Widget Countdown & State Tests", () {
    final sampleClasses = [
      SchoolClass(
        id: 'c1',
        subject: 'Math 101',
        courseCode: 'MATH101',
        room: 'Room 101',
        teacher: 'Prof. Gauss',
        daysOfWeek: [1, 2, 3, 4, 5], // Mon-Fri
        startTime: '08:00 AM',
        endTime: '10:00 AM',
      ),
      SchoolClass(
        id: 'c2',
        subject: 'Physics 201',
        courseCode: 'PHYS201',
        room: 'Lab 2',
        teacher: 'Prof. Newton',
        daysOfWeek: [1, 3, 5], // Mon, Wed, Fri
        startTime: '10:00 AM', // Consecutive with c1
        endTime: '12:00 PM',
      ),
      SchoolClass(
        id: 'c3',
        subject: 'Chemistry 301',
        courseCode: 'CHEM301',
        room: 'Lab 3',
        teacher: 'Prof. Curie',
        daysOfWeek: [1, 3], // Mon, Wed
        startTime: '02:00 PM',
        endTime: '04:00 PM',
      ),
    ];

    test('1. Countdown changes as time advances', () {
      final monday = DateTime(2026, 8, 24, 7, 0, 0); // 1h before Math starts
      final status1 = service.calculateDayStatus(sampleClasses, monday);
      expect(status1.nextClass, isNotNull);
      expect(status1.nextClass!.schoolClass.id, 'c1');
      expect(status1.nextClass!.timeUntilStart?.inMinutes, 60);
      expect(status1.nextClass!.timeUntilStartFormatted, '1h');

      // Advance by 30 minutes
      final at730 = DateTime(2026, 8, 24, 7, 30, 0);
      final status2 = service.calculateDayStatus(sampleClasses, at730);
      expect(status2.nextClass!.timeUntilStart?.inMinutes, 30);
      expect(status2.nextClass!.timeUntilStartFormatted, '30m');

      // Advance to 45 seconds before start
      final at759 = DateTime(2026, 8, 24, 7, 59, 15);
      final status3 = service.calculateDayStatus(sampleClasses, at759);
      expect(status3.nextClass!.timeUntilStart?.inSeconds, 45);
      expect(status3.nextClass!.timeUntilStartFormatted, '< 1m');

      // During Math class (at 9:00 AM, 1 hour remaining)
      final at900 = DateTime(2026, 8, 24, 9, 0, 0);
      final status4 = service.calculateDayStatus(sampleClasses, at900);
      final currentMath = status4.currentClasses.first;
      expect(currentMath.timeRemaining?.inMinutes, 60);
      expect(currentMath.timeRemainingFormatted, '1h');

      // 45 seconds before Math ends
      final at959 = DateTime(2026, 8, 24, 9, 59, 15);
      final status5 = service.calculateDayStatus(sampleClasses, at959);
      final currentMathEnding = status5.currentClasses.first;
      expect(currentMathEnding.timeRemaining?.inSeconds, 45);
      expect(currentMathEnding.timeRemainingFormatted, '< 1m');
    });

    test('2. No negative countdown is rendered', () {
      // 10 minutes past Math end time (10:10 AM)
      final pastMath = DateTime(2026, 8, 24, 10, 10, 0);
      final status = service.calculateDayStatus(sampleClasses, pastMath);

      final mathStatus = status.classes.firstWhere(
        (cs) => cs.schoolClass.id == 'c1',
      );
      expect(mathStatus.status, ClassState.completed);
      expect(mathStatus.timeRemaining, isNull);
      expect(mathStatus.timeUntilStart, isNull);
      expect(mathStatus.timeRemainingFormatted, '');
      expect(mathStatus.timeUntilStartFormatted, '');
      expect(mathStatus.targetTime, isNull);

      // Verify duration formatter never returns negative values
      const negativeDur = Duration(minutes: -5, seconds: -30);
      final formatted = ClassStatus(
        schoolClass: sampleClasses.first,
        status: ClassState.completed,
        timeRemaining: negativeDur,
      ).timeRemainingFormatted;
      expect(formatted, '0m');
      expect(formatted.contains('-'), isFalse);
    });

    test('3. A class starting triggers the correct state transition', () {
      // 1 second before start
      final beforeStart = DateTime(2026, 8, 24, 7, 59, 59);
      final statusBefore = service.calculateDayStatus(
        sampleClasses,
        beforeStart,
      );
      final mathBefore = statusBefore.classes.firstWhere(
        (cs) => cs.schoolClass.id == 'c1',
      );
      expect(mathBefore.status, ClassState.upcoming);
      expect(
        mathBefore.targetTime,
        DateTime(2026, 8, 24, 8, 0, 0),
      );

      // Exact start time (08:00:00)
      final exactStart = DateTime(2026, 8, 24, 8, 0, 0);
      final statusAtStart = service.calculateDayStatus(
        sampleClasses,
        exactStart,
      );
      final mathAtStart = statusAtStart.classes.firstWhere(
        (cs) => cs.schoolClass.id == 'c1',
      );
      expect(mathAtStart.status, ClassState.current);
      expect(
        mathAtStart.targetTime,
        DateTime(2026, 8, 24, 10, 0, 0),
      );
      expect(statusAtStart.currentClasses.any((cs) => cs.schoolClass.id == 'c1'), isTrue);
    });

    test('4. A class ending triggers the correct state transition', () {
      // 1 second before end
      final beforeEnd = DateTime(2026, 8, 24, 9, 59, 59);
      final statusBefore = service.calculateDayStatus(sampleClasses, beforeEnd);
      final mathBefore = statusBefore.classes.firstWhere(
        (cs) => cs.schoolClass.id == 'c1',
      );
      expect(mathBefore.status, ClassState.current);
      expect(mathBefore.targetTime, DateTime(2026, 8, 24, 10, 0, 0));

      // Exact end time (10:00:00) - consecutive with Physics starting at 10:00:00
      final exactEnd = DateTime(2026, 8, 24, 10, 0, 0);
      final statusAtEnd = service.calculateDayStatus(sampleClasses, exactEnd);
      final mathAtEnd = statusAtEnd.classes.firstWhere(
        (cs) => cs.schoolClass.id == 'c1',
      );
      expect(mathAtEnd.status, ClassState.completed);
      expect(mathAtEnd.targetTime, isNull);

      // Physics starts at exact 10:00:00
      final physicsAt10 = statusAtEnd.classes.firstWhere(
        (cs) => cs.schoolClass.id == 'c2',
      );
      expect(physicsAt10.status, ClassState.current);
      expect(physicsAt10.targetTime, DateTime(2026, 8, 24, 12, 0, 0));
    });

    test('5. The next class is selected correctly across the day', () {
      // At 7:00 AM: Next is Math
      final earlyMorning = DateTime(2026, 8, 24, 7, 0, 0);
      final s1 = service.calculateDayStatus(sampleClasses, earlyMorning);
      expect(s1.currentClasses, isEmpty);
      expect(s1.nextClass!.schoolClass.id, 'c1');

      // At 8:30 AM (during Math): Next is Physics
      final duringMath = DateTime(2026, 8, 24, 8, 30, 0);
      final s2 = service.calculateDayStatus(sampleClasses, duringMath);
      expect(s2.currentClasses.first.schoolClass.id, 'c1');
      expect(s2.nextClass!.schoolClass.id, 'c2');

      // At 12:30 PM (between Physics and Chemistry): Next is Chemistry
      final betweenClasses = DateTime(2026, 8, 24, 12, 30, 0);
      final s3 = service.calculateDayStatus(sampleClasses, betweenClasses);
      expect(s3.currentClasses, isEmpty);
      expect(s3.nextClass!.schoolClass.id, 'c3');

      // At 2:30 PM (during Chemistry): No further classes today
      final duringChem = DateTime(2026, 8, 24, 14, 30, 0);
      final s4 = service.calculateDayStatus(sampleClasses, duringChem);
      expect(s4.currentClasses.first.schoolClass.id, 'c3');
      expect(s4.nextClass, isNull);
    });

    test('6. No more classes today displays the correct state', () {
      // At 5:00 PM (after Chemistry ended at 4:00 PM)
      final afterSchool = DateTime(2026, 8, 24, 17, 0, 0);
      final status = service.calculateDayStatus(sampleClasses, afterSchool);

      expect(status.hasNoMoreClasses, isTrue);
      expect(status.currentClasses, isEmpty);
      expect(status.nextClass, isNull);
      // Tuesday's first class is Math 101 at 8:00 AM
      expect(status.nextDayClass, isNotNull);
      expect(status.nextDayClass!.schoolClass.id, 'c1');
    });

    test('7. Midnight and day changes are handled correctly', () {
      // 11:59:59 PM Monday
      final lateMonday = DateTime(2026, 8, 24, 23, 59, 59);
      final sMonday = service.calculateDayStatus(sampleClasses, lateMonday);
      expect(sMonday.weekday, 1);
      expect(sMonday.hasNoMoreClasses, isTrue);

      // 12:00:00 AM Tuesday
      final midnightTuesday = DateTime(2026, 8, 25, 0, 0, 0);
      final sTuesday = service.calculateDayStatus(
        sampleClasses,
        midnightTuesday,
      );
      expect(sTuesday.weekday, 2);
      // On Tuesday, Math 101 is scheduled (daysOfWeek: [1, 2, 3, 4, 5])
      expect(sTuesday.classes.length, 1);
      expect(sTuesday.classes.first.schoolClass.id, 'c1');
      expect(sTuesday.nextClass!.schoolClass.id, 'c1');
      expect(sTuesday.currentClasses, isEmpty);
    });

    test('8. Saturday and Sunday schedules remain correct', () {
      // Saturday with no classes scheduled
      final saturday = DateTime(2026, 8, 29, 10, 0, 0);
      final sSat = service.calculateDayStatus(sampleClasses, saturday);
      expect(sSat.classes, isEmpty);
      expect(sSat.hasNoMoreClasses, isTrue);
      // Next day with classes is Monday's Math
      expect(sSat.nextDayClass, isNotNull);
      expect(sSat.nextDayClass!.schoolClass.id, 'c1');

      // Sunday with no classes scheduled
      final sunday = DateTime(2026, 8, 30, 10, 0, 0);
      final sSun = service.calculateDayStatus(sampleClasses, sunday);
      expect(sSun.classes, isEmpty);
      expect(sSun.hasNoMoreClasses, isTrue);
      expect(sSun.nextDayClass, isNotNull);
      expect(sSun.nextDayClass!.schoolClass.id, 'c1');

      // Saturday with an explicit Saturday class
      final saturdayClass = SchoolClass(
        id: 'sat-1',
        subject: 'Weekend Robotics',
        room: 'Lab R',
        teacher: 'Prof. Turing',
        daysOfWeek: [6], // Saturday only
        startTime: '09:00 AM',
        endTime: '12:00 PM',
      );
      final classesWithSat = [...sampleClasses, saturdayClass];
      final sSatWithClass = service.calculateDayStatus(
        classesWithSat,
        saturday,
      );
      expect(sSatWithClass.classes.length, 1);
      expect(sSatWithClass.classes.first.schoolClass.id, 'sat-1');
      expect(sSatWithClass.currentClasses.first.schoolClass.id, 'sat-1');
    });

    test('9. Updating a timetable refreshes the widget with fresh payload', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final tempDir = await Directory.systemTemp.createTemp('widget_refresh_test_');
      await HiveService.instance.resetForTesting();
      await HiveService.instance.init(directoryPath: tempDir.path);
      addTearDown(() async {
        await HiveService.instance.resetForTesting();
        await tempDir.delete(recursive: true);
      });

      Map<String, dynamic>? lastPayload;
      const channel = MethodChannel('com.reminderhub.reminder_hub/school_widget');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'updateAllWidgets') {
          lastPayload = (call.arguments as Map).cast<String, dynamic>();
          return true;
        }
        return null;
      });
      addTearDown(() {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      // Add a class to Hive and update widget
      final hive = HiveService.instance;
      await hive.saveSchoolClass(sampleClasses.first);

      final success = await WidgetService.instance.updateSchoolWidget();
      expect(success, isTrue);
      expect(lastPayload, isNotNull);
      expect(lastPayload!['today'], isNotNull);
      expect(lastPayload!['timetable'], isNotNull);

      final todayMap = (lastPayload!['today'] as Map).cast<String, dynamic>();
      expect(todayMap['headerTitle'], "Today's Classes");
      expect(todayMap['allClasses'], isNotEmpty);
    });

    test('10. Repeated widget updates do not create duplicate scheduled work', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final tempDir = await Directory.systemTemp.createTemp('widget_dedup_test_');
      await HiveService.instance.resetForTesting();
      await HiveService.instance.init(directoryPath: tempDir.path);
      addTearDown(() async {
        await HiveService.instance.resetForTesting();
        await tempDir.delete(recursive: true);
      });

      var callCount = 0;
      const channel = MethodChannel('com.reminderhub.reminder_hub/school_widget');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'updateAllWidgets') {
          callCount++;
          return true;
        }
        return null;
      });
      addTearDown(() {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      // Call repeatedly
      for (var i = 0; i < 5; i++) {
        await WidgetService.instance.updateSchoolWidget();
      }
      expect(callCount, 5);
    });

    test('11. An expired class never remains the countdown target', () {
      // Math: 8:00 AM - 10:00 AM.
      // At 10:00:01 AM, Math is expired
      final at100001 = DateTime(2026, 8, 24, 10, 0, 1);
      final status = service.calculateDayStatus(sampleClasses, at100001);

      final mathStatus = status.classes.firstWhere(
        (cs) => cs.schoolClass.id == 'c1',
      );
      expect(mathStatus.status, ClassState.completed);
      expect(mathStatus.targetTime, isNull);

      // The current target must belong to the active Physics class, not Math
      expect(status.currentClasses.first.schoolClass.id, 'c2');
      expect(
        status.currentClasses.first.targetTime,
        DateTime(2026, 8, 24, 12, 0, 0),
      );
    });

    test('12. Returning to app or triggering widget refresh recalculates from actual current time', () {
      // Time 1: 07:50 AM (Upcoming, 10m to start)
      final t1 = DateTime(2026, 8, 24, 7, 50, 0);
      final s1 = service.calculateDayStatus(sampleClasses, t1);
      expect(s1.nextClass!.schoolClass.id, 'c1');
      expect(s1.nextClass!.timeUntilStartFormatted, '10m');

      // Time 2: App returned to foreground at 08:15 AM (Active, 1h 45m remaining)
      final t2 = DateTime(2026, 8, 24, 8, 15, 0);
      final s2 = service.calculateDayStatus(sampleClasses, t2);
      expect(s2.currentClasses.first.schoolClass.id, 'c1');
      expect(s2.currentClasses.first.timeRemainingFormatted, '1h 45m');

      // Time 3: App returned to foreground at 12:15 PM (Math and Physics done, Chemistry next in 1h 45m)
      final t3 = DateTime(2026, 8, 24, 12, 15, 0);
      final s3 = service.calculateDayStatus(sampleClasses, t3);
      expect(s3.currentClasses, isEmpty);
      expect(s3.nextClass!.schoolClass.id, 'c3');
      expect(s3.nextClass!.timeUntilStartFormatted, '1h 45m');
    });
  });
}
