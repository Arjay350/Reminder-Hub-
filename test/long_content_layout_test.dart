import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/models/pet_models.dart';
import 'package:reminder_hub/screens/bills/bills_screen.dart';
import 'package:reminder_hub/screens/reminders/reminders_screen.dart';
import 'package:reminder_hub/services/hive_service.dart';
import 'package:reminder_hub/services/pet_service.dart';
import 'package:reminder_hub/widgets/bill_dialog.dart';
import 'package:reminder_hub/widgets/reminder_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hive = HiveService.instance;
  Directory? tempDir;

  group('populated content layout stress', () {
    setUp(() async {
      await hive.resetForTesting();
      PetService.instance.cancelPendingTimers();
      final now = DateTime.now();
      PetService.instance.preferencesNotifier.value = PetPreferences(
        lastTaskGenerationDate:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        dailyTasks: const [
          PetDailyTask(
            id: 'diary_entry',
            title: 'Diary',
            category: 'Personal Growth',
            foodReward: 1,
            requiredCount: 1,
          ),
          PetDailyTask(
            id: 'school_schedule',
            title: 'Schedule',
            category: 'School',
            foodReward: 1,
            requiredCount: 1,
          ),
          PetDailyTask(
            id: 'study_25',
            title: 'Study',
            category: 'Study',
            foodReward: 2,
            requiredCount: 1,
          ),
        ],
      );
      final previousTempDir = tempDir;
      if (previousTempDir != null && await previousTempDir.exists()) {
        await previousTempDir.delete(recursive: true);
      }
      tempDir = await Directory.systemTemp.createTemp('long_content_test_');
      await hive.init(directoryPath: tempDir!.path, runMigrations: false);
    });

    tearDown(PetService.instance.dispose);

    testWidgets(
      'long reminder titles and descriptions render losslessly without layout errors',
      (tester) async {
        _setNarrowLargeTextViewport(tester);
        for (final length in [100, 500, 1000, 5000]) {
          final value = List.filled(length, 'x').join();
          final reminder = Reminder(
            id: 'reminder-$length',
            title: value,
            category: 'Personal',
            description: value,
            date: DateTime(2030, 1, 1),
            time: '09:00',
            repeat: 'None',
            reminderBefore: 'At time',
            priority: 'Medium',
            notes: '',
            completed: false,
          );
          await tester.pumpWidget(
            _testApp(ReminderDialog(key: ValueKey(length), reminder: reminder)),
          );
          await _pumpFrames(tester);

          expect(
            tester
                .widget<EditableText>(find.byType(EditableText).at(0))
                .controller
                .text,
            value,
          );
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText).at(1))
                .controller
                .text,
            value,
          );
          expect(tester.takeException(), isNull);
          final saveButton = tester.widget<ElevatedButton>(
            find.byType(ElevatedButton).first,
          );
          expect(saveButton.onPressed, isNotNull);
          expect(
            tester.getSize(find.byType(ElevatedButton).first).height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'long bill names and large amounts render losslessly without layout errors',
      (tester) async {
        _setNarrowLargeTextViewport(tester);
        final amounts = [1e100, double.maxFinite];
        const lengths = [100, 500, 1000, 5000];
        for (var index = 0; index < lengths.length; index++) {
          final length = lengths[index];
          final value = List.filled(length, 'x').join();
          final amount = amounts[index.isEven ? 0 : 1];
          final bill = Bill(
            id: 'bill-$length',
            name: value,
            amount: amount,
            dueDate: DateTime(2030, 1, 1),
            repeat: 'Monthly',
            category: 'Utilities',
            paid: false,
            reminderSchedule: '3 days before',
            notes: '',
          );
          await tester.pumpWidget(
            _testApp(BillDialog(key: ValueKey(length), bill: bill)),
          );
          await _pumpFrames(tester);

          expect(
            tester
                .widget<EditableText>(find.byType(EditableText).at(0))
                .controller
                .text,
            value,
          );
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText).at(1))
                .controller
                .text,
            amount.toString(),
          );
          expect(tester.takeException(), isNull);
          final saveButton = tester.widget<ElevatedButton>(
            find.byType(ElevatedButton).first,
          );
          expect(saveButton.onPressed, isNotNull);
          expect(
            tester.getSize(find.byType(ElevatedButton).first).height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets('reminder screen empty state fits a narrow large-text screen', (
      tester,
    ) async {
      _setNarrowLargeTextViewport(tester);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(_testApp(const RemindersScreen()));
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'populated reminders screen renders long titles and high scaling without overflow or stalling',
      (tester) async {
        _setNarrowLargeTextViewport(tester);
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

        // Populate Hive with multiple complex reminders having long text
        await tester.runAsync(() async {
          for (int i = 1; i <= 6; i++) {
            final longTitle =
                'Reminder $i: ${List.filled(50, 'important task ').join()}';
            final longDesc = List.filled(80, 'detail note ').join();
            final reminder = Reminder(
              id: 'pop-rem-$i',
              title: longTitle,
              category: i.isEven ? 'Work' : 'Bills',
              description: longDesc,
              date: DateTime.now().add(Duration(days: i)),
              time: '10:00 AM',
              repeat: 'Monthly',
              reminderBefore: '1 day',
              priority: i % 3 == 0 ? 'High' : 'Medium',
              notes: '',
              completed: i == 1,
              targetDayOfMonth: 31,
            );
            await hive.saveReminder(reminder);
          }
        });

        await tester.pumpWidget(_testApp(const RemindersScreen()));
        // First pump triggers the async _loadReminders() call
        await _pumpFrames(tester);

        expect(tester.takeException(), isNull);
        final reminderList = _verticalListView();
        expect(reminderList, findsOneWidget);

        // Verify tap target dimensions for completion buttons and actions
        final checkboxes = find.byType(Checkbox);
        expect(checkboxes, findsWidgets);
        for (final element in checkboxes.evaluate()) {
          final renderBox = element.renderObject as RenderBox?;
          if (renderBox != null && renderBox.hasSize) {
            expect(renderBox.size.height, greaterThanOrEqualTo(40));
          }
        }

        // Verify scrolling works without throwing layout exceptions
        await tester.drag(reminderList, const Offset(0, -350));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'populated bills screen renders large amounts, long names and high scaling without overflow or stalling',
      (tester) async {
        _setNarrowLargeTextViewport(tester);
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

        await tester.runAsync(() async {
          final testAmounts = [1299.99, 999999999.99, 1e20, double.maxFinite];
          for (int i = 0; i < testAmounts.length; i++) {
            final longName =
                'Bill $i: ${List.filled(30, 'Enterprise Service ').join()}';
            final bill = Bill(
              id: 'pop-bill-$i',
              name: longName,
              amount: testAmounts[i],
              dueDate: DateTime.now().add(Duration(days: (i - 1) * 3)),
              repeat: 'Monthly',
              category: 'Utilities',
              paid: i.isEven,
              reminderSchedule: '3 days before',
              notes: 'Long notes for bill $i',
            );
            await hive.saveBill(bill);
          }
        });

        await tester.pumpWidget(_testApp(const BillsScreen()));
        // First pump triggers the async _loadBills() call
        await _pumpFrames(tester);

        expect(tester.takeException(), isNull);
        final billList = _verticalListView();
        expect(billList, findsOneWidget);

        // Test scroll stress
        await tester.drag(billList, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      },
    );
  });

  // Keep asynchronous Hive shutdown outside the widget test's fake-async zone.
  group('isolated Hive cleanup', () {
    test('closes the isolated database after widget layout tests', () async {
      await hive.resetForTesting();
      final directory = tempDir;
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
  });
}

void _setNarrowLargeTextViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _testApp(Widget child) => MediaQuery(
  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
  child: MaterialApp(home: Scaffold(body: child)),
);

Future<void> _pumpFrames(WidgetTester tester) async {
  // Advance a bounded five seconds of fake time. pumpAndSettle can wait forever
  // when any mounted widget keeps requesting frames or scheduling timers.
  for (var frame = 0; frame < 2; frame++) {
    await tester.pump(const Duration(milliseconds: 2500));
  }
}

Finder _verticalListView() => find.byWidgetPredicate(
  (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
);
