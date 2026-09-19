import '../models/app_models.dart';

/// A class representing the current state of a school class at a given time
class ClassStatus {
  const ClassStatus({
    required this.schoolClass,
    required this.status,
    this.timeRemaining,
    this.timeUntilStart,
  });

  final SchoolClass schoolClass;
  final ClassState status;
  final Duration? timeRemaining; // For current classes: time until end
  final Duration? timeUntilStart; // For next classes: time until start

  String get timeRemainingFormatted {
    if (timeRemaining == null) return '';
    return _formatDuration(timeRemaining!);
  }

  String get timeUntilStartFormatted {
    if (timeUntilStart == null) return '';
    return _formatDuration(timeUntilStart!);
  }

  static String _formatDuration(Duration d) {
    if (d.isNegative) return '0m';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }
}

enum ClassState {
  current,
  next,
  completed,
  upcoming,
}

/// A class to hold the complete timetable status for a given day
class DayTimetableStatus {
  const DayTimetableStatus({
    required this.date,
    required this.weekday,
    required this.classes,
    required this.currentClasses,
    required this.nextClass,
    required this.hasNoMoreClasses,
    required this.nextDayClass,
  });

  final DateTime date;
  final int weekday;
  final List<ClassStatus> classes;
  final List<ClassStatus> currentClasses;
  final ClassStatus? nextClass;
  final bool hasNoMoreClasses;
  final ClassStatus? nextDayClass; // First class of next day with classes
}

/// A class to hold weekly timetable statistics
class WeeklyTimetableStats {
  const WeeklyTimetableStats({
    required this.totalOccurrences,
    required this.classesByDay,
  });

  final int totalOccurrences;
  final Map<int, int> classesByDay; // weekday -> count
}

/// Unified service for all timetable calculations
/// This is the single source of truth for dashboard, timetable screen, and Android widget
class TimetableCalculationService {
  TimetableCalculationService._internal();
  static final TimetableCalculationService instance = TimetableCalculationService._internal();

