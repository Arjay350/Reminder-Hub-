import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/utilities/formatters.dart';
import '../models/app_models.dart';
import 'hive_service.dart';
import 'timetable_calculation_service.dart';

class WidgetService {
  WidgetService._internal() {
    _initChannel();
  }
  static final WidgetService instance = WidgetService._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.reminderhub.reminder_hub/school_widget',
  );

  // Bills widget uses a different channel
  static const MethodChannel _billsChannel = MethodChannel(
    'com.reminderhub.reminder_hub/bills_widget',
  );

  final TimetableCalculationService _timetableService =
      TimetableCalculationService.instance;

  void Function(String route)? onNavigationRequested;

  void _initChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNavigateTo') {
        final route = (call.arguments as Map?)?['route'] as String?;
        if (route != null) {
          onNavigationRequested?.call(route);
        }
      }
    });
  }

  Future<String?> getLaunchRoute() async {
    if (kIsWeb) return null;
    // A widget can start the Android activity before the Flutter method
    // channel has finished registering. Retry briefly so cold-start taps are
    // delivered after the app has opened instead of being lost.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final route = await _channel.invokeMethod<String>('getLaunchRoute');
        if (route != null && route.isNotEmpty) return route;
        return null;
      } on PlatformException {
        if (attempt == 2) return null;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      } on MissingPluginException {
        if (attempt == 2) return null;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    return null;
  }

  /// Updates the Bills native Android Home Screen Widget
  /// directly from the existing Bill Hive box (single source of truth).
  /// Uses displayStatus/displayDueDate respecting reminder activation window.
  Future<void> updateBillsWidget() async {
    try {
      final hive = HiveService.instance;
      await hive.ensureInitialized();

      final List<Bill> allBills = hive.getBills();
      final now = DateTime.now();

      // Compute display status for each bill respecting activation window
      final billsData = <Map<String, dynamic>>[];
      var unpaidCount = 0;
      var overdueCount = 0;

      for (final bill in allBills) {
        final displayStatus = bill.getDisplayStatus(referenceDate: now);
        final displayDueDate = bill.getDisplayDueDate(referenceDate: now);
        final isOverdue = displayStatus == 'overdue';
        final isUnpaid = displayStatus == 'unpaid';

        if (isUnpaid) unpaidCount++;
        if (isOverdue) overdueCount++;

        billsData.add({
          'id': bill.id,
          'name': bill.name,
          'amount': bill.amount,
          'dueDate': Formatters.formatDate(displayDueDate),
          'dueDateIso': displayDueDate.toIso8601String(),
          'rawDueDateIso': bill.dueDate.toIso8601String(),
          'status': displayStatus,
          'repeat': bill.repeat,
          'reminderSchedule': bill.reminderSchedule,
          'paid': bill.paid,
          'isRecurring': bill.isRecurring,
          'advanceDays': bill.getReminderAdvanceDays(),
          'category': bill.category,
        });
      }

      // Sort: Overdue first, then Unpaid, then Upcoming, then Paid
      billsData.sort((a, b) {
        final statusOrder = {
          'overdue': 0,
          'unpaid': 1,
          'upcoming': 2,
          'paid': 3,
        };
        final aOrder = statusOrder[a['status']] ?? 4;
        final bOrder = statusOrder[b['status']] ?? 4;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        return (a['dueDateIso'] as String).compareTo(b['dueDateIso'] as String);
      });

      final totalBills = allBills.length;

      final billsPayload = {
        'bills': billsData,
        'totalBills': totalBills,
        'unpaidCount': unpaidCount,
        'overdueCount': overdueCount,
        'timestamp': now.millisecondsSinceEpoch,
      };

      if (!kIsWeb) {
        await _billsChannel.invokeMethod('updateAllWidgets', billsPayload);
      }
    } catch (e) {
      debugPrint('WidgetService.updateBillsWidget error: $e');
    }
  }

  /// Updates both native Android Home Screen Widgets (Today's Classes & Weekly Timetable)
  /// directly from the existing SchoolClass Hive box (single source of truth).
  Future<void> updateSchoolWidget() async {
    try {
      final hive = HiveService.instance;
      await hive.ensureInitialized();

      final List<SchoolClass> allClasses = hive.getSchoolClasses();
      final now = DateTime.now();

      // Use the unified timetable calculation service
      final dayStatus = _timetableService.calculateDayStatus(allClasses, now);
      final weeklyStats = _timetableService.calculateWeeklyStats(allClasses);

      // ── 1. Today's Classes Payload ──────────────────────────────────────────
      final todayClasses = dayStatus.classes
          .map((cs) => cs.schoolClass)
          .toList();

      // Determine next class text for widget
      String nextClassText = 'Tap to open schedule';
      if (dayStatus.currentClasses.isNotEmpty) {
        if (dayStatus.currentClasses.length == 1) {
          nextClassText =
              'NOW: ${dayStatus.currentClasses.first.schoolClass.subject}';
        } else {
          nextClassText =
              'NOW: ${dayStatus.currentClasses.length} classes in progress';
        }
      } else if (dayStatus.nextClass != null) {
        final next = dayStatus.nextClass!;
        nextClassText =
            'Next: ${next.schoolClass.subject} at ${next.schoolClass.startTime}';
        if (next.timeUntilStart != null) {
          nextClassText += ' (${next.timeUntilStartFormatted})';
        }
      } else if (dayStatus.hasNoMoreClasses) {
        if (dayStatus.nextDayClass != null) {
          nextClassText =
              'Done today. Next: ${dayStatus.nextDayClass!.schoolClass.subject} tomorrow ${dayStatus.nextDayClass!.schoolClass.startTime}';
        } else {
          nextClassText = 'All classes done for the week';
        }
      } else {
        nextClassText = 'No classes today';
      }

      final dateFormatted = DateFormat('EEEE, MMM d').format(now);

      final todayClassList = todayClasses.map((c) {
        final detailsList = <String>[];
        if (c.courseCode.trim().isNotEmpty) {
          detailsList.add(c.courseCode.trim());
        }
        if (c.room.trim().isNotEmpty) {
          detailsList.add(c.room.trim());
        }
        if (c.teacher.trim().isNotEmpty) {
          detailsList.add(c.teacher.trim());
        }

        final cs = dayStatus.classes.firstWhere(
          (status) => status.schoolClass.id == c.id,
          orElse: () =>
              ClassStatus(schoolClass: c, status: ClassState.upcoming),
        );

        return {
          'id': c.id,
          'time': c.startTime,
          'startTime': c.startTime,
          'endTime': c.endTime,
          'subject': c.subject,
          'courseCode': c.courseCode,
          'room': c.room,
          'teacher': c.teacher,
          'daysOfWeek': c.daysOfWeek,
          'details': detailsList.isNotEmpty
              ? detailsList.join(' • ')
              : (c.room.isNotEmpty ? c.room : 'Class Session'),
          'color': c.colorValue,
          'colorValue': c.colorValue,
          'status': cs.status.name, // current, next, upcoming, completed
          'timeRemaining': cs.timeRemainingFormatted,
          'timeUntilStart': cs.timeUntilStartFormatted,
        };
      }).toList();

      final allClassesJsonList = allClasses
          .map(
            (c) => {
              'id': c.id,
              'subject': c.subject,
              'courseCode': c.courseCode,
              'teacher': c.teacher,
              'room': c.room,
              'daysOfWeek': c.daysOfWeek,
              'startTime': c.startTime,
              'endTime': c.endTime,
              'colorValue': c.colorValue,
              'reminderBefore': c.reminderBefore,
              'notes': c.notes,
            },
          )
          .toList();

      final dayModesMap = hive.getDayClassModes();
      final dayModesJson = {
        '1': dayModesMap[1] ?? DayClassMode.f2f,
        '2': dayModesMap[2] ?? DayClassMode.f2f,
        '3': dayModesMap[3] ?? DayClassMode.f2f,
        '4': dayModesMap[4] ?? DayClassMode.f2f,
        '5': dayModesMap[5] ?? DayClassMode.f2f,
        '6': dayModesMap[6] ?? DayClassMode.f2f,
        '7': dayModesMap[7] ?? DayClassMode.f2f,
      };

      final todayPayload = {
        'headerTitle': "Today's Classes",
        'dateSubtitle': dateFormatted,
        'badgeText': todayClasses.isEmpty
            ? 'Free Day'
            : '${todayClasses.length} ${todayClasses.length == 1 ? "Class" : "Classes"}',
        'nextClassText': nextClassText,
        'dateFooter': DateFormat('MMM d').format(now),
        'classes': todayClassList,
        'allClasses': allClassesJsonList,
        'dayModes': dayModesJson,
        'timestamp': now.millisecondsSinceEpoch,
      };

      // ── 2. Weekly Timetable Payload (Monday - Sunday) ────────────────────
      List<Map<String, dynamic>> extractDayClasses(int dayNum) {
        final dayList = allClasses.where((c) => c.occursOnDay(dayNum)).toList();
        dayList.sort((a, b) {
          final aTime = TimetableCalculationService.parseTimeToday(
            now,
            a.startTime,
          );
          final bTime = TimetableCalculationService.parseTimeToday(
            now,
            b.startTime,
          );
          return aTime.compareTo(bTime);
        });
        return dayList
            .map(
              (c) => {
                'time': _timetableService.formatCompactTime(c.startTime),
                'subject': c.courseCode.isNotEmpty ? c.courseCode : c.subject,
                'fullSubject': c.subject,
                'courseCode': c.courseCode,
                'room': c.room,
              },
            )
            .toList();
      }

      final timetableDays = {
        'mon': extractDayClasses(1),
        'tue': extractDayClasses(2),
        'wed': extractDayClasses(3),
        'thu': extractDayClasses(4),
        'fri': extractDayClasses(5),
        'sat': extractDayClasses(6),
        'sun': extractDayClasses(7),
      };

      final timetableDayModes = {
        'mon': timetableDays['mon']!.isEmpty
            ? 'No Classes'
            : DayClassMode.getShortName(dayModesMap[1] ?? DayClassMode.f2f),
        'tue': timetableDays['tue']!.isEmpty
            ? 'No Classes'
            : DayClassMode.getShortName(dayModesMap[2] ?? DayClassMode.f2f),
        'wed': timetableDays['wed']!.isEmpty
            ? 'No Classes'
            : DayClassMode.getShortName(dayModesMap[3] ?? DayClassMode.f2f),
        'thu': timetableDays['thu']!.isEmpty
            ? 'No Classes'
            : DayClassMode.getShortName(dayModesMap[4] ?? DayClassMode.f2f),
        'fri': timetableDays['fri']!.isEmpty
            ? 'No Classes'
            : DayClassMode.getShortName(dayModesMap[5] ?? DayClassMode.f2f),
        'sat': timetableDays['sat']!.isEmpty
            ? 'No Classes'
            : DayClassMode.getShortName(dayModesMap[6] ?? DayClassMode.f2f),
        'sun': timetableDays['sun']!.isEmpty
            ? 'No Classes'
            : DayClassMode.getShortName(dayModesMap[7] ?? DayClassMode.f2f),
      };

      final timetablePayload = {
        'headerTitle': 'WEEKLY TIMETABLE',
        'subtitle': 'Mon – Sun Schedule',
        'badgeText': allClasses.isEmpty
            ? 'No Classes'
            : '${weeklyStats.totalOccurrences} Total (${weeklyStats.classesByDay.values.fold(0, (a, b) => a + b)} occurrences)',
        'footerInfo': 'Tap to open Reminder Hub',
        'footerBrand': 'Reminder Hub',
        'totalClasses': weeklyStats.totalOccurrences,
        'classesByDay': weeklyStats.classesByDay,
        'days': timetableDays,
        'dayModes': timetableDayModes,
      };

      if (!kIsWeb) {
        await _channel.invokeMethod('updateAllWidgets', {
          'today': todayPayload,
          'timetable': timetablePayload,
        });
      }
    } catch (e) {
      debugPrint('WidgetService.updateSchoolWidget error: $e');
    }
  }
}
