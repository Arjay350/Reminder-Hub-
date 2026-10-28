import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/diary_models.dart';

void main() {
  group('DiaryEntry persistence', () {
    final createdAt = DateTime(2026, 6, 20, 9);

    test('unlocked diary data round-trips with tags and checklist', () {
      final entry = DiaryEntry(
        id: 'entry-1',
        title: 'A good day',
        content: 'Finished my work',
        createdAt: createdAt,
        updatedAt: createdAt,
        mood: 'Happy',
        tags: const ['home', 'school'],
        checklistItems: const [
          NotebookChecklistItem(
            id: 'item-1',
            text: 'Review notes',
            isChecked: true,
          ),
        ],
      );

      final restored = DiaryEntry.fromJson(entry.toStoredJson());

      expect(restored.title, entry.title);
      expect(restored.content, entry.content);
      expect(restored.mood, 'Happy');
      expect(restored.tags, ['home', 'school']);
      expect(restored.checklistItems.single.isChecked, isTrue);
      expect(restored.isLocked, isFalse);
    });

    test('all mood values persist unchanged when reopening a diary entry', () {
      for (final mood in DiaryEntry.moods.keys) {
        final entry = DiaryEntry(
          id: 'entry-$mood',
          title: 'A day',
          content: 'Diary text',
          createdAt: createdAt,
          updatedAt: createdAt,
          mood: mood,
        );

        final reopened = DiaryEntry.fromJson(entry.toStoredJson());

        expect(reopened.mood, mood);
      }
    });

    test('locked diary storage contains no searchable private fields', () {
      const encryptedPayload = 'v2:iv:ciphertext:mac';
      final entry = DiaryEntry(
        id: 'private-1',
        title: 'Sensitive title',
        content: 'Sensitive content',
        createdAt: createdAt,
        updatedAt: createdAt,
        mood: 'Sad',
        tags: const ['secret'],
        isLocked: true,
        encryptedPayload: encryptedPayload,
      );

      final stored = entry.toStoredJson();
      final encoded = stored.toString();
      final restored = DiaryEntry.fromJson(stored);

      expect(stored.keys.toSet(), {
        'id',
        'createdAt',
        'updatedAt',
        'isLocked',
        'encryptedPayload',
      });
      expect(encoded, isNot(contains('Sensitive')));
      expect(encoded, isNot(contains('secret')));
      expect(restored.title, isEmpty);
      expect(restored.content, isEmpty);
      expect(restored.tags, isEmpty);
      expect(restored.mood, isNull);
      expect(restored.encryptedPayload, encryptedPayload);
    });
  });

  group('NotebookNote persistence', () {
    final createdAt = DateTime(2026, 6, 20, 9);

    test('unlocked note preserves pin and checklist state', () {
      final note = NotebookNote(
        id: 'note-1',
        title: 'Biology',
        content: 'Cell structure',
        createdAt: createdAt,
        updatedAt: createdAt,
        category: 'Study',
        isPinned: true,
        checklistItems: const [
          NotebookChecklistItem(id: 'item-1', text: 'Read chapter'),
        ],
      );

      final restored = NotebookNote.fromJson(note.toStoredJson());

      expect(restored.title, note.title);
      expect(restored.category, 'Study');
      expect(restored.isPinned, isTrue);
      expect(restored.checklistItems.single.text, 'Read chapter');
    });

    test('private note encryptable payload keeps pin inside the payload', () {
      final note = NotebookNote(
        id: 'private-note',
        title: 'Private',
        content: 'Hidden content',
        createdAt: createdAt,
        updatedAt: createdAt,
        isPinned: true,
        isLocked: true,
      );

      final privatePayload = note.toPrivatePayload();
      final stored = note.toStoredJson(encryptedPayload: 'ciphertext');

      expect(privatePayload['isPinned'], isTrue);
      expect(stored.keys, containsAll(['id', 'isLocked', 'encryptedPayload']));
      expect(stored, isNot(contains('title')));
      expect(stored, isNot(contains('content')));
      expect(stored, isNot(contains('isPinned')));
    });
  });
}
