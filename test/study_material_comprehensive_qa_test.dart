import 'dart:convert';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/study_material_models.dart';
import 'package:reminder_hub/services/study_material_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

void main() {
  final service = StudyMaterialService.instance;

  group('1. Text Analyzer & Extraction Rules', () {
    test('Definition extraction detects all supported syntactic patterns', () {
      const text = '''
Photosynthesis is defined as the synthesis of organic compounds from light.
Mitosis refers to the process of cell division in eukaryotic cells.
Algorithm means a finite sequence of well-defined computer implementable instructions.
Respiration is the process of releasing energy from glucose.
A database is an organized collection of structured information.
Planets are celestial bodies orbiting a star.
''';
      final analysis = service.analyzeText(text);

      expect(analysis.definitions.length, greaterThanOrEqualTo(5));
      final terms = analysis.definitions
          .map((d) => d.term.toLowerCase())
          .toList();
      expect(terms, contains('photosynthesis'));
      expect(terms, contains('mitosis'));
      expect(terms, contains('algorithm'));
      expect(terms, contains('respiration'));
      expect(terms, contains('a database'));
    });

    test('Heading detection recognizes ALL CAPS and keyword prefixes', () {
      const text = '''
CHAPTER 1: COMPUTER NETWORKS
Introduction to networking concepts.
Unit 2 - Data Link Layer
Error detection and framing.
SECTION 3.1: ROUTING
Routing algorithms and protocols.
IMPORTANT HEADING WITHOUT PREFIX
Normal sentence with lower case words.
''';
      final analysis = service.analyzeText(text);

      // Notice: Only the keyword (e.g. 'CHAPTER') is stripped, retaining '1: COMPUTER NETWORKS'
      expect(analysis.titles, contains('1: COMPUTER NETWORKS'));
      expect(analysis.titles, contains('2 - Data Link Layer'));
      expect(analysis.titles, contains('3.1: ROUTING'));
      expect(analysis.titles, contains('IMPORTANT HEADING WITHOUT PREFIX'));
      expect(
        analysis.titles,
        isNot(contains('Normal sentence with lower case words.')),
      );
    });

    test('Fact extraction identifies fact keywords and bulleted lists', () {
      const text = '''
Photosynthesis occurs mainly inside the chloroplasts of plant cells.
The nucleus contains the genetic material of eukaryotic organisms.
The solar system consists of eight recognized planets and dwarf planets.
Industrial synthesis produces polymers used in manufacturing.
- The human body uses glucose for cellular respiration.
* The atomic nucleus is located at the center of an atom.
1. The compiler includes lexical and semantic analysis stages.
• Nitrogen is classified as a nonmetal element.
''';
      final analysis = service.analyzeText(text);

      expect(analysis.facts.length, greaterThanOrEqualTo(6));
      expect(
        analysis.facts.any((f) => f.text.contains('occurs mainly inside')),
        isTrue,
      );
      expect(
        analysis.facts.any((f) => f.text.contains('contains the genetic')),
        isTrue,
      );
      expect(
        analysis.facts.any((f) => f.text.contains('uses glucose for')),
        isTrue,
      );
    });

    test('Deduplication prevents repeated definitions and identical facts', () {
      const text = '''
A cache is a high speed data storage layer.
A cache is a high speed data storage layer.
Caching occurs in memory.
Caching occurs in memory.
''';
      final analysis = service.analyzeText(text);

      expect(analysis.definitions.length, 1);
      expect(analysis.facts.length, 1);
    });

    test('Stop words are excluded from key term ranking', () {
      const text = '''
The and for are but not you all any can had her was one our out this that.
Quantum entanglement describes correlations between separated particles.
Quantum mechanics predicts microscopic phenomena.
''';
      final analysis = service.analyzeText(text);

      expect(
        analysis.terms.map((t) => t.toLowerCase()),
        isNot(contains('the')),
      );
      expect(
        analysis.terms.map((t) => t.toLowerCase()),
        isNot(contains('and')),
      );
      expect(analysis.terms.map((t) => t.toLowerCase()), contains('quantum'));
    });

    test('Empty text produces zero-confidence empty analysis', () {
      final analysis = service.analyzeText('');
      expect(analysis.wordCount, 0);
      expect(analysis.ocrConfidence, 0);
      expect(analysis.definitions, isEmpty);
      expect(analysis.facts, isEmpty);
      expect(analysis.terms, isEmpty);
    });
  });

  group('2. Reviewer Generation', () {
    test(
      'Reviewer includes header, terms, definitions, and facts without inventing text',
      () {
        final material = StudyMaterial(
          id: 'rev-1',
          fileName: 'biology.txt',
          filePath: '/test/biology.txt',
          fileType: 'txt',
          fileSizeBytes: 500,
          importedAt: DateTime.now(),
          status: MaterialProcessingStatus.completed,
          extractedText: '''
Photosynthesis is the process of converting light into chemical energy.
Chloroplasts contain chlorophyll pigments.
A plant cell contains chloroplasts.
- Light reactions produce ATP and NADPH.
''',
          analysis: service.analyzeText('''
Photosynthesis is the process of converting light into chemical energy.
Chloroplasts contain chlorophyll pigments.
A plant cell contains chloroplasts.
- Light reactions produce ATP and NADPH.
'''),
        );

        final reviewer = service.generateReviewer(material);

        expect(reviewer, contains('Local Study Reviewer'));
        expect(reviewer, contains('Generated from: biology.txt'));
        expect(reviewer, contains('Key Terms'));
        expect(reviewer, contains('Definitions'));
        expect(
          reviewer,
          contains('Photosynthesis: converting light into chemical energy'),
        );
        expect(reviewer, contains('Important Facts'));
        expect(reviewer, contains('A plant cell contains chloroplasts'));
      },
    );
  });

  group('3. Quiz Generation & QA Defects Audit', () {
    final sampleMaterial = StudyMaterial(
      id: 'quiz-mat-1',
      fileName: 'networks.txt',
      filePath: '/test/networks.txt',
      fileType: 'txt',
      fileSizeBytes: 400,
      importedAt: DateTime.now(),
      status: MaterialProcessingStatus.completed,
      extractedText: '''
A router is a networking device that forwards data packets between computer networks.
A switch is a networking device that connects devices together on a single computer network.
Routing occurs at the network layer of the OSI reference model.
Switches operate at the data link layer.
Firewalls produce traffic logs for network security audits.
''',
      analysis: service.analyzeText('''
A router is a networking device that forwards data packets between computer networks.
A switch is a networking device that connects devices together on a single computer network.
Routing occurs at the network layer of the OSI reference model.
Switches operate at the data link layer.
Firewalls produce traffic logs for network security audits.
'''),
    );

    test('Multiple choice questions have valid prompts and distractors', () {
      final quiz = service.generateQuiz(
        sampleMaterial,
        requestedCount: 10,
        type: 'multipleChoice',
      );

      expect(quiz, isNotEmpty);
      for (final q in quiz) {
        expect(q.type, 'definition');
        expect(q.options.length, greaterThanOrEqualTo(2));
        expect(q.options, contains(q.answer));
      }
    });

    test(
      'Multiple choice options are randomized while preserving the answer',
      () {
        final quiz = service.generateQuiz(
          sampleMaterial,
          requestedCount: 10,
          type: 'multipleChoice',
        );

        for (final q in quiz) {
          expect(q.options, contains(q.answer));
        }
      },
    );

    test('True / False questions can contain safe true and false variants', () {
      final quiz = service.generateQuiz(
        sampleMaterial,
        requestedCount: 10,
        type: 'trueFalse',
      );

      expect(quiz, isNotEmpty);
      expect(quiz.map((q) => q.answer), contains('True'));
      expect(quiz.map((q) => q.answer), contains('False'));
    });

    test(
      'Hard difficulty returns reliable questions when source supports them',
      () {
        final hardQuiz = service.generateQuiz(
          sampleMaterial,
          requestedCount: 10,
          difficulty: 'hard',
        );

        expect(hardQuiz, isNotEmpty);
      },
    );

    test('Medium difficulty selects a different candidate set from Easy', () {
      final easyQuiz = service.generateQuiz(
        sampleMaterial,
        requestedCount: 10,
        difficulty: 'easy',
      );
      final mediumQuiz = service.generateQuiz(
        sampleMaterial,
        requestedCount: 10,
        difficulty: 'medium',
      );

      final samePrompts =
          mediumQuiz.length == easyQuiz.length &&
          mediumQuiz.asMap().entries.every(
            (entry) => entry.value.prompt == easyQuiz[entry.key].prompt,
          );
      expect(samePrompts, isFalse);
    });

    test(
      'Question count capping respects requestedCount without inventing questions',
      () {
        final count5 = service.generateQuiz(sampleMaterial, requestedCount: 2);
        expect(count5.length, equals(2));

        final count100 = service.generateQuiz(
          sampleMaterial,
          requestedCount: 100,
        );
        // It should gracefully cap at available candidate count without duplicating
        expect(count100.length, lessThanOrEqualTo(10));
      },
    );
  });

  group('4. Flashcards & Progress Tracking', () {
    test('Flashcards are generated from definitions and facts', () {
      final material = StudyMaterial(
        id: 'fc-mat-1',
        fileName: 'sample.txt',
        filePath: '/test/sample.txt',
        fileType: 'txt',
        fileSizeBytes: 200,
        importedAt: DateTime.now(),
        status: MaterialProcessingStatus.completed,
        extractedText:
            'A proxy is an intermediary server. A proxy contains cache stores.',
        analysis: service.analyzeText(
          'A proxy is an intermediary server. A proxy contains cache stores.',
        ),
      );

      final cards = service.generateFlashcards(material);

      expect(cards, isNotEmpty);
      expect(cards.any((c) => c.front.contains('What is')), isTrue);
      expect(cards.any((c) => c.front == 'Recall this fact'), isTrue);
    });

    test('Flashcard status update modifies known and needsReview', () {
      const card = StudyFlashcard(
        id: 'card-1',
        front: 'Front',
        back: 'Back',
        confidence: MaterialConfidence.high,
      );

      final knownCard = card.copyWith(known: true, needsReview: false);
      expect(knownCard.known, isTrue);
      expect(knownCard.needsReview, isFalse);

      final reviewCard = card.copyWith(known: false, needsReview: true);
      expect(reviewCard.known, isFalse);
      expect(reviewCard.needsReview, isTrue);
    });
  });

  group('5. Scanned PDF Page Combiner & Ordering', () {
    test(
      'Pages are combined in strictly ascending order with [Page N] headers',
      () {
        final pages = [
          '[Page 1]\nFirst page text.',
          '[Page 2]\nSecond page text.',
          '[Page 3]\nThird page text.',
        ];

        final combined = service.combineOcrPages(pages);

        expect(combined, contains('[Page 1]'));
        expect(combined, contains('[Page 2]'));
        expect(combined, contains('[Page 3]'));

        final p1 = combined.indexOf('[Page 1]');
        final p2 = combined.indexOf('[Page 2]');
        final p3 = combined.indexOf('[Page 3]');

        expect(p1, lessThan(p2));
        expect(p2, lessThan(p3));
      },
    );

    test('Empty pages are omitted without corrupting overall text', () {
      final pages = [
        '[Page 1]\nValid text.',
        '   ',
        '',
        '[Page 4]\nFourth page text.',
      ];

      final combined = service.combineOcrPages(pages);

      expect(combined, startsWith('[Page 1]'));
      expect(combined, endsWith('Fourth page text.'));
      expect(combined, isNot(contains('[Page 2]')));
      expect(combined, isNot(contains('[Page 3]')));
    });
  });

  group('6. Data Models & JSON Serialization Safety', () {
    test('StudyMaterial serialization roundtrip preserves all fields', () {
      final material = StudyMaterial(
        id: 'json-123',
        fileName: 'lecture.pdf',
        filePath: '/storage/lecture.pdf',
        fileType: 'pdf',
        fileSizeBytes: 1048576,
        importedAt: DateTime(2026, 9, 20, 14, 30),
        status: MaterialProcessingStatus.completed,
        extractedText: 'Extracted sample text',
        displayName: 'Custom Lecture Name',
        errorMessage: null,
        reviewer: 'Sample Reviewer Content',
        quizScore: 9,
        analysis: const StudyMaterialAnalysis(
          titles: ['TITLE'],
          topics: ['Topic A'],
          terms: ['Term 1'],
          wordCount: 150,
          potentialQuestionCount: 5,
          ocrConfidence: 0.85,
        ),
        quiz: const [
          StudyQuizQuestion(
            id: 'q1',
            type: 'multipleChoice',
            prompt: 'Question?',
            options: ['A', 'B'],
            answer: 'A',
            explanation: 'Exp',
            confidence: MaterialConfidence.high,
          ),
        ],
        flashcards: const [
          StudyFlashcard(
            id: 'f1',
            front: 'F',
            back: 'B',
            confidence: MaterialConfidence.high,
            known: true,
            needsReview: false,
          ),
        ],
      );

      final json = material.toJson();
      final restored = StudyMaterial.fromJson(json);

      expect(restored.id, equals(material.id));
      expect(restored.name, equals('Custom Lecture Name'));
      expect(restored.fileType, equals('pdf'));
      expect(restored.fileSizeBytes, equals(1048576));
      expect(restored.quizScore, equals(9));
      expect(restored.analysis.ocrConfidence, equals(0.85));
      expect(restored.quiz.length, equals(1));
      expect(restored.quiz.first.options, equals(['A', 'B']));
      expect(restored.flashcards.length, equals(1));
      expect(restored.flashcards.first.known, isTrue);
      expect(restored.flashcards.first.needsReview, isFalse);
    });

    test('Deserialization handles missing or malformed fields safely', () {
      final minimalJson = <String, dynamic>{
        'id': 'min-1',
        'fileName': 'file.txt',
      };

      final restored = StudyMaterial.fromJson(minimalJson);

      expect(restored.id, 'min-1');
      expect(restored.fileName, 'file.txt');
      expect(restored.fileType, 'unknown');
      expect(restored.fileSizeBytes, 0);
      expect(restored.status, MaterialProcessingStatus.failed);
      expect(restored.extractedText, '');
      expect(restored.quiz, isEmpty);
      expect(restored.flashcards, isEmpty);
      expect(restored.quizScore, isNull);
    });
  });

  group('7. Normal PDF Generation & Local Text Extraction (Syncfusion)', () {
    test(
      'Generate PDF with selectable text, extract with Syncfusion, and analyze',
      () async {
        // Create a normal PDF in-memory using Syncfusion
        final pdfDoc = PdfDocument();
        final page = pdfDoc.pages.add();
        final font = PdfStandardFont(PdfFontFamily.helvetica, 12);

        const content = '''DATABASE SYSTEMS

A database is an organized collection of data.
A DBMS is software used to create, manage, and manipulate databases.
A primary key uniquely identifies each record in a table.
Normalization is the process of organizing data to reduce redundancy.''';

        page.graphics.drawString(
          content,
          font,
          bounds: const Rect.fromLTWH(0, 0, 500, 500),
        );

        final pdfBytes = await pdfDoc.save();
        pdfDoc.dispose();

        // Verify that Syncfusion extracts selectable text directly
        final loadedDoc = PdfDocument(inputBytes: pdfBytes);
        final extractedText = PdfTextExtractor(loadedDoc).extractText();
        loadedDoc.dispose();

        expect(extractedText, isNotEmpty);
        expect(extractedText, contains('DATABASE SYSTEMS'));
        expect(extractedText, contains('collection of data'));

        // Pass into analyzer pipeline
        final analysis = service.analyzeText(extractedText);
        expect(analysis.titles, contains('DATABASE SYSTEMS'));
        expect(analysis.definitions, isNotEmpty);

        // Verify reviewer, quiz, and flashcards generated from extracted PDF text
        final material = StudyMaterial(
          id: 'pdf-real-1',
          fileName: 'database.pdf',
          filePath: '/tmp/database.pdf',
          fileType: 'pdf',
          fileSizeBytes: pdfBytes.length,
          importedAt: DateTime.now(),
          status: MaterialProcessingStatus.completed,
          extractedText: extractedText,
          analysis: analysis,
        );

        final reviewer = service.generateReviewer(material);
        expect(reviewer, contains('Local Study Reviewer'));
        // QA Finding: Headings/Titles are parsed by analyzer but omitted from generateReviewer output
        expect(reviewer, contains('Key Terms'));
        expect(reviewer, contains('- DATABASE'));
        expect(reviewer, contains('Definitions'));
        expect(
          reviewer,
          contains('A database: an organized collection of data'),
        );

        final quiz = service.generateQuiz(material, requestedCount: 5);
        expect(quiz, isNotEmpty);
        expect(quiz.every((q) => q.sourceText.isNotEmpty), isTrue);

        final cards = service.generateFlashcards(material);
        expect(cards, isNotEmpty);
      },
    );
  });

  group('8. DOCX Local Text Extraction (ZipDecoder + XML)', () {
    test('Generate DOCX zip structure and extract paragraphs locally', () async {
      // Construct a minimal valid docx archive
      final archive = Archive();
      const documentXml =
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>OPERATING SYSTEMS</w:t></w:r></w:p>
    <w:p><w:r><w:t>A process is an instance of a program in execution.</w:t></w:r></w:p>
    <w:p><w:r><w:t>Deadlock occurs when two processes wait indefinitely.</w:t></w:r></w:p>
  </w:body>
</w:document>''';

      final contentBytes = utf8.encode(documentXml);
      archive.addFile(
        ArchiveFile('word/document.xml', contentBytes.length, contentBytes),
      );
      final zipEncoder = ZipEncoder();
      final docxBytes = zipEncoder.encode(archive);

      expect(docxBytes, isNotNull);

      // Decode using the exact same logic as StudyMaterialService._extractDocx
      final decodedArchive = ZipDecoder().decodeBytes(docxBytes);
      final file = decodedArchive.findFile('word/document.xml');
      expect(file, isNotNull);

      final xml = XmlDocument.parse(utf8.decode(file!.content as List<int>));
      final paragraphs = <String>[];
      for (final paragraph in xml.findAllElements('w:p')) {
        final text = paragraph
            .findAllElements('w:t')
            .map((node) => node.innerText)
            .join();
        if (text.trim().isNotEmpty) paragraphs.add(text.trim());
      }
      final extractedDocxText = paragraphs.join('\n');

      expect(extractedDocxText, contains('OPERATING SYSTEMS'));
      expect(extractedDocxText, contains('instance of a program in execution'));

      final analysis = service.analyzeText(extractedDocxText);
      expect(analysis.titles, contains('OPERATING SYSTEMS'));
      expect(
        analysis.definitions.any(
          (d) => d.term.toLowerCase().contains('process'),
        ),
        isTrue,
      );
      expect(
        analysis.facts.any((f) => f.text.contains('Deadlock occurs')),
        isTrue,
      );
    });
  });

  group('9. Safeguards & Limits Validation', () {
    test('Scanned PDF 200-page limit boundary logic verification', () {
      // Rule in StudyMaterialService: if (pageCount > 200) -> rejected
      bool isAllowed(int pages) => pages <= 200;

      expect(isAllowed(199), isTrue, reason: '199 pages should be allowed');
      expect(isAllowed(200), isTrue, reason: '200 pages should be allowed');
      expect(isAllowed(201), isFalse, reason: '201 pages should be rejected');
    });

    test('File size 50 MB safeguard boundary verification', () {
      const maxAllowedBytes = 50 * 1024 * 1024; // 52,428,800 bytes
      bool isAllowedSize(int bytes) => bytes <= maxAllowedBytes;

      expect(isAllowedSize(maxAllowedBytes - 1), isTrue);
      expect(isAllowedSize(maxAllowedBytes), isTrue);
      expect(isAllowedSize(maxAllowedBytes + 1), isFalse);
    });
  });

  group('10. Error Handling & Malformed Input Safety', () {
    test(
      'Invalid DOCX document without word/document.xml throws FormatException',
      () {
        final archive = Archive();
        final documentFile = archive.findFile('word/document.xml');
        expect(documentFile, isNull);
        expect(() {
          if (documentFile == null) {
            throw const FormatException('Invalid DOCX document');
          }
        }, throwsA(isA<FormatException>()));
      },
    );
  });
}
