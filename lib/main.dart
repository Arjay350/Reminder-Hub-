import 'package:flutter/material.dart';
import 'core/security/security_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/ai_accounts/ai_accounts_screen.dart';
import 'screens/bills/bills_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/reminders/reminders_screen.dart';
import 'screens/school_schedule/school_schedule_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/study/study_dashboard_screen.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await HiveService.instance.init();
  } catch (e) {
    debugPrint('Hive init warning: $e');
  }
  try {
    await NotificationService.instance.init();
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.rescheduleAll();
  } catch (e) {
    debugPrint('Notification init warning: $e');
  }
  try {
    await WidgetService.instance.updateSchoolWidget();
  } catch (e) {
    debugPrint('Widget init warning: $e');
  }
  try {
    await WidgetService.instance.updateBillsWidget();
  } catch (e) {
    debugPrint('Bills widget init warning: $e');
  }
  runApp(const ReminderHubApp());
}

class ReminderHubApp extends StatefulWidget {
  const ReminderHubApp({super.key});

  @override
  State<ReminderHubApp> createState() => _ReminderHubAppState();
}

class _ReminderHubAppState extends State<ReminderHubApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemeSetting();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NotificationService.instance.requestPermissions();
        await NotificationService.instance.rescheduleAll();
      } catch (e) {
        debugPrint('Post-frame notification reconciliation error: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetService.instance.updateSchoolWidget();
      WidgetService.instance.updateBillsWidget();
      NotificationService.instance.rescheduleAll();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      WidgetService.instance.updateSchoolWidget();
      WidgetService.instance.updateBillsWidget();
    }
  }

  Future<void> _loadThemeSetting() async {
    final settings = HiveService.instance.getSettings();
    setState(() {
      _themeMode = _parseThemeMode(settings.themeMode);
    });
  }

  ThemeMode _parseThemeMode(String mode) {
    if (mode == 'Light') return ThemeMode.light;
    if (mode == 'Dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  void _onThemeChanged(String mode) {
    setState(() {
      _themeMode = _parseThemeMode(mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: MainNavigationShell(onThemeChanged: _onThemeChanged),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key, this.onThemeChanged});

  final Function(String themeMode)? onThemeChanged;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppLock();
    _setupWidgetNavigation();
  }

  int _currentIndex = 0;
  bool _unlocked = false;
  bool _appLockChecked = false;
  String? _pendingWidgetRoute;
  bool _widgetNavigationReady = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden) &&
        HiveService.instance.getSettings().appLock &&
        mounted) {
      setState(() => _unlocked = false);
    }
  }

  void _setupWidgetNavigation() {
    WidgetService.instance.onNavigationRequested = (route) {
      _handleWidgetRoute(route);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _widgetNavigationReady = true;
      final route = await WidgetService.instance.getLaunchRoute();
      if (route != null) _handleWidgetRoute(route);
    });
  }

  void _handleWidgetRoute(String route) {
    if (!_widgetNavigationReady || !_appLockChecked || !_unlocked || !mounted) {
      _pendingWidgetRoute = route;
      return;
    }

    if (route == '/school_schedule' || route == 'school_schedule') {
      _navigateToSchoolSchedule();
    } else if (route == '/bills' || route == 'bills') {
      _navigateToBills();
    }
  }

  void _openPendingWidgetRoute() {
    final route = _pendingWidgetRoute;
    _pendingWidgetRoute = null;
    if (route != null) _handleWidgetRoute(route);
  }

  void _navigateToSchoolSchedule() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SchoolScheduleScreen()));
  }

  void _navigateToBills() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BillsScreen()));
  }

  Future<void> _checkAppLock() async {
    final settings = HiveService.instance.getSettings();
    if (!mounted) return;
    setState(() {
      _appLockChecked = true;
      _unlocked = !settings.appLock;
    });
    if (!settings.appLock) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPendingWidgetRoute(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return PinLockScreen(
        onSuccess: () {
          setState(() => _unlocked = true);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _openPendingWidgetRoute(),
          );
        },
      );
    }

    final screens = [
      HomeScreen(
        key: const ValueKey('home'),
        onNavigateTab: (index) => setState(() => _currentIndex = index),
      ),
      const CalendarScreen(key: ValueKey('calendar')),
      const StudyDashboardScreen(key: ValueKey('study')),
      RemindersScreen(key: ValueKey('reminders_$_currentIndex')),
      const AIAccountsScreen(key: ValueKey('ai_accounts')),
      SettingsScreen(
        key: const ValueKey('settings'),
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final content = IndexedStack(index: _currentIndex, children: screens);

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (value) =>
                        setState(() => _currentIndex = value),
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Icon(Icons.notifications_active_rounded, size: 30),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: Text('Calendar'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: Text('Study'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.notifications_none_outlined),
                        selectedIcon: Icon(Icons.notifications),
                        label: Text('Reminders'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.smart_toy_outlined),
                        selectedIcon: Icon(Icons.smart_toy),
                        label: Text('AI Accounts'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (value) =>
                  setState(() => _currentIndex = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Calendar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Study',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_none_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'Reminders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: Icon(Icons.smart_toy),
                  label: 'AI Accounts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  String _errorText = '';
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _initBiometricsAndPrompt();
  }

  Future<void> _initBiometricsAndPrompt() async {
    final settings = HiveService.instance.getSettings();
    if (!settings.biometricEnabled) return;

    final isAvail = await SecurityService.instance.isBiometricsAvailable();
    if (mounted) setState(() => _canCheckBiometrics = isAvail);

    if (isAvail) {
      _promptBiometrics();
    }
  }

  Future<void> _promptBiometrics() async {
    try {
      final success = await SecurityService.instance.authenticate(
        reason: 'Scan your fingerprint to unlock Reminder Hub',
      );
      if (success && mounted) {
        widget.onSuccess();
      }
    } catch (_) {
      // Graceful fallback to PIN
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Reminder Hub Locked',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your 4-digit PIN or use Fingerprint Unlock to access offline data',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      errorText: _errorText.isEmpty ? null : _errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.length == 4) {
                        _verify(val);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _verify(_pinController.text),
                      icon: const Icon(Icons.key),
                      label: const Text('Unlock with PIN'),
                    ),
                    if (_canCheckBiometrics) ...[
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.fingerprint, size: 24),
                        tooltip: 'Use Fingerprint Unlock',
                        onPressed: _promptBiometrics,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verify(String enteredPin) async {
    final valid = await SecurityService.instance.verifyPin(enteredPin);
    if (valid) {
      widget.onSuccess();
    } else {
      setState(() => _errorText = 'Incorrect PIN');
      _pinController.clear();
    }
  }
}
