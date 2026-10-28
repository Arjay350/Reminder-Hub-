import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/widgets/diary_mini_calendar.dart';

void main() {
  test('month calculations handle short months and leap years', () {
    expect(DiaryMiniCalendar.daysInDisplayedMonth(DateTime(2024, 2)), 29);
    expect(DiaryMiniCalendar.daysInDisplayedMonth(DateTime(2025, 2)), 28);
    expect(DiaryMiniCalendar.weeksInDisplayedMonth(DateTime(2026, 2)), 5);
  });

  for (final width in [320.0, 412.0, 600.0]) {
    testWidgets('calendar fits at $width logical pixels', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: DiaryMiniCalendar(
                displayedMonth: DateTime(2026, 10),
                selectedDate: DateTime(2026, 10, 6),
                entryCounts: {DateTime(2026, 10, 6): 2},
                onMonthChanged: _ignoreDate,
                onDateSelected: _ignoreDate,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('diary-date-2026-10-6')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('date selection and month navigation update calendar state', (
    tester,
  ) async {
    var month = DateTime(2026, 1);
    DateTime? selectedDate = DateTime(2026, 1, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DiaryMiniCalendar(
              displayedMonth: month,
              selectedDate: selectedDate,
              entryCounts: const {},
              onMonthChanged: (value) => setState(() => month = value),
              onDateSelected: (value) => setState(() => selectedDate = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('December 2025'), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('January 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('diary-date-2026-1-31')));
    await tester.pumpAndSettle();
    expect(selectedDate, DateTime(2026, 1, 31));
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar entry count is included in its date semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiaryMiniCalendar(
            displayedMonth: DateTime(2026, 10),
            selectedDate: null,
            entryCounts: {DateTime(2026, 10, 6): 2},
            onMonthChanged: _ignoreDate,
            onDateSelected: _ignoreDate,
          ),
        ),
      ),
    );

    final dateLabel = tester
        .getSemantics(
          find.byKey(const ValueKey('diary-date-semantics-2026-10-6')),
        )
        .label;
    expect(dateLabel, startsWith('Tuesday, October 6, 2026, 2 diary entries'));
    semantics.dispose();
  });
}

void _ignoreDate(DateTime date) {}
