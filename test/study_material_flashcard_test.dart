import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/study_material_models.dart';
import 'package:reminder_hub/screens/study/study_materials_screen.dart';

void main() {
  test('flashcard status updates preserve shuffled order and current card', () {
    const cards = [
      StudyFlashcard(
        id: 'three',
        front: 'Three',
        back: '3',
        confidence: MaterialConfidence.high,
      ),
      StudyFlashcard(
        id: 'one',
        front: 'One',
        back: '1',
        confidence: MaterialConfidence.high,
      ),
      StudyFlashcard(
        id: 'two',
        front: 'Two',
        back: '2',
        confidence: MaterialConfidence.high,
      ),
    ];
    final updated = replaceFlashcardPreservingOrder(
      cards,
      cards.first.copyWith(known: true, needsReview: false),
    );

    expect(updated.map((card) => card.id), ['three', 'one', 'two']);
    expect(updated.first.known, isTrue);
    expect(updated.first.needsReview, isFalse);
  });

  test('needs-review status preserves shuffled order', () {
    const cards = [
      StudyFlashcard(
        id: 'five',
        front: 'Five',
        back: '5',
        confidence: MaterialConfidence.high,
      ),
      StudyFlashcard(
        id: 'two',
        front: 'Two',
        back: '2',
        confidence: MaterialConfidence.high,
      ),
    ];
    final updated = replaceFlashcardPreservingOrder(
      cards,
      cards.last.copyWith(known: false, needsReview: true),
    );

    expect(updated.map((card) => card.id), ['five', 'two']);
    expect(updated.last.needsReview, isTrue);
  });
}
