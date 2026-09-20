import 'dart:math';
import 'package:flutter/material.dart';

enum StudyPhase { study, shortBreak, longBreak, completed }

class StudyMethod {
  StudyMethod({
    required this.id,
    required this.name,
    required this.description,
    required this.studyDurationMinutes,
    required this.shortBreakDurationMinutes,
    required this.longBreakDurationMinutes,
    required this.sessionsBeforeLongBreak,
    required this.type,
  });

  final String id;
  final String name;
  final String description;
  final int studyDurationMinutes;
  final int shortBreakDurationMinutes;
  final int longBreakDurationMinutes;
  final int sessionsBeforeLongBreak;
  final String type;

  StudyMethod copyWith({
    String? id,
    String? name,
    String? description,
    int? studyDurationMinutes,
    int? shortBreakDurationMinutes,
    int? longBreakDurationMinutes,
    int? sessionsBeforeLongBreak,
    String? type,
  }) {
    return StudyMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      studyDurationMinutes: studyDurationMinutes ?? this.studyDurationMinutes,
      shortBreakDurationMinutes:
          shortBreakDurationMinutes ?? this.shortBreakDurationMinutes,
      longBreakDurationMinutes:
          longBreakDurationMinutes ?? this.longBreakDurationMinutes,
      sessionsBeforeLongBreak:
          sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'studyDurationMinutes': studyDurationMinutes,
    'shortBreakDurationMinutes': shortBreakDurationMinutes,
    'longBreakDurationMinutes': longBreakDurationMinutes,
    'sessionsBeforeLongBreak': sessionsBeforeLongBreak,
    'type': type,
  };

  factory StudyMethod.fromJson(Map<String, dynamic> json) => StudyMethod(
    id:
        (json['id'] as String?) ??
        'custom_${DateTime.now().millisecondsSinceEpoch}',
    name: (json['name'] as String?) ?? 'Custom',
    description: (json['description'] as String?) ?? '',
    studyDurationMinutes: (json['studyDurationMinutes'] as num?)?.toInt() ?? 25,
    shortBreakDurationMinutes:
        (json['shortBreakDurationMinutes'] as num?)?.toInt() ?? 5,
    longBreakDurationMinutes:
        (json['longBreakDurationMinutes'] as num?)?.toInt() ?? 15,
    sessionsBeforeLongBreak:
        (json['sessionsBeforeLongBreak'] as num?)?.toInt() ?? 4,
    type: (json['type'] as String?) ?? 'custom',
  );
}

class StudySessionRecord {
  StudySessionRecord({
    required this.id,
    required this.subject,
    required this.methodName,
    required this.methodType,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.completedSessions,
    required this.completed,
  });

  final String id;
  final String subject;
  final String methodName;
  final String methodType;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMinutes;
  final int completedSessions;
  final bool completed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'methodName': methodName,
    'methodType': methodType,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'durationMinutes': durationMinutes,
    'completedSessions': completedSessions,
    'completed': completed,
  };

  factory StudySessionRecord.fromJson(
    Map<String, dynamic> json,
  ) => StudySessionRecord(
    id: (json['id'] as String?) ?? 'study_session',
    subject: (json['subject'] as String?) ?? 'General',
    methodName: (json['methodName'] as String?) ?? 'Pomodoro',
    methodType: (json['methodType'] as String?) ?? 'pomodoro',
    startedAt:
        DateTime.tryParse((json['startedAt'] as String?) ?? '') ??
        DateTime.now(),
    endedAt:
        DateTime.tryParse((json['endedAt'] as String?) ?? '') ?? DateTime.now(),
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
    completed: json['completed'] is bool ? json['completed'] as bool : false,
  );
}

class StudySettings {
  StudySettings({
    this.selectedMethodId = 'pomodoro',
    this.selectedSubject = '',
    this.defaultSessions = 4,
    this.notificationsEnabled = true,
    this.customMethodId,
    this.customFocusMinutes = 45,
    this.customBreakMinutes = 10,
    this.customLongBreakMinutes = 20,
  });

  final String selectedMethodId;
  final String selectedSubject;
  final int defaultSessions;
  final bool notificationsEnabled;
  final String? customMethodId;
  final int customFocusMinutes;
  final int customBreakMinutes;
  final int customLongBreakMinutes;

