import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/study_models.dart';
import 'package:reminder_hub/services/study_service.dart';

void main() {
  group('Study timer logic', () {
    test('Pomodoro defaults use the expected focus and break durations', () {
      final pomodoro = StudyService.defaultStudyMethods.firstWhere(
        (method) => method.name == 'Pomodoro',
      );

      expect(pomodoro.studyDurationMinutes, 25);
      expect(pomodoro.shortBreakDurationMinutes, 5);
      expect(pomodoro.longBreakDurationMinutes, 15);
      expect(pomodoro.sessionsBeforeLongBreak, 4);
    });

    test(
      'phase advancement moves to break and then to the next study round',
      () {
        final method = StudyService.defaultStudyMethods.firstWhere(
          (method) => method.name == 'Pomodoro',
        );
        final now = DateTime(2026, 9, 20, 19, 0, 0);

        var state = StudyTimerState.initial(
          method: method,
          subject: 'Mathematics',
          totalSessions: 4,
          startedAt: now,
        );

        expect(state.phase, StudyPhase.study);
        expect(state.currentSession, 1);

        state = state.withElapsed(now.add(const Duration(minutes: 26)), method);
        expect(state.phase, StudyPhase.shortBreak);
        expect(state.currentSession, 1);

        state = state.withElapsed(now.add(const Duration(minutes: 31)), method);
        expect(state.phase, StudyPhase.study);
        expect(state.currentSession, 2);
      },
    );
  });
}
