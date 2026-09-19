import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_models.dart';

class HiveService {
  static final HiveService instance = HiveService._internal();
  HiveService._internal();

  // Data version for migrations
  static const int currentDataVersion = 4;

  Box<String>? _remindersBox;
  Box<String>? _schoolClassesBox;
  Box<String>? _aiAccountsBox;
  Box<String>? _userAccountsBox;
  Box<String>? _billsBox;
  Box<String>? _gasPurchasesBox;
  Box<String>? _suppliersBox;
  Box<String>? _settingsBox;
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
    await _remindersBox?.flush();
    await _schoolClassesBox?.flush();
    await _aiAccountsBox?.flush();
    await _userAccountsBox?.flush();
    await _billsBox?.flush();
    await _gasPurchasesBox?.flush();
    await _suppliersBox?.flush();
    await _settingsBox?.flush();
  }
}