  StudySettings copyWith({
    String? selectedMethodId,
    String? selectedSubject,
    int? defaultSessions,
    bool? notificationsEnabled,
    String? customMethodId,
    int? customFocusMinutes,
    int? customBreakMinutes,
    int? customLongBreakMinutes,
  }) {
    return StudySettings(
      selectedMethodId: selectedMethodId ?? this.selectedMethodId,
      selectedSubject: selectedSubject ?? this.selectedSubject,
      defaultSessions: defaultSessions ?? this.defaultSessions,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      customMethodId: customMethodId ?? this.customMethodId,
      customFocusMinutes: customFocusMinutes ?? this.customFocusMinutes,
      customBreakMinutes: customBreakMinutes ?? this.customBreakMinutes,
      customLongBreakMinutes:
          customLongBreakMinutes ?? this.customLongBreakMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'selectedMethodId': selectedMethodId,
    'selectedSubject': selectedSubject,
    'defaultSessions': defaultSessions,
    'notificationsEnabled': notificationsEnabled,
    'customMethodId': customMethodId,
    'customFocusMinutes': customFocusMinutes,
    'customBreakMinutes': customBreakMinutes,
    'customLongBreakMinutes': customLongBreakMinutes,
  };

  factory StudySettings.fromJson(Map<String, dynamic> json) => StudySettings(
    selectedMethodId: (json['selectedMethodId'] as String?) ?? 'pomodoro',
    selectedSubject: (json['selectedSubject'] as String?) ?? '',
    defaultSessions: (json['defaultSessions'] as num?)?.toInt() ?? 4,
    notificationsEnabled: json['notificationsEnabled'] is bool
        ? json['notificationsEnabled'] as bool
        : true,
    customMethodId: json['customMethodId'] as String?,
    customFocusMinutes: (json['customFocusMinutes'] as num?)?.toInt() ?? 45,
    customBreakMinutes: (json['customBreakMinutes'] as num?)?.toInt() ?? 10,
    customLongBreakMinutes:
        (json['customLongBreakMinutes'] as num?)?.toInt() ?? 20,
  );
}

class StudyTimerState {
  StudyTimerState({
    required this.subject,
    required this.method,
    required this.totalSessions,
    required this.currentSession,
    required this.phase,
    required this.remainingSeconds,
    required this.isRunning,
    required this.lastUpdatedAt,
    required this.completed,
    this.statusMessage = 'Ready to focus',
  });

  final String subject;
  final StudyMethod method;
  final int totalSessions;
  final int currentSession;
  final StudyPhase phase;
  final int remainingSeconds;
  final bool isRunning;
  final DateTime lastUpdatedAt;
  final bool completed;
  final String statusMessage;

  Duration get remainingDuration => Duration(seconds: max(0, remainingSeconds));

  String get formattedRemaining {
    final hours = remainingDuration.inHours;
    final minutes = remainingDuration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remainingDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  bool get isStudyPhase => phase == StudyPhase.study;
  bool get isBreakPhase =>
      phase == StudyPhase.shortBreak || phase == StudyPhase.longBreak;

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'method': method.toJson(),
    'totalSessions': totalSessions,
    'currentSession': currentSession,
    'phase': phase.name,
    'remainingSeconds': remainingSeconds,
    'isRunning': isRunning,
    'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    'completed': completed,
    'statusMessage': statusMessage,
  };

  factory StudyTimerState.fromJson(
    Map<String, dynamic> json,
  ) => StudyTimerState(
    subject: (json['subject'] as String?) ?? 'General',
    method: StudyMethod.fromJson(
      Map<String, dynamic>.from(json['method'] as Map? ?? {}),
    ),
    totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 4,
    currentSession: (json['currentSession'] as num?)?.toInt() ?? 1,
    phase: StudyPhase.values.firstWhere(
      (value) => value.name == (json['phase'] as String? ?? 'study'),
      orElse: () => StudyPhase.study,
    ),
    remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 1500,
    isRunning: json['isRunning'] is bool ? json['isRunning'] as bool : false,
    lastUpdatedAt:
        DateTime.tryParse((json['lastUpdatedAt'] as String?) ?? '') ??
        DateTime.now(),
    completed: json['completed'] is bool ? json['completed'] as bool : false,
    statusMessage: (json['statusMessage'] as String?) ?? 'Ready to focus',
  );

  factory StudyTimerState.initial({
    required StudyMethod method,
    required String subject,
    required int totalSessions,
    required DateTime startedAt,
  }) {
    return StudyTimerState(
      subject: subject,
      method: method,
      totalSessions: max(1, totalSessions),
      currentSession: 1,
      phase: StudyPhase.study,
      remainingSeconds: method.studyDurationMinutes * 60,
      isRunning: true,
      lastUpdatedAt: startedAt,
      completed: false,
      statusMessage: 'Focus session started',
    );
  }