  /// Parses a time string like "8:00 AM" or "01:30 PM" into minutes from midnight
  static int parseTimeToMinutes(String timeStr) {
    int hour = 8;
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
      hour = 8;
      minute = 0;
    }
    return (hour * 60 + minute).clamp(0, 24 * 60 - 1);
  }

  /// Creates a DateTime for today at the given time string
  static DateTime parseTimeToday(DateTime now, String timeStr) {
    final minutes = parseTimeToMinutes(timeStr);
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// Gets all class occurrences for a specific weekday (1=Mon, ..., 7=Sun)
  /// Each occurrence is a separate entry even if it's the same SchoolClass on different days
  List<SchoolClass> getClassesForDay(List<SchoolClass> allClasses, int weekday) {
    return allClasses.where((c) => c.occursOnDay(weekday)).toList()
      ..sort((a, b) => parseTimeToMinutes(a.startTime).compareTo(parseTimeToMinutes(b.startTime)));
  }

  /// Gets all class occurrences across the week (Mon-Sat)
  /// Returns a flat list where each class-day combination is a separate occurrence
  List<ClassOccurrence> getAllWeeklyOccurrences(List<SchoolClass> allClasses) {
    final occurrences = <ClassOccurrence>[];
    for (final c in allClasses) {
      for (final day in c.daysOfWeek) {
        if (day >= 1 && day <= 6) { // Mon-Sat only for weekly count
          occurrences.add(ClassOccurrence(schoolClass: c, weekday: day));
        }
      }
    }
    // Sort by weekday then start time
    occurrences.sort((a, b) {
      final dayCmp = a.weekday.compareTo(b.weekday);
      if (dayCmp != 0) return dayCmp;
      return parseTimeToMinutes(a.schoolClass.startTime).compareTo(parseTimeToMinutes(b.schoolClass.startTime));
    });
    return occurrences;
  }

  /// Calculates total class occurrences for the week (Mon-Sat)
  int getTotalWeeklyOccurrences(List<SchoolClass> allClasses) {
    return getAllWeeklyOccurrences(allClasses).length;
  }

  /// Gets class count by day for the week
  Map<int, int> getClassesByDay(List<SchoolClass> allClasses) {
    final map = <int, int>{};
    for (int day = 1; day <= 6; day++) {
      map[day] = allClasses.where((c) => c.occursOnDay(day)).length;
    }
    return map;
  }

  /// Calculates the complete timetable status for a given day
  DayTimetableStatus calculateDayStatus(List<SchoolClass> allClasses, DateTime now) {
    final weekday = now.weekday; // 1=Mon, ..., 7=Sun
    final nowMinutes = now.hour * 60 + now.minute;

    // Get all classes for today
    final todayClasses = getClassesForDay(allClasses, weekday);

    // Calculate status for each class
    final classStatuses = <ClassStatus>[];
    for (final c in todayClasses) {
      final startMin = parseTimeToMinutes(c.startTime);
      final endMin = parseTimeToMinutes(c.endTime);
      if (endMin <= startMin) continue; // Invalid class

      ClassState state;
      Duration? timeRemaining;
      Duration? timeUntilStart;

      if (nowMinutes < startMin) {
        // Class hasn't started yet
        state = ClassState.upcoming;
        timeUntilStart = Duration(minutes: startMin - nowMinutes);
      } else if (nowMinutes >= startMin && nowMinutes < endMin) {
        // Class is currently active
        state = ClassState.current;
        timeRemaining = Duration(minutes: endMin - nowMinutes);
      } else {
        // Class has ended
        state = ClassState.completed;
      }

      classStatuses.add(ClassStatus(
        schoolClass: c,
        status: state,
        timeRemaining: timeRemaining,
        timeUntilStart: timeUntilStart,
      ));
    }

    // Find all currently active classes
    final currentClasses = classStatuses.where((cs) => cs.status == ClassState.current).toList();

    // Find the next upcoming class (first one that hasn't started)
    final upcomingClasses = classStatuses.where((cs) => cs.status == ClassState.upcoming).toList();
    ClassStatus? nextClass;
    if (upcomingClasses.isNotEmpty) {
      nextClass = upcomingClasses.first;
      // Update its status to "next"
      nextClass = ClassStatus(
        schoolClass: nextClass.schoolClass,
        status: ClassState.next,
        timeUntilStart: nextClass.timeUntilStart,
      );
    }

    // Check if no more classes today
    final hasNoMoreClasses = currentClasses.isEmpty && upcomingClasses.isEmpty;

    // Find next day's first class (for "no more classes today" state)
    ClassStatus? nextDayClass;
    if (hasNoMoreClasses) {
      for (int dayOffset = 1; dayOffset <= 7; dayOffset++) {
        final checkWeekday = ((weekday + dayOffset - 1) % 7) + 1;
        // Only check Mon-Sat (1-6), skip Sunday (7)
        if (checkWeekday == 7) continue;
        final nextDayClasses = getClassesForDay(allClasses, checkWeekday);
        if (nextDayClasses.isNotEmpty) {
          final firstClass = nextDayClasses.first;
          nextDayClass = ClassStatus(
            schoolClass: firstClass,
            status: ClassState.upcoming,
            timeUntilStart: null, // Not relevant for next day
          );
          break;
        }
      }
    }

    return DayTimetableStatus(
      date: now,
      weekday: weekday,
      classes: classStatuses,
      currentClasses: currentClasses,
      nextClass: nextClass,
      hasNoMoreClasses: hasNoMoreClasses,
      nextDayClass: nextDayClass,
    );
  }

  /// Calculates weekly timetable statistics
  WeeklyTimetableStats calculateWeeklyStats(List<SchoolClass> allClasses) {
    return WeeklyTimetableStats(
      totalOccurrences: getTotalWeeklyOccurrences(allClasses),
      classesByDay: getClassesByDay(allClasses),
    );
  }

  /// Formats a time string for compact display (e.g., "8:00 AM" -> "8:00")
  String formatCompactTime(String timeStr) {
    try {
      final clean = timeStr.trim();
      final withoutLeadingZero = clean.startsWith('0') && clean.length > 1
          ? clean.substring(1)
          : clean;
      return withoutLeadingZero.replaceAll(' AM', '').replaceAll(' PM', '').trim();
    } catch (_) {
      return timeStr;
    }
  }

  /// Gets the display name for a weekday number
  static String getDayName(int weekday, {bool short = false}) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const shortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weekday >= 1 && weekday <= 7) {
      return short ? shortNames[weekday - 1] : names[weekday - 1];
    }
    return '';
  }
}

class ClassOccurrence {
  ClassOccurrence({required this.schoolClass, required this.weekday});
  final SchoolClass schoolClass;
  final int weekday;
}