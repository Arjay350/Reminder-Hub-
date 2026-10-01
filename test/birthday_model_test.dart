import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/services/pet_service.dart';

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
}
