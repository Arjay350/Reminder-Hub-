import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/backup_service.dart';
import '../../services/hive_service.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/school_class_dialog.dart';
import '../../widgets/weekly_timetable_widget.dart';
import '../../services/pet_service.dart';

class SchoolScheduleScreen extends StatefulWidget {
  const SchoolScheduleScreen({super.key});

  @override
  State<SchoolScheduleScreen> createState() => _SchoolScheduleScreenState();
}

class _SchoolScheduleScreenState extends State<SchoolScheduleScreen> {
  final HiveService _hive = HiveService.instance;

  List<SchoolClass> _classes = [];
  Map<int, String> _dayModes = {};
  int _selectedDayFilter = 0; // 0 = All Days, 1 = Mon, ..., 7 = Sun
  int _viewMode = 0; // 0 = List View, 1 = Weekly Timetable

  final List<Map<String, dynamic>> _filters = [
    {'day': 0, 'label': 'All Days'},
    {'day': 1, 'label': 'Mon'},
    {'day': 2, 'label': 'Tue'},
    {'day': 3, 'label': 'Wed'},
    {'day': 4, 'label': 'Thu'},
    {'day': 5, 'label': 'Fri'},
    {'day': 6, 'label': 'Sat'},
    {'day': 7, 'label': 'Sun'},
  ];

