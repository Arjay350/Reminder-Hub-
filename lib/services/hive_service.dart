import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/security/security_service.dart';
import '../models/app_models.dart';
import '../models/diary_models.dart';
import '../models/study_models.dart';
import '../models/pet_models.dart';
import 'encryption_service.dart';

class HiveService {
  static final HiveService instance = HiveService._internal();
  HiveService._internal();

  // Data version for migrations
  static const int currentDataVersion = 10;

  final ValueNotifier<int> remindersChangedNotifier = ValueNotifier<int>(0);
  void notifyRemindersChanged() {
    remindersChangedNotifier.value++;
  }

  Box<String>? _remindersBox;
  Box<String>? _reminderHistoryBox;
  Box<String>? _schoolClassesBox;
  Box<String>? _aiAccountsBox;
  Box<String>? _userAccountsBox;
  Box<String>? _billsBox;
  Box<String>? _gasPurchasesBox;
  Box<String>? _suppliersBox;
  Box<String>? _settingsBox;
  Box<String>? _birthdaysBox;
  Box<String>? _diaryEntriesBox;
  Box<String>? _diaryEntryDatesBox;
  Box<String>? _notesBox;
  Box<String>? _studyMethodsBox;
  Box<String>? _studyHistoryBox;
  Box<String>? _studyTimerBox;
  Box<String>? _studySettingsBox;
  Box<String>? _studySubjectsBox;
  Box<String>? _petBox;
  bool _initialized = false;
  String? _credentialEncryptionKey;
  bool _credentialStorageLocked = false;
  final List<UserAccount> _userAccountCache = [];

  Future<void> init({
    @visibleForTesting String? directoryPath,
    @visibleForTesting String? testCredentialEncryptionKey,
    @visibleForTesting bool runMigrations = true,
  }) async {
    if (_initialized) return;

    if (directoryPath == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(directoryPath);
    }

    _remindersBox = await Hive.openBox<String>('reminders');
    _reminderHistoryBox = await Hive.openBox<String>('reminder_history');
    _schoolClassesBox = await Hive.openBox<String>('school_classes');
    _aiAccountsBox = await Hive.openBox<String>('ai_accounts');
    _userAccountsBox = await Hive.openBox<String>('user_accounts');
    _billsBox = await Hive.openBox<String>('bills');
    _gasPurchasesBox = await Hive.openBox<String>('gas_purchases');
    _suppliersBox = await Hive.openBox<String>('suppliers');
    _settingsBox = await Hive.openBox<String>('settings');
    _birthdaysBox = await Hive.openBox<String>('birthdays');
    _diaryEntriesBox = await Hive.openBox<String>('diary_entries');
    _diaryEntryDatesBox = await Hive.openBox<String>('diary_entry_dates');
    _notesBox = await Hive.openBox<String>('notes');
    _studyMethodsBox = await Hive.openBox<String>('study_methods');
    _studyHistoryBox = await Hive.openBox<String>('study_history');
    _studyTimerBox = await Hive.openBox<String>('study_timer');
    _studySettingsBox = await Hive.openBox<String>('study_settings');
    _studySubjectsBox = await Hive.openBox<String>('study_subjects');
    _petBox = await Hive.openBox<String>('pet');
    _initialized = true;

    try {
      await _initializeUserAccountEncryption(testCredentialEncryptionKey);
      if (runMigrations) {
        await _runMigrations();
        await _initializeDiaryEntryDateIndex();
      }
    } catch (_) {
      await Hive.close();
      _resetBoxReferences();
      _initialized = false;
      rethrow;
    }
  }

  Future<void> _initializeUserAccountEncryption(String? testKey) async {
    final box = _userAccountsBox!;
    if (box.isEmpty) {
      _credentialEncryptionKey = testKey;
      _credentialStorageLocked = false;
      return;
    }

    final records = <MapEntry<dynamic, String>>[];
    var hasEncryptedRecord = false;
    for (final entry in box.toMap().entries) {
      final raw = entry.value;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Invalid saved account record.');
      }
      final record = Map<String, dynamic>.from(decoded);
      hasEncryptedRecord |= EncryptionService.instance.isEncryptedAccountRecord(
        record,
      );
      records.add(MapEntry(entry.key, raw));
    }

