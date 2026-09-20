enum MaterialProcessingStatus { imported, processing, completed, failed }

enum MaterialConfidence { high, medium, low }

class StudyDefinition {
  const StudyDefinition({
    required this.term,
    required this.definition,
    this.confidence = MaterialConfidence.high,
    this.sourceText = '',
    this.sourcePage,
  });

  final String term;
  final String definition;
  final MaterialConfidence confidence;
  final String sourceText;
  final int? sourcePage;

  Map<String, dynamic> toJson() => {
    'term': term,
    'definition': definition,
    'confidence': confidence.name,
    'sourceText': sourceText,
    'sourcePage': sourcePage,
  };

  factory StudyDefinition.fromJson(Map<String, dynamic> json) =>
      StudyDefinition(
        term: (json['term'] as String?) ?? '',
        definition: (json['definition'] as String?) ?? '',
        confidence: MaterialConfidence.values.firstWhere(
          (value) => value.name == json['confidence'],
          orElse: () => MaterialConfidence.high,
        ),
        sourceText: (json['sourceText'] as String?) ?? '',
        sourcePage: (json['sourcePage'] as num?)?.toInt(),
      );
}

class StudyFact {
  const StudyFact({
    required this.text,
    this.confidence = MaterialConfidence.medium,
    this.sourcePage,
  });

  final String text;
  final MaterialConfidence confidence;
  final int? sourcePage;

  Map<String, dynamic> toJson() => {
    'text': text,
    'confidence': confidence.name,
    'sourcePage': sourcePage,
  };

  factory StudyFact.fromJson(Map<String, dynamic> json) => StudyFact(
    text: (json['text'] as String?) ?? '',
    confidence: MaterialConfidence.values.firstWhere(
      (value) => value.name == json['confidence'],
      orElse: () => MaterialConfidence.medium,
    ),
    sourcePage: (json['sourcePage'] as num?)?.toInt(),
  );
}

class StudyMaterialAnalysis {
  const StudyMaterialAnalysis({
    this.titles = const [],
    this.topics = const [],
    this.terms = const [],
    this.definitions = const [],
    this.facts = const [],
    this.questionLikeSentences = const [],
    this.wordCount = 0,
    this.potentialQuestionCount = 0,
    this.ocrConfidence = 1,
  });

  final List<String> titles;
  final List<String> topics;
  final List<String> terms;
  final List<StudyDefinition> definitions;
  final List<StudyFact> facts;
  final List<String> questionLikeSentences;
  final int wordCount;
  final int potentialQuestionCount;
  final double ocrConfidence;

  Map<String, dynamic> toJson() => {
    'titles': titles,
    'topics': topics,
    'terms': terms,
    'definitions': definitions.map((item) => item.toJson()).toList(),
    'facts': facts.map((item) => item.toJson()).toList(),
    'questionLikeSentences': questionLikeSentences,
    'wordCount': wordCount,
    'potentialQuestionCount': potentialQuestionCount,
    'ocrConfidence': ocrConfidence,
  };

  factory StudyMaterialAnalysis.fromJson(Map<String, dynamic> json) =>
      StudyMaterialAnalysis(
        titles: _stringList(json['titles']),
        topics: _stringList(json['topics']),
        terms: _stringList(json['terms']),
        definitions: _objectList(json['definitions'], StudyDefinition.fromJson),
        facts: _objectList(json['facts'], StudyFact.fromJson),
        questionLikeSentences: _stringList(json['questionLikeSentences']),
        wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
        potentialQuestionCount:
            (json['potentialQuestionCount'] as num?)?.toInt() ?? 0,
        ocrConfidence: (json['ocrConfidence'] as num?)?.toDouble() ?? 1,
      );
}

class StudyQuizQuestion {
  const StudyQuizQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.confidence,
    this.sourceText = '',
  });

  final String id;
  final String type;
  final String prompt;
  final List<String> options;
  final String answer;
  final String explanation;
  final MaterialConfidence confidence;
  final String sourceText;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'prompt': prompt,
    'options': options,
    'answer': answer,
    'explanation': explanation,
    'confidence': confidence.name,
    'sourceText': sourceText,
  };

  factory StudyQuizQuestion.fromJson(Map<String, dynamic> json) =>
      StudyQuizQuestion(
        id: (json['id'] as String?) ?? '',
        type: (json['type'] as String?) ?? 'multipleChoice',
        prompt: (json['prompt'] as String?) ?? '',
        options: _stringList(json['options']),
        answer: (json['answer'] as String?) ?? '',
        explanation: (json['explanation'] as String?) ?? '',
        confidence: MaterialConfidence.values.firstWhere(
          (value) => value.name == json['confidence'],
          orElse: () => MaterialConfidence.medium,
        ),
        sourceText: (json['sourceText'] as String?) ?? '',
      );
}

