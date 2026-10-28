import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/widgets/diary_mood_filter.dart';

void _ignoreMoodChange(String? mood) {}

void main() {
  const moods = {
    'Happy': '😊',
    'Sad': '😔',
    'Angry': '😠',
    'Calm': '😌',
    'Exhausted': '😴',
    'Stressed': '😣',
    'Productive': '💪',
  };

  for (final width in [320.0, 412.0, 600.0]) {
    testWidgets('all moods fit at $width logical pixels', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: DiaryMoodFilter(
                  selectedMood: null,
                  onChanged: _ignoreMoodChange,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final entry in moods.entries) {
        expect(find.text(entry.key), findsOneWidget);
        expect(find.text(entry.value), findsOneWidget);
      }
      expect(find.text('All'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mood cards and All report selected filter values', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? selectedMood;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.all(18),
              child: DiaryMoodFilter(
                selectedMood: selectedMood,
                onChanged: (mood) => setState(() => selectedMood = mood),
              ),
            ),
          ),
        ),
      ),
    );

    for (final mood in moods.keys) {
      expect(
        tester
                .getSemantics(find.bySemanticsLabel('Filter diary by $mood'))
                .flagsCollection
                .isSelected ==
            ui.Tristate.isTrue,
        isFalse,
      );
      await tester.tap(find.text(mood));
      await tester.pumpAndSettle();
      expect(selectedMood, mood);
      expect(
        tester
                .getSemantics(find.bySemanticsLabel('Filter diary by $mood'))
                .flagsCollection
                .isSelected ==
            ui.Tristate.isTrue,
        isTrue,
      );
    }

    await tester.tap(find.text('Productive'));
    await tester.pumpAndSettle();
    expect(selectedMood, isNull);

    await tester.tap(find.text('Sad'));
    await tester.pumpAndSettle();
    expect(selectedMood, 'Sad');

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(selectedMood, isNull);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
