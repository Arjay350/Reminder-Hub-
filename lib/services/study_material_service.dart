import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../models/study_material_models.dart';
import 'hive_service.dart';

typedef MaterialProgressCallback = void Function(String message, double value);

class StudyMaterialService {
  static final StudyMaterialService instance = StudyMaterialService._internal();
  StudyMaterialService._internal();

  final HiveService _hive = HiveService.instance;

  Future<StudyMaterial> importMaterial(
    String filePath, {
    MaterialProgressCallback? onProgress,
  }) async {
    final file = File(filePath);
    final stat = await file.stat();
    final fileName = path.basename(filePath);
    final extension = path
        .extension(fileName)
        .toLowerCase()
        .replaceFirst('.', '');
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}_${fileName.hashCode}';

    try {
      onProgress?.call('Extracting text...', 0.15);
      final extraction = await _extractText(
        filePath,
        extension,
        onProgress: onProgress,
      );
      onProgress?.call('Analyzing content...', 0.65);
      final analysis = analyzeText(
        extraction.text,
        ocrConfidence: extraction.ocrConfidence,
      );
      final status = extraction.text.trim().isEmpty
          ? MaterialProcessingStatus.failed
          : MaterialProcessingStatus.completed;
      final material = StudyMaterial(
        id: id,
        fileName: fileName,
        filePath: filePath,
        fileType: extension.isEmpty ? 'unknown' : extension,
        fileSizeBytes: stat.size,
        importedAt: now,
        status: status,
        extractedText: extraction.text,
        analysis: analysis,
        errorMessage: status == MaterialProcessingStatus.failed
            ? extraction.errorMessage ??
                  'No readable text was found. Try a clearer image or a document containing selectable text.'
            : null,
      );
      await _hive.saveStudyMaterial(material);
      return material;
    } catch (error) {
      final material = StudyMaterial(
        id: id,
        fileName: fileName,
        filePath: filePath,
        fileType: extension.isEmpty ? 'unknown' : extension,
        fileSizeBytes: stat.size,
        importedAt: now,
        status: MaterialProcessingStatus.failed,
        extractedText: '',
        analysis: const StudyMaterialAnalysis(),
        errorMessage: _friendlyError(error),
      );
      await _hive.saveStudyMaterial(material);
      return material;
    }
  }

  StudyMaterialAnalysis analyzeText(
    String rawText, {
    double ocrConfidence = 1,
  }) {
    final text = _cleanText(rawText);
    if (text.isEmpty) return const StudyMaterialAnalysis(ocrConfidence: 0);

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final sentences = _sentences(text);
    final titles = <String>[];
    final definitions = <StudyDefinition>[];
    final facts = <StudyFact>[];
    final questions = <String>[];
    final keywordScores = <String, double>{};
    final termCounts = <String, int>{};

    for (final line in lines) {
      if (_looksLikeHeading(line)) titles.add(_stripHeadingPrefix(line));
      for (final word in _words(line)) {
        if (!_stopWords.contains(word)) {
          termCounts[word] = (termCounts[word] ?? 0) + 1;
          keywordScores[word] =
              (keywordScores[word] ?? 0) + (_looksLikeHeading(line) ? 3 : 1);
        }
      }
    }

    for (final sentence in sentences) {
      final definition = _parseDefinition(sentence);
      if (definition != null) {
        definitions.add(definition);
        keywordScores[definition.term.toLowerCase()] =
            (keywordScores[definition.term.toLowerCase()] ?? 0) + 5;
        continue;
      }
      if (sentence.contains('?')) {
        questions.add(sentence);
      }
      if (_looksLikeFact(sentence)) {
        facts.add(
          StudyFact(text: sentence, confidence: _factConfidence(sentence)),
        );
      }
    }

    for (final line in lines) {
      if (_isListItem(line) && line.length > 12) {
        final item = _stripListPrefix(line);
        if (!_containsIgnoreCase(facts.map((fact) => fact.text), item)) {
          facts.add(StudyFact(text: item, confidence: MaterialConfidence.high));
        }
      }
    }

    final rankedTerms =
        keywordScores.entries
            .where((entry) => entry.key.length > 2)
            .where((entry) => (termCounts[entry.key] ?? 0) > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final terms = <String>[];
    for (final entry in rankedTerms) {
      final display = _displayTerm(entry.key, lines);
      if (display != null &&
          !terms.any((term) => term.toLowerCase() == display.toLowerCase())) {
        terms.add(display);
      }
      if (terms.length == 30) break;
    }

    final topicSet = <String>{
      ...titles.take(15),
      ...definitions.map((definition) => definition.term),
    };
    if (topicSet.isEmpty) topicSet.addAll(terms.take(8));

    return StudyMaterialAnalysis(
      titles: titles.take(20).toList(),
      topics: topicSet.take(20).toList(),
      terms: terms,
      definitions: _uniqueDefinitions(definitions),
      facts: _uniqueFacts(facts).take(40).toList(),
      questionLikeSentences: questions.take(20).toList(),
      wordCount: _words(text).length,
      potentialQuestionCount: definitions.length + facts.length,
      ocrConfidence: ocrConfidence,
    );
  }

  String generateReviewer(StudyMaterial material) {
    final analysis = material.analysis;
    final buffer = StringBuffer()
      ..writeln('Local Study Reviewer')
      ..writeln('Generated from: ${material.name}')
      ..writeln()
      ..writeln(
        'This reviewer was generated locally from the imported material.',
      );

    if (analysis.terms.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Key Terms');
      for (final term in analysis.terms) {
        buffer.writeln('- $term');
      }
    }
    if (analysis.titles.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Key Headings / Topics');
      for (final title in analysis.titles) {
        buffer.writeln('- $title');
      }
    }
    if (analysis.definitions.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Definitions');
      for (final definition in analysis.definitions) {
        buffer.writeln('${definition.term}: ${definition.definition}');
      }
    }
    if (analysis.facts.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Important Facts');
      for (final fact in analysis.facts) {
        buffer.writeln('- ${fact.text}');
      }
    }
    return buffer.toString().trim();
  }

  List<StudyQuizQuestion> generateQuiz(
    StudyMaterial material, {
    int requestedCount = 10,
    String difficulty = 'easy',
    String type = 'mixed',
  }) {
    final analysis = material.analysis;
    final result = <StudyQuizQuestion>[];
    final usedPrompts = <String>{};
    final candidates = <_QuizCandidate>[];

    for (final definition in analysis.definitions) {
      if (definition.confidence == MaterialConfidence.low) continue;
      candidates.add(
        _QuizCandidate(
          prompt: 'What is ${definition.term}?',
          answer: definition.definition,
          source: definition.sourceText.isEmpty
              ? '${definition.term} is ${definition.definition}'
              : definition.sourceText,
          confidence: definition.confidence,
          kind: 'definition',
          distractors: analysis.definitions
              .where((item) => item.term != definition.term)
              .map((item) => item.definition)
              .toList(),
        ),
      );
      candidates.add(
        _QuizCandidate(
          prompt: _fillBlankPrompt(definition),
          answer: definition.term,
          source: definition.sourceText.isEmpty
              ? '${definition.term} is ${definition.definition}'
              : definition.sourceText,
          confidence: definition.confidence,
          kind: 'fillInBlank',
          distractors: const [],
        ),
      );
    }
    for (final fact in analysis.facts) {
      if (fact.confidence == MaterialConfidence.low) continue;
      candidates.add(
        _QuizCandidate(
          prompt: fact.text,
          answer: 'True',
          source: fact.text,
          confidence: fact.confidence,
          kind: 'trueFalse',
          distractors: const ['False'],
        ),
      );
      final falseStatement = _falseStatement(fact.text, analysis.terms);
      if (falseStatement != null) {
        candidates.add(
          _QuizCandidate(
            prompt: falseStatement,
            answer: 'False',
            source: fact.text,
            confidence: fact.confidence,
            kind: 'trueFalse',
            distractors: const ['True'],
          ),
        );
      }
    }

    for (final candidate in candidates) {
      if (result.length >= requestedCount) break;
      if (!_matchesDifficulty(candidate, difficulty)) continue;
      final allowed = type == 'mixed' || type == _quizTypeLabel(candidate.kind);
      if (!allowed) continue;
      final normalized = _normalize(candidate.prompt);
      if (!usedPrompts.add(normalized)) continue;
      final options = candidate.kind == 'definition'
          ? _options(candidate.answer, candidate.distractors)
          : candidate.kind == 'trueFalse'
          ? const ['True', 'False']
          : const <String>[];
      result.add(
        StudyQuizQuestion(
          id: '${material.id}_${result.length}',
          type: candidate.kind,
          prompt: candidate.prompt,
          options: options,
          answer: candidate.answer,
          explanation: candidate.source,
          confidence: candidate.confidence,
          sourceText: candidate.source,
        ),
      );
    }
    return result;
  }

  List<StudyFlashcard> generateFlashcards(StudyMaterial material) {
    final cards = <StudyFlashcard>[];
    for (final definition in material.analysis.definitions) {
      cards.add(
        StudyFlashcard(
          id: '${material.id}_definition_${cards.length}',
          front: 'What is ${definition.term}?',
          back: definition.definition,
          confidence: definition.confidence,
          sourceText: definition.sourceText,
        ),
      );
    }
    for (final fact in material.analysis.facts) {
      if (cards.length >= 50) break;
      cards.add(
        StudyFlashcard(
          id: '${material.id}_fact_${cards.length}',
          front: 'Recall this fact',
          back: fact.text,
          confidence: fact.confidence,
          sourceText: fact.text,
        ),
      );
    }
    return cards;
  }

  Future<StudyMaterial> saveReviewer(StudyMaterial material) async {
    final updated = material.copyWith(reviewer: generateReviewer(material));
    await _hive.saveStudyMaterial(updated);
    return updated;
  }

  Future<StudyMaterial> saveQuiz(
    StudyMaterial material, {
    int requestedCount = 10,
    String difficulty = 'easy',
    String type = 'mixed',
  }) async {
    final quiz = generateQuiz(
      material,
      requestedCount: requestedCount,
      difficulty: difficulty,
      type: type,
    );
    final updated = material.copyWith(quiz: quiz);
    await _hive.saveStudyMaterial(updated);
    return updated;
  }

  Future<StudyMaterial> saveFlashcards(StudyMaterial material) async {
    final updated = material.copyWith(flashcards: generateFlashcards(material));
    await _hive.saveStudyMaterial(updated);
    return updated;
  }

  Future<StudyMaterial> updateFlashcard(
    StudyMaterial material,
    String cardId, {
    bool? known,
    bool? needsReview,
  }) async {
    final cards = material.flashcards
        .map(
          (card) => card.id == cardId
              ? card.copyWith(known: known, needsReview: needsReview)
              : card,
        )
        .toList();
    final updated = material.copyWith(flashcards: cards);
    await _hive.saveStudyMaterial(updated);
    return updated;
  }

  Future<_ExtractionResult> _extractText(
    String filePath,
    String extension, {
    MaterialProgressCallback? onProgress,
  }) async {
    switch (extension) {
      case 'txt':
        return _ExtractionResult(text: await File(filePath).readAsString());
      case 'pdf':
        final bytes = await File(filePath).readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        try {
          final text = PdfTextExtractor(document).extractText();
          if (text.trim().isNotEmpty) {
            return _ExtractionResult(text: text);
          }
        } finally {
          document.dispose();
        }
        return _extractScannedPdf(filePath, onProgress: onProgress);
      case 'docx':
        return _ExtractionResult(text: await _extractDocx(filePath));
      case 'jpg':
      case 'jpeg':
      case 'png':
        onProgress?.call('Running local OCR...', 0.45);
        return _extractImageText(filePath);
      default:
        throw UnsupportedError(
          'Unsupported file type .$extension. Supported files: PDF, DOCX, TXT, JPG, JPEG, PNG.',
        );
    }
  }

  Future<_ExtractionResult> _extractScannedPdf(
    String filePath, {
    MaterialProgressCallback? onProgress,
  }) async {
    final document = await pdfx.PdfDocument.openFile(filePath);
    final pageCount = document.pagesCount;
    if (pageCount > 200) {
      await document.close();
      return const _ExtractionResult(
        text: '',
        ocrConfidence: 0,
        errorMessage:
            'This scanned PDF has more than 200 pages. Split it into smaller files before local OCR.',
      );
    }
    final pageTexts = <String>[];
    var failedPages = 0;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
        onProgress?.call(
          'OCR page $pageNumber of $pageCount',
          0.2 + (0.4 * pageNumber / pageCount),
        );
        pdfx.PdfPage? page;
        try {
          page = await document.getPage(pageNumber);
          final renderWidth = math.min(1800, math.max(900, page.width * 1.5));
          final renderHeight = page.height * (renderWidth / page.width);
          final rendered = await page.render(
            width: renderWidth.toDouble(),
            height: renderHeight,
            format: pdfx.PdfPageImageFormat.jpeg,
            quality: 85,
            backgroundColor: '#FFFFFF',
          );
          if (rendered == null) {
            throw const FormatException('PDF page rendering returned no image');
          }
          final temporaryFile = File(
            path.join(
              (await getTemporaryDirectory()).path,
              'reminderhub_study_page_${DateTime.now().microsecondsSinceEpoch}.jpg',
            ),
          );
          await temporaryFile.writeAsBytes(rendered.bytes, flush: true);
          try {
            final pageResult = await _recognizeImageText(
              temporaryFile.path,
              recognizer,
            );
            if (pageResult.text.trim().isNotEmpty) {
              pageTexts.add('[Page $pageNumber]\n${pageResult.text.trim()}');
            }
          } finally {
            if (await temporaryFile.exists()) await temporaryFile.delete();
          }
        } catch (_) {
          failedPages++;
        } finally {
          await page?.close();
        }
      }
    } finally {
      await recognizer.close();
      await document.close();
    }
    final text = combineOcrPages(pageTexts);
    return _ExtractionResult(
      text: text,
      ocrConfidence: text.isEmpty
          ? 0
          : text.split(RegExp(r'\s+')).length < 5
          ? 0.25
          : failedPages > 0
          ? 0.55
          : 0.7,
      errorMessage: text.isEmpty
          ? 'No readable text could be extracted from this scanned PDF. Try a clearer scan with better resolution and contrast.'
          : failedPages > 0
          ? '$failedPages page${failedPages == 1 ? '' : 's'} could not be read. The remaining pages were processed.'
          : null,
    );
  }

  String combineOcrPages(List<String> pages) =>
      pages.where((page) => page.trim().isNotEmpty).join('\n\n');
  Future<String> _extractDocx(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentFile = archive.findFile('word/document.xml');
    if (documentFile == null) {
      throw const FormatException('Invalid DOCX document');
    }
    final xml = XmlDocument.parse(
      utf8.decode(documentFile.content as List<int>),
    );
    final paragraphs = <String>[];
    for (final paragraph in xml.findAllElements('w:p')) {
      final text = paragraph
          .findAllElements('w:t')
          .map((node) => node.innerText)
          .join();
      if (text.trim().isNotEmpty) paragraphs.add(text.trim());
    }
    return paragraphs.join('\n');
  }

  Future<_ExtractionResult> _extractImageText(String filePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      return _recognizeImageText(filePath, recognizer);
    } finally {
      await recognizer.close();
    }
  }

  Future<_ExtractionResult> _recognizeImageText(
    String filePath,
    TextRecognizer recognizer,
  ) async {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(filePath),
    );
    final text = result.text.trim();
    return _ExtractionResult(
      text: text,
      ocrConfidence: text.length < 20 ? 0.25 : 0.7,
      errorMessage: text.isEmpty
          ? 'No readable text was found. Try a clearer image or a document containing selectable text.'
          : null,
    );
  }

  String _cleanText(String text) => text
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  List<String> _sentences(String text) => text
      .split(RegExp(r'(?<=[.!?])\s+|\n+'))
      .map((sentence) => sentence.trim())
      .where((sentence) => sentence.length >= 12)
      .toList();

  StudyDefinition? _parseDefinition(String sentence) {
    final match = RegExp(
      r'^(.{2,80}?)\s+(?:is defined as|refers to|means|is the process of|is|are)\s+(.+?)[.!?]?$',
      caseSensitive: false,
    ).firstMatch(sentence.trim());
    if (match == null) return null;
    final term = match
        .group(1)!
        .trim()
        .replaceFirst(RegExp(r'^[-*\d.) ]+'), '');
    final definition = match.group(2)!.trim();
    if (term.split(RegExp(r'\s+')).length > 8 || definition.length < 8) {
      return null;
    }
    return StudyDefinition(
      term: term,
      definition: definition,
      confidence: MaterialConfidence.high,
      sourceText: sentence,
    );
  }

  bool _looksLikeHeading(String line) {
    final words = line.split(RegExp(r'\s+'));
    if (words.length > 12 || line.endsWith('.') || line.endsWith('?')) {
      return false;
    }
    if (RegExp(
      r'^(?:chapter|section|unit|lesson|topic)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }
    return line == line.toUpperCase() && line.length > 3;
  }

  bool _isListItem(String line) =>
      RegExp(r'^(?:[-*•]|\d+[.)])\s+').hasMatch(line);

  bool _looksLikeFact(String sentence) => RegExp(
    r'\b(occur|occurs|contain|contains|consist|consists|produce|produces|use|uses|used|locate|located|find|found|include|includes|require|requires|provide|provides|call|called|known|important|classify|classified|measure|measured)\b',
    caseSensitive: false,
  ).hasMatch(sentence);

  MaterialConfidence _factConfidence(String sentence) => sentence.length <= 180
      ? MaterialConfidence.high
      : MaterialConfidence.medium;

  List<String> _words(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 2)
      .toList();

  String _stripHeadingPrefix(String line) => line
      .replaceFirst(
        RegExp(
          r'^(?:chapter|section|unit|lesson|topic)\s*[:\-]?\s*',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  String _stripListPrefix(String line) =>
      line.replaceFirst(RegExp(r'^(?:[-*•]|\d+[.)])\s+'), '').trim();

  String? _displayTerm(String term, List<String> lines) {
    for (final line in lines) {
      final match = RegExp(
        '\\b${RegExp.escape(term)}\\b',
        caseSensitive: false,
      ).firstMatch(line);
      if (match != null) return match.group(0);
    }
    return term;
  }

  List<StudyDefinition> _uniqueDefinitions(List<StudyDefinition> values) {
    final seen = <String>{};
    return values.where((item) => seen.add(_normalize(item.term))).toList();
  }

  List<StudyFact> _uniqueFacts(List<StudyFact> values) {
    final seen = <String>{};
    return values.where((item) => seen.add(_normalize(item.text))).toList();
  }

  bool _containsIgnoreCase(Iterable<String> values, String target) =>
      values.any((value) => _normalize(value) == _normalize(target));

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  List<String> _options(String answer, List<String> distractors) {
    final options = <String>[answer];
    for (final distractor in distractors) {
      if (distractor != answer && !options.contains(distractor)) {
        options.add(distractor);
      }
      if (options.length == 4) break;
    }
    options.shuffle(math.Random());
    return options.length >= 2 ? options : const [];
  }

  bool _matchesDifficulty(_QuizCandidate candidate, String difficulty) {
    final source = candidate.source.toLowerCase();
    final detailed = source.length >= 70;
    final relational = RegExp(
      r'\b(and|between|while|because|therefore|whereas|compared|relationship|causes|depends)\b',
    ).hasMatch(source);
    switch (difficulty) {
      case 'medium':
        return candidate.kind == 'trueFalse' || detailed;
      case 'hard':
        return detailed && relational;
      case 'easy':
      default:
        return candidate.kind == 'definition' || !detailed;
    }
  }

  String _fillBlankPrompt(StudyDefinition definition) {
    final source = definition.sourceText.isEmpty
        ? '${definition.term} is ${definition.definition}.'
        : definition.sourceText;
    final match = RegExp(
      RegExp.escape(definition.term),
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) return '${definition.term} is defined as ______.';
    return source.replaceRange(match.start, match.end, '______');
  }

  String? _falseStatement(String fact, List<String> terms) {
    final matching = terms
        .where(
          (term) => RegExp(
            '\\b${RegExp.escape(term)}\\b',
            caseSensitive: false,
          ).hasMatch(fact),
        )
        .toList();
    if (matching.isEmpty) return null;
    final replacement = terms.firstWhere(
      (term) =>
          !matching.any((item) => item.toLowerCase() == term.toLowerCase()),
      orElse: () => '',
    );
    if (replacement.isEmpty) return null;
    return fact.replaceFirst(
      RegExp(RegExp.escape(matching.first), caseSensitive: false),
      replacement,
    );
  }

  String _quizTypeLabel(String kind) => switch (kind) {
    'definition' => 'multipleChoice',
    'trueFalse' => 'trueFalse',
    'fillInBlank' => 'fillInBlank',
    _ => kind,
  };

  String _friendlyError(Object error) {
    if (error is UnsupportedError) {
      return error.message?.toString() ?? 'Unsupported file.';
    }
    if (error is FormatException) {
      return 'The selected document appears to be corrupted or invalid.';
    }
    return 'The material could not be processed locally: $error';
  }

  static const _stopWords = <String>{
    'the',
    'and',
    'for',
    'are',
    'but',
    'not',
    'you',
    'all',
    'any',
    'can',
    'had',
    'her',
    'was',
    'one',
    'our',
    'out',
    'this',
    'that',
    'with',
    'from',
    'they',
    'have',
    'were',
    'will',
    'would',
    'there',
    'their',
    'which',
    'about',
    'into',
    'than',
    'then',
    'them',
    'these',
    'those',
    'also',
    'being',
    'when',
    'where',
    'what',
    'whose',
    'how',
    'why',
    'does',
    'its',
    'has',
    'his',
    'she',
    'him',
    'more',
    'some',
    'such',
    'only',
    'over',
    'under',
    'between',
    'through',
    'during',
    'each',
    'other',
    'may',
    'might',
    'should',
    'could',
    'very',
  };
}

class _ExtractionResult {
  const _ExtractionResult({
    required this.text,
    this.ocrConfidence = 1,
    this.errorMessage,
  });

  final String text;
  final double ocrConfidence;
  final String? errorMessage;
}

class _QuizCandidate {
  const _QuizCandidate({
    required this.prompt,
    required this.answer,
    required this.source,
    required this.confidence,
    required this.kind,
    required this.distractors,
  });

  final String prompt;
  final String answer;
  final String source;
  final MaterialConfidence confidence;
  final String kind;
  final List<String> distractors;
}
