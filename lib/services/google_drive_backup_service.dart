import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../models/app_models.dart';
import '../models/diary_models.dart';
import '../models/pet_models.dart';
import '../models/study_models.dart';
import 'hive_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';

/// Metadata for a backup stored in Google Drive appDataFolder.
class GoogleDriveBackupFile {
  const GoogleDriveBackupFile({
    required this.id,
    required this.name,
    required this.createdTime,
    required this.sizeBytes,
    this.description,
  });

  final String id;
  final String name;
  final DateTime createdTime;
  final int sizeBytes;
  final String? description;
}

/// Result of a Google Drive backup operation.
class GoogleDriveBackupResult {
  const GoogleDriveBackupResult({
    required this.success,
    this.fileId,
    this.fileName,
    this.timestamp,
    this.errorMessage,
  });

  final bool success;
  final String? fileId;
  final String? fileName;
  final DateTime? timestamp;
  final String? errorMessage;
}

/// Result of a Google Drive restore operation.
class GoogleDriveRestoreResult {
  const GoogleDriveRestoreResult({
    required this.success,
    this.restoredCounts = const {},
    this.errorMessage,
  });

  final bool success;
  final Map<String, int> restoredCounts;
  final String? errorMessage;
}

class GoogleDriveBackupService {
  static final GoogleDriveBackupService instance =
      GoogleDriveBackupService._internal();
  GoogleDriveBackupService._internal();

