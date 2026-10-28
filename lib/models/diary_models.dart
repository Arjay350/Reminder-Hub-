class NotebookChecklistItem {
  const NotebookChecklistItem({
    required this.id,
    required this.text,
    this.isChecked = false,
  });

  final String id;
  final String text;
  final bool isChecked;

  NotebookChecklistItem copyWith({String? text, bool? isChecked}) =>
      NotebookChecklistItem(
        id: id,
        text: text ?? this.text,
        isChecked: isChecked ?? this.isChecked,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isChecked': isChecked,
  };

  factory NotebookChecklistItem.fromJson(Map<String, dynamic> json) =>
      NotebookChecklistItem(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        isChecked: json['isChecked'] as bool? ?? false,
      );
}

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.mood,
    this.category = 'Personal',
    this.tags = const [],
    this.linkedSubjectId,
    this.linkedSubjectName,
    this.checklistItems = const [],
    this.isLocked = false,
    this.encryptedPayload,
    this.isUnlockedInMemory = false,
  });

  static const moods = <String, String>{
    'Happy': '😊',
    'Sad': '😔',
    'Angry': '😠',
    'Calm': '😌',
    'Exhausted': '😴',
    'Stressed': '😣',
    'Productive': '💪',
  };

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? mood;
  final String category;
  final List<String> tags;
  final String? linkedSubjectId;
  final String? linkedSubjectName;
  final List<NotebookChecklistItem> checklistItems;
  final bool isLocked;
  final String? encryptedPayload;
  final bool isUnlockedInMemory;

  String get displayTitle =>
      title.trim().isEmpty ? _formatDate(createdAt) : title.trim();

  DiaryEntry copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    String? mood,
    bool clearMood = false,
    String? category,
    List<String>? tags,
    String? linkedSubjectId,
    String? linkedSubjectName,
    bool clearLinkedSubject = false,
    List<NotebookChecklistItem>? checklistItems,
    bool? isLocked,
    bool? isUnlockedInMemory,
  }) => DiaryEntry(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    mood: clearMood ? null : (mood ?? this.mood),
    category: category ?? this.category,
    tags: tags ?? this.tags,
    linkedSubjectId: clearLinkedSubject
        ? null
        : (linkedSubjectId ?? this.linkedSubjectId),
    linkedSubjectName: clearLinkedSubject
        ? null
        : (linkedSubjectName ?? this.linkedSubjectName),
    checklistItems: checklistItems ?? this.checklistItems,
    isLocked: isLocked ?? this.isLocked,
    isUnlockedInMemory: isUnlockedInMemory ?? this.isUnlockedInMemory,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'mood': mood,
    'category': category,
    'tags': tags,
    'linkedSubjectId': linkedSubjectId,
    'linkedSubjectName': linkedSubjectName,
    'checklistItems': checklistItems.map((item) => item.toJson()).toList(),
  };

  Map<String, dynamic> toPrivatePayload() => {
    'title': title,
    'content': content,
    'mood': mood,
    'category': category,
    'tags': tags,
    'linkedSubjectId': linkedSubjectId,
    'linkedSubjectName': linkedSubjectName,
    'checklistItems': checklistItems.map((item) => item.toJson()).toList(),
  };

  Map<String, dynamic> toStoredJson({String? encryptedPayload}) =>
      isLocked
      ? {
          'id': id,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': updatedAt.toIso8601String(),
          'isLocked': true,
          'encryptedPayload': encryptedPayload ?? this.encryptedPayload,
        }
      : {...toJson(), 'isLocked': false};

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final isLocked = json['isLocked'] as bool? ?? false;
    final date = DateTime.tryParse(json['createdAt'] as String? ?? '');
    return DiaryEntry(
      id: json['id'] as String? ?? '',
      title: isLocked ? '' : (json['title'] as String? ?? ''),
      content: isLocked ? '' : (json['content'] as String? ?? ''),
      createdAt: date ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          date ??
          DateTime.fromMillisecondsSinceEpoch(0),
      mood: isLocked ? null : _validMood(json['mood']),
      category: isLocked ? 'Private' : json['category'] as String? ?? 'Personal',
      tags: isLocked ? const [] : _stringList(json['tags']),
      linkedSubjectId: isLocked ? null : json['linkedSubjectId'] as String?,
      linkedSubjectName: isLocked
          ? null
          : json['linkedSubjectName'] as String?,
      checklistItems: isLocked
          ? const []
          : _checklist(json['checklistItems']),
      isLocked: isLocked,
      encryptedPayload: isLocked
          ? json['encryptedPayload'] as String?
          : null,
      isUnlockedInMemory: false,
    );
  }
}

