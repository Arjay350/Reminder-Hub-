import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../models/study_models.dart';
import '../../services/hive_service.dart';
import '../../services/study_service.dart';
import '../../services/timetable_calculation_service.dart';
import '../../widgets/custom_card.dart';
import '../school_schedule/school_schedule_screen.dart';
import '../study/study_dashboard_screen.dart';
import '../../services/pet_service.dart';

class SchoolHubScreen extends StatefulWidget {
  const SchoolHubScreen({super.key});

  @override
  State<SchoolHubScreen> createState() => _SchoolHubScreenState();
}

class _SchoolHubScreenState extends State<SchoolHubScreen> {
  final _hive = HiveService.instance;
  final _study = StudyService.instance;
  final _timetable = TimetableCalculationService.instance;
  List<SchoolClass> _classes = [];
  DayTimetableStatus? _today;
  StudyTimerState? _activeTimer;
  int _todayMinutes = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _hive.ensureInitialized();
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _classes = _hive.getSchoolClasses();
      _today = _timetable.calculateDayStatus(_classes, now);
      _activeTimer = _study.getActiveTimerState();
      _todayMinutes = _study
          .calculateStatistics(now: now)
          .totalStudyMinutesToday;
    });

    PetService.instance.onScheduleChecked();
    PetService.instance.checkUpcomingEvents(schoolClasses: _classes);
    final today = _today;
    if (today != null &&
        today.classes.isNotEmpty &&
        today.currentClasses.isEmpty &&
        today.nextClass == null) {
      PetService.instance.recordTaskProgress('school_all', count: 1, setDirect: true);
    }
  }

  Future<void> _openSchedule() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SchoolScheduleScreen()));
    await _loadData();
  }

  Future<void> _openStudyTimer() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StudyDashboardScreen()));
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today =
        _today ?? _timetable.calculateDayStatus(_classes, DateTime.now());
    final current = today.currentClasses.firstOrNull;
    final next = today.nextClass;
    final featured = current?.schoolClass ?? next?.schoolClass;
    final isRunning = _activeTimer?.isRunning == true;

    return Scaffold(
      appBar: AppBar(title: const Text('School Hub')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'YOUR SCHOOL DAY',
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF14B8A6),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${TimetableCalculationService.getDayName(DateTime.now().weekday)}, ${_formatDate(DateTime.now())}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            _buildClassHero(context, today, featured, current, next),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Focus today',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _todayMinutes < 60
                      ? '${_todayMinutes}m logged'
                      : '${_todayMinutes ~/ 60}h ${_todayMinutes % 60}m logged',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildFocusPanel(context, isRunning),
            const SizedBox(height: 26),
            Text(
              'Your tools',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildToolRow(
              context,
              color: const Color(0xFF14B8A6),
              icon: Icons.calendar_month_rounded,
              title: 'School Schedule',
              subtitle: 'Browse the week, switch days, manage classes',
              trailing: '${_classes.length} classes',
              onTap: _openSchedule,
            ),
            const SizedBox(height: 10),
            _buildToolRow(
              context,
              color: const Color(0xFF6366F1),
              icon: Icons.timer_rounded,
              title: 'Study Timer',
              subtitle: 'Pomodoro, focus methods, and recent sessions',
              trailing: isRunning ? 'In progress' : 'Start a session',
              onTap: _openStudyTimer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassHero(
    BuildContext context,
    DayTimetableStatus today,
    SchoolClass? featured,
    ClassStatus? current,
    ClassStatus? next,
  ) {
    final isCurrent = current != null;
    final noClasses = today.classes.isEmpty;
    final finished = !noClasses && featured == null;
    final accent = featured?.color ?? const Color(0xFF14B8A6);
    final theme = Theme.of(context);
    final timeUntil = isCurrent
        ? current.timeRemainingFormatted
        : next?.timeUntilStartFormatted;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: _openSchedule,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(20),
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
                children: [
                  Icon(
                    isCurrent
                        ? Icons.circle
                        : noClasses
                        ? Icons.celebration_outlined
                        : Icons.schedule_rounded,
                    color: Colors.white,
                    size: isCurrent ? 10 : 17,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCurrent
                        ? 'NOW'
                        : finished
                        ? 'SCHEDULE COMPLETE'
                        : noClasses
                        ? 'FREE DAY'
                        : 'UP NEXT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${today.classes.length} ${today.classes.length == 1 ? 'CLASS' : 'CLASSES'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (featured != null) ...[
                Text(
                  featured.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (featured.courseCode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    featured.courseCode,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .76),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _detailChip(Icons.access_time_rounded, featured.timeRange),
                    if (featured.room.isNotEmpty)
                      _detailChip(Icons.meeting_room_outlined, featured.room),
                    if (featured.teacher.isNotEmpty)
                      _detailChip(Icons.person_outline, featured.teacher),
                  ],
                ),
                if (timeUntil?.isNotEmpty == true) ...[
                  const SizedBox(height: 18),
                  Text(
                    isCurrent ? '$timeUntil remaining' : 'Starts in $timeUntil',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  finished
                      ? 'You’ve made it through today.'
                      : 'No classes today',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  finished && today.nextDayClass != null
                      ? 'Next on your timetable: ${today.nextDayClass!.schoolClass.subject}.'
                      : 'Enjoy the open space in your schedule.',
                  style: TextStyle(color: Colors.white.withValues(alpha: .78)),
                ),
              ],
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'OPEN TIMETABLE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

  Widget _buildFocusPanel(BuildContext context, bool isRunning) {
    final theme = Theme.of(context);
    final active = _activeTimer;
    return CustomCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      onTap: _openStudyTimer,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.self_improvement_rounded,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRunning ? 'FOCUS IN PROGRESS' : 'READY TO FOCUS?',
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active?.subject ?? 'Make a little space to study',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  active == null
                      ? '$_todayMinutes minutes completed today'
                      : '${formatStudyClock(active.remainingDuration)} left · ${buildStudyPhaseText(active.phase)}',
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
          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildToolRow(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return CustomCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 15),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: .86)),
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
