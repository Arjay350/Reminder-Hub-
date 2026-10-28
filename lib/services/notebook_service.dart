import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;

import '../core/security/security_service.dart';
import '../models/diary_models.dart';
import 'hive_service.dart';
import 'pet_service.dart';

class NotebookService {
  NotebookService._();
  static final NotebookService instance = NotebookService._();

  final HiveService _hive = HiveService.instance;
  final Random _random = Random.secure();

  List<DiaryEntry> getDiaryEntries() => _hive.getDiaryEntries();
  List<NotebookNote> getNotes() => _hive.getNotes();

  Future<void> saveDiaryEntry(DiaryEntry entry, {bool isNew = false}) async {
    if (entry.id.trim().isEmpty) {
      throw ArgumentError.value(entry.id, 'entry.id', 'Must not be empty');
    }
    if (entry.isLocked) {
      final payload = entry.isUnlockedInMemory || entry.encryptedPayload == null
          ? await _encrypt(entry.toPrivatePayload())
          : entry.encryptedPayload!;
      await _hive.saveStoredDiaryEntry(
        entry.id,
        entry.toStoredJson(encryptedPayload: payload),
      );
    } else {
      await _hive.saveStoredDiaryEntry(entry.id, entry.toStoredJson());
    }

    if (isNew) {
      try {
        final pet = PetService.instance;
        if (pet.isEnabled) {
          await pet.recordTaskProgress(
            'diary_entry',
            count: 1,
            setDirect: true,
          );
          pet.onDiaryMoodSelected(entry.mood);
        }
      } catch (error) {
        debugPrint('NotebookService: pet diary integration failed: $error');
      }
    }
  }

  Future<void> saveNote(NotebookNote note) async {
    if (note.id.trim().isEmpty) {
      throw ArgumentError.value(note.id, 'note.id', 'Must not be empty');
    }
    if (note.isLocked) {
      final payload = note.isUnlockedInMemory || note.encryptedPayload == null
          ? await _encrypt(note.toPrivatePayload())
          : note.encryptedPayload!;
      await _hive.saveStoredNote(
        note.id,
        note.toStoredJson(encryptedPayload: payload),
      );
    } else {
      await _hive.saveStoredNote(note.id, note.toStoredJson());
    }
  }

  Future<DiaryEntry?> openDiaryEntry(DiaryEntry entry) async {
    if (!entry.isLocked) return entry;
    final authenticated = await SecurityService.instance.authenticate(
      reason: 'Authenticate to unlock this private diary entry',
    );
    if (!authenticated) return null;
    final payload = entry.encryptedPayload;
    if (payload == null || payload.isEmpty) {
      throw const FormatException('Private diary entry has no encrypted data');
    }
    final opened = _diaryFromPayload(entry, await _decrypt(payload));
    if (payload.split(':').length == 2) {
      await saveDiaryEntry(opened);
    }
    return opened;
  }

  Future<NotebookNote?> openNote(NotebookNote note) async {
    if (!note.isLocked) return note;
    final authenticated = await SecurityService.instance.authenticate(
      reason: 'Authenticate to unlock this private note',
    );
    if (!authenticated) return null;
    final payload = note.encryptedPayload;
    if (payload == null || payload.isEmpty) {
      throw const FormatException('Private note has no encrypted data');
    }
    final opened = _noteFromPayload(note, await _decrypt(payload));
    if (payload.split(':').length == 2) {
      await saveNote(opened);
    }
    return opened;
  }

  Future<void> deleteDiaryEntry(String id) => _hive.deleteDiaryEntry(id);
  Future<void> deleteNote(String id) => _hive.deleteNote(id);

  bool diaryMatches(DiaryEntry entry, String query) {
    if (entry.isLocked) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return entry.title.toLowerCase().contains(q) ||
        entry.content.toLowerCase().contains(q) ||
        (entry.mood?.toLowerCase().contains(q) ?? false) ||
        entry.category.toLowerCase().contains(q) ||
        entry.tags.any((tag) => tag.toLowerCase().contains(q)) ||
        (entry.linkedSubjectName?.toLowerCase().contains(q) ?? false);
  }

  bool noteMatches(NotebookNote note, String query) {
    if (note.isLocked) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return note.title.toLowerCase().contains(q) ||
        note.content.toLowerCase().contains(q) ||
        note.category.toLowerCase().contains(q) ||
        note.tags.any((tag) => tag.toLowerCase().contains(q)) ||
        (note.linkedSubjectName?.toLowerCase().contains(q) ?? false);
  }

  Future<String> exportDiaryMarkdown(DiaryEntry entry) async {
    final checklist = entry.checklistItems.isEmpty
        ? ''
        : '\n\n## Checklist\n${entry.checklistItems.map((item) => '- [${item.isChecked ? 'x' : ' '}] ${item.text}').join('\n')}';
    return [
      '# ${entry.displayTitle}',
      DateTimeToLongDate.format(entry.createdAt),
      'Last modified: ${DateTimeToLongDate.format(entry.updatedAt)}',
      if (entry.mood != null)
        'Mood: ${DiaryEntry.moods[entry.mood]} ${entry.mood}',
      'Category: ${entry.category}',
      if (entry.tags.isNotEmpty) 'Tags: ${entry.tags.join(', ')}',
      if (entry.linkedSubjectName?.isNotEmpty == true)
        'Subject: ${entry.linkedSubjectName}',
      '',
      entry.content,
      checklist,
    ].join('\n');
  }

