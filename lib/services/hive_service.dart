import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_models.dart';
import '../models/study_models.dart';
import '../models/pet_models.dart';

class HiveService {
  static final HiveService instance = HiveService._internal();
  HiveService._internal();

  // Data version for migrations
  static const int currentDataVersion = 8;

  Box<String>? _remindersBox;
  Box<String>? _schoolClassesBox;
  Box<String>? _aiAccountsBox;
  Box<String>? _userAccountsBox;
  Box<String>? _billsBox;
  Box<String>? _gasPurchasesBox;
  Box<String>? _suppliersBox;
  Box<String>? _settingsBox;
  Box<String>? _birthdaysBox;
  Box<String>? _studyMethodsBox;
  Box<String>? _studyHistoryBox;
  Box<String>? _studyTimerBox;
  Box<String>? _studySettingsBox;
  Box<String>? _studySubjectsBox;
  Box<String>? _petBox;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    _remindersBox = await Hive.openBox<String>('reminders');
    _schoolClassesBox = await Hive.openBox<String>('school_classes');
    _aiAccountsBox = await Hive.openBox<String>('ai_accounts');
    _userAccountsBox = await Hive.openBox<String>('user_accounts');
    _billsBox = await Hive.openBox<String>('bills');
    _gasPurchasesBox = await Hive.openBox<String>('gas_purchases');
    _suppliersBox = await Hive.openBox<String>('suppliers');
    _settingsBox = await Hive.openBox<String>('settings');
    _birthdaysBox = await Hive.openBox<String>('birthdays');
    _studyMethodsBox = await Hive.openBox<String>('study_methods');
    _studyHistoryBox = await Hive.openBox<String>('study_history');
    _studyTimerBox = await Hive.openBox<String>('study_timer');
    _studySettingsBox = await Hive.openBox<String>('study_settings');
    _studySubjectsBox = await Hive.openBox<String>('study_subjects');
    _petBox = await Hive.openBox<String>('pet');
    _initialized = true;

    // Run migrations after all boxes are opened
    await _runMigrations();
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
  }

  Future<void> deleteReminder(String id) async {
    await ensureInitialized();
    await _remindersBox!.delete(id);
    await _remindersBox!.flush();
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
    return _readRecords(_userAccountsBox!, UserAccount.fromJson);
  }

  Future<void> saveUserAccount(UserAccount account) async {
    await ensureInitialized();
    await _userAccountsBox!.put(account.id, jsonEncode(account.toJson()));
    await _userAccountsBox!.flush();
  }

  Future<void> deleteUserAccount(String id) async {
    await ensureInitialized();
    await _userAccountsBox!.delete(id);
    await _userAccountsBox!.flush();
  }

  // --- Bills ---
  List<Bill> getBills() {
    if (_billsBox == null) return [];
    return _readRecords(_billsBox!, Bill.fromJson);
  }

  Future<void> saveBill(Bill bill) async {
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
    await _schoolClassesBox?.clear();
    await _aiAccountsBox?.clear();
    await _userAccountsBox?.clear();
    await _billsBox?.clear();
    await _gasPurchasesBox?.clear();
    await _suppliersBox?.clear();
    await _settingsBox?.clear();
    await _birthdaysBox?.clear();
    await _studyMethodsBox?.clear();
    await _studyHistoryBox?.clear();
    await _studyTimerBox?.clear();
    await _studySettingsBox?.clear();
    await _studySubjectsBox?.clear();
    await _petBox?.clear();
    await _remindersBox?.flush();
    await _schoolClassesBox?.flush();
    await _aiAccountsBox?.flush();
    await _userAccountsBox?.flush();
    await _billsBox?.flush();
    await _gasPurchasesBox?.flush();
    await _suppliersBox?.flush();
    await _settingsBox?.flush();
    await _birthdaysBox?.flush();
    await _studyMethodsBox?.flush();
    await _studyHistoryBox?.flush();
    await _studyTimerBox?.flush();
    await _studySettingsBox?.flush();
    await _studySubjectsBox?.flush();
    await _petBox?.flush();
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
