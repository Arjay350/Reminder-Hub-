import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/utilities/formatters.dart';
import '../../models/app_models.dart';
import '../../models/study_models.dart';
import '../../services/hive_service.dart';
import '../../services/gas_calculation_service.dart';
import '../../services/timetable_calculation_service.dart';
import '../../services/study_service.dart';
import '../../widgets/secure_action_gate.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/reminder_dialog.dart';
import '../../widgets/bill_dialog.dart';
import '../../widgets/ai_account_dialog.dart';
import '../../widgets/user_account_dialog.dart';
import '../../widgets/gas_purchase_dialog.dart';
import '../account_manager/account_manager_screen.dart';
import '../ai_accounts/ai_accounts_screen.dart';
import '../gas_tracker/gas_tracker_screen.dart';
import '../bills/bills_screen.dart';
import '../school/school_hub_screen.dart';
import '../school_schedule/school_schedule_screen.dart';
import '../study/study_dashboard_screen.dart';
import '../search/global_search_screen.dart';
import '../../widgets/quick_add_modal.dart';
import '../../widgets/school_class_dialog.dart';
import '../../widgets/whats_new_dialog.dart';
import '../../widgets/pet/pet_companion_card.dart';
import '../../services/pet_service.dart';
import '../../core/constants/app_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNavigateTab});

  final Function(int index)? onNavigateTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HiveService _hive = HiveService.instance;
  final TimetableCalculationService _timetableService =
      TimetableCalculationService.instance;

  List<Reminder> _reminders = [];
  List<SchoolClass> _schoolClasses = [];
  List<Bill> _bills = [];
  List<UserAccount> _userAccounts = [];
  List<AIAccount> _aiAccounts = [];
  List<GasPurchase> _gasPurchases = [];
  List<Birthday> _birthdays = [];
  int _todayFocusMinutes = 0;
  AppSettings? _settings;
  StudyTimerState? _activeStudyState;

  DayTimetableStatus? _dayStatus;
  Timer? _timetableUpdateTimer;
  bool _whatsNewPrompted = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _startTimetableTimer();
  }

  @override
  void dispose() {
    _timetableUpdateTimer?.cancel();
    super.dispose();
  }

  void _startTimetableTimer() {
    // Update every 30 seconds for real-time class status updates
    _timetableUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _updateTimetableStatus();
      }
    });
  }

  void _updateTimetableStatus() {
    final now = DateTime.now();
    final status = _timetableService.calculateDayStatus(_schoolClasses, now);
    if (mounted) {
      setState(() {
        _dayStatus = status;
        _aiAccounts = _hive.getAIAccounts();
        _activeStudyState = StudyService.instance.getActiveTimerState();
        final today = DateTime.now();
        _todayFocusMinutes = StudyService.instance
            .getStudyHistory()
            .where((session) => Formatters.isSameDay(session.startedAt, today))
            .fold(0, (total, session) => total + session.durationMinutes);
      });

      // Synchronize class schedule and study timer state with pet companion
      final hasActive = status.currentClasses.isNotEmpty;
      final hasNext = status.nextClass != null;
      final currentName =
          status.currentClasses.firstOrNull?.schoolClass.subject;
      final nextName = status.nextClass?.schoolClass.subject;
      PetService.instance.onClassStatusChanged(
        isClassHappening: hasActive,
        isClassUpcoming: hasNext,
        className: currentName ?? nextName,
      );

      final study = _activeStudyState;
      if (study != null) {
        PetService.instance.onStudyTimerUpdated(
          isRunning: study.isRunning,
          isBreak:
              study.phase == StudyPhase.shortBreak ||
              study.phase == StudyPhase.longBreak,
          isCompleted: study.completed,
          subject: study.subject,
        );
      }
    }
  }

  Future<void> _refreshData() async {
    await _hive.ensureInitialized();
    if (!mounted) return;
    final settings = _hive.getSettings();
    setState(() {
      _reminders = _hive.getReminders();
      _schoolClasses = _hive.getSchoolClasses();
      _bills = _hive.getBills();
      _userAccounts = _hive.getUserAccounts();
      _aiAccounts = _hive.getAIAccounts();
      _birthdays = _hive.getBirthdays();
      _activeStudyState = StudyService.instance.getActiveTimerState();
      _todayFocusMinutes = StudyService.instance
          .getStudyHistory()
          .where(
            (session) =>
                Formatters.isSameDay(session.startedAt, DateTime.now()),
          )
          .fold(0, (total, session) => total + session.durationMinutes);
      _gasPurchases = _hive.getGasPurchases();
      _settings = settings;
    });
    _updateTimetableStatus();
    PetService.instance.checkUpcomingEvents(
      reminders: _reminders,
      bills: _bills,
      birthdays: _birthdays,
    );

    // Check first-time setup for name
    if (!settings.nameSetupCompleted &&
        (settings.userName.isEmpty || settings.userName == 'User')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFirstTimeNameDialog();
      });
    } else if (!_whatsNewPrompted &&
        _hive.shouldShowWhatsNew(AppConstants.appVersion)) {
      _whatsNewPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWhatsNewDialog();
      });
    }
  }

  Future<void> _showWhatsNewDialog() async {
    if (!mounted) return;
    final release = WhatsNewRegistry.getRelease(AppConstants.appVersion);
    if (release == null) return;
    await WhatsNewDialog.show(
      context,
      release: release,
      onDismissed: () async {
        await _hive.setLastSeenWhatsNewVersion(AppConstants.appVersion);
      },
    );
  }

  Future<void> _showFirstTimeNameDialog() async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF141A2E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.waving_hand_rounded,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Welcome to Reminder Hub!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'What should we call you?',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'e.g. Junjifil',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final enteredName = controller.text.trim();
                    final finalName = enteredName.isNotEmpty
                        ? enteredName
                        : 'User';
                    final current = _hive.getSettings();
                    final updated = current.copyWith(
                      userName: finalName,
                      nameSetupCompleted: true,
                      lastSeenWhatsNewVersion: AppConstants.appVersion,
                    );
                    await _hive.saveSettings(updated);
                    await _hive.setLastSeenWhatsNewVersion(
                      AppConstants.appVersion,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    _refreshData();
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardClassHero(
    BuildContext context,
    DayTimetableStatus dayStatus,
  ) {
    final currentClass = dayStatus.currentClasses.firstOrNull;
    final nextClass = dayStatus.nextClass;
    final featuredClass = currentClass?.schoolClass ?? nextClass?.schoolClass;
    final isCurrent = currentClass != null;
    final finishedForToday =
        featuredClass == null && dayStatus.classes.isNotEmpty;
    final isFreeDay = dayStatus.classes.isEmpty;
    final accent = featuredClass?.color ?? const Color(0xFF14B8A6);
    final startLabel = featuredClass?.startTime ?? '';
    final endLabel = featuredClass?.endTime ?? '';
    final countdown = isCurrent
        ? currentClass.timeRemainingFormatted
        : nextClass?.timeUntilStartFormatted;
    final statusLabel = isCurrent
        ? 'HAPPENING NOW'
        : finishedForToday
        ? 'DAY COMPLETE'
        : isFreeDay
        ? 'NO CLASSES TODAY'
        : 'UP NEXT';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SchoolHubScreen()))
            .then((_) => _refreshData()),
        child: Ink(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(accent, const Color(0xFF111827), .48)!,
                Color.lerp(accent, const Color(0xFF0F172A), .72)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCurrent
                              ? Icons.circle
                              : isFreeDay
                              ? Icons.celebration_outlined
                              : Icons.schedule_rounded,
                          size: 9,
                          color: isCurrent
                              ? const Color(0xFF86EFAC)
                              : Colors.white,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          statusLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: .8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${dayStatus.classes.length} ${dayStatus.classes.length == 1 ? 'CLASS' : 'CLASSES'} TODAY',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (featuredClass != null) ...[
                Text(
                  isCurrent ? 'Your current class' : 'Coming up next',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .74),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  featuredClass.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (featuredClass.courseCode.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    featuredClass.courseCode,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroDetailChip(
                      Icons.access_time_rounded,
                      '$startLabel – $endLabel',
                    ),
                    if (featuredClass.room.isNotEmpty)
                      _heroDetailChip(
                        Icons.meeting_room_outlined,
                        featuredClass.room,
                      ),
                    if (featuredClass.teacher.isNotEmpty)
                      _heroDetailChip(
                        Icons.person_outline_rounded,
                        featuredClass.teacher,
                      ),
                  ],
                ),
                if (countdown?.isNotEmpty == true) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(
                        Icons.hourglass_bottom_rounded,
                        color: Color(0xFFBFDBFE),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCurrent
                            ? '$countdown remaining'
                            : 'Starts in $countdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                Text(
                  finishedForToday
                      ? 'Classes wrapped for today'
                      : 'No classes today',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  finishedForToday
                      ? dayStatus.nextDayClass == null
                            ? 'You’ve made it through today’s schedule.'
                            : 'Next on your timetable: ${dayStatus.nextDayClass!.schoolClass.subject} at ${dayStatus.nextDayClass!.schoolClass.startTime}.'
                      : 'Enjoy the open space in your schedule or plan a focus session.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .78),
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    'OPEN SCHOOL HUB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: .7,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingBirthdaysCard(
    BuildContext context,
    List<Birthday> birthdays,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final upcoming =
        birthdays.where((birthday) => birthday.daysUntilNext <= 14).toList()
          ..sort((a, b) => a.daysUntilNext.compareTo(b.daysUntilNext));

    if (upcoming.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151F34) : const Color(0xFFFFF1F6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF472B6).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cake_rounded, color: Color(0xFFF472B6)),
              const SizedBox(width: 8),
              Text(
                'Upcoming Birthdays',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...upcoming.take(3).map((birthday) {
            final days = birthday.daysUntilNext;
            String badge;
            if (days == 0) {
              badge = birthday.turningAge == null
                  ? '🎂 Today'
                  : '🎂 Today · Turns ${birthday.turningAge}';
            } else if (days == 1) {
              badge = birthday.turningAge == null
                  ? '🎂 Tomorrow'
                  : '🎂 Tomorrow · Turns ${birthday.turningAge}';
            } else {
              badge = birthday.turningAge == null
                  ? '🎉 In $days days'
                  : '🎉 In $days days · Turns ${birthday.turningAge}';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          birthday.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (birthday.relationship.isNotEmpty)
                          Text(
                            birthday.relationship,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9A8D4).withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Color(0xFFBE185D),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _heroDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: .85), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingReminder(BuildContext context, Reminder? reminder) {
    final theme = Theme.of(context);
    if (reminder == null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const ReminderDialog(),
            );
            _refreshData();
          },
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: .45,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'You’re all caught up. Tap to add a reminder.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.add_rounded),
              ],
            ),
          ),
        ),
      );
    }

    final priorityColor = reminder.priority == 'High'
        ? Colors.red
        : reminder.priority == 'Medium'
        ? Colors.orange
        : Colors.blue;
    final dueAt = _reminderDueAt(reminder);
    final dueLabel = Formatters.isSameDay(dueAt, DateTime.now())
        ? 'TODAY · ${reminder.time}'
        : '${Formatters.formatShortDate(reminder.date)} · ${reminder.time}';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onNavigateTab?.call(2),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: reminder.categoryColor.withValues(alpha: .22),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Row(
              key: ValueKey(reminder.id),
              children: [
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    color: reminder.categoryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: reminder.categoryColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    reminder.categoryIcon,
                    color: reminder.categoryColor,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dueLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    reminder.priority,
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DateTime _reminderDueAt(Reminder reminder) {
    final cleaned = reminder.time.trim().toUpperCase();
    final isPm = cleaned.contains('PM');
    final isAm = cleaned.contains('AM');
    final parts = cleaned
        .replaceAll('AM', '')
        .replaceAll('PM', '')
        .trim()
        .split(':');
    var hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;
    return DateTime(
      reminder.date.year,
      reminder.date.month,
      reminder.date.day,
      hour,
      minute,
    );
  }

  Widget _buildFocusPanel(BuildContext context) {
    final state = _activeStudyState;
    final theme = Theme.of(context);
    final color = state == null
        ? const Color(0xFF6366F1)
        : studyPhaseColor(state.phase);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context)
            .push(
              MaterialPageRoute(builder: (_) => const StudyDashboardScreen()),
            )
            .then((_) => _refreshData()),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: .22)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: state == null || state.completed
                          ? 0
                          : (1 -
                                    state.remainingSeconds /
                                        (state.phase == StudyPhase.study
                                            ? state
                                                      .method
                                                      .studyDurationMinutes *
                                                  60
                                            : state.phase ==
                                                  StudyPhase.shortBreak
                                            ? state
                                                      .method
                                                      .shortBreakDurationMinutes *
                                                  60
                                            : state
                                                      .method
                                                      .longBreakDurationMinutes *
                                                  60))
                                .clamp(0.0, 1.0),
                      strokeWidth: 4,
                      backgroundColor: color.withValues(alpha: .12),
                      color: color,
                    ),
                    Icon(
                      state?.isRunning == true
                          ? Icons.bolt_rounded
                          : Icons.self_improvement_rounded,
                      color: color,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state?.isRunning == true ? 'FOCUS IN PROGRESS' : 'FOCUS',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state == null ? 'Ready to focus?' : state.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      state == null
                          ? '$_todayFocusMinutes min completed today'
                          : '${formatStudyClock(state.remainingDuration)} left · ${buildStudyPhaseText(state.phase)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIResetsSection(BuildContext context) {
    final resetsByProvider = <String, List<AIAccount>>{};
    for (final account in _aiAccounts) {
      resetsByProvider.putIfAbsent(account.service, () => []).add(account);
    }
    final providers = resetsByProvider.keys.toList()..sort();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.smart_toy_rounded,
                  size: 20,
                  color: Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Resets',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(builder: (_) => const AIAccountsScreen()),
                  )
                  .then((_) => _refreshData()),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (providers.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('No AI accounts'),
              subtitle: const Text(
                'Add accounts to track reset schedules and cooldowns',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(builder: (_) => const AIAccountsScreen()),
                  )
                  .then((_) => _refreshData()),
            ),
          ),
        ...providers.map((provider) {
          final accounts = resetsByProvider[provider]!;
          final activeAccounts = accounts
              .where((a) => a.currentResetStatus == 'Active')
              .toList();
          final cooldownAccounts = accounts
              .where((a) => a.currentResetStatus == 'Cooldown')
              .toList();
          final label = provider == 'GitHub Copilot' ? 'Copilot' : provider;

          String statusSubtitle;
          if (activeAccounts.isNotEmpty && cooldownAccounts.isNotEmpty) {
            statusSubtitle =
                '${activeAccounts.length} Active · ${cooldownAccounts.length} Cooldown';
          } else if (activeAccounts.isNotEmpty) {
            statusSubtitle =
                '${activeAccounts.length} Active · ${activeAccounts.map((a) => a.accountName).join(', ')}';
          } else {
            statusSubtitle =
                '${cooldownAccounts.length} Cooldown · ${cooldownAccounts.map((a) => a.accountName).join(', ')}';
          }

          final hasActive = activeAccounts.isNotEmpty;

          return Card(
            child: ListTile(
              leading: Icon(
                Icons.smart_toy_outlined,
                color: accounts.first.serviceColor,
              ),
              title: Text(label),
              subtitle: Text(
                statusSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasActive
                      ? const Color(0xFF31A24C)
                      : (isDark
                            ? Colors.amber.shade300
                            : Colors.amber.shade800),
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (activeAccounts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF31A24C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${activeAccounts.length} Active',
                        style: const TextStyle(
                          color: Color(0xFF31A24C),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (cooldownAccounts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(
                          alpha: isDark ? 0.2 : 0.15,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${cooldownAccounts.length} Cooldown',
                        style: TextStyle(
                          color: isDark
                              ? Colors.amber.shade200
                              : Colors.amber.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AIAccountsScreen(initialService: provider),
                    ),
                  )
                  .then((_) => _refreshData()),
            ),
          );
        }),
        const SizedBox(height: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final dayStatus =
        _dayStatus ?? _timetableService.calculateDayStatus(_schoolClasses, now);

    final todayReminders = _reminders
        .where((r) => Formatters.isSameDay(r.date, now))
        .toList();
    final overdueReminders = _reminders
        .where(
          (r) =>
              !r.completed &&
              r.date.isBefore(now) &&
              !Formatters.isSameDay(r.date, now),
        )
        .toList();
    final upcomingBills = _bills.where((b) => !b.paid).toList();
    final billsDueSoon = upcomingBills.where((bill) {
      final due = bill.getDisplayDueDate();
      return !due.isBefore(DateTime(now.year, now.month, now.day)) &&
          due.isBefore(DateTime(now.year, now.month, now.day + 8));
    }).length;
    final pendingTodayReminders = todayReminders
        .where((reminder) => !reminder.completed)
        .length;
    final todayClassCount = dayStatus.classes.length;
    final futureReminders =
        _reminders
            .where(
              (reminder) =>
                  !reminder.completed && _reminderDueAt(reminder).isAfter(now),
            )
            .toList()
          ..sort((a, b) => _reminderDueAt(a).compareTo(_reminderDueAt(b)));
    final nextReminder = futureReminders.firstOrNull;

    final todayDay = DateTime(now.year, now.month, now.day);
    final latestGas = _gasPurchases.where((purchase) {
      final purchaseDay = DateTime(
        purchase.purchaseDate.year,
        purchase.purchaseDate.month,
        purchase.purchaseDate.day,
      );
      return !purchaseDay.isAfter(todayDay);
    }).firstOrNull;
    final userName = _settings?.userName ?? 'User';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final profileImagePath = _settings?.profileImagePath ?? '';
    final hasCustomImage =
        profileImagePath.isNotEmpty && File(profileImagePath).existsSync();

    int? lastTankDuration;
    final completedPurchases = _gasPurchases.where((purchase) {
      final purchaseDay = DateTime(
        purchase.purchaseDate.year,
        purchase.purchaseDate.month,
        purchase.purchaseDate.day,
      );
      return !purchaseDay.isAfter(todayDay);
    }).toList();
    if (completedPurchases.length >= 2) {
      lastTankDuration = GasCalculationService.calculateCompletedTankDuration(
        completedPurchases[1].purchaseDate,
        completedPurchases[0].purchaseDate,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          edgeOffset: 10,
          color: theme.colorScheme.primary,
          child: AnimationLimiter(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  horizontalOffset: 30.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: [
                  // Premium Header Row with Avatar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => widget.onNavigateTab?.call(
                                4,
                              ), // Navigate to Settings/Profile
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: hasCustomImage
                                      ? null
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF8B5CF6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF6366F1,
                                      ).withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: hasCustomImage
                                      ? Image.file(
                                          File(profileImagePath),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Center(
                                                    child: Text(
                                                      userInitial,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                        )
                                      : Center(
                                          child: Text(
                                            userInitial,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getGreeting(userName),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _getGreetingIcon(),
                                      size: 15,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade700,
                                    ),
                                  ],
                                ),
                                Text(
                                  'Reminder Hub',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                    fontSize: 22,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GlobalSearchScreen(),
                            ),
                          ).then((_) => _refreshData());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Local Pet Companion
                  const PetCompanionCard(),

                  const SizedBox(height: 18),
                  _buildUpcomingBirthdaysCard(context, _birthdays),
                  const SizedBox(height: 18),

                  Text(
                    'Your day at a glance',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDashboardClassHero(context, dayStatus),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today at a glance',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        Formatters.formatShortDate(now),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _overviewMetric(
                            width: width,
                            label: 'Classes today',
                            value: '$todayClassCount',
                            icon: Icons.school_outlined,
                            color: const Color(0xFF14B8A6),
                            onTap: () => Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => const SchoolHubScreen(),
                                  ),
                                )
                                .then((_) => _refreshData()),
                          ),
                          _overviewMetric(
                            width: width,
                            label: 'Bills due soon',
                            value: '$billsDueSoon',
                            icon: Icons.receipt_long_outlined,
                            color: const Color(0xFFF59E0B),
                            onTap: () => Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => const BillsScreen(),
                                  ),
                                )
                                .then((_) => _refreshData()),
                          ),
                          _overviewMetric(
                            width: width,
                            label: 'Reminders due',
                            value: '$pendingTodayReminders',
                            icon: Icons.notifications_active_outlined,
                            color: const Color(0xFF6366F1),
                            onTap: () => widget.onNavigateTab?.call(2),
                          ),
                          _overviewMetric(
                            width: width,
                            label: 'Focus today',
                            value: _todayFocusMinutes < 60
                                ? '${_todayFocusMinutes}m'
                                : '${_todayFocusMinutes ~/ 60}h ${_todayFocusMinutes % 60}m',
                            icon: Icons.timer_outlined,
                            color: const Color(0xFF8B5CF6),
                            onTap: () => Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const StudyDashboardScreen(),
                                  ),
                                )
                                .then((_) => _refreshData()),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Up next',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateTab?.call(2),
                        child: const Text('All reminders'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildUpcomingReminder(context, nextReminder),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Focus',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => const StudyDashboardScreen(),
                              ),
                            )
                            .then((_) => _refreshData()),
                        child: const Text('Open timer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildFocusPanel(context),
                  const SizedBox(height: 16),
                  _buildAIResetsSection(context),
                  const SizedBox(height: 8),

                  // Quick Actions Section
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _quickActionButton(
                          context,
                          label: 'Add Reminder',
                          icon: Icons.add_alert_rounded,
                          color: const Color(0xFF6366F1),
                          onTap: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const ReminderDialog(),
                            );
                            _refreshData();
                          },
                        ),
                        const SizedBox(width: 10),
                        _quickActionButton(
                          context,
                          label: 'Class Schedule',
                          icon: Icons.school_rounded,
                          color: const Color(0xFF14B8A6),
                          onTap: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const SchoolClassDialog(),
                            );
                            _refreshData();
                          },
                        ),
                        const SizedBox(width: 10),
                        _quickActionButton(
                          context,
                          label: 'Add Bill',
                          icon: Icons.receipt_long,
                          color: const Color(0xFF10B981),
                          onTap: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const BillDialog(),
                            );
                            _refreshData();
                          },
                        ),
                        const SizedBox(width: 10),
                        _quickActionButton(
                          context,
                          label: 'AI Reset',
                          icon: Icons.smart_toy,
                          color: const Color(0xFF8B5CF6),
                          onTap: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const AIAccountDialog(),
                            );
                            _refreshData();
                          },
                        ),
                        const SizedBox(width: 10),
                        _quickActionButton(
                          context,
                          label: 'Login Account',
                          icon: Icons.lock_outline,
                          color: const Color(0xFFF59E0B),
                          onTap: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const UserAccountDialog(),
                            );
                            _refreshData();
                          },
                        ),
                        const SizedBox(width: 10),
                        _quickActionButton(
                          context,
                          label: 'LPG Order',
                          icon: Icons.propane_tank_rounded,
                          color: const Color(0xFFEF4444),
                          onTap: () async {
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const GasPurchaseDialog(),
                            );
                            _refreshData();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Today's Classes Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Today\'s Classes',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SchoolScheduleScreen(),
                            ),
                          ).then((_) => _refreshData());
                        },
                        child: const Text('View Schedule'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final classStatus =
                          _dayStatus ??
                          _timetableService.calculateDayStatus(
                            _schoolClasses,
                            now,
                          );
                      final transitionKey = [
                        ...classStatus.currentClasses.map(
                          (item) => 'current:${item.schoolClass.id}',
                        ),
                        if (classStatus.nextClass != null)
                          'next:${classStatus.nextClass!.schoolClass.id}',
                        if (classStatus.hasNoMoreClasses) 'done',
                      ].join('|');
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, .035),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(transitionKey),
                          child: _buildTodaysClassesCard(
                            context,
                            _schoolClasses,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 26),

                  // Cooking LPG Status Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 20,
                            color: Color(0xFFF97316),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Household LPG Status',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GasTrackerScreen(),
                            ),
                          ).then((_) => _refreshData());
                        },
                        child: const Text('Open Tracker'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildLpgStatusCard(context, latestGas, lastTankDuration),
                  const SizedBox(height: 26),

                  // Modules & Hubs
                  Text(
                    'Modules & Hubs',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _moduleCard(
                          context,
                          title: 'School Hub',
                          subtitle: '${_schoolClasses.length} class schedules',
                          icon: Icons.school_rounded,
                          color: const Color(0xFF14B8A6),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SchoolHubScreen(),
                              ),
                            ).then((_) => _refreshData());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _moduleCard(
                          context,
                          title: 'Bills Tracker',
                          subtitle: '${upcomingBills.length} due soon',
                          icon: Icons.receipt_long,
                          color: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BillsScreen(),
                              ),
                            ).then((_) => _refreshData());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _moduleCard(
                          context,
                          title: 'Account Manager',
                          subtitle: '${_userAccounts.length} saved logins',
                          icon: Icons.lock_outline,
                          color: const Color(0xFFF59E0B),
                          onTap: () async {
                            final authenticated = await showSecureActionGate(
                              context,
                              title: 'Unlock Account Manager',
                              message:
                                  'Enter your PIN or use fingerprint to continue.',
                            );
                            if (!authenticated || !context.mounted) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AccountManagerScreen(),
                              ),
                            );
                            _refreshData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _moduleCard(
                          context,
                          title: 'LPG Gas Tracker',
                          subtitle: latestGas != null
                              ? 'Active: ${latestGas.tankSize}'
                              : 'No orders logged',
                          icon: Icons.propane_tank_rounded,
                          color: const Color(0xFFEF4444),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GasTrackerScreen(),
                              ),
                            ).then((_) => _refreshData());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  // Overdue Alerts
                  if (overdueReminders.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          'Overdue Reminders',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...overdueReminders.map(
                      (r) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Card(
                          color: isDark
                              ? const Color(0xFF28181E)
                              : const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: Colors.red.withValues(alpha: 0.2),
                              width: 1.2,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              r.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              '${r.category} • Overdue ${Formatters.formatShortDate(r.date)}',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Transform.scale(
                              scale: 0.9,
                              child: Checkbox(
                                value: r.completed,
                                activeColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: (val) async {
                                  final isDone = val ?? false;
                                  final updated = r.copyWith(completed: isDone);
                                  await _hive.saveReminder(updated);
                                  if (isDone) {
                                    PetService.instance.onReminderCompleted(
                                      updated,
                                    );
                                  }
                                  _refreshData();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const QuickAddModal(),
          );
          _refreshData();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quick Add'),
      ),
    );
  }

  Widget _overviewMetric({
    required double width,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? .12 : .07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: .16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, .12),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          value,
                          key: ValueKey(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomCard(
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysClassesCard(
    BuildContext context,
    List<SchoolClass> classes,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    // Use the calculated day status if available, otherwise compute it
    final dayStatus =
        _dayStatus ?? _timetableService.calculateDayStatus(classes, now);

    // If no classes today
    if (dayStatus.classes.isEmpty) {
      return CustomCard(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_outlined, color: Color(0xFF14B8A6)),
          ),
          title: const Text(
            'No classes today',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: dayStatus.nextDayClass != null
              ? Text(
                  'Next class: ${dayStatus.nextDayClass!.schoolClass.subject} at ${dayStatus.nextDayClass!.schoolClass.startTime}',
                )
              : const Text('Enjoy your free day or check your full timetable.'),
          trailing: const Icon(Icons.add, size: 20),
          onTap: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const SchoolClassDialog(),
            );
            _refreshData();
          },
        ),
      );
    }

    // Build the main class status card
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Class(es) section
          if (dayStatus.currentClasses.isNotEmpty) ...[
            ...dayStatus.currentClasses.map(
              (cs) => _buildCurrentClassCard(cs, dayStatus, isDark),
            ),
            if (dayStatus.nextClass != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
            ],
          ],

          // Next Class section
          if (dayStatus.nextClass != null && dayStatus.currentClasses.isEmpty)
            _buildNextClassCard(dayStatus.nextClass!, isDark)
          else if (dayStatus.nextClass != null)
            _buildNextClassCard(dayStatus.nextClass!, isDark, compact: true),

          // No more classes today section
          if (dayStatus.hasNoMoreClasses &&
              dayStatus.currentClasses.isEmpty &&
              dayStatus.nextClass == null)
            _buildNoMoreClassesCard(dayStatus, isDark),

          // Other classes today section
          if (dayStatus.classes.length >
              (dayStatus.currentClasses.length +
                  (dayStatus.nextClass != null ? 1 : 0))) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _buildOtherClassesList(dayStatus, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentClassCard(
    ClassStatus cs,
    DayTimetableStatus dayStatus,
    bool isDark,
  ) {
    final c = cs.schoolClass;
    final timeRemaining = cs.timeRemainingFormatted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.green,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CURRENT CLASS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c.timeRange,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (timeRemaining.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ends in $timeRemaining',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (c.room.isNotEmpty || c.teacher.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (c.room.isNotEmpty) ...[
                Icon(
                  Icons.meeting_room_outlined,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Room: ${c.room}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (c.teacher.isNotEmpty) ...[
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Teacher: ${c.teacher}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ],
        if (dayStatus.currentClasses.length > 1) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  'Multiple classes in progress (${dayStatus.currentClasses.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNextClassCard(
    ClassStatus cs,
    bool isDark, {
    bool compact = false,
  }) {
    final c = cs.schoolClass;
    final timeUntilStart = cs.timeUntilStartFormatted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: Color(0xFF8B5CF6),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF8B5CF6,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NEXT CLASS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c.timeRange,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (timeUntilStart.isNotEmpty && !compact) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Starts in $timeUntilStart',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (!compact && (c.room.isNotEmpty || c.teacher.isNotEmpty)) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (c.room.isNotEmpty) ...[
                Icon(
                  Icons.meeting_room_outlined,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Room: ${c.room}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (c.teacher.isNotEmpty) ...[
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Teacher: ${c.teacher}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNoMoreClassesCard(DayTimetableStatus dayStatus, bool isDark) {
    final todayWeekday = dayStatus.weekday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NO MORE CLASSES TODAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All done for ${TimetableCalculationService.getDayName(todayWeekday)}!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (dayStatus.nextDayClass != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Color(0xFF14B8A6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next class: ${TimetableCalculationService.getDayName((todayWeekday % 7) + 1, short: true)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF14B8A6),
                        ),
                      ),
                      Text(
                        '${dayStatus.nextDayClass!.schoolClass.subject} • ${dayStatus.nextDayClass!.schoolClass.startTime}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOtherClassesList(DayTimetableStatus dayStatus, bool isDark) {
    // Get classes that aren't current or next
    final otherClasses = dayStatus.classes
        .where(
          (cs) =>
              cs.status == ClassState.upcoming ||
              cs.status == ClassState.completed,
        )
        .skip(dayStatus.nextClass != null ? 1 : 0)
        .toList();

    if (otherClasses.isEmpty) return const SizedBox.shrink();

    final dayName = TimetableCalculationService.getDayName(dayStatus.weekday);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Other classes $dayName (${otherClasses.length}):',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        ...otherClasses.map(
          (cs) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Icon(
                  cs.status == ClassState.completed
                      ? Icons.check_circle
                      : Icons.circle,
                  size: 6,
                  color: cs.status == ClassState.completed
                      ? Colors.green
                      : cs.schoolClass.color,
                ),
                const SizedBox(width: 8),
                Text(
                  '${cs.schoolClass.startTime} - ${cs.schoolClass.subject}${cs.schoolClass.room.isNotEmpty ? " (${cs.schoolClass.room})" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.status == ClassState.completed
                        ? Colors.green
                        : (isDark ? Colors.grey.shade300 : Colors.black87),
                    fontWeight: cs.status == ClassState.completed
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLpgStatusCard(
    BuildContext context,
    GasPurchase? latestGas,
    int? lastTankDuration,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (latestGas == null) {
      return CustomCard(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.propane_tank_rounded, color: Colors.red),
          ),
          title: const Text(
            'No LPG orders yet',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Record your first order to start tracking lifespan.',
          ),
          trailing: const Icon(Icons.add, size: 20),
          onTap: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const GasPurchaseDialog(),
            );
            _refreshData();
          },
        ),
      );
    }

    final daysInUse = GasCalculationService.calculateActiveTankDays(
      latestGas.purchaseDate,
    );

    return CustomCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.propane_tank_rounded,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LPG Tank Size: ${latestGas.tankSize}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ordered: ${Formatters.formatDate(latestGas.purchaseDate)}',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'In Use: $daysInUse ${daysInUse == 1 ? 'day' : 'days'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          if (lastTankDuration != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.history, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Last tank lasted $lastTankDuration days',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getGreeting(String name) {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, $name';
    if (hour < 18) return 'Good afternoon, $name';
    return 'Good evening, $name';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 18) return Icons.wb_sunny_outlined;
    return Icons.nights_stay_rounded;
  }
}
