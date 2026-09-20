import 'dart:convert';

import '../models/study_models.dart';
import 'hive_service.dart';
import 'notification_service.dart';

class StudyService {
  static final StudyService instance = StudyService._internal();
  StudyService._internal();

  final HiveService _hive = HiveService.instance;

  static List<StudyMethod> get defaultStudyMethods => [
    StudyMethod(
      id: 'light',
      name: '15/5 — Light Study',
      description: 'Short study focus with a quick break.',
      studyDurationMinutes: 15,
      shortBreakDurationMinutes: 5,
      longBreakDurationMinutes: 15,
      sessionsBeforeLongBreak: 4,
      type: 'light',
    ),
    StudyMethod(
      id: 'pomodoro',
      name: 'Pomodoro',
      description: 'Classic focus with short and long breaks.',
      studyDurationMinutes: 25,
      shortBreakDurationMinutes: 5,
      longBreakDurationMinutes: 15,
      sessionsBeforeLongBreak: 4,
      type: 'pomodoro',
    ),
    StudyMethod(
      id: 'fifty_ten',
      name: '50/10',
      description: 'Balanced deep work and rest cycle.',
      studyDurationMinutes: 50,
      shortBreakDurationMinutes: 10,
      longBreakDurationMinutes: 20,
      sessionsBeforeLongBreak: 3,
      type: 'fifty_ten',
    ),
    StudyMethod(
      id: 'ninety_minute',
      name: '90-Minute Focus',
      description: 'Longer deep-work block with a recovery break.',
      studyDurationMinutes: 90,
      shortBreakDurationMinutes: 20,
      longBreakDurationMinutes: 20,
      sessionsBeforeLongBreak: 2,
      type: 'ninety_minute',
    ),
    StudyMethod(
      id: 'custom',
      name: 'Custom Timer',
      description: 'User-defined study and break lengths.',
      studyDurationMinutes: 45,
      shortBreakDurationMinutes: 10,
      longBreakDurationMinutes: 20,
      sessionsBeforeLongBreak: 3,
      type: 'custom',
    ),
  ];

  Future<void> ensureInitialized() async {
    await _hive.ensureInitialized();
  }

  StudyMethod findMethod(String id) {
    final methods = getStudyMethods();
    for (final method in methods) {
      if (method.id == id) return method;
    }
    return methods.first;
  }

  List<StudyMethod> getStudyMethods() {
    final stored = _hive.getStudyMethods();
    if (stored.isEmpty) {
      for (final method in defaultStudyMethods) {
        _hive.saveStudyMethod(method);
      }
      return List<StudyMethod>.from(defaultStudyMethods);
    }
    return stored;
  }

  Future<void> saveStudyMethod(StudyMethod method) async {
    await ensureInitialized();
    await _hive.saveStudyMethod(method);
  }

  Future<void> deleteStudyMethod(String id) async {
    await ensureInitialized();
    await _hive.deleteStudyMethod(id);
  }

  StudySettings getStudySettings() {
    return _hive.getStudySettings();
  }

  Future<void> saveStudySettings(StudySettings settings) async {
    await ensureInitialized();
    await _hive.saveStudySettings(settings);
  }

  StudyTimerState? getActiveTimerState() {
    return _hive.getStudyTimerState();
  }

  Future<void> saveActiveTimerState(StudyTimerState state) async {
    await ensureInitialized();
    await _hive.saveStudyTimerState(state);
  }

  Future<void> clearActiveTimerState() async {
    await ensureInitialized();
    await _hive.clearStudyTimerState();
  }

  List<StudySessionRecord> getStudyHistory() {
    return _hive.getStudyHistory();
  }

  List<String> getStudySubjects() {
    final subjects = <String>{};
    for (final schoolClass in _hive.getSchoolClasses()) {
      final subject = schoolClass.subject.trim();
      if (subject.isNotEmpty) subjects.add(subject);
    }
    subjects.addAll(_hive.getStudySubjects());
    for (final session in getStudyHistory()) {
      final subject = session.subject.trim();
      if (subject.isNotEmpty && subject.toLowerCase() != 'general') {
        subjects.add(subject);
      }
    }
    return subjects.toList()..sort();
  }

  Future<void> saveStudySubject(String subject) async {
    await _hive.saveStudySubject(subject);
  }

  Future<void> saveStudyHistoryRecord(StudySessionRecord record) async {
    await ensureInitialized();
    await _hive.saveStudyHistoryRecord(record);
  }

  StudyTimerState createInitialState({
    required StudyMethod method,
    required String subject,
    int totalSessions = 4,
    DateTime? startedAt,
  }) {
    final now = startedAt ?? DateTime.now();
    return StudyTimerState.initial(
      method: method,
      subject: subject.trim().isNotEmpty ? subject.trim() : 'General',
      totalSessions: totalSessions,
      startedAt: now,
    );
  }