  Future<String> exportNoteMarkdown(NotebookNote note) async {
    final checklist = note.checklistItems.isEmpty
        ? ''
        : '\n\n## Checklist\n${note.checklistItems.map((item) => '- [${item.isChecked ? 'x' : ' '}] ${item.text}').join('\n')}';
    return [
      '# ${note.title.trim().isEmpty ? 'Untitled note' : note.title.trim()}',
      DateTimeToLongDate.format(note.createdAt),
      'Last modified: ${DateTimeToLongDate.format(note.updatedAt)}',
      'Category: ${note.category}',
      if (note.tags.isNotEmpty) 'Tags: ${note.tags.join(', ')}',
      if (note.linkedSubjectName?.isNotEmpty == true)
        'Subject: ${note.linkedSubjectName}',
      '',
      note.content,
      checklist,
    ].join('\n');
  }

  Future<String> _encrypt(Map<String, dynamic> data) async {
    final key = await _encryptionKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encryptionKey = encrypt.Key.fromBase64(key);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(encryptionKey, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(jsonEncode(data), iv: iv);
    final authenticatedData = '${iv.base64}:${encrypted.base64}';
    final mac = crypto.Hmac(
      crypto.sha256,
      _authenticationKey(encryptionKey),
    ).convert(utf8.encode(authenticatedData));
    return 'v2:$authenticatedData:${base64Encode(mac.bytes)}';
  }

  Future<Map<String, dynamic>> _decrypt(String payload) async {
    final parts = payload.split(':');
    final isLegacyPayload = parts.length == 2;
    if (!isLegacyPayload && (parts.length != 4 || parts[0] != 'v2')) {
      throw const FormatException('Invalid private notebook payload');
    }
    final encryptionKey = encrypt.Key.fromBase64(await _encryptionKey());
    final ivPart = isLegacyPayload ? parts[0] : parts[1];
    final ciphertextPart = isLegacyPayload ? parts[1] : parts[2];
    if (!isLegacyPayload) {
      final authenticatedData = '$ivPart:$ciphertextPart';
      final expectedMac = crypto.Hmac(
        crypto.sha256,
        _authenticationKey(encryptionKey),
      ).convert(utf8.encode(authenticatedData)).bytes;
      final suppliedMac = base64Decode(parts[3]);
      if (!_constantTimeEquals(expectedMac, suppliedMac)) {
        throw const FormatException('Private notebook integrity check failed');
      }
    }
    final encrypter = encrypt.Encrypter(
      encrypt.AES(encryptionKey, mode: encrypt.AESMode.cbc),
    );
    final plaintext = encrypter.decrypt64(
      ciphertextPart,
      iv: encrypt.IV.fromBase64(ivPart),
    );
    final decoded = jsonDecode(plaintext);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid private notebook content');
    }
    return decoded;
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    var difference = first.length ^ second.length;
    final length = first.length > second.length ? first.length : second.length;
    for (var index = 0; index < length; index++) {
      final left = index < first.length ? first[index] : 0;
      final right = index < second.length ? second[index] : 0;
      difference |= left ^ right;
    }
    return difference == 0;
  }

  List<int> _authenticationKey(encrypt.Key encryptionKey) => crypto.sha256
      .convert(
        utf8.encode(
          'ReminderHub notebook authentication:${encryptionKey.base64}',
        ),
      )
      .bytes;

  Future<String> _encryptionKey() async {
    final security = SecurityService.instance;
    final existing = await security.getNotebookEncryptionKey();
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final key = base64Encode(bytes);
    await security.setNotebookEncryptionKey(key);
    return key;
  }

  DiaryEntry _diaryFromPayload(
    DiaryEntry placeholder,
    Map<String, dynamic> payload,
  ) => DiaryEntry(
    id: placeholder.id,
    title: payload['title'] as String? ?? '',
    content: payload['content'] as String? ?? '',
    createdAt: placeholder.createdAt,
    updatedAt: placeholder.updatedAt,
    mood: payload['mood'] as String?,
    category: payload['category'] as String? ?? 'Personal',
    tags: payload['tags'] is List
        ? (payload['tags'] as List).whereType<String>().toList()
        : const [],
    linkedSubjectId: payload['linkedSubjectId'] as String?,
    linkedSubjectName: payload['linkedSubjectName'] as String?,
    checklistItems: payload['checklistItems'] is List
        ? (payload['checklistItems'] as List)
              .whereType<Map>()
              .map(
                (item) => NotebookChecklistItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const [],
    isLocked: true,
    encryptedPayload: placeholder.encryptedPayload,
    isUnlockedInMemory: true,
  );

  NotebookNote _noteFromPayload(
    NotebookNote placeholder,
    Map<String, dynamic> payload,
  ) => NotebookNote(
    id: placeholder.id,
    title: payload['title'] as String? ?? '',
    content: payload['content'] as String? ?? '',
    createdAt: placeholder.createdAt,
    updatedAt: placeholder.updatedAt,
    category: payload['category'] as String? ?? 'Other',
    tags: payload['tags'] is List
        ? (payload['tags'] as List).whereType<String>().toList()
        : const [],
    linkedSubjectId: payload['linkedSubjectId'] as String?,
    linkedSubjectName: payload['linkedSubjectName'] as String?,
    checklistItems: payload['checklistItems'] is List
        ? (payload['checklistItems'] as List)
              .whereType<Map>()
              .map(
                (item) => NotebookChecklistItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const [],
    isPinned: payload['isPinned'] as bool? ?? false,
    isLocked: true,
    encryptedPayload: placeholder.encryptedPayload,
    isUnlockedInMemory: true,
  );
}

class DateTimeToLongDate {
  static String format(DateTime value) =>
      '${_month(value.month)} ${value.day}, ${value.year}';

  static String _month(int month) => const [
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
}