class StudyFlashcard {
  const StudyFlashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.confidence,
    this.sourceText = '',
    this.known = false,
    this.needsReview = false,
  });

  final String id;
  final String front;
  final String back;
  final MaterialConfidence confidence;
  final String sourceText;
  final bool known;
  final bool needsReview;

  StudyFlashcard copyWith({bool? known, bool? needsReview}) => StudyFlashcard(
    id: id,
    front: front,
    back: back,
    confidence: confidence,
    sourceText: sourceText,
    known: known ?? this.known,
    needsReview: needsReview ?? this.needsReview,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'front': front,
    'back': back,
    'confidence': confidence.name,
    'sourceText': sourceText,
    'known': known,
    'needsReview': needsReview,
  };

  factory StudyFlashcard.fromJson(Map<String, dynamic> json) => StudyFlashcard(
    id: (json['id'] as String?) ?? '',
    front: (json['front'] as String?) ?? '',
    back: (json['back'] as String?) ?? '',
    confidence: MaterialConfidence.values.firstWhere(
      (value) => value.name == json['confidence'],
      orElse: () => MaterialConfidence.medium,
    ),
    sourceText: (json['sourceText'] as String?) ?? '',
    known: json['known'] is bool ? json['known'] as bool : false,
    needsReview: json['needsReview'] is bool
        ? json['needsReview'] as bool
        : false,
  );
}

class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.fileSizeBytes,
    required this.importedAt,
    required this.status,
    required this.extractedText,
    required this.analysis,
    this.displayName,
    this.errorMessage,
    this.reviewer,
    this.quiz = const [],
    this.flashcards = const [],
    this.quizScore,
  });

  final String id;
  final String fileName;
  final String filePath;
  final String fileType;
  final int fileSizeBytes;
  final DateTime importedAt;
  final MaterialProcessingStatus status;
  final String extractedText;
  final StudyMaterialAnalysis analysis;
  final String? displayName;
  final String? errorMessage;
  final String? reviewer;
  final List<StudyQuizQuestion> quiz;
  final List<StudyFlashcard> flashcards;
  final int? quizScore;

  String get name =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : fileName;

  StudyMaterial copyWith({
    String? displayName,
    MaterialProcessingStatus? status,
    String? extractedText,
    StudyMaterialAnalysis? analysis,
    String? errorMessage,
    String? reviewer,
    List<StudyQuizQuestion>? quiz,
    List<StudyFlashcard>? flashcards,
    int? quizScore,
  }) => StudyMaterial(
    id: id,
    fileName: fileName,
    filePath: filePath,
    fileType: fileType,
    fileSizeBytes: fileSizeBytes,
    importedAt: importedAt,
    status: status ?? this.status,
    extractedText: extractedText ?? this.extractedText,
    analysis: analysis ?? this.analysis,
    displayName: displayName ?? this.displayName,
    errorMessage: errorMessage ?? this.errorMessage,
    reviewer: reviewer ?? this.reviewer,
    quiz: quiz ?? this.quiz,
    flashcards: flashcards ?? this.flashcards,
    quizScore: quizScore ?? this.quizScore,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'filePath': filePath,
    'fileType': fileType,
    'fileSizeBytes': fileSizeBytes,
    'importedAt': importedAt.toIso8601String(),
    'status': status.name,
    'extractedText': extractedText,
    'analysis': analysis.toJson(),
    'displayName': displayName,
    'errorMessage': errorMessage,
    'reviewer': reviewer,
    'quiz': quiz.map((item) => item.toJson()).toList(),
    'flashcards': flashcards.map((item) => item.toJson()).toList(),
    'quizScore': quizScore,
  };

  factory StudyMaterial.fromJson(Map<String, dynamic> json) => StudyMaterial(
    id: (json['id'] as String?) ?? '',
    fileName: (json['fileName'] as String?) ?? '',
    filePath: (json['filePath'] as String?) ?? '',
    fileType: (json['fileType'] as String?) ?? 'unknown',
    fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
    importedAt:
        DateTime.tryParse((json['importedAt'] as String?) ?? '') ??
        DateTime.now(),
    status: MaterialProcessingStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => MaterialProcessingStatus.failed,
    ),
    extractedText: (json['extractedText'] as String?) ?? '',
    analysis: StudyMaterialAnalysis.fromJson(
      Map<String, dynamic>.from(json['analysis'] as Map? ?? {}),
    ),
    displayName: json['displayName'] as String?,
    errorMessage: json['errorMessage'] as String?,
    reviewer: json['reviewer'] as String?,
    quiz: _objectList(json['quiz'], StudyQuizQuestion.fromJson),
    flashcards: _objectList(json['flashcards'], StudyFlashcard.fromJson),
    quizScore: (json['quizScore'] as num?)?.toInt(),
  );
}

List<String> _stringList(dynamic value) =>
    value is List ? value.whereType<String>().toList() : <String>[];

List<T> _objectList<T>(dynamic value, T Function(Map<String, dynamic>) parse) =>
    value is List
    ? value
          .whereType<Map>()
          .map((item) => parse(Map<String, dynamic>.from(item)))
          .toList()
    : <T>[];