  StudyTimerState syncWithNow(StudyTimerState state, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    if (!state.isRunning || state.completed) {
      return state.copyWith(lastUpdatedAt: refNow);
    }

    final elapsed = refNow.difference(state.lastUpdatedAt).inSeconds;
    if (elapsed <= 0) {
      return state.copyWith(lastUpdatedAt: refNow);
    }

    final remaining = state.remainingSeconds - elapsed;
    if (remaining > 0) {
      return state.copyWith(
        remainingSeconds: remaining,
        lastUpdatedAt: refNow,
        statusMessage: _phaseStatusText(state.phase),
      );
    }

    return advancePhase(state, now: refNow);
  }

  StudyTimerState pauseTimer(StudyTimerState state, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    final synced = syncWithNow(state, now: refNow);
    return synced.copyWith(
      isRunning: false,
      lastUpdatedAt: refNow,
      statusMessage: 'Paused',
    );
  }

  StudyTimerState resumeTimer(StudyTimerState state, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    final synced = syncWithNow(state, now: refNow);
    if (synced.completed) {
      return synced;
    }
    return synced.copyWith(
      isRunning: true,
      lastUpdatedAt: refNow,
      statusMessage: _phaseStatusText(synced.phase),
    );
  }

  StudyTimerState skipPhase(StudyTimerState state, {DateTime? now}) {
    final refNow = now ?? DateTime.now();
    if (state.phase == StudyPhase.study) {
      return state.copyWith(
        phase: state.currentSession >= state.totalSessions
            ? StudyPhase.longBreak
            : StudyPhase.shortBreak,
        remainingSeconds: _phaseDurationSeconds(
          state.currentSession >= state.totalSessions
              ? StudyPhase.longBreak
              : StudyPhase.shortBreak,
          state.method,
        ),
        isRunning: true,
        lastUpdatedAt: refNow,
        statusMessage: state.currentSession >= state.totalSessions
            ? 'Long break started.'
            : 'Time for a short break.',
      );
    }

    if (state.phase == StudyPhase.shortBreak) {
      final shouldLongBreak = state.currentSession >= state.totalSessions;
      return state.copyWith(
        phase: shouldLongBreak ? StudyPhase.longBreak : StudyPhase.study,
        currentSession: shouldLongBreak
            ? state.currentSession
            : state.currentSession + 1,
        remainingSeconds: _phaseDurationSeconds(
          shouldLongBreak ? StudyPhase.longBreak : StudyPhase.study,
          state.method,
        ),
        isRunning: true,
        lastUpdatedAt: refNow,
        statusMessage: shouldLongBreak
            ? 'Great work! Long break started.'
            : 'Next study session started.',
      );
    }

    return state.copyWith(
      phase: StudyPhase.study,
      currentSession: 1,
      remainingSeconds: _phaseDurationSeconds(StudyPhase.study, state.method),
      isRunning: true,
      lastUpdatedAt: refNow,
      statusMessage: 'Fresh cycle started.',
    );
  }

  StudyTimerState resetTimer(StudyTimerState state) {
    return state.copyWith(
      currentSession: 1,
      phase: StudyPhase.study,
      remainingSeconds: state.method.studyDurationMinutes * 60,
      isRunning: false,
      completed: false,
      lastUpdatedAt: DateTime.now(),
      statusMessage: 'Session reset',
    );
  }

  StudyTimerState advancePhase(StudyTimerState state, {DateTime? now}) {
    final refNow = now ?? DateTime.now();

    if (state.phase == StudyPhase.study) {
      if (state.currentSession >= state.totalSessions) {
        return state.copyWith(
          phase: StudyPhase.shortBreak,
          remainingSeconds: _phaseDurationSeconds(
            StudyPhase.shortBreak,
            state.method,
          ),
          isRunning: true,
          lastUpdatedAt: refNow,
          statusMessage: 'Time for a short break.',
        );
      }

      return state.copyWith(
        phase: StudyPhase.shortBreak,
        remainingSeconds: _phaseDurationSeconds(
          StudyPhase.shortBreak,
          state.method,
        ),
        isRunning: true,
        lastUpdatedAt: refNow,
        statusMessage: 'Time for a short break.',
      );
    }

    if (state.phase == StudyPhase.shortBreak) {
      if (state.currentSession >= state.totalSessions) {
        return state.copyWith(
          phase: StudyPhase.longBreak,
          remainingSeconds: _phaseDurationSeconds(
            StudyPhase.longBreak,
            state.method,
          ),
          isRunning: true,
          lastUpdatedAt: refNow,
          statusMessage: 'Great work! Long break started.',
        );
      }

      return state.copyWith(
        phase: StudyPhase.study,
        currentSession: state.currentSession + 1,
        remainingSeconds: _phaseDurationSeconds(StudyPhase.study, state.method),
        isRunning: true,
        lastUpdatedAt: refNow,
        statusMessage: 'Next study session started.',
      );
    }

    if (state.phase == StudyPhase.longBreak) {
      return state.copyWith(
        phase: StudyPhase.study,
        currentSession: 1,
        remainingSeconds: _phaseDurationSeconds(StudyPhase.study, state.method),
        isRunning: true,
        lastUpdatedAt: refNow,
        statusMessage: 'Fresh cycle started.',
      );
    }

    return state.copyWith(
      phase: StudyPhase.completed,
      remainingSeconds: 0,
      isRunning: false,
      completed: true,
      lastUpdatedAt: refNow,
      statusMessage: 'Study session complete!',
    );
  }

