import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/study_material_models.dart';
import 'package:reminder_hub/services/study_material_service.dart';

void main() {
  final service = StudyMaterialService.instance;

  test('analyzer detects definitions, headings, facts, terms, and counts', () {
    const source = '''PHOTOSYNTHESIS

Photosynthesis is the process by which plants convert light energy into chemical energy.
Photosynthesis occurs mainly in chloroplasts.
- Carbon dioxide and water are used as inputs.
- Glucose and oxygen are produced.''';

    final analysis = service.analyzeText(source);

    expect(analysis.titles, contains('PHOTOSYNTHESIS'));
    expect(analysis.definitions, isNotEmpty);
    final photosynthesis = analysis.definitions.firstWhere(
      (definition) => definition.term == 'Photosynthesis',
    );
    expect(
      photosynthesis.definition,
      contains('process by which plants convert light energy'),
    );
    expect(analysis.facts.length, greaterThanOrEqualTo(3));
    expect(analysis.wordCount, greaterThan(10));
    expect(analysis.potentialQuestionCount, greaterThan(0));
  });

  test('generation remains grounded and skips hard questions', () {
    final material = StudyMaterial(
      id: 'material-1',
      fileName: 'lesson.txt',
      filePath: '/offline/lesson.txt',
      fileType: 'txt',
      fileSizeBytes: 100,
      importedAt: DateTime(2026, 9, 20),
      status: MaterialProcessingStatus.completed,
      extractedText: 'Water is a liquid substance.',
      analysis: service.analyzeText('Water is a liquid substance.'),
    );

    final reviewer = service.generateReviewer(material);
    final quiz = service.generateQuiz(material, requestedCount: 10);
    final hardQuiz = service.generateQuiz(
      material,
      requestedCount: 10,
      difficulty: 'hard',
    );
    final flashcards = service.generateFlashcards(material);

    expect(reviewer, contains('Water'));
    expect(quiz, isNotEmpty);
    expect(quiz.every((question) => question.sourceText.isNotEmpty), isTrue);
    expect(hardQuiz, isEmpty);
    expect(flashcards.single.back, contains('liquid substance'));
  });

  test('duplicate facts and definitions are removed', () {
    final analysis = service.analyzeText(
      'Gravity is a force that attracts objects.\n'
      'Gravity is a force that attracts objects.\n'
      'Gravity occurs everywhere.',
    );

    expect(analysis.definitions, hasLength(1));
    expect(
      analysis.facts.map((fact) => fact.text.toLowerCase()).toSet().length,
      analysis.facts.length,
    );
  });

  test('material serialization preserves generated content', () {
    final material = StudyMaterial(
      id: 'material-2',
      fileName: 'notes.txt',
      filePath: '/offline/notes.txt',
      fileType: 'txt',
      fileSizeBytes: 20,
      importedAt: DateTime(2026, 9, 20),
      status: MaterialProcessingStatus.completed,
      extractedText: 'A LAN is a local area network.',
      analysis: service.analyzeText('A LAN is a local area network.'),
      reviewer: 'Local Study Reviewer',
      flashcards: const [
        StudyFlashcard(
          id: 'card-1',
          front: 'What is a LAN?',
          back: 'A local area network.',
          confidence: MaterialConfidence.high,
        ),
      ],
    );

    final restored = StudyMaterial.fromJson(material.toJson());
    expect(restored.extractedText, material.extractedText);
    expect(restored.reviewer, material.reviewer);
    expect(restored.flashcards.single.front, 'What is a LAN?');
  });

  test('scanned PDF OCR pages preserve order and skip unreadable pages', () {
    final combined = service.combineOcrPages([
      '[Page 1]\nIntroduction',
      '',
      '[Page 3]\nNormalization',
    ]);

    expect(combined, startsWith('[Page 1]'));
    expect(combined, contains('[Page 3]'));
    expect(
      combined.indexOf('[Page 1]'),
      lessThan(combined.indexOf('[Page 3]')),
    );
    expect(combined, isNot(contains('[Page 2]')));
  });

  test('multiple-choice answers remain present after option shuffling', () {
    final material = StudyMaterial(
      id: 'mc-material',
      fileName: 'mc.txt',
      filePath: '/offline/mc.txt',
      fileType: 'txt',
      fileSizeBytes: 1,
      importedAt: DateTime(2026, 9, 20),
      status: MaterialProcessingStatus.completed,
      extractedText:
          'Alpha is the first concept in this lesson. Beta is the second concept in this lesson. Gamma is the third concept in this lesson. Delta is the fourth concept in this lesson.',
      analysis: service.analyzeText(
        'Alpha is the first concept in this lesson. Beta is the second concept in this lesson. Gamma is the third concept in this lesson. Delta is the fourth concept in this lesson.',
      ),
    );
    final questions = service.generateQuiz(
      material,
      requestedCount: 4,
      type: 'multipleChoice',
    );

    expect(questions, isNotEmpty);
    for (final question in questions) {
      expect(question.options, hasLength(4));
      expect(question.options, contains(question.answer));
    }
  });

  test('difficulty levels select grounded candidates', () {
    final material = StudyMaterial(
      id: 'difficulty-material',
      fileName: 'difficulty.txt',
      filePath: '/offline/difficulty.txt',
      fileType: 'txt',
      fileSizeBytes: 1,
      importedAt: DateTime(2026, 9, 20),
      status: MaterialProcessingStatus.completed,
      extractedText:
          'A database is an organized collection of information. '
          'Normalization occurs because it reduces redundancy and requires related tables to be structured carefully. '
          'Chloroplasts contain chlorophyll pigments.',
      analysis: service.analyzeText(
        'A database is an organized collection of information. '
        'Normalization occurs because it reduces redundancy and requires related tables to be structured carefully. '
        'Chloroplasts contain chlorophyll pigments.',
      ),
    );

    final easy = service.generateQuiz(material, difficulty: 'easy');
    final medium = service.generateQuiz(material, difficulty: 'medium');
    final hard = service.generateQuiz(material, difficulty: 'hard');

    expect(easy, isNotEmpty);
    expect(medium, isNotEmpty);
    expect(hard, isNotEmpty);
    expect(hard.every((question) => question.sourceText.isNotEmpty), isTrue);
  });

  test('facts support plural verbs and true-false variation', () {
    final analysis = service.analyzeText(
      'Chloroplasts contain chlorophyll pigments. '
      'Cells require ATP. '
      'Networks consist of connected devices. '
      'Plants produce oxygen.',
    );
    expect(analysis.facts.length, greaterThanOrEqualTo(4));

    final material = StudyMaterial(
      id: 'tf-material',
      fileName: 'tf.txt',
      filePath: '/offline/tf.txt',
      fileType: 'txt',
      fileSizeBytes: 1,
      importedAt: DateTime(2026, 9, 20),
      status: MaterialProcessingStatus.completed,
      extractedText:
          'TCP provides reliable delivery. UDP provides fast delivery.',
      analysis: service.analyzeText(
        'TCP provides reliable delivery. UDP provides fast delivery.',
      ),
    );
    final answers = service
        .generateQuiz(material, type: 'trueFalse')
        .map((question) => question.answer)
        .toSet();
    expect(answers, contains('True'));
    expect(answers, contains('False'));
  });

  test('reviewer includes detected headings and fill blanks use concise terms', () {
    final material = StudyMaterial(
      id: 'heading-material',
      fileName: 'headings.txt',
      filePath: '/offline/headings.txt',
      fileType: 'txt',
      fileSizeBytes: 1,
      importedAt: DateTime(2026, 9, 20),
      status: MaterialProcessingStatus.completed,
      extractedText:
          'DATABASE SYSTEMS\nA database is an organized collection.\nNORMALIZATION\nNormalization is the reduction of redundancy.',
      analysis: service.analyzeText(
        'DATABASE SYSTEMS\nA database is an organized collection.\nNORMALIZATION\nNormalization is the reduction of redundancy.',
      ),
    );
    final reviewer = service.generateReviewer(material);
    final blanks = service.generateQuiz(material, type: 'fillInBlank');

    expect(reviewer, contains('Key Headings / Topics'));
    expect(reviewer, contains('DATABASE SYSTEMS'));
    expect(reviewer, contains('NORMALIZATION'));
    expect(blanks, isNotEmpty);
    expect(blanks.first.answer.split(' '), hasLength(lessThan(5)));
    expect(blanks.first.prompt, contains('______'));
  });
}
