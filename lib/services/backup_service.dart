import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
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
      'schoolClasses': hive.getSchoolClasses().map((e) => e.toJson()).toList(),
      'schoolDayModes': _encodeDayModes(hive.getDayClassModes()),
      'aiAccounts': hive.getAIAccounts().map((e) => e.toJson()).toList(),
      'userAccounts': hive.getUserAccounts().map((e) => e.toJson()).toList(),
      'bills': hive.getBills().map((e) => e.toJson()).toList(),
      'gasPurchases': hive.getGasPurchases().map((e) => e.toJson()).toList(),
      'suppliers': hive.getSuppliers().map((e) => e.toJson()).toList(),
      'settings': hive.getSettings().toJson(),
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

  Future<bool> importBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select a Reminder Hub backup',
      );
      if (result.isEmpty || result.first.path == null) return false;
      return importBackupFromFile(result.first.path!);
    } catch (_) {
      return false;
    }
  }

  Future<bool> importBackupFromFile(String path) async {
    var notificationsCancelled = false;
    try {
      final data = await _readJsonMap(path);
      final parsed = _parseFullBackup(data);
      if (parsed == null) return false;

      final hive = HiveService.instance;
      await hive.ensureInitialized();
      await NotificationService.instance.cancelAll();
      notificationsCancelled = true;
      await hive.clearAll();
      for (final item in parsed.reminders) {
        await hive.saveReminder(item);
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
      if (parsed.settings != null) {
        await hive.saveSettings(parsed.settings!);
      }
      await hive.saveAllDayClassModes(parsed.dayModes);
      await hive.setDataVersion(parsed.dataVersion);
      await _refreshAfterImport();
      return true;
    } catch (_) {
      if (notificationsCancelled) {
        await NotificationService.instance.rescheduleAll();
      }
      return false;
    }
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
      return _ParsedFullBackup(
        reminders: list('reminders', Reminder.fromJson),
        schoolClasses: list('schoolClasses', SchoolClass.fromJson),
        aiAccounts: list('aiAccounts', AIAccount.fromJson),
        userAccounts: list('userAccounts', UserAccount.fromJson),
        bills: list('bills', Bill.fromJson),
        gasPurchases: list('gasPurchases', GasPurchase.fromJson),
        suppliers: list('suppliers', Supplier.fromJson),
        settings: settings,
        dayModes: _parseDayModes(data['schoolDayModes']),
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
    required this.schoolClasses,
    required this.aiAccounts,
    required this.userAccounts,
    required this.bills,
    required this.gasPurchases,
    required this.suppliers,
    required this.settings,
    required this.dayModes,
    required this.dataVersion,
  });

  final List<Reminder> reminders;
  final List<SchoolClass> schoolClasses;
  final List<AIAccount> aiAccounts;
  final List<UserAccount> userAccounts;
  final List<Bill> bills;
  final List<GasPurchase> gasPurchases;
  final List<Supplier> suppliers;
  final AppSettings? settings;
  final Map<int, String> dayModes;
  final int dataVersion;
}