  Future<void> notifyPhaseChange(String title, String body) async {
    if (!HiveService.instance.getStudySettings().notificationsEnabled) return;
    await NotificationService.instance.showNotification(
      id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title: title,
      body: body,
      channelId: NotificationService.channelIdGeneral,
      channelName: NotificationService.channelNameGeneral,
      channelDescription: NotificationService.channelDescGeneral,
    );
  }

  StudyStatistics calculateStatistics({DateTime? now}) {
    final refNow = now ?? DateTime.now();
    final sessions = getStudyHistory();
    final todayStart = DateTime(refNow.year, refNow.month, refNow.day);
    final weekStart = todayStart.subtract(Duration(days: refNow.weekday - 1));

    final todayMinutes = sessions
        .where((session) => !session.endedAt.isBefore(todayStart))
        .fold<int>(0, (sum, session) => sum + session.durationMinutes);
    final weekMinutes = sessions
        .where((session) => !session.endedAt.isBefore(weekStart))
        .fold<int>(0, (sum, session) => sum + session.durationMinutes);

    final subjectCounts = <String, int>{};
    for (final session in sessions) {
      subjectCounts[session.subject] =
          (subjectCounts[session.subject] ?? 0) + 1;
    }
    final mostStudiedSubject = subjectCounts.isEmpty
        ? 'N/A'
        : subjectCounts.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;

    int streak = 0;
    var cursor = DateTime(refNow.year, refNow.month, refNow.day);
    while (true) {
      final hasStudyOnDay = sessions.any(
        (session) =>
            session.startedAt.year == cursor.year &&
            session.startedAt.month == cursor.month &&
            session.startedAt.day == cursor.day,
      );
      if (!hasStudyOnDay) {
        break;
      }
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final averageSessionDuration = sessions.isEmpty
        ? 0
        : (sessions.fold<int>(
                    0,
                    (sum, session) => sum + session.durationMinutes,
                  ) /
                  sessions.length)
              .round();

    return StudyStatistics(
      totalStudyMinutesToday: todayMinutes,
      totalStudyMinutesThisWeek: weekMinutes,
      totalSessions: sessions.length,
      mostStudiedSubject: mostStudiedSubject,
      currentStreak: streak,
      averageSessionDurationMinutes: averageSessionDuration,
    );
  }

  int _phaseDurationSeconds(StudyPhase phase, StudyMethod method) {
    switch (phase) {
      case StudyPhase.study:
        return method.studyDurationMinutes * 60;
      case StudyPhase.shortBreak:
        return method.shortBreakDurationMinutes * 60;
      case StudyPhase.longBreak:
        return method.longBreakDurationMinutes * 60;
      case StudyPhase.completed:
        return 0;
    }
  }

  String _phaseStatusText(StudyPhase phase) {
    switch (phase) {
      case StudyPhase.study:
        return 'Focus session in progress';
      case StudyPhase.shortBreak:
        return 'Short break';
      case StudyPhase.longBreak:
        return 'Long break';
      case StudyPhase.completed:
        return 'Study session complete';
    }
  }
}

String buildStudySessionSummary(StudySessionRecord record) {
  final subject = record.subject.trim().isEmpty ? 'General' : record.subject;
  final duration = formatStudyDuration(record.durationMinutes);
  return '$subject • $duration • ${record.completedSessions} sessions';
}

Map<String, dynamic> studySessionPayload(StudySessionRecord record) =>
    record.toJson();

String studySessionHashKey(StudySessionRecord record) =>
    '${record.id}_${record.startedAt.millisecondsSinceEpoch}';

String studyMethodSummary(StudyMethod method) {
  final longBreak = method.longBreakDurationMinutes;
  return '${method.name}: ${method.studyDurationMinutes} min study / ${method.shortBreakDurationMinutes} min short break / $longBreak min long break';
}

String encodeStudySettings(StudySettings settings) =>
    jsonEncode(settings.toJson());

StudySettings decodeStudySettings(String raw) {
  try {
    return StudySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return StudySettings();
  }
}
