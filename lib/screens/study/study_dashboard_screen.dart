import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/study_models.dart';
import 'study_materials_screen.dart';
import '../../services/study_service.dart';

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

  void _openStudyTimer([String? subject]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudyTimerScreen(initialSubject: subject),
      ),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Study'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _activeState != null && _activeState!.isRunning
                            ? 'Continue Study Session'
                            : 'Ready to focus?',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activeState != null
                            ? 'Subject: ${_activeState!.subject}'
                            : 'Choose a method and start your next study block.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openStudyTimer,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            _activeState != null
                                ? 'Continue Study Session'
                                : 'Start Study Session',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.library_books_outlined),
                  title: const Text('Study Materials'),
                  subtitle: const Text(
                    'Import materials and generate local reviewers, quizzes, and flashcards.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StudyMaterialsScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Study Subjects',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _addSubject,
                    tooltip: 'Add study subject',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_subjects.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.link_rounded),
                    title: Text('No subjects yet'),
                    subtitle: Text(
                      'Add a subject here or add classes in School Schedule.',
                    ),
                  ),
                )
              else
                ..._subjects.map(
                  (subject) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_rounded),
                      title: Text(subject),
                      subtitle: const Text('Start a study session'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openStudyTimer(subject),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _statCard('Today', _todayMinutes),
                  _statCard(
                    'Sessions',
                    '${_studyService.calculateStatistics().totalSessions}',
                  ),
                  _statCard(
                    'Streak',
                    '${_studyService.calculateStatistics().currentStreak} days',
                  ),
                  _statCard(
                    'Average',
                    formatStudyDuration(
                      _studyService
                          .calculateStatistics()
                          .averageSessionDurationMinutes,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Recent Sessions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_recentHistory.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No study sessions yet. Start your first focus block.',
                    ),
                  ),
                )
              else
                ..._recentHistory.map(
                  (session) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_rounded),
                      title: Text(session.subject),
                      subtitle: Text(
                        '${session.methodName} • ${formatStudyDuration(session.durationMinutes)}',
                      ),
                      trailing: Text('${session.completedSessions} sessions'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
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
      final updated = _studyService.syncWithNow(_state!);
      setState(() {
        _state = updated;
      });
      _studyService.saveActiveTimerState(updated);
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
  }

  void _resume() {
    if (_state == null) return;
    final updated = _studyService.resumeTimer(_state!);
    setState(() => _state = updated);
    _studyService.saveActiveTimerState(updated);
    _startTicker();
  }

  void _reset() {
    if (_state == null) return;
    final updated = _studyService.resetTimer(_state!);
    _stopTicker();
    setState(() => _state = updated);
    _studyService.saveActiveTimerState(updated);
  }

  Future<void> _changeMode() async {
    _stopTicker();
    await _studyService.clearActiveTimerState();
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
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Timer')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject (optional)',
                    hintText: 'Mathematics',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMethod?.id,
                  items: StudyService.defaultStudyMethods
                      .map(
                        (method) => DropdownMenuItem(
                          value: method.id,
                          child: Text(_methodLabel(method)),
                        ),
                      )
                      .toList(),
                  onChanged: (methodId) {
                    if (methodId == null) return;
                    setState(
                      () => _selectedMethod = StudyService.defaultStudyMethods
                          .firstWhere((method) => method.id == methodId),
                    );
                  },
                  decoration: const InputDecoration(labelText: 'Study Method'),
                ),
                if (_selectedMethod?.id == 'custom') ...[
                  const SizedBox(height: 12),
                  _numberField(
                    controller: _focusMinutesController,
                    label: 'Focus duration (minutes)',
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    controller: _breakMinutesController,
                    label: 'Short break duration (minutes)',
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    controller: _sessionsController,
                    label: 'Number of focus sessions',
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    controller: _longBreakMinutesController,
                    label: 'Long break duration (15-30 minutes)',
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _startNewSession,
                  child: const Text('Start Study Session'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_timerStarted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Session')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Session ready',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Subject: ${state.subject}'),
                Text('Mode: ${_methodLabel(state.method)}'),
                const SizedBox(height: 8),
                Text(
                  '${state.method.studyDurationMinutes} min focus • '
                  '${state.method.shortBreakDurationMinutes} min break • '
                  '${state.totalSessions} focus sessions',
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _resume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start / Resume Timer'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Reset Session'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _endSession,
                  child: const Text('End Session'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final method = state.method;
    final phaseName = buildStudyPhaseText(state.phase);
    final progress = (state.currentSession / state.totalSessions).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Study Timer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                state.subject.toUpperCase(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _methodLabel(method),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Text(
                formatStudyClock(state.remainingDuration),
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                phaseName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: studyPhaseColor(state.phase),
                ),
              ),
              const SizedBox(height: 8),
              Text('Session ${state.currentSession} of ${state.totalSessions}'),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!state.isRunning)
                    ElevatedButton(
                      onPressed: _resume,
                      child: const Text('Resume'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _pause,
                      child: const Text('Pause'),
                    ),
                  ElevatedButton(onPressed: _reset, child: const Text('Reset')),
                  ElevatedButton(
                    onPressed: _endSession,
                    child: const Text('End Session'),
                  ),
                ],
              ),
              if (state.phase == StudyPhase.longBreak) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _changeMode,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Change Study Mode'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }
}
