import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/services/pet_service.dart';
import 'package:reminder_hub/widgets/birthday_dialog.dart';
import 'package:reminder_hub/widgets/quick_add_modal.dart';

void main() {
  group('Birthday model', () {
    test('computes next birthday without a year and respects date math', () {
      final birthday = Birthday(
        id: 'b1',
        name: 'John',
        birthDate: DateTime(2002, 10, 15),
        relationship: 'Family',
        giftIdeas: 'Headphones',
      );

      final now = DateTime(2026, 10, 2);
      final next = birthday.nextBirthdayDateFor(now);
      expect(next, DateTime(2026, 10, 15));
      expect(birthday.turningAgeFor(now), 24);
      expect(birthday.daysUntilNextFor(now), 13);
      expect(birthday.formattedDateFor(now), 'October 15 (Turns 24)');
    });

    test('supports birth dates without a year', () {
      final birthday = Birthday(
        id: 'b2',
        name: 'Maria',
        birthDate: DateTime(2000, 2, 29),
        relationship: 'Friend',
        giftIdeas: 'Cake',
        yearKnown: false,
      );

      expect(birthday.turningAge, isNull);
      expect(birthday.formattedDate, 'February 29');
      final next = birthday.nextBirthdayDateFor(DateTime(2026, 3, 1));
      expect(next, DateTime(2027, 2, 28));
    });

    test('stores and restores the user-birthday flag', () {
      final birthday = Birthday(
        id: 'user1',
        name: 'Sam',
        birthDate: DateTime(1993, 5, 18),
        isUserBirthday: true,
      );

      final decoded = Birthday.fromJson(birthday.toJson());
      expect(decoded.isUserBirthday, isTrue);
      expect(decoded.copyWith(isUserBirthday: false).isUserBirthday, isFalse);
    });

    test(
      'duplicate personal birthdays are removed without affecting contacts',
      () {
        final personal = Birthday(
          id: 'personal',
          name: 'Sam',
          birthDate: DateTime(1993, 5, 18),
          isUserBirthday: true,
        );
        final duplicatePersonal = Birthday(
          id: 'personal-duplicate',
          name: 'Sam',
          birthDate: DateTime(1993, 5, 19),
          isUserBirthday: true,
        );
        final contact = Birthday(
          id: 'contact',
          name: 'Mom',
          birthDate: DateTime(1960, 5, 18),
        );

        final normalized = Birthday.keepSingleUserBirthday([
          personal,
          contact,
          duplicatePersonal,
        ]);

        expect(normalized.map((birthday) => birthday.id), [
          'personal',
          'contact',
        ]);
        expect(
          normalized.where((birthday) => birthday.isUserBirthday),
          hasLength(1),
        );
      },
    );

    test('occursOnDate recurs every year and computes ageOnYear correctly', () {
      final birthday = Birthday(
        id: 'b-apr17',
        name: 'Alex',
        birthDate: DateTime(2006, 4, 17),
        yearKnown: true,
      );

      // Birthday should recur on April 17 in every year
      expect(birthday.occursOnDate(DateTime(2006, 4, 17)), isTrue);
      expect(birthday.occursOnDate(DateTime(2024, 4, 17)), isTrue);
      expect(birthday.occursOnDate(DateTime(2026, 4, 17)), isTrue);
      expect(birthday.occursOnDate(DateTime(2030, 4, 17)), isTrue);

      // Different dates should not match
      expect(birthday.occursOnDate(DateTime(2026, 4, 18)), isFalse);
      expect(birthday.occursOnDate(DateTime(2026, 5, 17)), isFalse);

      // Age calculation by year
      expect(birthday.ageOnYear(2006), 0);
      expect(birthday.ageOnYear(2024), 18);
      expect(birthday.ageOnYear(2026), 20);
      expect(birthday.ageOnYear(2030), 24);
      expect(birthday.ageOnYear(2000), isNull);
    });

    test('nextBirthdayDateFor matches today even when reference has time of day', () {
      final birthday = Birthday(
        id: 'b-today',
        name: 'Jordan',
        birthDate: DateTime(2006, 4, 17),
      );

      // Reference is at 10:30:45 AM on the birthday
      final refWithTime = DateTime(2026, 4, 17, 10, 30, 45);
      final next = birthday.nextBirthdayDateFor(refWithTime);
      expect(next, DateTime(2026, 4, 17));
      expect(birthday.daysUntilNextFor(refWithTime), 0);
    });
  });

  group('Birthday phrase parsing', () {
    test('detects the user birthday in natural-language phrases', () {
      final parser = PetService.instance;

      final todayUser = parser.parseBirthdayReference("Today is my birthday");
      expect(todayUser, isNotNull);
      expect(todayUser!.isUserBirthdayMention, isTrue);
      expect(todayUser.isToday, isTrue);

      final tomorrowUser = parser.parseBirthdayReference("My bday is tomorrow");
      expect(tomorrowUser, isNotNull);
      expect(tomorrowUser!.isUserBirthdayMention, isTrue);
      expect(tomorrowUser.isTomorrow, isTrue);

      final otherPerson = parser.parseBirthdayReference(
        "John's birthday is today",
      );
      expect(otherPerson, isNotNull);
      expect(otherPerson!.isUserBirthdayMention, isFalse);
      expect(otherPerson.isToday, isTrue);
    });
  });

  testWidgets('birthday form starts with the selected calendar date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BirthdayDialog(initialDate: DateTime(2026, 10, 15)),
        ),
      ),
    );

    expect(find.text('October 15, 2026'), findsOneWidget);
  });

  testWidgets('birthday is offered in Quick Add', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QuickAddModal())),
    );

    expect(find.text('Add Birthday'), findsOneWidget);
  });

  testWidgets(
    'clicking "This is my birthday" hides the relationship selector',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BirthdayDialog(),
          ),
        ),
      );

      // Initially relationship section is visible
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);

      // Tap "🎂 This is my birthday" checkbox
      final checkboxFinder = find.text('🎂 This is my birthday');
      expect(checkboxFinder, findsOneWidget);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Relationship section should now be hidden
      expect(find.text('Relationship'), findsNothing);
      expect(find.text('Family'), findsNothing);

      // Tap checkbox again to uncheck
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Relationship section should be visible again
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
    },
  );
}
