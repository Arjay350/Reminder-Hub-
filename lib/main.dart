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
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'services/password_route_observer.dart';
import 'services/widget_service.dart';
import 'services/pet_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await HiveService.instance.init();
  } catch (e) {
    debugPrint('Hive init warning: $e');
  }
  try {
    await PetService.instance.init();
  } catch (e) {
    debugPrint('Pet init warning: $e');
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
      PetService.instance.resume();
      WidgetService.instance.updateSchoolWidget();
      WidgetService.instance.updateBillsWidget();
      NotificationService.instance.rescheduleAll();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      PetService.instance.suspend();
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
      navigatorObservers: [passwordRouteObserver],
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
    // local_auth briefly moves the app to inactive while its system prompt is
    // displayed. Locking here replaces the current page with the main PIN
    // screen and interrupts password reveal. Backgrounding still locks it.
    if ((state == AppLifecycleState.paused ||
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
      RemindersScreen(key: ValueKey('reminders_$_currentIndex')),
      AIAccountsScreen(
        key: const ValueKey('ai_accounts'),
        isScreenActive: _currentIndex == 3,
      ),
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
  final FocusNode _pinFocusNode = FocusNode();
  String _errorText = '';
  bool _canCheckBiometrics = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_refreshPinIndicators);
    _initBiometricsAndPrompt();
  }

  @override
  void dispose() {
    _pinController.removeListener(_refreshPinIndicators);
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _refreshPinIndicators() {
    if (mounted) setState(() {});
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
    if (_isAuthenticating) return;
    if (mounted) setState(() => _isAuthenticating = true);
    try {
      final success = await SecurityService.instance.authenticate(
        reason: 'Scan your fingerprint to unlock Reminder Hub',
      );
      if (success && mounted) {
        widget.onSuccess();
      }
    } catch (_) {
      // Graceful fallback to PIN
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -80,
            child: _lockDecoration(
              240,
              theme.colorScheme.primary.withValues(alpha: .07),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -90,
            child: _lockDecoration(
              280,
              const Color(0xFF14B8A6).withValues(alpha: .06),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 480),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - value)),
                            child: child,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: .12,
                                ),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: .16,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: .16,
                                    ),
                                    blurRadius: 32,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.lock_rounded,
                                size: 44,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'ReminderHub Locked',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your 4-digit PIN or use Fingerprint Unlock to access offline data',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _securityPill(
                                  Icons.verified_user_outlined,
                                  'SECURE',
                                  const Color(0xFF6366F1),
                                ),
                                _securityPill(
                                  Icons.lock_outline_rounded,
                                  'PRIVATE',
                                  const Color(0xFF8B5CF6),
                                ),
                                _securityPill(
                                  Icons.phone_android_rounded,
                                  'LOCAL',
                                  const Color(0xFF14B8A6),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'ENTER YOUR PIN',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Material(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _pinFocusNode.requestFocus,
                                child: Container(
                                  height: 76,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _errorText.isNotEmpty
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(4, (index) {
                                          final filled =
                                              index < _pinController.text.length;
                                          final active =
                                              index ==
                                              _pinController.text.length;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              width: 48,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: filled
                                                    ? theme.colorScheme.primary
                                                        .withValues(alpha: .10)
                                                    : theme
                                                          .colorScheme
                                                          .surfaceContainerHighest
                                                          .withValues(
                                                            alpha: .45,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: active &&
                                                          _errorText.isEmpty
                                                      ? theme.colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: .7,
                                                          )
                                                      : theme.colorScheme
                                                          .outlineVariant,
                                                ),
                                              ),
                                              child: Center(
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  width: filled ? 13 : 11,
                                                  height: filled ? 13 : 11,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: filled
                                                        ? theme.colorScheme
                                                            .primary
                                                        : theme
                                                              .colorScheme
                                                              .outlineVariant,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      Opacity(
                                        opacity: 0.01,
                                        child: TextField(
                                          controller: _pinController,
                                          focusNode: _pinFocusNode,
                                          keyboardType: TextInputType.number,
                                          obscureText: true,
                                          maxLength: 4,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.transparent,
                                            fontSize: 1,
                                          ),
                                          cursorColor: Colors.transparent,
                                          decoration: const InputDecoration(
                                            counterText: '',
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (value) {
                                            if (_errorText.isNotEmpty) {
                                              setState(() => _errorText = '');
                                            }
                                            if (value.length == 4) {
                                              _verify(value);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: _errorText.isEmpty
                                  ? const SizedBox(height: 26)
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _errorText,
                                        key: const ValueKey('pin_error'),
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton.icon(
                                onPressed: () => _verify(_pinController.text),
                                icon: const Icon(Icons.key_rounded),
                                label: const Text(
                                  'Unlock with PIN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B5BD6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                              ),
                            ),
                            if (_canCheckBiometrics) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton.icon(
                                  onPressed: _isAuthenticating
                                      ? null
                                      : _promptBiometrics,
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(
                                      milliseconds: 180,
                                    ),
                                    child: _isAuthenticating
                                        ? SizedBox(
                                            key: const ValueKey('auth_progress'),
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme.colorScheme.primary,
                                            ),
                                          )
                                        : Icon(
                                            Icons.fingerprint_rounded,
                                            key: const ValueKey('fingerprint'),
                                            size: 24,
                                            color: theme.colorScheme.primary,
                                          ),
                                  ),
                                  label: Text(
                                    _isAuthenticating
                                        ? 'Waiting for fingerprint…'
                                        : 'Unlock with Fingerprint',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.colorScheme.primary,
                                    side: BorderSide(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: .35),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockDecoration(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _securityPill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .15)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
            color: color,
          ),
        ),
      ],
    ),
  );

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