  StudyTimerState copyWith({
    String? subject,
    StudyMethod? method,
    int? totalSessions,
    int? currentSession,
    StudyPhase? phase,
    int? remainingSeconds,
    bool? isRunning,
    DateTime? lastUpdatedAt,
    bool? completed,
    String? statusMessage,
  }) {
    return StudyTimerState(
      subject: subject ?? this.subject,
      method: method ?? this.method,
      totalSessions: totalSessions ?? this.totalSessions,
      currentSession: currentSession ?? this.currentSession,
      phase: phase ?? this.phase,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      completed: completed ?? this.completed,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  StudyTimerState withElapsed(DateTime now, StudyMethod methodOverride) {
    final elapsedSeconds = now.difference(lastUpdatedAt).inSeconds;
    if (elapsedSeconds <= 0) {
      return copyWith(method: methodOverride, lastUpdatedAt: now);
    }

    var next = copyWith(method: methodOverride, lastUpdatedAt: now);
    var remaining = next.remainingSeconds - elapsedSeconds;

    while (remaining <= 0) {
      if (next.phase == StudyPhase.study) {
        final currentTarget = next.currentSession;
        if (currentTarget >= next.totalSessions) {
          next = next.copyWith(
            phase: StudyPhase.shortBreak,
            remainingSeconds: next.method.shortBreakDurationMinutes * 60,
            isRunning: true,
            statusMessage: 'Time for a short break.',
          );
          remaining += next.method.shortBreakDurationMinutes * 60;
          continue;
        }

        next = next.copyWith(
          phase: StudyPhase.shortBreak,
          remainingSeconds: next.method.shortBreakDurationMinutes * 60,
          isRunning: true,
          statusMessage: 'Time for a short break.',
        );
        remaining += next.method.shortBreakDurationMinutes * 60;
        continue;
      }

      if (next.phase == StudyPhase.shortBreak) {
        if (next.currentSession >= next.totalSessions) {
          next = next.copyWith(
            phase: StudyPhase.longBreak,
            remainingSeconds: next.method.longBreakDurationMinutes * 60,
            isRunning: true,
            statusMessage: 'Great work! Long break started.',
          );
          remaining += next.method.longBreakDurationMinutes * 60;
          continue;
        }

        final nextSession = next.currentSession + 1;
        next = next.copyWith(
          phase: StudyPhase.study,
          currentSession: nextSession,
          remainingSeconds: next.method.studyDurationMinutes * 60,
          isRunning: true,
          statusMessage: 'Next study session started.',
        );
        remaining += next.method.studyDurationMinutes * 60;
        continue;
      }

      next = next.copyWith(
        phase: StudyPhase.study,
        currentSession: 1,
        remainingSeconds: next.method.studyDurationMinutes * 60,
        isRunning: true,
        statusMessage: 'Fresh cycle started.',
      );
      remaining += next.method.studyDurationMinutes * 60;
      continue;
    }

    return next.copyWith(
      remainingSeconds: remaining,
      isRunning: next.isRunning,
      lastUpdatedAt: now,
    );
  }
}

class StudyStatistics {
  StudyStatistics({
    required this.totalStudyMinutesToday,
    required this.totalStudyMinutesThisWeek,
    required this.totalSessions,
    required this.mostStudiedSubject,
    required this.currentStreak,
    required this.averageSessionDurationMinutes,
  });

  final int totalStudyMinutesToday;
  final int totalStudyMinutesThisWeek;
  final int totalSessions;
  final String mostStudiedSubject;
  final int currentStreak;
  final int averageSessionDurationMinutes;
}

String formatStudyDuration(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}

String formatStudyClock(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String buildStudyPhaseText(StudyPhase phase) {
  switch (phase) {
    case StudyPhase.study:
      return 'Focus Session';
    case StudyPhase.shortBreak:
      return 'Short Break';
    case StudyPhase.longBreak:
      return 'Long Break';
    case StudyPhase.completed:
      return 'Session Complete';
  }
}

Color studyPhaseColor(StudyPhase phase) {
  switch (phase) {
    case StudyPhase.study:
      return const Color(0xFF4F46E5);
    case StudyPhase.shortBreak:
      return const Color(0xFF14B8A6);
    case StudyPhase.longBreak:
      return const Color(0xFFF59E0B);
    case StudyPhase.completed:
      return const Color(0xFF22C55E);
  }
}