class NotebookNote {
  const NotebookNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.category = 'Other',
    this.tags = const [],
    this.linkedSubjectId,
    this.linkedSubjectName,
    this.checklistItems = const [],
    this.isPinned = false,
    this.isLocked = false,
    this.encryptedPayload,
    this.isUnlockedInMemory = false,
  });

  static const categories = <String, String>{
    'Study': '📚',
    'School': '🏫',
    'Personal': '👤',
    'Ideas': '💡',
    'Finances': '💰',
    'Work': '💼',
    'Other': '📌',
  };

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String category;
  final List<String> tags;
  final String? linkedSubjectId;
  final String? linkedSubjectName;
  final List<NotebookChecklistItem> checklistItems;
  final bool isPinned;
  final bool isLocked;
  final String? encryptedPayload;
  final bool isUnlockedInMemory;

  NotebookNote copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    String? category,
    List<String>? tags,
    String? linkedSubjectId,
    String? linkedSubjectName,
    bool clearLinkedSubject = false,
    List<NotebookChecklistItem>? checklistItems,
    bool? isPinned,
    bool? isLocked,
    bool? isUnlockedInMemory,
  }) => NotebookNote(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    linkedSubjectId: clearLinkedSubject
        ? null
        : (linkedSubjectId ?? this.linkedSubjectId),
    linkedSubjectName: clearLinkedSubject
        ? null
        : (linkedSubjectName ?? this.linkedSubjectName),
    checklistItems: checklistItems ?? this.checklistItems,
    isPinned: isPinned ?? this.isPinned,
    isLocked: isLocked ?? this.isLocked,
    isUnlockedInMemory: isUnlockedInMemory ?? this.isUnlockedInMemory,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'category': category,
    'tags': tags,
    'linkedSubjectId': linkedSubjectId,
    'linkedSubjectName': linkedSubjectName,
    'checklistItems': checklistItems.map((item) => item.toJson()).toList(),
    'isPinned': isPinned,
  };

  Map<String, dynamic> toPrivatePayload() => {
    'title': title,
    'content': content,
    'category': category,
    'tags': tags,
    'linkedSubjectId': linkedSubjectId,
    'linkedSubjectName': linkedSubjectName,
    'checklistItems': checklistItems.map((item) => item.toJson()).toList(),
    'isPinned': isPinned,
  };

  Map<String, dynamic> toStoredJson({String? encryptedPayload}) =>
      isLocked
      ? {
          'id': id,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': updatedAt.toIso8601String(),
          'isLocked': true,
          'encryptedPayload': encryptedPayload ?? this.encryptedPayload,
        }
      : {...toJson(), 'isLocked': false};

  factory NotebookNote.fromJson(Map<String, dynamic> json) {
    final isLocked = json['isLocked'] as bool? ?? false;
    final date = DateTime.tryParse(json['createdAt'] as String? ?? '');
    return NotebookNote(
      id: json['id'] as String? ?? '',
      title: isLocked ? '' : (json['title'] as String? ?? ''),
      content: isLocked ? '' : (json['content'] as String? ?? ''),
      createdAt: date ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          date ??
          DateTime.fromMillisecondsSinceEpoch(0),
      category: isLocked ? 'Private' : json['category'] as String? ?? 'Other',
      tags: isLocked ? const [] : _stringList(json['tags']),
      linkedSubjectId: isLocked ? null : json['linkedSubjectId'] as String?,
      linkedSubjectName: isLocked
          ? null
          : json['linkedSubjectName'] as String?,
      checklistItems: isLocked
          ? const []
          : _checklist(json['checklistItems']),
      isPinned: isLocked ? false : json['isPinned'] as bool? ?? false,
      isLocked: isLocked,
      encryptedPayload: isLocked
          ? json['encryptedPayload'] as String?
          : null,
      isUnlockedInMemory: false,
    );
  }
}

String _formatDate(DateTime date) =>
    '${_monthName(date.month)} ${date.day}, ${date.year}';

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String? _validMood(dynamic value) =>
    value is String && DiaryEntry.moods.containsKey(value) ? value : null;

List<String> _stringList(dynamic value) => value is List
    ? value.whereType<String>().where((item) => item.trim().isNotEmpty).toList()
    : const [];

List<NotebookChecklistItem> _checklist(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map(
            (item) => NotebookChecklistItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList()
    : const [];
