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
    testWidgets('mood dropdown fits at $width logical pixels', (tester) async {
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

      expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
      expect(find.text('All Moods'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      for (final entry in moods.entries) {
        expect(find.text(entry.key), findsOneWidget);
      }
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
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mood).last);
      await tester.pumpAndSettle();
      expect(selectedMood, mood);
      expect(find.text(mood), findsOneWidget);
    }

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Moods').last);
    await tester.pumpAndSettle();
    expect(selectedMood, isNull);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