  static const List<Map<String, dynamic>> _daysInfo = [
    {'day': 1, 'name': 'Monday', 'short': 'Mon'},
    {'day': 2, 'name': 'Tuesday', 'short': 'Tue'},
    {'day': 3, 'name': 'Wednesday', 'short': 'Wed'},
    {'day': 4, 'name': 'Thursday', 'short': 'Thu'},
    {'day': 5, 'name': 'Friday', 'short': 'Fri'},
    {'day': 6, 'name': 'Saturday', 'short': 'Sat'},
    {'day': 7, 'name': 'Sunday', 'short': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _hive.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _classes = _hive.getSchoolClasses();
      _dayModes = _hive.getDayClassModes();
    });
    PetService.instance.onScheduleChecked();
    PetService.instance.checkUpcomingEvents(schoolClasses: _classes);
    await WidgetService.instance.updateSchoolWidget();
  }

  Future<void> _updateDayMode(int day, String mode) async {
    setState(() {
      _dayModes[day] = mode;
    });
    await _hive.saveDayClassMode(day, mode);
    await WidgetService.instance.updateSchoolWidget();
  }

  Future<void> _exportSchoolSchedule() async {
    try {
      final path = await BackupService.instance.exportSchoolSchedule();
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Schedule exported: $path')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a backup folder first')),
        );
      }
    }
  }

  Future<void> _shareSchoolSchedule() async {
    try {
      await BackupService.instance.exportSchoolSchedule(share: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share the schedule')),
        );
      }
    }
  }

  Future<void> _importSchoolSchedule() async {
    final backup = await BackupService.instance.pickSchoolScheduleBackup();
    if (!mounted || backup == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid or cancelled schedule import')),
        );
      }
      return;
    }

    final existingIds = _classes.map((item) => item.id).toSet();
    final duplicates = backup.classes
        .where((item) => existingIds.contains(item.id))
        .length;
    var action = SchoolScheduleDuplicateAction.add;
    if (duplicates > 0) {
      final selected = await showDialog<SchoolScheduleDuplicateAction>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate classes found'),
          content: Text(
            '$duplicates class${duplicates == 1 ? '' : 'es'} already exist. '
            'How should they be imported?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, SchoolScheduleDuplicateAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, SchoolScheduleDuplicateAction.add),
              child: const Text('Add as new'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, SchoolScheduleDuplicateAction.replace),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (!mounted || selected == null) return;
      action = selected;
    }

    final result = await BackupService.instance.importSchoolSchedule(
      backup,
      action,
    );
    if (!mounted || result == null) return;
    setState(() {
      _classes = _hive.getSchoolClasses();
      _dayModes = _hive.getDayClassModes();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${result.imported} class${result.imported == 1 ? '' : 'es'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final todayWeekday = DateTime.now().weekday; // 1 = Mon, ..., 7 = Sun

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'School Schedule',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Schedule data',
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportSchoolSchedule();
                  break;
                case 'share':
                  _shareSchoolSchedule();
                  break;
                case 'import':
                  _importSchoolSchedule();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file_outlined),
                  title: Text('Export Schedule'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text('Share Schedule'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('Import Schedule'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // View Mode Selector (Class List vs Weekly Timetable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141A2E)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _viewMode = 0),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _viewMode == 0
                              ? const Color(0xFF14B8A6)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _viewMode == 0
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF14B8A6,
                                    ).withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.format_list_bulleted_rounded,
                              size: 16,
                              color: _viewMode == 0
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Class List',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _viewMode == 0
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.grey.shade300
                                          : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _viewMode = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _viewMode == 1
                              ? const Color(0xFF14B8A6)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _viewMode == 1
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF14B8A6,
                                    ).withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_view_week_rounded,
                              size: 16,
                              color: _viewMode == 1
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Weekly Timetable',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _viewMode == 1
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.grey.shade300
                                          : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_viewMode == 1) ...[
            // Weekly School Timetable View
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Class Timetable',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mon – Sat with Day Learning Modes',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _openWeeklyLearningModesConfig,
                    icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                    label: const Text(
                      'Modes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF14B8A6),
                      side: const BorderSide(color: Color(0xFF14B8A6)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: WeeklySchoolTimetableWidget(
                  classes: _classes,
                  dayModes: _dayModes,
                  onScheduleChanged: _loadData,
                ),
              ),
            ),
          ] else ...[
            // Day Filter Chips (Mon to Sat)
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final f = _filters[index];
                  final day = f['day'] as int;
                  final label = f['label'] as String;
                  final isSelected = _selectedDayFilter == day;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedDayFilter = day);
                        final tomorrowWeekday = (DateTime.now().weekday % 7) + 1;
                        if (day == tomorrowWeekday) {
                          PetService.instance.onScheduleChecked(isTomorrow: true);
                        } else if (day == DateTime.now().weekday || day == 0) {
                          PetService.instance.onScheduleChecked();
                        }
                      },
                      selectedColor: const Color(
                        0xFF14B8A6,
                      ).withValues(alpha: 0.15),
                      checkmarkColor: const Color(0xFF14B8A6),
                      labelStyle: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF14B8A6)
                            : (isDark ? Colors.grey.shade300 : Colors.black87),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF14B8A6).withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),

            // Class List grouped by Day (DAY -> CLASS MODE -> CLASSES)
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(.035, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_selectedDayFilter),
                  child: _buildDayBasedClassList(isDark, todayWeekday),
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Class'),
      ),
    );
  }

  Widget _buildDayBasedClassList(bool isDark, int todayWeekday) {
    final displayedDays = _selectedDayFilter == 0
        ? _daysInfo
        : _daysInfo
              .where((d) => (d['day'] as int) == _selectedDayFilter)
              .toList();

    if (_classes.isEmpty && _selectedDayFilter == 0) {
      return EmptyState(
        title: 'No Classes Scheduled',
        message:
            'Add your subjects, course codes, room locations, and recurring days',
        icon: Icons.school_outlined,
        actionLabel: 'Add Class',
        onAction: _openAddDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: displayedDays.length,
      itemBuilder: (context, index) {
        final dayInfo = displayedDays[index];
        final dayNum = dayInfo['day'] as int;
        final dayName = (dayInfo['name'] as String).toUpperCase();
        final isToday = dayNum == todayWeekday;
        final mode = _dayModes[dayNum] ?? DayClassMode.f2f;

        final dayClasses = _classes
            .where((c) => c.occursOnDay(dayNum))
            .toList();
        dayClasses.sort((a, b) => a.startTime.compareTo(b.startTime));

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Day Header with Class Mode Badge ──────────────────────────
              _buildDayHeader(
                dayNum,
                dayName,
                mode,
                isToday,
                isDark,
                dayClasses.length,
              ),
              const SizedBox(height: 8),

              // ── Classes for this Day ──────────────────────────────────────
              if (dayClasses.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF141A2E).withValues(alpha: 0.5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1E294B)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'No classes for $dayName',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openAddDialogForDay(dayNum),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF14B8A6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...dayClasses.map((c) => _buildClassCard(c, mode, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayHeader(
    int dayNum,
    String dayName,
    String mode,
    bool isToday,
    bool isDark,
    int classCount,
  ) {
    final bool hasClasses = classCount > 0;
    Color modeColor;
    IconData modeIcon;
    switch (mode) {
      case DayClassMode.asyncModule:
        modeColor = const Color(0xFF8B5CF6); // Purple
        modeIcon = Icons.menu_book_rounded;
        break;
      case DayClassMode.syncOnline:
        modeColor = const Color(0xFF3B82F6); // Blue
        modeIcon = Icons.videocam_rounded;
        break;
      case DayClassMode.f2f:
      default:
        modeColor = const Color(0xFF10B981); // Emerald
        modeIcon = Icons.domain_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? const Color(0xFF14B8A6).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF1E294B) : const Color(0xFFE2E8F0)),
          width: isToday ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isToday
                            ? const Color(0xFF14B8A6)
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (hasClasses)
                  // Active Mode Tag (only when day has classes)
                  Row(
                    children: [
                      Icon(modeIcon, size: 14, color: modeColor),
                      const SizedBox(width: 6),
                      Text(
                        mode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: modeColor,
                        ),
                      ),
                    ],
                  )
                else
                  // Empty Day Tag
                  Row(
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 13,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'No Classes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Mode Switcher Popup (Only available when day has classes)
          if (hasClasses)
            PopupMenuButton<String>(
              tooltip: 'Change Mode for $dayName',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDark ? const Color(0xFF141A2E) : Colors.white,
              initialValue: mode,
              onSelected: (newMode) => _updateDayMode(dayNum, newMode),
              itemBuilder: (context) => DayClassMode.allModes.map((m) {
                final isSel = m == mode;
                Color itemColor;
                IconData itemIcon;
                if (m == DayClassMode.asyncModule) {
                  itemColor = const Color(0xFF8B5CF6);
                  itemIcon = Icons.menu_book_rounded;
                } else if (m == DayClassMode.syncOnline) {
                  itemColor = const Color(0xFF3B82F6);
                  itemIcon = Icons.videocam_rounded;
                } else {
                  itemColor = const Color(0xFF10B981);
                  itemIcon = Icons.domain_rounded;
                }

                return PopupMenuItem<String>(
                  value: m,
                  child: Row(
                    children: [
                      Icon(itemIcon, color: itemColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          m,
                          style: TextStyle(
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSel
                                ? itemColor
                                : (isDark ? Colors.white : Colors.black87),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isSel) Icon(Icons.check, size: 16, color: itemColor),
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: modeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DayClassMode.getShortName(mode),
                      style: TextStyle(
                        color: modeColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: modeColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassCard(SchoolClass c, String dayMode, bool isDark) {
    final bool isAsync = dayMode == DayClassMode.asyncModule;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAsync ? Icons.menu_book_rounded : Icons.school,
                    color: c.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.subject,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (c.courseCode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Course Code: ${c.courseCode}',
                          style: TextStyle(
                            fontSize: 13,
                            color: c.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  onPressed: () => _openEditDialog(c),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => _deleteClass(c),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip(Icons.access_time, c.timeRange, isDark),
                if (c.room.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _infoChip(Icons.meeting_room_outlined, c.room, isDark),
                ],
              ],
            ),
            if (c.teacher.isNotEmpty || c.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (c.teacher.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Instructor: ${c.teacher}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              if (c.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  c.notes,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E294B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWeeklyLearningModesConfig() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tempModes = Map<int, String>.from(_dayModes);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Learning Mode',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure learning mode per day (Mon–Sat)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._daysInfo.map((d) {
                  final int day = d['day'] as int;
                  final String name = d['name'] as String;
                  final int classCount = _classes
                      .where((c) => c.occursOnDay(day))
                      .length;
                  final bool hasClasses = classCount > 0;
                  final currentMode = tempModes[day] ?? DayClassMode.f2f;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: hasClasses
                                    ? (isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B))
                                    : (isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600),
                              ),
                            ),
                            if (!hasClasses)
                              Text(
                                'No classes scheduled',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        if (hasClasses)
                          DropdownButton<String>(
                            value: currentMode,
                            underline: const SizedBox.shrink(),
                            dropdownColor: isDark
                                ? const Color(0xFF141A2E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            items: DayClassMode.allModes.map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  tempModes[day] = val;
                                });
                              }
                            },
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(
                                      0xFF1E294B,
                                    ).withValues(alpha: 0.5)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.block_rounded,
                                  size: 13,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'No Classes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(bottomSheetContext);
                      setState(() {
                        _dayModes = Map<int, String>.from(tempModes);
                      });
                      await _hive.saveAllDayClassModes(_dayModes);
                      await WidgetService.instance.updateSchoolWidget();
                    },
                    child: const Text(
                      'Save Learning Modes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAddDialog() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SchoolClassDialog(),
    );
    if (result != null) _loadData();
  }

  Future<void> _openAddDialogForDay(int dayNum) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SchoolClassDialog(initialDay: dayNum),
    );
    if (result != null) _loadData();
  }

  Future<void> _openEditDialog(SchoolClass schoolClass) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SchoolClassDialog(schoolClass: schoolClass),
    );
    if (result != null) _loadData();
  }

  Future<void> _deleteClass(SchoolClass schoolClass) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Class Schedule?',
      message:
          'Are you sure you want to delete ${schoolClass.subject} from your schedule?',
    );
    if (confirm) {
      await NotificationService.instance.cancelNotificationForId(
        schoolClass.id,
      );
      await _hive.deleteSchoolClass(schoolClass.id);
      _loadData();
    }
  }
}