    String? key;
    try {
      key = testKey ?? await SecurityService.instance.getAccountEncryptionKey();
    } catch (_) {
      _credentialStorageLocked = true;
      return;
    }
    if (key == null) {
      if (hasEncryptedRecord) {
        _credentialStorageLocked = true;
        return;
      }
      try {
        key = _generateCredentialKey();
        await SecurityService.instance.setAccountEncryptionKey(key);
      } catch (_) {
        _credentialStorageLocked = true;
        return;
      }
    }
    _credentialEncryptionKey = key;
    _credentialStorageLocked = false;

    _userAccountCache.clear();
    for (final entry in records) {
      final decoded = jsonDecode(entry.value) as Map;
      final record = Map<String, dynamic>.from(decoded);
      final isEncrypted = EncryptionService.instance.isEncryptedAccountRecord(
        record,
      );
      final json = isEncrypted
          ? await EncryptionService.instance.decryptAccountJson(
              entry.value,
              key,
            )
          : entry.value;
      final account = UserAccount.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      if (account.id != entry.key) {
        throw const FormatException('Saved account identifier mismatch.');
      }
      _userAccountCache.add(account);
      if (!isEncrypted) {
        final encrypted = await EncryptionService.instance.encryptAccountJson(
          entry.value,
          key,
        );
        await box.put(entry.key, encrypted);
        await box.flush();
      }
    }
  }

  String _generateCredentialKey() {
    final random = Random.secure();
    return base64Encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  Future<void> _runMigrations() async {
    final currentVersion = _getStoredDataVersion();
    if (currentVersion < currentDataVersion) {
      debugPrint(
        'Running data migration from v$currentVersion to v$currentDataVersion',
      );
      await _migrate(currentVersion, currentDataVersion);
      await _setStoredDataVersion(currentDataVersion);
      debugPrint('Data migration completed successfully');
    }
  }

  int _getStoredDataVersion() {
    if (_settingsBox == null) return 1;
    final raw = _settingsBox!.get('data_version');
    if (raw == null) return 1;
    return int.tryParse(raw) ?? 1;
  }

  int get dataVersion => _getStoredDataVersion();

  Future<void> setDataVersion(int version) async {
    await _setStoredDataVersion(version);
  }

  Future<void> _setStoredDataVersion(int version) async {
    await ensureInitialized();
    await _settingsBox!.put('data_version', version.toString());
    await _settingsBox!.flush();
  }

  Future<void> _migrate(int fromVersion, int toVersion) async {
    // Migration from v1 to v2: Add paymentHistory to Bills (already handled by Bill.fromJson)
    if (fromVersion < 2) {
      // v1 -> v2: Bill paymentHistory already has safe defaults in fromJson
      debugPrint(
        'Migration v1->v2: Bill paymentHistory defaults handled by model',
      );
    }
    if (fromVersion < 4) {
      // v3 -> v4: Migrate AI accounts that were inadvertently assigned 'daily'
      // back to 'Exact Date/Time' so their notifications do not repeat daily.
      for (final account in getAIAccounts()) {
        if (account.resetSchedule.trim().toLowerCase() == 'daily') {
          final updated = account.copyWith(resetSchedule: 'Exact Date/Time');
          await saveAIAccount(updated);
        }
      }
      debugPrint(
        'Migration v3->v4: AI accounts resetSchedule migrated to Exact Date/Time',
      );
    }
    if (fromVersion < 5) {
      debugPrint('Migration v4->v5: Study module defaults initialized safely.');
    }
    if (fromVersion < 7) {
      debugPrint(
        'Migration v6->v7: Safe migration for Pet Body Condition fields.',
      );
      final prefs = getPetPreferences();
      if (prefs.lastBodyConditionUpdate == null) {
        final updated = prefs.copyWith(lastBodyConditionUpdate: DateTime.now());
        await savePetPreferences(updated);
      }
    }
    if (fromVersion < 8) {
      await _migrateDuplicateUserBirthdays();
    }
    if (fromVersion < 10) {
      for (final bill in getBills()) {
        await saveBill(bill);
      }
    }
  }

  Future<void> _migrateDuplicateUserBirthdays() async {
    final birthdays = getBirthdays();
    final normalized = Birthday.keepSingleUserBirthday(birthdays);
    if (normalized.length == birthdays.length) return;

    final retainedIds = normalized.map((birthday) => birthday.id).toSet();
    for (final birthday in birthdays) {
      if (birthday.isUserBirthday && !retainedIds.contains(birthday.id)) {
        await _birthdaysBox!.delete(birthday.id);
      }
    }
    await _birthdaysBox!.flush();
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  List<T> _readRecords<T>(
    Box<String> box,
    T Function(Map<String, dynamic>) parse,
  ) {
    final records = <T>[];
    for (final raw in box.values) {
      try {
        records.add(parse(jsonDecode(raw) as Map<String, dynamic>));
      } catch (error) {
        debugPrint('Skipping invalid Hive record: $error');
      }
    }
    return records;
  }

  // --- Reminders ---
  List<Reminder> getReminders() {
    if (_remindersBox == null) return [];
    return _readRecords(_remindersBox!, Reminder.fromJson);
  }

  Future<void> saveReminder(Reminder reminder) async {
    await ensureInitialized();
    await _remindersBox!.put(reminder.id, jsonEncode(reminder.toJson()));
    await _remindersBox!.flush();
    notifyRemindersChanged();
  }

  Future<void> deleteReminder(String id) async {
    await ensureInitialized();
    await _remindersBox!.delete(id);
    await _remindersBox!.flush();
    notifyRemindersChanged();
  }

  // --- Reminder Completion History ---
  List<ReminderHistoryRecord> getReminderHistory() {
    if (_reminderHistoryBox == null) return [];
    final records = _readRecords(
      _reminderHistoryBox!,
      ReminderHistoryRecord.fromJson,
    );
    records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return records;
  }

  Future<void> saveReminderHistoryRecord(ReminderHistoryRecord record) async {
    await ensureInitialized();
    await _reminderHistoryBox!.put(record.id, jsonEncode(record.toJson()));
    await _reminderHistoryBox!.flush();
    notifyRemindersChanged();
  }

  Future<void> deleteReminderHistoryRecord(String id) async {
    await ensureInitialized();
    await _reminderHistoryBox!.delete(id);
    await _reminderHistoryBox!.flush();
    notifyRemindersChanged();
  }

  Future<void> clearReminderHistory() async {
    await ensureInitialized();
    await _reminderHistoryBox!.clear();
    await _reminderHistoryBox!.flush();
    notifyRemindersChanged();
  }

  // --- School Classes ---
  List<SchoolClass> getSchoolClasses() {
    if (_schoolClassesBox == null) return [];
    return _readRecords(_schoolClassesBox!, SchoolClass.fromJson);
  }

  Future<void> saveSchoolClass(SchoolClass schoolClass) async {
    await ensureInitialized();
    await _schoolClassesBox!.put(
      schoolClass.id,
      jsonEncode(schoolClass.toJson()),
    );
    await _schoolClassesBox!.flush();
  }

  Future<void> deleteSchoolClass(String id) async {
    await ensureInitialized();
    await _schoolClassesBox!.delete(id);
    await _schoolClassesBox!.flush();
  }

  // --- AI Accounts ---
  List<AIAccount> getAIAccounts() {
    if (_aiAccountsBox == null) return [];
    return _readRecords(_aiAccountsBox!, AIAccount.fromJson);
  }

  Future<void> saveAIAccount(AIAccount account) async {
    await ensureInitialized();
    await _aiAccountsBox!.put(account.id, jsonEncode(account.toJson()));
    await _aiAccountsBox!.flush();
  }

  Future<void> deleteAIAccount(String id) async {
    await ensureInitialized();
    await _aiAccountsBox!.delete(id);
    await _aiAccountsBox!.flush();
  }

  // --- User Accounts ---
  List<UserAccount> getUserAccounts() {
    if (_userAccountsBox == null) return [];
    if (_credentialStorageLocked ||
        (_userAccountsBox!.isNotEmpty && _credentialEncryptionKey == null)) {
      throw StateError(
        'Saved account credentials are locked because the device secure key is unavailable. '
        'Your data has not been deleted; restore a passphrase-protected backup from Settings.',
      );
    }
    return List<UserAccount>.unmodifiable(_userAccountCache);
  }

  Map<String, String> getUserAccountStorageRecords() {
    if (_userAccountsBox == null) return {};
    return {
      for (final entry in _userAccountsBox!.toMap().entries)
        entry.key: entry.value,
    };
  }

  @visibleForTesting
  Future<void> writeRawUserAccountRecordForTesting(
    String id,
    String serializedRecord,
  ) async {
    await ensureInitialized();
    await _userAccountsBox!.put(id, serializedRecord);
    await _userAccountsBox!.flush();
  }

  Future<void> restoreUserAccountStorageRecords(
    Map<String, String> records, {
    String? encryptionKey,
  }) async {
    await ensureInitialized();
    await _userAccountsBox!.clear();
    await _userAccountsBox!.putAll(records);
    await _userAccountsBox!.flush();
    _userAccountCache.clear();
    _credentialEncryptionKey = encryptionKey;
    _credentialStorageLocked = records.isNotEmpty && encryptionKey == null;
    if (encryptionKey == null) return;
    for (final entry in records.entries) {
      final decoded = jsonDecode(entry.value) as Map;
      final record = Map<String, dynamic>.from(decoded);
      final isEncrypted = EncryptionService.instance.isEncryptedAccountRecord(
        record,
      );
      final serialized = isEncrypted
          ? await EncryptionService.instance.decryptAccountJson(
              entry.value,
              encryptionKey,
            )
          : entry.value;
      final account = UserAccount.fromJson(
        jsonDecode(serialized) as Map<String, dynamic>,
      );
      if (account.id != entry.key) {
        throw const FormatException('Saved account identifier mismatch.');
      }
      _userAccountCache.add(account);
      if (!isEncrypted) {
        await _userAccountsBox!.put(
          entry.key,
          await EncryptionService.instance.encryptAccountJson(
            entry.value,
            encryptionKey,
          ),
        );
      }
    }
    await _userAccountsBox!.flush();
  }

  Future<void> saveUserAccount(UserAccount account) async {
    await ensureInitialized();
    var key = _credentialEncryptionKey;
    if (key == null) {
      key = await SecurityService.instance.getAccountEncryptionKey();
      if (key == null) {
        if (_userAccountsBox!.isNotEmpty) {
          throw StateError(
            'Cannot replace the secure key while encrypted account records exist.',
          );
        }
        key = _generateCredentialKey();
        await SecurityService.instance.setAccountEncryptionKey(key);
      }
      _credentialEncryptionKey = key;
    }
    _credentialStorageLocked = false;
    final serialized = jsonEncode(account.toJson());
    final encrypted = await EncryptionService.instance.encryptAccountJson(
      serialized,
      key,
    );
    await _userAccountsBox!.put(account.id, encrypted);
    await _userAccountsBox!.flush();
    _userAccountCache.removeWhere((stored) => stored.id == account.id);
    _userAccountCache.add(account);
  }

  Future<void> deleteUserAccount(String id) async {
    await ensureInitialized();
    await _userAccountsBox!.delete(id);
    await _userAccountsBox!.flush();
    _userAccountCache.removeWhere((account) => account.id == id);
  }

  // --- Bills ---
  List<Bill> getBills() {
    if (_billsBox == null) return [];
    return _readRecords(_billsBox!, Bill.fromJson);
  }

  Future<void> saveBill(Bill bill) async {
    if (!Bill.isValidAmount(bill.amount)) {
      throw ArgumentError.value(
        bill.amount,
        'bill.amount',
        'Must be a finite amount greater than zero.',
      );
    }
    await ensureInitialized();
    await _billsBox!.put(bill.id, jsonEncode(bill.toJson()));
    await _billsBox!.flush();
  }

  Future<void> deleteBill(String id) async {
    await ensureInitialized();
    await _billsBox!.delete(id);
    await _billsBox!.flush();
  }

  // --- Gas Purchases ---
  List<GasPurchase> getGasPurchases() {
    if (_gasPurchasesBox == null) return [];
    final list = _readRecords(_gasPurchasesBox!, GasPurchase.fromJson);
    list.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    return list;
  }

  Future<void> saveGasPurchase(GasPurchase purchase) async {
    await ensureInitialized();
    await _gasPurchasesBox!.put(purchase.id, jsonEncode(purchase.toJson()));
    await _gasPurchasesBox!.flush();
  }

  Future<void> deleteGasPurchase(String id) async {
    await ensureInitialized();
    await _gasPurchasesBox!.delete(id);
    await _gasPurchasesBox!.flush();
  }

  // --- Suppliers ---
  List<Supplier> getSuppliers() {
    if (_suppliersBox == null) return [];
    return _readRecords(_suppliersBox!, Supplier.fromJson);
  }

  Future<void> saveSupplier(Supplier supplier) async {
    await ensureInitialized();
    await _suppliersBox!.put(supplier.id, jsonEncode(supplier.toJson()));
    await _suppliersBox!.flush();
  }

  Future<void> deleteSupplier(String id) async {
    await ensureInitialized();
    await _suppliersBox!.delete(id);
    await _suppliersBox!.flush();
  }

  // --- Birthdays ---
  List<Birthday> getBirthdays() {
    if (_birthdaysBox == null) return [];
    final birthdays = _readRecords(_birthdaysBox!, Birthday.fromJson);
    birthdays.sort((a, b) => a.nextBirthdayDate.compareTo(b.nextBirthdayDate));
    return birthdays;
  }

  Future<void> saveBirthday(Birthday birthday) async {
    await ensureInitialized();

    if (birthday.isUserBirthday) {
      final otherBirthdays = getBirthdays().where(
        (item) => item.isUserBirthday && item.id != birthday.id,
      );
      for (final otherBirthday in otherBirthdays) {
        final replacement = otherBirthday.copyWith(isUserBirthday: false);
        await _birthdaysBox!.put(
          replacement.id,
          jsonEncode(replacement.toJson()),
        );
      }
    }

    await _birthdaysBox!.put(birthday.id, jsonEncode(birthday.toJson()));
    await _birthdaysBox!.flush();
  }

  Future<void> deleteBirthday(String id) async {
    await ensureInitialized();
    await _birthdaysBox!.delete(id);
    await _birthdaysBox!.flush();
  }

  // --- Diary & Notes ---
  List<DiaryEntry> getDiaryEntries() {
    if (_diaryEntriesBox == null) return [];
    return _readRecords(_diaryEntriesBox!, DiaryEntry.fromJson);
  }

  Map<DateTime, int> getDiaryEntryDateCounts() {
    final dateBox = _diaryEntryDatesBox;
    if (dateBox == null) return const {};
    final counts = <DateTime, int>{};
    for (final storedDate in dateBox.values) {
      final date = DateTime.tryParse(storedDate);
      if (date == null) {
        debugPrint('HiveService: invalid diary date index value: $storedDate');
        continue;
      }
      final localDate = DateTime(date.year, date.month, date.day);
      counts.update(localDate, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  List<DiaryEntry> getDiaryEntriesForDate(DateTime date) {
    final entriesBox = _diaryEntriesBox;
    final datesBox = _diaryEntryDatesBox;
    if (entriesBox == null || datesBox == null) return [];

    final dateValue = _diaryDateIndexValue(date);
    final entries = <DiaryEntry>[];
    for (final record in datesBox.toMap().entries) {
      if (record.value != dateValue) continue;
      final raw = entriesBox.get(record.key);
      if (raw == null) continue;
      try {
        entries.add(
          DiaryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (error) {
        debugPrint('Skipping invalid diary entry ${record.key}: $error');
      }
    }
    return entries;
  }

  Future<void> saveDiaryEntry(DiaryEntry entry) async {
    await ensureInitialized();
    await saveStoredDiaryEntry(entry.id, entry.toStoredJson());
  }

  Future<void> saveStoredDiaryEntry(
    String id,
    Map<String, dynamic> storedData,
  ) async {
    await ensureInitialized();
    await _diaryEntriesBox!.put(id, jsonEncode(storedData));
    await _updateDiaryEntryDateIndex(id, storedData);
    await _diaryEntriesBox!.flush();
  }

  Future<void> deleteDiaryEntry(String id) async {
    await ensureInitialized();
    await _diaryEntriesBox!.delete(id);
    await _diaryEntryDatesBox!.delete(id);
    await _diaryEntryDatesBox!.flush();
    await _diaryEntriesBox!.flush();
  }

  Future<void> _initializeDiaryEntryDateIndex() async {
    final initialized = _settingsBox!.get('diary_date_index_initialized');
    if (initialized == 'true') return;

    for (final key in _diaryEntriesBox!.keys) {
      final raw = _diaryEntriesBox!.get(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          debugPrint('HiveService: diary entry $key is not a JSON object');
          continue;
        }
        final rawDate = decoded['createdAt'];
        final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
        if (date == null) {
          debugPrint(
            'HiveService: diary entry $key has no valid creation date',
          );
          continue;
        }
        await _diaryEntryDatesBox!.put(
          key.toString(),
          _diaryDateIndexValue(date),
        );
      } catch (error) {
        debugPrint('HiveService: skipping diary date index for $key: $error');
      }
    }
    await _diaryEntryDatesBox!.flush();
    await _settingsBox!.put('diary_date_index_initialized', 'true');
    await _settingsBox!.flush();
  }

  Future<void> _updateDiaryEntryDateIndex(
    String id,
    Map<String, dynamic> storedData,
  ) async {
    final rawDate = storedData['createdAt'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (date == null) {
      throw FormatException('Diary entry $id has no valid creation date');
    }
    await _diaryEntryDatesBox!.put(id, _diaryDateIndexValue(date));
    await _diaryEntryDatesBox!.flush();
  }

  String _diaryDateIndexValue(DateTime date) {
    final localDate = date.toLocal();
    final year = localDate.year.toString().padLeft(4, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  List<NotebookNote> getNotes() {
    if (_notesBox == null) return [];
    return _readRecords(_notesBox!, NotebookNote.fromJson);
  }

  Future<void> saveNote(NotebookNote note) async {
    await ensureInitialized();
    await _notesBox!.put(note.id, jsonEncode(note.toStoredJson()));
    await _notesBox!.flush();
  }

  Future<void> saveStoredNote(
    String id,
    Map<String, dynamic> storedData,
  ) async {
    await ensureInitialized();
    await _notesBox!.put(id, jsonEncode(storedData));
    await _notesBox!.flush();
  }

  Future<void> deleteNote(String id) async {
    await ensureInitialized();
    await _notesBox!.delete(id);
    await _notesBox!.flush();
  }

  // --- Settings ---
  AppSettings getSettings() {
    final fallback = AppSettings(
      themeMode: 'System',
      userName: '',
      nameSetupCompleted: false,
      notificationTime: '09:00 AM',
      currency: '₱',
      appLock: false,
      biometricEnabled: false,
    );

    if (_settingsBox == null || _settingsBox!.isEmpty) {
      return fallback;
    }

    final str = _settingsBox!.get('current_settings');
    if (str == null || str.trim().isEmpty) {
      return fallback;
    }

    try {
      final decoded = jsonDecode(str);
      if (decoded is! Map<String, dynamic>) {
        return fallback;
      }
      return AppSettings.fromJson(decoded);
    } catch (error) {
      debugPrint('Invalid stored settings; falling back to defaults: $error');
      return fallback;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await ensureInitialized();
    final safeSettings = AppSettings.fromJson(settings.toJson());
    await _settingsBox!.put(
      'current_settings',
      jsonEncode(safeSettings.toJson()),
    );
    await _settingsBox!.flush();
  }

  // --- What's New Version Tracking ---
  bool hasExistingUserData() {
    if (_settingsBox == null) return false;
    final hasSettings = _settingsBox!.get('current_settings') != null;
    final hasDataVersion = _settingsBox!.get('data_version') != null;
    final hasReminders = _remindersBox?.isNotEmpty ?? false;
    final hasBills = _billsBox?.isNotEmpty ?? false;
    final hasClasses = _schoolClassesBox?.isNotEmpty ?? false;
    final hasAi = _aiAccountsBox?.isNotEmpty ?? false;
    final hasAccounts = _userAccountsBox?.isNotEmpty ?? false;
    final hasGas = _gasPurchasesBox?.isNotEmpty ?? false;
    return hasSettings ||
        hasDataVersion ||
        hasReminders ||
        hasBills ||
        hasClasses ||
        hasAi ||
        hasAccounts ||
        hasGas;
  }

  String getLastSeenWhatsNewVersion() {
    if (_settingsBox == null) return '';
    final str = _settingsBox!.get('last_seen_whats_new_version');
    if (str != null && str.isNotEmpty) return str;
    final settings = getSettings();
    return settings.lastSeenWhatsNewVersion;
  }

  Future<void> setLastSeenWhatsNewVersion(String version) async {
    await ensureInitialized();
    await _settingsBox!.put('last_seen_whats_new_version', version);
    final settings = getSettings();
    await saveSettings(settings.copyWith(lastSeenWhatsNewVersion: version));
    await _settingsBox!.flush();
  }

  bool shouldShowWhatsNew(String currentVersion) {
    final lastSeen = getLastSeenWhatsNewVersion();
    if (lastSeen == currentVersion) {
      return false; // Already seen for this version
    }

    final isExistingUser = hasExistingUserData();
    if (!isExistingUser && lastSeen.isEmpty) {
      // Brand new install: do not show upgrade popup, mark current version
      setLastSeenWhatsNewVersion(currentVersion);
      return false;
    }

    // Existing user upgrading who hasn't seen currentVersion
    return true;
  }

  // --- Day-Based Class Modes (Mon = 1 ... Sat = 6) ---
  Map<int, String> getDayClassModes() {
    final defaultModes = <int, String>{
      1: DayClassMode.f2f,
      2: DayClassMode.f2f,
      3: DayClassMode.f2f,
      4: DayClassMode.f2f,
      5: DayClassMode.f2f,
      6: DayClassMode.f2f,
    };
    if (_settingsBox == null) return defaultModes;
    final raw = _settingsBox!.get('school_day_modes');
    if (raw == null) return defaultModes;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = Map<int, String>.from(defaultModes);
      decoded.forEach((key, val) {
        final dayNum = int.tryParse(key);
        if (dayNum != null && dayNum >= 1 && dayNum <= 6 && val is String) {
          result[dayNum] = val;
        }
      });
      return result;
    } catch (_) {
      return defaultModes;
    }
  }

  Future<void> saveDayClassMode(int day, String mode) async {
    await ensureInitialized();
    final current = getDayClassModes();
    current[day] = mode;
    final mapToSave = current.map((k, v) => MapEntry(k.toString(), v));
    await _settingsBox!.put('school_day_modes', jsonEncode(mapToSave));
    await _settingsBox!.flush();
  }

  Future<void> saveAllDayClassModes(Map<int, String> modes) async {
    await ensureInitialized();
    final mapToSave = modes.map((k, v) => MapEntry(k.toString(), v));
    await _settingsBox!.put('school_day_modes', jsonEncode(mapToSave));
    await _settingsBox!.flush();
  }

  // --- Clear All Data ---
  // --- Study Methods ---
  List<StudyMethod> getStudyMethods() {
    if (_studyMethodsBox == null) return [];
    return _readRecords(_studyMethodsBox!, StudyMethod.fromJson);
  }

  Future<void> saveStudyMethod(StudyMethod method) async {
    await ensureInitialized();
    await _studyMethodsBox!.put(method.id, jsonEncode(method.toJson()));
    await _studyMethodsBox!.flush();
  }

  Future<void> deleteStudyMethod(String id) async {
    await ensureInitialized();
    await _studyMethodsBox!.delete(id);
    await _studyMethodsBox!.flush();
  }

  // --- Study Settings ---
  StudySettings getStudySettings() {
    if (_studySettingsBox == null || _studySettingsBox!.isEmpty) {
      return StudySettings();
    }
    final raw = _studySettingsBox!.get('current_study_settings');
    if (raw == null || raw.trim().isEmpty) {
      return StudySettings();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return StudySettings();
      return StudySettings.fromJson(decoded);
    } catch (_) {
      return StudySettings();
    }
  }

  Future<void> saveStudySettings(StudySettings settings) async {
    await ensureInitialized();
    final safeSettings = StudySettings.fromJson(settings.toJson());
    await _studySettingsBox!.put(
      'current_study_settings',
      jsonEncode(safeSettings.toJson()),
    );
    await _studySettingsBox!.flush();
  }

  // --- Study Timer State ---
  StudyTimerState? getStudyTimerState() {
    if (_studyTimerBox == null || _studyTimerBox!.isEmpty) return null;
    final raw = _studyTimerBox!.get('current_timer_state');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return StudyTimerState.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveStudyTimerState(StudyTimerState state) async {
    await ensureInitialized();
    await _studyTimerBox!.put(
      'current_timer_state',
      jsonEncode(state.toJson()),
    );
    await _studyTimerBox!.flush();
  }

  Future<void> clearStudyTimerState() async {
    await ensureInitialized();
    await _studyTimerBox!.delete('current_timer_state');
    await _studyTimerBox!.flush();
  }

  List<String> getStudySubjects() {
    if (_studySubjectsBox == null) return [];
    return _studySubjectsBox!.values
        .map((subject) => subject.trim())
        .where((subject) => subject.isNotEmpty)
        .toList();
  }

  Future<void> saveStudySubject(String subject) async {
    final normalized = subject.trim();
    if (normalized.isEmpty) return;
    await ensureInitialized();
    final exists = getStudySubjects().any(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) return;
    await _studySubjectsBox!.put(normalized, normalized);
    await _studySubjectsBox!.flush();
  }

  // --- Study History ---
  List<StudySessionRecord> getStudyHistory() {
    if (_studyHistoryBox == null) return [];
    return _readRecords(_studyHistoryBox!, StudySessionRecord.fromJson);
  }

  Future<void> saveStudyHistoryRecord(StudySessionRecord record) async {
    await ensureInitialized();
    await _studyHistoryBox!.put(record.id, jsonEncode(record.toJson()));
    await _studyHistoryBox!.flush();
  }

  Future<void> clearAll() async {
    await ensureInitialized();
    await _remindersBox?.clear();
    await _reminderHistoryBox?.clear();
    await _schoolClassesBox?.clear();
    await _aiAccountsBox?.clear();
    await _userAccountsBox?.clear();
    await _billsBox?.clear();
    await _gasPurchasesBox?.clear();
    await _suppliersBox?.clear();
    await _settingsBox?.clear();
    await _birthdaysBox?.clear();
    await _diaryEntriesBox?.clear();
    await _diaryEntryDatesBox?.clear();
    await _notesBox?.clear();
    await _studyMethodsBox?.clear();
    await _studyHistoryBox?.clear();
    await _studyTimerBox?.clear();
    await _studySettingsBox?.clear();
    await _studySubjectsBox?.clear();
    await _petBox?.clear();
    await _remindersBox?.flush();
    await _reminderHistoryBox?.flush();
    await _schoolClassesBox?.flush();
    await _aiAccountsBox?.flush();
    await _userAccountsBox?.flush();
    await _billsBox?.flush();
    await _gasPurchasesBox?.flush();
    await _suppliersBox?.flush();
    await _settingsBox?.flush();
    await _birthdaysBox?.flush();
    await _diaryEntriesBox?.flush();
    await _diaryEntryDatesBox?.flush();
    await _notesBox?.flush();
    await _studyMethodsBox?.flush();
    await _studyHistoryBox?.flush();
    await _studyTimerBox?.flush();
    await _studySettingsBox?.flush();
    await _studySubjectsBox?.flush();
    await _petBox?.flush();
    _userAccountCache.clear();
    if (_userAccountsBox?.isEmpty == true) {
      _credentialStorageLocked = false;
    }
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    if (_initialized) await Hive.close();
    _resetBoxReferences();
    _credentialEncryptionKey = null;
    _credentialStorageLocked = false;
    _userAccountCache.clear();
    _initialized = false;
  }

  void _resetBoxReferences() {
    _remindersBox = null;
    _reminderHistoryBox = null;
    _schoolClassesBox = null;
    _aiAccountsBox = null;
    _userAccountsBox = null;
    _billsBox = null;
    _gasPurchasesBox = null;
    _suppliersBox = null;
    _settingsBox = null;
    _birthdaysBox = null;
    _diaryEntriesBox = null;
    _diaryEntryDatesBox = null;
    _notesBox = null;
    _studyMethodsBox = null;
    _studyHistoryBox = null;
    _studyTimerBox = null;
    _studySettingsBox = null;
    _studySubjectsBox = null;
    _petBox = null;
  }

  // --- Pet Companion Preferences ---
  PetPreferences getPetPreferences() {
    if (_petBox == null || _petBox!.isEmpty) {
      return const PetPreferences();
    }
    final raw = _petBox!.get('pet_preferences');
    if (raw == null || raw.trim().isEmpty) {
      return const PetPreferences();
    }
    return PetPreferences.fromJsonString(raw);
  }

  Future<void> savePetPreferences(PetPreferences prefs) async {
    if (_petBox == null) return;
    await ensureInitialized();
    await _petBox!.put('pet_preferences', prefs.toJsonString());
    await _petBox!.flush();
  }
}