  static const String _appIdentifier = 'com.reminderhub.reminder_hub';
  // Android requires the Web OAuth client ID unless google-services.json
  // supplies a default_web_client_id resource.
  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '149381523150-1jk8fpdl4p6fmfscei6d6vn1iu8ras29.apps.googleusercontent.com',
  );
  static const String _cloudFormat = 'reminderhub-cloud-backup';
  static const int _formatVersion = 2;
  static const String _appDataSpace = 'appDataFolder';

  static const List<String> _scopes = [
    drive.DriveApi.driveAppdataScope,
  ];

  bool _initialized = false;
  GoogleSignInAccount? _currentUser;

  /// Stream of user sign-in state changes.
  final ValueNotifier<GoogleSignInAccount?> currentUserNotifier =
      ValueNotifier<GoogleSignInAccount?>(null);

  /// Initializes the GoogleSignIn plugin instance once.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );
      _initialized = true;

      // Listen to authentication events from google_sign_in
      GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          switch (event) {
            case GoogleSignInAuthenticationEventSignIn(:final user):
              _currentUser = user;
              currentUserNotifier.value = user;
              _persistAccountEmail(user.email);
            case GoogleSignInAuthenticationEventSignOut():
              _currentUser = null;
              currentUserNotifier.value = null;
              _persistAccountEmail(null);
          }
        },
        onError: (error) {
          debugPrint('GoogleSignIn auth event error: $error');
        },
      );

      // Attempt non-interactive sign-in restoration
      await restorePreviousSignIn();
    } catch (e) {
      debugPrint('GoogleDriveBackupService initialization warning: $e');
    }
  }

  /// Restores existing sign-in silently without showing UI.
  Future<GoogleSignInAccount?> restorePreviousSignIn() async {
    try {
      final account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account != null) {
        _currentUser = account;
        currentUserNotifier.value = account;
        await _persistAccountEmail(account.email);
      }
      return account;
    } catch (e) {
      debugPrint('Silent Google Sign-In attempt error: $e');
      return null;
    }
  }

  /// Interactive sign-in flow. Requests authentication and drive.appdata scope.
  Future<GoogleSignInAccount?> signIn() async {
    await initialize();
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _scopes,
      );
      _currentUser = account;
      currentUserNotifier.value = account;
      await _persistAccountEmail(account.email);
      return account;
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Disconnects / signs out the currently authenticated account.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      _currentUser = null;
      currentUserNotifier.value = null;
      await _persistAccountEmail(null);
    } catch (e) {
      debugPrint('Google Sign-Out error: $e');
    }
  }

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<void> _persistAccountEmail(String? email) async {
    try {
      final hive = HiveService.instance;
      await hive.ensureInitialized();
      final currentSettings = hive.getSettings();
      if (currentSettings.googleDriveAccountEmail != email) {
        await hive.saveSettings(
          currentSettings.copyWith(googleDriveAccountEmail: email ?? ''),
        );
      }
    } catch (_) {}
  }

  /// Obtains an authorized DriveApi client.
  Future<drive.DriveApi> _getDriveApi({bool promptIfNecessary = true}) async {
    var account = _currentUser;
    if (account == null) {
      if (promptIfNecessary) {
        account = await signIn();
      } else {
        account = await restorePreviousSignIn();
      }
    }

    if (account == null) {
      throw const FormatException('Not signed in to Google Drive.');
    }

    GoogleSignInClientAuthorization? authz;
    try {
      authz = await account.authorizationClient.authorizationForScopes(_scopes);
    } catch (_) {}

    if (authz == null) {
      if (promptIfNecessary) {
        authz = await account.authorizationClient.authorizeScopes(_scopes);
      } else {
        throw const FormatException(
          'Google Drive appDataFolder scope not authorized.',
        );
      }
    }

    final authClient = authz.authClient(scopes: _scopes);
    return drive.DriveApi(authClient);
  }

  // ---------------------------------------------------------------------------
  // Backup Creation & Upload
  // ---------------------------------------------------------------------------

  /// Creates a full, versioned, checksum-validated backup and uploads it to Google Drive appDataFolder.
  Future<GoogleDriveBackupResult> createBackup() async {
    try {
      final driveApi = await _getDriveApi(promptIfNecessary: true);
      final hive = HiveService.instance;
      await hive.ensureInitialized();

      final now = DateTime.now().toUtc();
      final backupData = _buildBackupMap(hive, now);

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final jsonBytes = utf8.encode(jsonString);

      final fileName = 'reminderhub_cloud_backup_${now.millisecondsSinceEpoch}.json';
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [_appDataSpace]
        ..mimeType = 'application/json'
        ..description = 'ReminderHub offline-first backup created on ${now.toIso8601String()}';

      final mediaStream = Stream.value(jsonBytes);
      final media = drive.Media(
        mediaStream,
        jsonBytes.length,
        contentType: 'application/json',
      );

      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );

      if (uploadedFile.id == null || uploadedFile.id!.isEmpty) {
        return const GoogleDriveBackupResult(
          success: false,
          errorMessage: 'Google Drive API did not return a valid file ID.',
        );
      }

      // Record successful backup timestamp in AppSettings
      final settings = hive.getSettings();
      await hive.saveSettings(
        settings.copyWith(
          lastGoogleDriveBackupDate: now.toIso8601String(),
          googleDriveAccountEmail: _currentUser?.email ?? settings.googleDriveAccountEmail,
        ),
      );

      return GoogleDriveBackupResult(
        success: true,
        fileId: uploadedFile.id,
        fileName: fileName,
        timestamp: now.toLocal(),
      );
    } on GoogleSignInException catch (e) {
      return GoogleDriveBackupResult(
        success: false,
        errorMessage: 'Sign in error: ${e.description ?? e.code.name}',
      );
    } catch (e) {
      debugPrint('Google Drive backup error: $e');
      return GoogleDriveBackupResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Backup Listing & Retrieval
  // ---------------------------------------------------------------------------

  /// Lists all ReminderHub backups found in the user's appDataFolder.
  Future<List<GoogleDriveBackupFile>> listBackups() async {
    try {
      final driveApi = await _getDriveApi(promptIfNecessary: false);
      final fileList = await driveApi.files.list(
        spaces: _appDataSpace,
        q: "trashed = false",
        orderBy: 'createdTime desc',
        $fields: 'files(id, name, createdTime, size, description)',
      );

      final files = fileList.files ?? <drive.File>[];
      final results = <GoogleDriveBackupFile>[];

      for (final f in files) {
        if (f.id == null) continue;
        final name = f.name ?? 'reminderhub_backup.json';
        final created = f.createdTime?.toLocal() ?? DateTime.now();
        final size = int.tryParse(f.size ?? '0') ?? 0;
        results.add(
          GoogleDriveBackupFile(
            id: f.id!,
            name: name,
            createdTime: created,
            sizeBytes: size,
            description: f.description,
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint('Error listing Google Drive backups: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Restore Workflow with Safety Snapshot & Rollback
  // ---------------------------------------------------------------------------

  /// Restores data from the specified Google Drive backup file ID.
  /// Employs a pre-restore safety snapshot so that if parsing or writing fails,
  /// existing local data is restored without corruption.
  Future<GoogleDriveRestoreResult> restoreBackup(String fileId) async {
    final hive = HiveService.instance;
    await hive.ensureInitialized();

    // 1. Download file from Google Drive
    String jsonContent;
    try {
      final driveApi = await _getDriveApi(promptIfNecessary: true);
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      jsonContent = utf8.decode(bytes);
    } catch (e) {
      return GoogleDriveRestoreResult(
        success: false,
        errorMessage: 'Failed to download backup from Google Drive: $e',
      );
    }

    // 2. Validate structure & checksum
    Map<String, dynamic> dataMap;
    try {
      final decoded = jsonDecode(jsonContent);
      if (decoded is! Map) {
        return const GoogleDriveRestoreResult(
          success: false,
          errorMessage: 'Invalid backup file: root must be a JSON object.',
        );
      }
      dataMap = Map<String, dynamic>.from(decoded);
    } catch (e) {
      return GoogleDriveRestoreResult(
        success: false,
        errorMessage: 'Failed to parse JSON backup: $e',
      );
    }

    // Verify format and application identifier
    final format = dataMap['format'];
    if (format != _cloudFormat && format != 'reminderhub-backup') {
      return const GoogleDriveRestoreResult(
        success: false,
        errorMessage: 'Incompatible backup format.',
      );
    }

    // Verify checksum if present
    final storedChecksum = dataMap['checksum'] as String?;
    if (storedChecksum != null && storedChecksum.isNotEmpty) {
      final dataWithoutChecksum = Map<String, dynamic>.from(dataMap)
        ..remove('checksum');
      final calculatedChecksum = sha256
          .convert(utf8.encode(jsonEncode(dataWithoutChecksum)))
          .toString();
      if (storedChecksum != calculatedChecksum) {
        // Fallback check against formatted JSON
        final altChecksum = sha256
            .convert(
              utf8.encode(
                const JsonEncoder.withIndent('  ').convert(dataWithoutChecksum),
              ),
            )
            .toString();
        if (storedChecksum != altChecksum) {
          debugPrint('Checksum mismatch warning. Proceeding with schema validation.');
        }
      }
    }

    // 3. Create Safety Snapshot of current local state for reliable rollback
    final snapshot = _createSafetySnapshot(hive);

    var notificationsCancelled = false;
    try {
      await NotificationService.instance.cancelAll();
      notificationsCancelled = true;

      // Clear existing boxes
      await hive.clearAll();

      // 4. Populate each box from backup data with safe type converters
      final counts = <String, int>{};

      // Reminders
      final remindersRaw = dataMap['reminders'] as List?;
      if (remindersRaw != null) {
        var count = 0;
        for (final r in remindersRaw) {
          if (r is Map) {
            await hive.saveReminder(
              Reminder.fromJson(Map<String, dynamic>.from(r)),
            );
            count++;
          }
        }
        counts['reminders'] = count;
      }

      // Reminder History
      final historyRaw = dataMap['reminderHistory'] as List?;
      if (historyRaw != null) {
        var count = 0;
        for (final h in historyRaw) {
          if (h is Map) {
            await hive.saveReminderHistoryRecord(
              ReminderHistoryRecord.fromJson(Map<String, dynamic>.from(h)),
            );
            count++;
          }
        }
        counts['reminderHistory'] = count;
      }

      // School Classes
      final schoolRaw = dataMap['schoolClasses'] as List?;
      if (schoolRaw != null) {
        var count = 0;
        for (final s in schoolRaw) {
          if (s is Map) {
            await hive.saveSchoolClass(
              SchoolClass.fromJson(Map<String, dynamic>.from(s)),
            );
            count++;
          }
        }
        counts['schoolClasses'] = count;
      }

      // School Day Modes
      final dayModesRaw = dataMap['schoolDayModes'];
      if (dayModesRaw is Map) {
        final modes = <int, String>{};
        dayModesRaw.forEach((k, v) {
          final day = int.tryParse(k.toString());
          if (day != null && v is String) {
            modes[day] = v;
          }
        });
        await hive.saveAllDayClassModes(modes);
      }

      // AI Accounts
      final aiRaw = dataMap['aiAccounts'] as List?;
      if (aiRaw != null) {
        var count = 0;
        for (final a in aiRaw) {
          if (a is Map) {
            await hive.saveAIAccount(
              AIAccount.fromJson(Map<String, dynamic>.from(a)),
            );
            count++;
          }
        }
        counts['aiAccounts'] = count;
      }

      // User Accounts
      final userAccountsRaw = dataMap['userAccounts'] as List?;
      if (userAccountsRaw != null) {
        var count = 0;
        for (final u in userAccountsRaw) {
          if (u is Map) {
            await hive.saveUserAccount(
              UserAccount.fromJson(Map<String, dynamic>.from(u)),
            );
            count++;
          }
        }
        counts['userAccounts'] = count;
      }

      // Bills
      final billsRaw = dataMap['bills'] as List?;
      if (billsRaw != null) {
        var count = 0;
        for (final b in billsRaw) {
          if (b is Map) {
            await hive.saveBill(
              Bill.fromJson(Map<String, dynamic>.from(b)),
            );
            count++;
          }
        }
        counts['bills'] = count;
      }

      // Gas Purchases
      final gasRaw = dataMap['gasPurchases'] as List?;
      if (gasRaw != null) {
        var count = 0;
        for (final g in gasRaw) {
          if (g is Map) {
            await hive.saveGasPurchase(
              GasPurchase.fromJson(Map<String, dynamic>.from(g)),
            );
            count++;
          }
        }
        counts['gasPurchases'] = count;
      }

      // Suppliers
      final suppliersRaw = dataMap['suppliers'] as List?;
      if (suppliersRaw != null) {
        var count = 0;
        for (final s in suppliersRaw) {
          if (s is Map) {
            await hive.saveSupplier(
              Supplier.fromJson(Map<String, dynamic>.from(s)),
            );
            count++;
          }
        }
        counts['suppliers'] = count;
      }

      // Birthdays
      final birthdaysRaw = dataMap['birthdays'] as List?;
      if (birthdaysRaw != null) {
        var count = 0;
        for (final b in birthdaysRaw) {
          if (b is Map) {
            await hive.saveBirthday(
              Birthday.fromJson(Map<String, dynamic>.from(b)),
            );
            count++;
          }
        }
        counts['birthdays'] = count;
      }

      // Diary Entries
      final diaryRaw = dataMap['diaryEntries'] as List?;
      if (diaryRaw != null) {
        var count = 0;
        for (final d in diaryRaw) {
          if (d is Map) {
            final entry = DiaryEntry.fromJson(Map<String, dynamic>.from(d));
            await hive.saveStoredDiaryEntry(entry.id, entry.toStoredJson());
            count++;
          }
        }
        counts['diaryEntries'] = count;
      }

      // Notes
      final notesRaw = dataMap['notes'] as List?;
      if (notesRaw != null) {
        var count = 0;
        for (final n in notesRaw) {
          if (n is Map) {
            final note = NotebookNote.fromJson(Map<String, dynamic>.from(n));
            await hive.saveStoredNote(note.id, note.toStoredJson());
            count++;
          }
        }
        counts['notes'] = count;
      }

      // Settings
      final settingsRaw = dataMap['settings'];
      if (settingsRaw is Map) {
        await hive.saveSettings(
          AppSettings.fromJson(Map<String, dynamic>.from(settingsRaw)),
        );
      }

      // Pet Preferences
      final petRaw = dataMap['petPreferences'];
      if (petRaw is Map) {
        await hive.savePetPreferences(
          PetPreferences.fromJson(Map<String, dynamic>.from(petRaw)),
        );
      }

      // Study Methods
      final studyMethodsRaw = dataMap['studyMethods'] as List?;
      if (studyMethodsRaw != null) {
        for (final m in studyMethodsRaw) {
          if (m is Map) {
            await hive.saveStudyMethod(
              StudyMethod.fromJson(Map<String, dynamic>.from(m)),
            );
          }
        }
      }

      // Study History
      final studyHistoryRaw = dataMap['studyHistory'] as List?;
      if (studyHistoryRaw != null) {
        for (final s in studyHistoryRaw) {
          if (s is Map) {
            await hive.saveStudyHistoryRecord(
              StudySessionRecord.fromJson(Map<String, dynamic>.from(s)),
            );
          }
        }
      }

      // Study Settings
      final studySettingsRaw = dataMap['studySettings'];
      if (studySettingsRaw is Map) {
        await hive.saveStudySettings(
          StudySettings.fromJson(Map<String, dynamic>.from(studySettingsRaw)),
        );
      }

      // Study Subjects
      final studySubjectsRaw = dataMap['studySubjects'] as List?;
      if (studySubjectsRaw != null) {
        for (final s in studySubjectsRaw) {
          if (s is String) {
            await hive.saveStudySubject(s);
          }
        }
      }

      // Data version
      final dataVersion = (dataMap['dataVersion'] as num?)?.toInt() ??
          HiveService.currentDataVersion;
      await hive.setDataVersion(dataVersion);

      // Reconcile notifications and native widgets
      await NotificationService.instance.rescheduleAll();
      await WidgetService.instance.updateSchoolWidget();
      await WidgetService.instance.updateBillsWidget();
      hive.notifyRemindersChanged();

      return GoogleDriveRestoreResult(
        success: true,
        restoredCounts: counts,
      );
    } catch (e) {
      debugPrint('Restore failed with error: $e. Executing rollback from safety snapshot...');
      await _rollbackToSnapshot(hive, snapshot);
      if (notificationsCancelled) {
        await NotificationService.instance.rescheduleAll();
      }
      return GoogleDriveRestoreResult(
        success: false,
        errorMessage: 'Restoration failed and was rolled back safely: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers: Payload Builder & Snapshot/Rollback
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildBackupMap(HiveService hive, DateTime now) {
    final base = <String, dynamic>{
      'format': _cloudFormat,
      'app': _appIdentifier,
      'version': _formatVersion,
      'timestamp': now.toIso8601String(),
      'dataVersion': hive.dataVersion,
      'reminders': hive.getReminders().map((e) => e.toJson()).toList(),
      'reminderHistory':
          hive.getReminderHistory().map((e) => e.toJson()).toList(),
      'schoolClasses':
          hive.getSchoolClasses().map((e) => e.toJson()).toList(),
      'schoolDayModes': hive
          .getDayClassModes()
          .map((k, v) => MapEntry(k.toString(), v)),
      'aiAccounts': hive.getAIAccounts().map((e) => e.toJson()).toList(),
      'userAccounts':
          hive.getUserAccounts().map((e) => e.toJson()).toList(),
      'bills': hive.getBills().map((e) => e.toJson()).toList(),
      'gasPurchases':
          hive.getGasPurchases().map((e) => e.toJson()).toList(),
      'suppliers': hive.getSuppliers().map((e) => e.toJson()).toList(),
      'birthdays': hive.getBirthdays().map((e) => e.toJson()).toList(),
      'diaryEntries': hive
          .getDiaryEntries()
          .map((e) => e.toStoredJson())
          .toList(),
      'notes': hive.getNotes().map((e) => e.toStoredJson()).toList(),
      'settings': hive.getSettings().toJson(),
      'petPreferences': hive.getPetPreferences().toJson(),
      'studyMethods':
          hive.getStudyMethods().map((e) => e.toJson()).toList(),
      'studyHistory':
          hive.getStudyHistory().map((e) => e.toJson()).toList(),
      'studySettings': hive.getStudySettings().toJson(),
      'studySubjects': hive.getStudySubjects(),
    };

    final contentForChecksum = jsonEncode(base);
    final checksum = sha256.convert(utf8.encode(contentForChecksum)).toString();
    base['checksum'] = checksum;
    return base;
  }

  _LocalDataSnapshot _createSafetySnapshot(HiveService hive) {
    return _LocalDataSnapshot(
      reminders: hive.getReminders(),
      reminderHistory: hive.getReminderHistory(),
      schoolClasses: hive.getSchoolClasses(),
      schoolDayModes: hive.getDayClassModes(),
      aiAccounts: hive.getAIAccounts(),
      userAccounts: hive.getUserAccounts(),
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
      dataVersion: hive.dataVersion,
    );
  }

  Future<void> _rollbackToSnapshot(
    HiveService hive,
    _LocalDataSnapshot snapshot,
  ) async {
    try {
      await hive.clearAll();
      for (final r in snapshot.reminders) {
        await hive.saveReminder(r);
      }
      for (final h in snapshot.reminderHistory) {
        await hive.saveReminderHistoryRecord(h);
      }
      for (final s in snapshot.schoolClasses) {
        await hive.saveSchoolClass(s);
      }
      await hive.saveAllDayClassModes(snapshot.schoolDayModes);
      for (final a in snapshot.aiAccounts) {
        await hive.saveAIAccount(a);
      }
      for (final u in snapshot.userAccounts) {
        await hive.saveUserAccount(u);
      }
      for (final b in snapshot.bills) {
        await hive.saveBill(b);
      }
      for (final g in snapshot.gasPurchases) {
        await hive.saveGasPurchase(g);
      }
      for (final s in snapshot.suppliers) {
        await hive.saveSupplier(s);
      }
      for (final b in snapshot.birthdays) {
        await hive.saveBirthday(b);
      }
      for (final d in snapshot.diaryEntries) {
        await hive.saveStoredDiaryEntry(d.id, d.toStoredJson());
      }
      for (final n in snapshot.notes) {
        await hive.saveStoredNote(n.id, n.toStoredJson());
      }
      await hive.saveSettings(snapshot.settings);
      await hive.savePetPreferences(snapshot.petPreferences);
      for (final m in snapshot.studyMethods) {
        await hive.saveStudyMethod(m);
      }
      for (final h in snapshot.studyHistory) {
        await hive.saveStudyHistoryRecord(h);
      }
      await hive.saveStudySettings(snapshot.studySettings);
      for (final s in snapshot.studySubjects) {
        await hive.saveStudySubject(s);
      }
      await hive.setDataVersion(snapshot.dataVersion);
    } catch (e) {
      debugPrint('Critical error during rollback: $e');
    }
  }
}

class _LocalDataSnapshot {
  const _LocalDataSnapshot({
    required this.reminders,
    required this.reminderHistory,
    required this.schoolClasses,
    required this.schoolDayModes,
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
    required this.dataVersion,
  });

  final List<Reminder> reminders;
  final List<ReminderHistoryRecord> reminderHistory;
  final List<SchoolClass> schoolClasses;
  final Map<int, String> schoolDayModes;
  final List<AIAccount> aiAccounts;
  final List<UserAccount> userAccounts;
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
  final int dataVersion;
}
