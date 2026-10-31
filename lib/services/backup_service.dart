import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../models/diary_models.dart';
import '../models/pet_models.dart';
import '../models/study_models.dart';
import '../core/security/security_service.dart';
import 'encryption_service.dart';
import 'hive_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';

/// How records with an id that already exists should be handled during a
/// school schedule import.
enum SchoolScheduleDuplicateAction { replace, add, cancel }

class SchoolScheduleBackup {
  const SchoolScheduleBackup({
    required this.classes,
    required this.dayModes,
    required this.exportedAt,
  });

  final List<SchoolClass> classes;
  final Map<int, String> dayModes;
  final String exportedAt;
}

class SchoolScheduleImportResult {
  const SchoolScheduleImportResult({
    required this.imported,
    required this.replaced,
    required this.added,
  });

  final int imported;
  final int replaced;
  final int added;
}

class BackupService {
  static final BackupService instance = BackupService._internal();
  BackupService._internal();

  static const _backupFormat = 'reminderhub-backup';
  static const _scheduleFormat = 'reminderhub-school-schedule';
  static const _formatVersion = 1;
  static const _uuid = Uuid();

  /// Opens the platform folder picker and remembers the selected folder.
  Future<String?> chooseBackupFolder() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder for Reminder Hub backups',
    );
    if (path != null && path.isNotEmpty) {
      final hive = HiveService.instance;
      await hive.ensureInitialized();
      await hive.saveSettings(
        hive.getSettings().copyWith(backupFolderPath: path),
      );
    }
    return path;
  }

  Future<String?> exportBackup({
    String? directoryPath,
    bool share = false,
  }) async {
    final hive = HiveService.instance;
    await hive.ensureInitialized();
    final now = DateTime.now();
    final fileName = 'reminderhub_backup_${now.millisecondsSinceEpoch}.json';
    final data = <String, dynamic>{
      'format': _backupFormat,
      'version': _formatVersion,
      'timestamp': now.toIso8601String(),
      'dataVersion': hive.dataVersion,
      'reminders': hive.getReminders().map((e) => e.toJson()).toList(),
      'reminderHistory':
          hive.getReminderHistory().map((e) => e.toJson()).toList(),
      'schoolClasses': hive.getSchoolClasses().map((e) => e.toJson()).toList(),
      'schoolDayModes': _encodeDayModes(hive.getDayClassModes()),
      'aiAccounts': hive.getAIAccounts().map((e) => e.toJson()).toList(),
      'userAccounts': hive.getUserAccounts().map((e) => e.toJson()).toList(),
      'bills': hive.getBills().map((e) => e.toJson()).toList(),
      'gasPurchases': hive.getGasPurchases().map((e) => e.toJson()).toList(),
      'suppliers': hive.getSuppliers().map((e) => e.toJson()).toList(),
      'birthdays': hive.getBirthdays().map((e) => e.toJson()).toList(),
      'diaryEntries': hive
          .getDiaryEntries()
          .map((entry) => entry.toStoredJson())
          .toList(),
      'notes': hive.getNotes().map((note) => note.toStoredJson()).toList(),
      'settings': hive.getSettings().toJson(),
      'petPreferences': hive.getPetPreferences().toJson(),
      'studyMethods':
          hive.getStudyMethods().map((e) => e.toJson()).toList(),
      'studyHistory':
          hive.getStudyHistory().map((e) => e.toJson()).toList(),
      'studySettings': hive.getStudySettings().toJson(),
      'studySubjects': hive.getStudySubjects(),
      'notebookEncryptionKey':
          await SecurityService.instance.getNotebookEncryptionKey(),
    };
    final contents = const JsonEncoder.withIndent('  ').convert(data);
    if (Platform.isAndroid && !share) {
      final savedUri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(contents)),
        mimeType: 'application/json',
        dialogTitle: 'Save Reminder Hub backup',
      );
      return savedUri?.toString();
    }

    final directory = share && Platform.isAndroid
        ? (await getTemporaryDirectory()).path
        : await _resolveDirectory(directoryPath, hive);
    final file = File('$directory${Platform.pathSeparator}$fileName');
    await file.writeAsString(contents, flush: true);
    if (share) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Reminder Hub Offline Backup',
        ),
      );
    }
    return file.path;
  }

  Future<String?> exportSchoolSchedule({
    String? directoryPath,
    bool share = false,
  }) async {
    final hive = HiveService.instance;
    await hive.ensureInitialized();
    // Sharing should not depend on a previously selected backup folder.
    // The share sheet only needs a readable temporary file, while regular
    // exports continue to use the user's persistent backup location.
    final now = DateTime.now();
    final data = <String, dynamic>{
      'format': _scheduleFormat,
      'version': _formatVersion,
      'exportedAt': now.toIso8601String(),
      'classes': hive.getSchoolClasses().map((e) => e.toJson()).toList(),
      'dayModes': _encodeDayModes(hive.getDayClassModes()),
    };
    final contents = const JsonEncoder.withIndent('  ').convert(data);
    if (Platform.isAndroid && !share) {
      final savedUri = await FilePicker.saveFile(
        fileName:
            'reminderhub_school_schedule_${now.millisecondsSinceEpoch}.json',
        bytes: Uint8List.fromList(utf8.encode(contents)),
        mimeType: 'application/json',
        dialogTitle: 'Save school schedule',
      );
      return savedUri?.toString();
    }

    final directory = share
        ? (await getTemporaryDirectory()).path
        : await _resolveDirectory(directoryPath, hive);
    final file = File(
      '$directory${Platform.pathSeparator}reminderhub_school_schedule_${now.millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(contents, flush: true);
    if (share) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Reminder Hub School Schedule',
        ),
      );
    }
    return file.path;
  }

  Future<bool> importBackup({
    String? passphrase,
    Future<String?> Function()? requestPassphrase,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Select a Reminder Hub backup',
    );
    if (result.isEmpty || result.first.path == null) return false;
    final path = result.first.path!;
    var selectedPassphrase = passphrase;
    if (selectedPassphrase == null) {
      final serialized = await File(path).readAsString();
      final envelope = jsonDecode(serialized);
      if (envelope is Map &&
          envelope['format'] == EncryptionService.portableBackupFormat) {
        selectedPassphrase = await requestPassphrase?.call();
        if (selectedPassphrase == null) return false;
      }
    }
    return importBackupFromFile(path, passphrase: selectedPassphrase);
  }

  Future<bool> importBackupFromFile(
    String path, {
    String? passphrase,
  }) async {
    var notificationsCancelled = false;
    _LocalRestoreSnapshot? snapshot;
    String? previousNotebookKey;
    String? previousAccountKey;
    try {
      final serialized = await File(path).readAsString();
      final envelope = jsonDecode(serialized);
      if (envelope is! Map) {
        throw const FormatException('Backup JSON root must be an object.');
      }
      final envelopeMap = Map<String, dynamic>.from(envelope);
      final isEncrypted =
          envelopeMap['format'] == EncryptionService.portableBackupFormat;
      final contents = isEncrypted
          ? await EncryptionService.instance.decryptBackupJson(
              serialized,
              passphrase ?? '',
            )
          : serialized;
      final decoded = jsonDecode(contents);
      if (decoded is! Map) {
        throw const FormatException('Backup JSON root must be an object.');
      }
      final data = Map<String, dynamic>.from(decoded);
      final parsed = _parseFullBackup(data);
      if (parsed == null) {
        throw const FormatException('Backup contents are invalid or unsupported.');
      }

      final hive = HiveService.instance;
      await hive.ensureInitialized();
      final restoreSnapshot = _LocalRestoreSnapshot.capture(hive);
      final notebookKeyBeforeRestore =
          await SecurityService.instance.getNotebookEncryptionKey();
      final accountKeyBeforeRestore =
          await SecurityService.instance.getAccountEncryptionKey();
      snapshot = restoreSnapshot;
      previousNotebookKey = notebookKeyBeforeRestore;
      previousAccountKey = accountKeyBeforeRestore;
      await NotificationService.instance.cancelAll();
      notificationsCancelled = true;
      await hive.clearAll();
      for (final item in parsed.reminders) {
        await hive.saveReminder(item);
      }
      for (final item in parsed.reminderHistory) {
        await hive.saveReminderHistoryRecord(item);
      }
      for (final item in parsed.schoolClasses) {
        await hive.saveSchoolClass(item);
      }
      for (final item in parsed.aiAccounts) {
        await hive.saveAIAccount(item);
      }
      for (final item in parsed.userAccounts) {
        await hive.saveUserAccount(item);
      }
      for (final item in parsed.bills) {
        await hive.saveBill(item);
      }
      for (final item in parsed.gasPurchases) {
        await hive.saveGasPurchase(item);
      }
      for (final item in parsed.suppliers) {
        await hive.saveSupplier(item);
      }
      for (final item in parsed.birthdays) {
        await hive.saveBirthday(item);
      }
      for (final item in parsed.diaryEntries) {
        await hive.saveStoredDiaryEntry(item.id, item.toStoredJson());
      }
      for (final item in parsed.notes) {
        await hive.saveStoredNote(item.id, item.toStoredJson());
      }
      if (parsed.settings != null) {
        await hive.saveSettings(parsed.settings!);
      }
      if (parsed.petPreferences != null) {
        await hive.savePetPreferences(parsed.petPreferences!);
      }
      for (final item in parsed.studyMethods) {
        await hive.saveStudyMethod(item);
      }
      for (final item in parsed.studyHistory) {
        await hive.saveStudyHistoryRecord(item);
      }
      if (parsed.studySettings != null) {
        await hive.saveStudySettings(parsed.studySettings!);
      }
      for (final item in parsed.studySubjects) {
        await hive.saveStudySubject(item);
      }
      await hive.saveAllDayClassModes(parsed.dayModes);
      await hive.setDataVersion(parsed.dataVersion);
      if (parsed.includesNotebookEncryptionKey) {
        final key = parsed.notebookEncryptionKey;
        if (key == null) {
          await SecurityService.instance.removeNotebookEncryptionKey();
        } else {
          await SecurityService.instance.setNotebookEncryptionKey(key);
        }
      }
      await _refreshAfterImport();
      return true;
    } catch (error, stackTrace) {
      if (snapshot != null) {
        try {
          if (previousAccountKey != null) {
            await SecurityService.instance.setAccountEncryptionKey(
              previousAccountKey,
            );
          } else {
            await SecurityService.instance.removeAccountEncryptionKey();
          }
          await _rollbackToSnapshot(
            snapshot,
            accountEncryptionKey: previousAccountKey,
          );
          if (previousNotebookKey != null) {
            await SecurityService.instance.setNotebookEncryptionKey(
              previousNotebookKey,
            );
          } else {
            await SecurityService.instance.removeNotebookEncryptionKey();
          }
        } catch (rollbackError, rollbackStackTrace) {
          Error.throwWithStackTrace(
            StateError(
              'Backup restore failed and local rollback could not finish: $rollbackError',
            ),
            rollbackStackTrace,
          );
        }
      }
      if (notificationsCancelled) {
        await NotificationService.instance.rescheduleAll();
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _rollbackToSnapshot(
    _LocalRestoreSnapshot snapshot, {
    required String? accountEncryptionKey,
  }) async {
    final hive = HiveService.instance;
    await hive.clearAll();
    for (final item in snapshot.reminders) {
      await hive.saveReminder(item);
    }
    for (final item in snapshot.reminderHistory) {
      await hive.saveReminderHistoryRecord(item);
    }
    for (final item in snapshot.schoolClasses) {
      await hive.saveSchoolClass(item);
    }
    for (final item in snapshot.aiAccounts) {
      await hive.saveAIAccount(item);
    }
    await hive.restoreUserAccountStorageRecords(
      snapshot.userAccountStorageRecords,
      encryptionKey: accountEncryptionKey,
    );
    for (final item in snapshot.bills) {
      await hive.saveBill(item);
    }
    for (final item in snapshot.gasPurchases) {
      await hive.saveGasPurchase(item);
    }
    for (final item in snapshot.suppliers) {
      await hive.saveSupplier(item);
    }
    for (final item in snapshot.birthdays) {
      await hive.saveBirthday(item);
    }
    for (final item in snapshot.diaryEntries) {
      await hive.saveStoredDiaryEntry(item.id, item.toStoredJson());
    }
    for (final item in snapshot.notes) {
      await hive.saveStoredNote(item.id, item.toStoredJson());
    }
    await hive.saveSettings(snapshot.settings);
    await hive.savePetPreferences(snapshot.petPreferences);
    for (final item in snapshot.studyMethods) {
      await hive.saveStudyMethod(item);
    }
    for (final item in snapshot.studyHistory) {
      await hive.saveStudyHistoryRecord(item);
    }
    await hive.saveStudySettings(snapshot.studySettings);
    for (final subject in snapshot.studySubjects) {
      await hive.saveStudySubject(subject);
    }
    await hive.saveAllDayClassModes(snapshot.dayModes);
    await hive.setDataVersion(snapshot.dataVersion);
    await _refreshAfterImport();
  }

  Future<SchoolScheduleBackup?> pickSchoolScheduleBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select a school schedule',
      );
      if (result.isEmpty || result.first.path == null) return null;
      final data = await _readJsonMap(result.first.path!);
      return _parseScheduleBackup(data);
    } catch (_) {
      return null;
    }
  }

  Future<SchoolScheduleImportResult?> importSchoolSchedule(
    SchoolScheduleBackup backup,
    SchoolScheduleDuplicateAction action,
  ) async {
    if (action == SchoolScheduleDuplicateAction.cancel) return null;
    final hive = HiveService.instance;
    await hive.ensureInitialized();
    final existing = {
      for (final item in hive.getSchoolClasses()) item.id: item,
    };
    final imported = <SchoolClass>[];
    var replaced = 0;
    var added = 0;
    for (final item in backup.classes) {
      if (existing.containsKey(item.id)) {
        if (action == SchoolScheduleDuplicateAction.replace) {
          imported.add(item);
          replaced++;
        } else {
          imported.add(item.copyWith(id: _uuid.v4()));
          added++;
        }
      } else {
        imported.add(item);
        added++;
      }
    }

    var notificationsCancelled = false;
    try {
      await NotificationService.instance.cancelAll();
      notificationsCancelled = true;
      if (action == SchoolScheduleDuplicateAction.replace) {
        for (final item in existing.values) {
          if (!imported.any((candidate) => candidate.id == item.id)) {
            await hive.deleteSchoolClass(item.id);
          }
        }
      }
      for (final item in imported) {
        await hive.saveSchoolClass(item);
      }
      if (action == SchoolScheduleDuplicateAction.replace || existing.isEmpty) {
        await hive.saveAllDayClassModes(backup.dayModes);
      }
      await _refreshAfterImport();
      return SchoolScheduleImportResult(
        imported: imported.length,
        replaced: replaced,
        added: added,
      );
    } catch (_) {
      if (notificationsCancelled) {
        await NotificationService.instance.rescheduleAll();
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> _readJsonMap(String path) async {
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map) {
      throw const FormatException('JSON root must be an object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<String> _resolveDirectory(String? requested, HiveService hive) async {
    var path = requested ?? hive.getSettings().backupFolderPath;
    if (path.trim().isEmpty) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final defaultBackupDir = Directory(
          '${docsDir.path}${Platform.pathSeparator}ReminderHub_Backups',
        );
        if (!await defaultBackupDir.exists()) {
          await defaultBackupDir.create(recursive: true);
        }
        path = defaultBackupDir.path;
      } catch (_) {
        final selected = await chooseBackupFolder();
        if (selected == null || selected.isEmpty) {
          throw const FileSystemException('No backup folder selected');
        }
        path = selected;
      }
    }
    final directory = Directory(path);
    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      // Keep the path in sync in case the picker returned a normalized path.
      final savedPath = hive.getSettings().backupFolderPath;
      if (savedPath != directory.path) {
        await hive.saveSettings(
          hive.getSettings().copyWith(backupFolderPath: directory.path),
        );
      }
    } catch (_) {}
    return directory.path;
  }

  Future<void> _refreshAfterImport() async {
    await NotificationService.instance.rescheduleAll();
    await WidgetService.instance.updateSchoolWidget();
    await WidgetService.instance.updateBillsWidget();
    HiveService.instance.notifyRemindersChanged();
  }

  Map<String, String> _encodeDayModes(Map<int, String> modes) =>
      modes.map((key, value) => MapEntry(key.toString(), value));

  SchoolScheduleBackup? _parseScheduleBackup(Map<String, dynamic> data) {
    if (data['format'] != _scheduleFormat ||
        data['version'] is! num ||
        (data['version'] as num).toInt() != _formatVersion ||
        data['classes'] is! List) {
      return null;
    }
    try {
      final classes = <SchoolClass>[];
      final ids = <String>{};
      for (final raw in data['classes'] as List) {
        if (raw is! Map) return null;
        final item = SchoolClass.fromJson(Map<String, dynamic>.from(raw));
        if (item.id.trim().isEmpty ||
            !ids.add(item.id) ||
            item.subject.trim().isEmpty ||
            item.daysOfWeek.isEmpty ||
            item.daysOfWeek.any((day) => day < 1 || day > 7) ||
            !_validTime(item.startTime) ||
            !_validTime(item.endTime)) {
          return null;
        }
        classes.add(item);
      }
      final modes = _parseScheduleDayModes(data['dayModes']);
      if (modes == null) return null;
      return SchoolScheduleBackup(
        classes: classes,
        dayModes: modes,
        exportedAt: (data['exportedAt'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  _ParsedFullBackup? _parseFullBackup(Map<String, dynamic> data) {
    final format = data['format'];
    if (format != null && format != _backupFormat) return null;
    try {
      List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
        final raw = data[key];
        if (raw == null) return <T>[];
        if (raw is! List) throw const FormatException('Record list expected');
        return raw.map((item) {
          if (item is! Map) throw const FormatException('Record expected');
          return parse(Map<String, dynamic>.from(item));
        }).toList();
      }

      final rawSettings = data['settings'];
      final settings = rawSettings == null
          ? null
          : AppSettings.fromJson(Map<String, dynamic>.from(rawSettings as Map));

      final rawPet = data['petPreferences'];
      final petPrefs = rawPet is Map
          ? PetPreferences.fromJson(Map<String, dynamic>.from(rawPet))
          : null;

      final rawStudySettings = data['studySettings'];
      final studySettings = rawStudySettings is Map
          ? StudySettings.fromJson(Map<String, dynamic>.from(rawStudySettings))
          : null;

      final rawSubjects = data['studySubjects'];
      final studySubjects = rawSubjects is List
          ? rawSubjects.whereType<String>().toList()
          : <String>[];
      final includesNotebookEncryptionKey = data.containsKey(
        'notebookEncryptionKey',
      );
      final rawNotebookKey = data['notebookEncryptionKey'];
      if (includesNotebookEncryptionKey &&
          rawNotebookKey != null &&
          rawNotebookKey is! String) {
        throw const FormatException('Invalid notebook recovery key.');
      }

      return _ParsedFullBackup(
        reminders: list('reminders', Reminder.fromJson),
        reminderHistory: list('reminderHistory', ReminderHistoryRecord.fromJson),
        schoolClasses: list('schoolClasses', SchoolClass.fromJson),
        aiAccounts: list('aiAccounts', AIAccount.fromJson),
        userAccounts: list('userAccounts', UserAccount.fromJson),
        bills: list('bills', Bill.fromJson),
        gasPurchases: list('gasPurchases', GasPurchase.fromJson),
        suppliers: list('suppliers', Supplier.fromJson),
        birthdays: list('birthdays', Birthday.fromJson),
        diaryEntries: list('diaryEntries', DiaryEntry.fromJson),
        notes: list('notes', NotebookNote.fromJson),
        settings: settings,
        petPreferences: petPrefs,
        studyMethods: list('studyMethods', StudyMethod.fromJson),
        studyHistory: list('studyHistory', StudySessionRecord.fromJson),
        studySettings: studySettings,
        studySubjects: studySubjects,
        dayModes: _parseDayModes(data['schoolDayModes']),
        notebookEncryptionKey: rawNotebookKey as String?,
        includesNotebookEncryptionKey: includesNotebookEncryptionKey,
        dataVersion:
            (data['dataVersion'] as num?)?.toInt() ??
            HiveService.currentDataVersion,
      );
    } catch (_) {
      return null;
    }
  }

  Map<int, String> _parseDayModes(dynamic raw) {
    final result = <int, String>{};
    if (raw is! Map) return result;
    raw.forEach((key, value) {
      final day = int.tryParse(key.toString());
      if (day != null &&
          day >= 1 &&
          day <= 7 &&
          value is String &&
          DayClassMode.allModes.contains(value)) {
        result[day] = value;
      }
    });
    return result;
  }

  Map<int, String>? _parseScheduleDayModes(dynamic raw) {
    if (raw == null) return {};
    if (raw is! Map) return null;
    final result = <int, String>{};
    for (final entry in raw.entries) {
      final day = int.tryParse(entry.key.toString());
      if (day == null ||
          day < 1 ||
          day > 7 ||
          entry.value is! String ||
          !DayClassMode.allModes.contains(entry.value)) {
        return null;
      }
      result[day] = entry.value as String;
    }
    return result;
  }

  bool _validTime(String value) => RegExp(
    r'^(0?[1-9]|1[0-2]):[0-5][0-9]\s?(AM|PM)$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

class _ParsedFullBackup {
  const _ParsedFullBackup({
    required this.reminders,
    required this.reminderHistory,
    required this.schoolClasses,
    required this.aiAccounts,
    required this.userAccounts,
    required this.bills,
    required this.gasPurchases,
    required this.suppliers,
    required this.birthdays,
    required this.diaryEntries,
    required this.notes,
    required this.settings,
    required this.petPreferences,
    required this.studyMethods,
    required this.studyHistory,
    required this.studySettings,
    required this.studySubjects,
    required this.dayModes,
    required this.dataVersion,
    required this.notebookEncryptionKey,
    required this.includesNotebookEncryptionKey,
  });

  final List<Reminder> reminders;
  final List<ReminderHistoryRecord> reminderHistory;
  final List<SchoolClass> schoolClasses;
  final List<AIAccount> aiAccounts;
  final List<UserAccount> userAccounts;
  final List<Bill> bills;
  final List<GasPurchase> gasPurchases;
  final List<Supplier> suppliers;
  final List<Birthday> birthdays;
  final List<DiaryEntry> diaryEntries;
  final List<NotebookNote> notes;
  final AppSettings? settings;
  final PetPreferences? petPreferences;
  final List<StudyMethod> studyMethods;
  final List<StudySessionRecord> studyHistory;
  final StudySettings? studySettings;
  final List<String> studySubjects;
  final Map<int, String> dayModes;
  final int dataVersion;
  final String? notebookEncryptionKey;
  final bool includesNotebookEncryptionKey;
}

class _LocalRestoreSnapshot {
  const _LocalRestoreSnapshot({
    required this.reminders,
    required this.reminderHistory,
    required this.schoolClasses,
    required this.aiAccounts,
    required this.userAccountStorageRecords,
    required this.bills,
    required this.gasPurchases,
    required this.suppliers,
    required this.birthdays,
    required this.diaryEntries,
    required this.notes,
    required this.settings,
    required this.petPreferences,
    required this.studyMethods,
    required this.studyHistory,
    required this.studySettings,
    required this.studySubjects,
    required this.dayModes,
    required this.dataVersion,
  });

  factory _LocalRestoreSnapshot.capture(HiveService hive) =>
      _LocalRestoreSnapshot(
        reminders: hive.getReminders(),
        reminderHistory: hive.getReminderHistory(),
        schoolClasses: hive.getSchoolClasses(),
        aiAccounts: hive.getAIAccounts(),
        userAccountStorageRecords: hive.getUserAccountStorageRecords(),
        bills: hive.getBills(),
        gasPurchases: hive.getGasPurchases(),
        suppliers: hive.getSuppliers(),
        birthdays: hive.getBirthdays(),
        diaryEntries: hive.getDiaryEntries(),
        notes: hive.getNotes(),
        settings: hive.getSettings(),
        petPreferences: hive.getPetPreferences(),
        studyMethods: hive.getStudyMethods(),
        studyHistory: hive.getStudyHistory(),
        studySettings: hive.getStudySettings(),
        studySubjects: hive.getStudySubjects(),
        dayModes: hive.getDayClassModes(),
        dataVersion: hive.dataVersion,
      );

  final List<Reminder> reminders;
  final List<ReminderHistoryRecord> reminderHistory;
  final List<SchoolClass> schoolClasses;
  final List<AIAccount> aiAccounts;
  final Map<String, String> userAccountStorageRecords;
  final List<Bill> bills;
  final List<GasPurchase> gasPurchases;
  final List<Supplier> suppliers;
  final List<Birthday> birthdays;
  final List<DiaryEntry> diaryEntries;
  final List<NotebookNote> notes;
  final AppSettings settings;
  final PetPreferences petPreferences;
  final List<StudyMethod> studyMethods;
  final List<StudySessionRecord> studyHistory;
  final StudySettings studySettings;
  final List<String> studySubjects;
  final Map<int, String> dayModes;
  final int dataVersion;
}
