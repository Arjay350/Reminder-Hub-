import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/study_models.dart';
import '../../services/study_service.dart';
import '../../services/pet_service.dart';

class StudyDashboardScreen extends StatefulWidget {
  const StudyDashboardScreen({super.key});

  @override
  State<StudyDashboardScreen> createState() => _StudyDashboardScreenState();
}

class _StudyDashboardScreenState extends State<StudyDashboardScreen> {
  final StudyService _studyService = StudyService.instance;
  StudyTimerState? _activeState;
  final List<StudySessionRecord> _recentHistory = [];
  List<String> _subjects = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadData();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final active = _studyService.getActiveTimerState();
    final history = _studyService.getStudyHistory();
    final subjects = _studyService.getStudySubjects();
    if (!mounted) return;
    setState(() {
      _activeState = active;
      _recentHistory.clear();
      _recentHistory.addAll(history.reversed.take(4));
      _subjects = subjects;
    });
  }

  String get _todayMinutes {
    final stats = _studyService.calculateStatistics();
    return formatStudyDuration(stats.totalStudyMinutesToday);
  }

  Future<void> _openStudyTimer([String? subject]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudyTimerScreen(initialSubject: subject),
      ),
    );
    await _loadData();
  }

  Future<void> _addSubject() async {
    final controller = TextEditingController();
    final subject = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Study Subject'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Mathematics'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || subject == null || subject.trim().isEmpty) return;
    await _studyService.saveStudySubject(subject);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _studyService.calculateStatistics();
    final active = _activeState;
    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFocusHero(context, active),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: .55,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _statMetric(
                      'Sessions',
                      '${stats.totalSessions}',
                      Icons.bolt_rounded,
                    ),
                    _statDivider(context),
                    _statMetric(
                      'Streak',
                      '${stats.currentStreak}d',
                      Icons.local_fire_department_outlined,
                    ),
                    _statDivider(context),
                    _statMetric(
                      'Average',
                      formatStudyDuration(stats.averageSessionDurationMinutes),
                      Icons.av_timer_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subjects',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSubject,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              if (_subjects.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: .48,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.menu_book_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No subjects yet. Add one or create a class in School Schedule.',
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: _subjects
                      .map(
                        (subject) => ActionChip(
                          avatar: const Icon(
                            Icons.menu_book_rounded,
                            size: 17,
                            color: Color(0xFF6366F1),
                          ),
                          label: Text(subject),
                          onPressed: () => _openStudyTimer(subject),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: .16),
                            ),
                          ),
                          backgroundColor: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: .07),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent sessions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_todayMinutes today',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_recentHistory.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: .48,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.spa_outlined, color: Color(0xFF6366F1)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your completed focus sessions will show up here.',
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._recentHistory.asMap().entries.map(
                  (entry) => _buildSessionRow(
                    context,
                    entry.value,
                    isLast: entry.key == _recentHistory.length - 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusHero(BuildContext context, StudyTimerState? active) {
    final theme = Theme.of(context);
    final isRunning = active?.isRunning == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF6366F1)],
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
              const Text(
                'FOCUS FOR TODAY',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  active == null
                      ? 'LOCAL TIMER'
                      : isRunning
                      ? buildStudyPhaseText(active.phase).toUpperCase()
                      : 'PAUSED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            active == null
                ? _todayMinutes
                : formatStudyClock(active.remainingDuration),
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          Text(
            active == null
                ? 'focused today'
                : '${active.subject} · ${active.isRunning ? 'Stay focused' : 'Session paused'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: .82)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openStudyTimer,
              icon: Icon(
                active != null
                    ? Icons.open_in_full_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                active != null ? 'Continue session' : 'Start focus session',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4338CA),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider(BuildContext context) => Container(
    width: 1,
    height: 36,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .6),
  );

  Widget _buildSessionRow(
    BuildContext context,
    StudySessionRecord session, {
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.subject,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${session.methodName} · ${formatStudyDuration(session.durationMinutes)} · ${session.completedSessions} sessions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '${session.endedAt.hour.toString().padLeft(2, '0')}:${session.endedAt.minute.toString().padLeft(2, '0')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key, this.initialSubject});

  final String? initialSubject;

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  final StudyService _studyService = StudyService.instance;
  StudyTimerState? _state;
  StudyMethod? _selectedMethod;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _focusMinutesController = TextEditingController(
    text: '45',
  );
  final TextEditingController _breakMinutesController = TextEditingController(
    text: '10',
  );
  final TextEditingController _sessionsController = TextEditingController(
    text: '4',
  );
  final TextEditingController _longBreakMinutesController =
      TextEditingController(text: '20');
  Timer? _timer;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subjectController.dispose();
    _focusMinutesController.dispose();
    _breakMinutesController.dispose();
    _sessionsController.dispose();
    _longBreakMinutesController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final settings = _studyService.getStudySettings();
    final active = _studyService.getActiveTimerState();
    final method =
        active?.method ?? _studyService.findMethod(settings.selectedMethodId);
    if (!mounted) return;
    setState(() {
      _selectedMethod = method;
      _state = active;
      _subjectController.text = widget.initialSubject?.trim().isNotEmpty == true
          ? widget.initialSubject!.trim()
          : active?.subject ?? settings.selectedSubject;
      _focusMinutesController.text = settings.customFocusMinutes.toString();
      _breakMinutesController.text = settings.customBreakMinutes.toString();
      _sessionsController.text = settings.defaultSessions.toString();
      _longBreakMinutesController.text = settings.customLongBreakMinutes
          .toString();
    });
  }

  void _startTicker() {
    _timerStarted = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _state == null) return;
      final oldCompleted = _state!.completed;
      final oldPhase = _state!.phase;
      final updated = _studyService.syncWithNow(_state!);
      setState(() {
        _state = updated;
      });
      _studyService.saveActiveTimerState(updated);

      if (updated.completed && !oldCompleted) {
        PetService.instance.onStudyTimerUpdated(
          isRunning: false,
          isBreak: false,
          isCompleted: true,
          subject: updated.subject,
        );
      } else if (updated.phase != oldPhase) {
        PetService.instance.onStudyTimerUpdated(
          isRunning: updated.isRunning,
          isBreak: updated.phase == StudyPhase.shortBreak ||
              updated.phase == StudyPhase.longBreak,
          isCompleted: false,
          subject: updated.subject,
        );
      }
    });
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
    _timerStarted = false;
  }

  void _pause() {
    if (_state == null) return;
    final updated = _studyService.pauseTimer(_state!);
    _stopTicker();
    setState(() => _state = updated);
    _studyService.saveActiveTimerState(updated);
    PetService.instance.onStudyTimerUpdated(
      isRunning: false,
      isBreak: updated.phase == StudyPhase.shortBreak ||
          updated.phase == StudyPhase.longBreak,
      isCompleted: false,
      subject: updated.subject,
    );
  }

  void _resume() {
    if (_state == null) return;
    final updated = _studyService.resumeTimer(_state!);
    setState(() => _state = updated);
    _studyService.saveActiveTimerState(updated);
    _startTicker();
    PetService.instance.onStudyTimerUpdated(
      isRunning: true,
      isBreak: updated.phase == StudyPhase.shortBreak ||
          updated.phase == StudyPhase.longBreak,
      isCompleted: false,
      subject: updated.subject,
    );
  }

  Future<bool> _confirmSessionAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _reset() async {
    if (_state == null) return;
    final confirmed = await _confirmSessionAction(
      title: 'Reset this session?',
      message:
          'The current timer will return to the beginning of this study session.',
      confirmLabel: 'Reset Session',
    );
    if (!confirmed || !mounted || _state == null) return;
    final updated = _studyService.resetTimer(_state!);
    _stopTicker();
    setState(() => _state = updated);
    _studyService.saveActiveTimerState(updated);
  }

  void _skipPhase() {
    if (_state == null || _state!.completed) return;
    final updated = _studyService.skipPhase(_state!);
    setState(() => _state = updated);
    _studyService.saveActiveTimerState(updated);
    _startTicker();
    PetService.instance.onStudyTimerUpdated(
      isRunning: updated.isRunning,
      isBreak: updated.phase == StudyPhase.shortBreak ||
          updated.phase == StudyPhase.longBreak,
      isCompleted: updated.completed,
      subject: updated.subject,
    );
  }

  Future<void> _changeMode() async {
    _stopTicker();
    await _studyService.clearActiveTimerState();
    PetService.instance.onStudyTimerUpdated(
      isRunning: false,
      isBreak: false,
      isCompleted: false,
    );
    if (!mounted) return;
    setState(() => _state = null);
  }

  Future<void> _startNewSession() async {
    final method = _buildSelectedMethod();
    final subject = _subjectController.text.trim();
    final totalSessions = _readPositiveInt(_sessionsController, 4);
    final state = _studyService.createInitialState(
      method: method,
      subject: subject.isEmpty ? 'General' : subject,
      totalSessions: totalSessions,
    );
    final runningState = _studyService.resumeTimer(state);
    setState(() => _state = runningState);
    await _studyService.saveActiveTimerState(runningState);
    PetService.instance.onStudyTimerUpdated(
      isRunning: true,
      isBreak: false,
      isCompleted: false,
      subject: runningState.subject,
    );
    final updatedSettings = _studyService.getStudySettings().copyWith(
      selectedSubject: subject,
      selectedMethodId: method.id,
      defaultSessions: totalSessions,
      customFocusMinutes: method.studyDurationMinutes,
      customBreakMinutes: method.shortBreakDurationMinutes,
      customLongBreakMinutes: method.longBreakDurationMinutes,
    );
    await _studyService.saveStudySettings(updatedSettings);
    _startTicker();
  }

  int _readPositiveInt(TextEditingController controller, int fallback) {
    final value = int.tryParse(controller.text.trim());
    return value == null || value < 1 ? fallback : value;
  }

  StudyMethod _buildSelectedMethod() {
    final selected = _selectedMethod ?? _studyService.findMethod('pomodoro');
    if (selected.id != 'custom') return selected;
    final focus = _readPositiveInt(_focusMinutesController, 45);
    final shortBreak = _readPositiveInt(_breakMinutesController, 10);
    final longBreak = _readPositiveInt(
      _longBreakMinutesController,
      20,
    ).clamp(15, 30);
    return selected.copyWith(
      studyDurationMinutes: focus,
      shortBreakDurationMinutes: shortBreak,
      longBreakDurationMinutes: longBreak,
      sessionsBeforeLongBreak: _readPositiveInt(_sessionsController, 4),
    );
  }

  String _methodLabel(StudyMethod method) {
    switch (method.id) {
      case 'light':
        return '15/5 — Light Study';
      case 'pomodoro':
        return '25/5 — Standard Pomodoro';
      case 'fifty_ten':
        return '50/10 — Long Focus';
      case 'ninety_minute':
        return '90/20 — Deep Study';
      default:
        return method.name;
    }
  }

  Future<void> _endSession() async {
    if (_state == null) return;
    final confirmed = await _confirmSessionAction(
      title: 'End this session?',
      message:
          'The study session will end and be saved to your study history.',
      confirmLabel: 'End Session',
    );
    if (!confirmed || !mounted || _state == null) return;
    _stopTicker();
    final record = StudySessionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      subject: _state!.subject,
      methodName: _state!.method.name,
      methodType: _state!.method.type,
      startedAt: DateTime.now().subtract(
        Duration(seconds: _state!.remainingSeconds == 0 ? 0 : 1500),
      ),
      endedAt: DateTime.now(),
      durationMinutes: ((1500 - _state!.remainingSeconds).clamp(0, 1500) / 60)
          .ceil(),
      completedSessions: _state!.currentSession,
      completed: true,
    );
    await _studyService.saveStudyHistoryRecord(record);
    await _studyService.clearActiveTimerState();
    PetService.instance.onStudyTimerUpdated(
      isRunning: false,
      isBreak: false,
      isCompleted: true,
      subject: record.subject,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
      final theme = Theme.of(context);
      final method = _buildSelectedMethod();
      final subject = _subjectController.text.trim();
      final isCustom = method.id == 'custom';
      final sessions = _readPositiveInt(_sessionsController, 4);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Study Timer'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.timer_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: theme.brightness == Brightness.dark
                                ? const [
                                    Color(0xFF25234D),
                                    Color(0xFF17243A),
                                  ]
                                : const [
                                    Color(0xFFEDEBFF),
                                    Color(0xFFE8F8F6),
                                  ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? .24
                                  : .12,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? .22
                                      : .12,
                                ),
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: Color(0xFF6366F1),
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'READY TO STUDY',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFF6366F1),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subject.isEmpty
                                        ? 'Plan a focused session'
                                        : subject,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Choose a study method and start a focused session.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _studySetupCard(
                        theme,
                        label: 'SUBJECT',
                        icon: Icons.bookmark_outline_rounded,
                        child: TextField(
                          controller: _subjectController,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'e.g. Mathematics',
                            prefixIcon: Icon(Icons.subject_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _studySetupCard(
                        theme,
                        label: 'STUDY METHOD',
                        icon: Icons.tune_rounded,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: Column(
                            key: ValueKey(_selectedMethod?.id ?? 'loading'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _selectedMethod?.id,
                                isExpanded: true,
                                items: StudyService.defaultStudyMethods
                                    .map(
                                      (method) => DropdownMenuItem(
                                        value: method.id,
                                        child: Text(
                                          _methodLabel(method),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (methodId) {
                                  if (methodId == null) return;
                                  setState(
                                    () => _selectedMethod = StudyService
                                        .defaultStudyMethods
                                        .firstWhere(
                                          (method) => method.id == methodId,
                                        ),
                                  );
                                },
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.timer_outlined),
                                ),
                              ),
                              if (isCustom) ...[
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, fieldConstraints) {
                                    final compact =
                                        fieldConstraints.maxWidth < 440;
                                    final fields = [
                                      _numberField(
                                        controller: _focusMinutesController,
                                        label: 'Focus (minutes)',
                                        onChanged: () => setState(() {}),
                                      ),
                                      _numberField(
                                        controller: _breakMinutesController,
                                        label: 'Short break (minutes)',
                                        onChanged: () => setState(() {}),
                                      ),
                                      _numberField(
                                        controller: _sessionsController,
                                        label: 'Focus sessions',
                                        onChanged: () => setState(() {}),
                                      ),
                                      _numberField(
                                        controller:
                                            _longBreakMinutesController,
                                        label: 'Long break (15–30 min)',
                                        onChanged: () => setState(() {}),
                                      ),
                                    ];
                                    if (compact) {
                                      return Column(
                                        children: [
                                          for (var i = 0;
                                              i < fields.length;
                                              i++) ...[
                                            if (i > 0)
                                              const SizedBox(height: 10),
                                            fields[i],
                                          ],
                                        ],
                                      );
                                    }
                                    return Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: fields
                                          .map(
                                            (field) => SizedBox(
                                              width:
                                                  (fieldConstraints.maxWidth -
                                                      10) /
                                                  2,
                                              child: field,
                                            ),
                                          )
                                          .toList(),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: .65,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .035),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.insights_rounded,
                                  size: 18,
                                  color: Color(0xFF14B8A6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'SESSION PREVIEW',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, previewConstraints) {
                                final columns =
                                    previewConstraints.maxWidth < 360 ? 2 : 4;
                                final gap = 8.0;
                                final width =
                                    (previewConstraints.maxWidth -
                                        gap * (columns - 1)) /
                                    columns;
                                final previews = [
                                  _previewStat(
                                    theme,
                                    Icons.bolt_rounded,
                                    '${method.studyDurationMinutes} min',
                                    'FOCUS',
                                    const Color(0xFF6366F1),
                                  ),
                                  _previewStat(
                                    theme,
                                    Icons.coffee_rounded,
                                    '${method.shortBreakDurationMinutes} min',
                                    'BREAK',
                                    const Color(0xFF14B8A6),
                                  ),
                                  _previewStat(
                                    theme,
                                    Icons.repeat_rounded,
                                    '$sessions cycles',
                                    'SESSIONS',
                                    const Color(0xFF8B5CF6),
                                  ),
                                  _previewStat(
                                    theme,
                                    Icons.self_improvement_rounded,
                                    '${method.longBreakDurationMinutes} min',
                                    'LONG BREAK',
                                    const Color(0xFFF59E0B),
                                  ),
                                ];
                                return Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: previews
                                      .map(
                                        (preview) => SizedBox(
                                          width: width,
                                          child: preview,
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: _startNewSession,
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: const Text(
                            'Start Study Session',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF5B5BD6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_timerStarted) {
      final theme = Theme.of(context);
      final phaseSeconds = switch (state.phase) {
        StudyPhase.study => state.method.studyDurationMinutes * 60,
        StudyPhase.shortBreak => state.method.shortBreakDurationMinutes * 60,
        StudyPhase.longBreak => state.method.longBreakDurationMinutes * 60,
        StudyPhase.completed => 1,
      };
      final phaseProgress = (1 - state.remainingSeconds / phaseSeconds).clamp(
        0.0,
        1.0,
      );
      final phaseColor = studyPhaseColor(state.phase);
      final sessionProgress =
          (state.currentSession / state.totalSessions).clamp(0.0, 1.0);
      final stateMessage = state.statusMessage.toLowerCase();
      final isReady = !state.isRunning &&
          !state.completed &&
          (stateMessage.contains('ready') || stateMessage.contains('reset'));
      return Scaffold(
        appBar: AppBar(title: const Text('Study Session')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight < 32
                        ? 0
                        : constraints.maxHeight - 32,
                    maxWidth: 620,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    _sessionInfoCard(theme, state),
                    const SizedBox(height: 18),
                    _sessionTimerDial(
                      context,
                      state: state,
                      phaseProgress: phaseProgress,
                      phaseColor: phaseColor,
                      size: 208,
                    ),
                    const SizedBox(height: 16),
                    _sessionProgressBar(
                      context,
                      state: state,
                      progress: sessionProgress,
                    ),
                    const SizedBox(height: 18),
                    _TimerControlButton(
                      isRunning: state.isRunning,
                      label: state.isRunning
                          ? 'Pause Timer'
                          : isReady
                          ? 'Start Timer'
                          : 'Resume Timer',
                      onPressed: _resume,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: const Text(
                              'Reset Session',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _endSession,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text(
                              'End Session',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              backgroundColor: theme.colorScheme.error
                                  .withValues(alpha: .08),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      );
    }

    final method = state.method;
    final phaseSeconds = switch (state.phase) {
      StudyPhase.study => method.studyDurationMinutes * 60,
      StudyPhase.shortBreak => method.shortBreakDurationMinutes * 60,
      StudyPhase.longBreak => method.longBreakDurationMinutes * 60,
      StudyPhase.completed => 1,
    };
    final phaseProgress = (1 - state.remainingSeconds / phaseSeconds).clamp(
      0.0,
      1.0,
    );
    final sessionProgress = (state.currentSession / state.totalSessions).clamp(
      0.0,
      1.0,
    );
    final phaseColor = studyPhaseColor(state.phase);

    return Scaffold(
      appBar: AppBar(title: const Text('Study Session')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              _sessionInfoCard(Theme.of(context), state),
              const SizedBox(height: 16),
              _sessionTimerDial(
                context,
                state: state,
                phaseProgress: phaseProgress,
                phaseColor: phaseColor,
                size: 218,
              ),
              const SizedBox(height: 16),
              _sessionProgressBar(
                context,
                state: state,
                progress: sessionProgress,
              ),
              const SizedBox(height: 20),
              _TimerControlButton(
                isRunning: state.isRunning,
                onPressed: state.isRunning ? _pause : _resume,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text(
                        'Reset Session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _endSession,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text(
                        'End Session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: .08),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: state.completed ? null : _skipPhase,
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Skip phase'),
                ),
              ),
              if (state.phase == StudyPhase.longBreak)
                TextButton.icon(
                  onPressed: _changeMode,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Change Study Mode'),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionInfoCard(ThemeData theme, StudyTimerState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.isRunning
                      ? 'STUDY SESSION'
                      : state.statusMessage.toLowerCase().contains('paused')
                      ? 'SESSION PAUSED'
                      : 'READY TO FOCUS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF6366F1),
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${state.currentSession}/${state.totalSessions}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            state.subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: Color(0xFF14B8A6),
              ),
              Text(
                _methodLabel(state.method),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF14B8A6),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${state.method.studyDurationMinutes} min focus  •  '
            '${state.method.shortBreakDurationMinutes} min break  •  '
            '${state.totalSessions} focus sessions',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionTimerDial(
    BuildContext context, {
    required StudyTimerState state,
    required double phaseProgress,
    required Color phaseColor,
    required double size,
  }) {
    final theme = Theme.of(context);
    final stateMessage = state.statusMessage.toLowerCase();
    final status = state.completed
        ? 'COMPLETE'
        : state.isRunning
        ? (state.isStudyPhase ? 'FOCUS' : 'BREAK')
        : (stateMessage.contains('ready') ||
              stateMessage.contains('reset'))
        ? 'READY'
        : 'PAUSED';

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: phaseColor.withValues(alpha: state.isRunning ? .1 : .05),
          boxShadow: state.isRunning
              ? [
                  BoxShadow(
                    color: phaseColor.withValues(alpha: .16),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : const [],
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: phaseProgress),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeInOutCubic,
            builder: (context, progress, _) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(phaseColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: phaseColor),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        status,
                        key: ValueKey(status),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: phaseColor,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        formatStudyClock(state.remainingDuration),
                        key: ValueKey(state.remainingSeconds),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.phase == StudyPhase.completed
                          ? 'Session complete'
                          : state.isStudyPhase
                          ? 'Study session'
                          : 'Break time',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionProgressBar(
    BuildContext context, {
    required StudyTimerState state,
    required double progress,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Focus sessions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Session ${state.currentSession} of ${state.totalSessions}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
            ),
          ),
        ),
      ],
    );
  }

  Widget _studySetupCard(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _previewStat(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: theme.brightness == Brightness.dark ? .14 : .08,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _TimerControlButton extends StatefulWidget {
  const _TimerControlButton({
    required this.isRunning,
    required this.onPressed,
    this.label,
  });

  final bool isRunning;
  final VoidCallback onPressed;
  final String? label;

  @override
  State<_TimerControlButton> createState() => _TimerControlButtonState();
}

class _TimerControlButtonState extends State<_TimerControlButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.label ?? (widget.isRunning ? 'Pause Timer' : 'Resume Timer');
    final icon = widget.isRunning
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? .97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B5BD6).withValues(alpha: .24),
                blurRadius: 13,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: widget.onPressed,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(icon, key: ValueKey(icon), size: 21),
            ),
            label: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
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
                label,
                key: ValueKey(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5B5BD6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
