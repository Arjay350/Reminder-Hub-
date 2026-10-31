import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/utilities/formatters.dart';
import '../../models/app_models.dart';
import '../../services/hive_service.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../services/reminder_completion_service.dart';
import 'reminder_history_screen.dart';
import '../../widgets/ai_account_dialog.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/reminder_dialog.dart';
import '../../widgets/school_class_dialog.dart';

enum ReminderSourceType { general, aiSubscription, schoolClass }

class UnifiedReminderEntry {
  UnifiedReminderEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.subtitle,
    required this.date,
    required this.time,
    required this.priority,
    required this.isCompleted,
    required this.categoryColor,
    required this.categoryIcon,
    required this.sourceType,
    required this.originalObject,
  });

  final String id;
  final String title;
  final String category;
  final String subtitle;
  final DateTime date;
  final String time;
  final String priority;
  final bool isCompleted;
  final Color categoryColor;
  final IconData categoryIcon;
  final ReminderSourceType sourceType;
  final dynamic originalObject;
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with WidgetsBindingObserver {
  final HiveService _hive = HiveService.instance;

  List<UnifiedReminderEntry> _allEntries = [];
  String _selectedCategory = 'All';
  String _selectedFilter = 'Pending'; // All, Pending, Completed, High
  String _searchQuery = '';
  bool _hideSchoolSchedule = false;

  final List<String> _categories = [
    'All',
    'School',
    'Subscriptions',
    'Gaming',
    'Work',
    'Personal',
    'Household',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hive.remindersChangedNotifier.addListener(_loadReminders);
    _loadReminders();
  }

  @override
  void dispose() {
    _hive.remindersChangedNotifier.removeListener(_loadReminders);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadReminders();
    }
  }

  DateTime _parseEntryDateTime(DateTime date, String timeStr) {
    final parsedTime = Reminder.parseTime(timeStr);
    if (parsedTime == null) return DateUtils.dateOnly(date);
    return DateTime(
      date.year,
      date.month,
      date.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  Future<void> _loadReminders() async {
    await _hive.ensureInitialized();
    if (!mounted) return;

    final reminders = _hive.getReminders();
    final aiAccounts = _hive.getAIAccounts();
    final schoolClasses = _hive.getSchoolClasses();
    final settings = _hive.getSettings();
    final now = DateTime.now();

    final List<UnifiedReminderEntry> entries = [];

    // 1. General Reminders
    for (final r in reminders) {
      entries.add(
        UnifiedReminderEntry(
          id: r.id,
          title: r.title,
          category: r.category,
          subtitle:
              '${r.category} • ${Formatters.formatShortDate(r.date)} at ${r.time}',
          date: r.date,
          time: r.time,
          priority: r.priority,
          isCompleted: r.completed,
          categoryColor: r.categoryColor,
          categoryIcon: r.categoryIcon,
          sourceType: ReminderSourceType.general,
          originalObject: r,
        ),
      );
    }

    // 2. Connected AI Subscription Renewals (for Paid plans only)
    for (final a in aiAccounts) {
      if (!a.isFreePlan) {
        entries.add(
          UnifiedReminderEntry(
            id: 'ai_sub_${a.id}',
            title: '${a.service} Subscription',
            category: 'Subscriptions',
            subtitle:
                '${a.accountName} (${a.plan}) • Subscription Renewal on ${Formatters.formatDate(a.renewalDate)}',
            date: a.renewalDate,
            time: '09:00 AM',
            priority: 'High',
            isCompleted: false,
            categoryColor: const Color(0xFF3B82F6),
            categoryIcon: Icons.credit_card_rounded,
            sourceType: ReminderSourceType.aiSubscription,
            originalObject: a,
          ),
        );
      }
    }

    // 3. Connected School Classes (Next recurring occurrence)
    for (final c in schoolClasses) {
      if (settings.hideSchoolScheduleInCalendar) continue;
      if (c.daysOfWeek.isEmpty) continue;
      int? minDaysAhead;
      for (final d in c.daysOfWeek) {
        int diff = d - now.weekday;
        if (diff < 0) diff += 7;
        if (diff == 0) {
          final classTimeToday = _parseEntryDateTime(now, c.startTime);
          if (classTimeToday.isBefore(now)) {
            diff = 7;
          }
        }
        if (minDaysAhead == null || diff < minDaysAhead) {
          minDaysAhead = diff;
        }
      }
      final nextClassDate = DateTime(
        now.year,
        now.month,
        now.day + (minDaysAhead ?? 0),
      );

      entries.add(
        UnifiedReminderEntry(
          id: 'school_class_${c.id}',
          title: 'Class: ${c.subject}',
          category: 'School',
          subtitle:
              '${c.room.isNotEmpty ? "Room ${c.room} • " : ""}${c.timeRange} (${c.daysFormatted})',
          date: nextClassDate,
          time: c.startTime,
          priority: 'Medium',
          isCompleted: false,
          categoryColor: c.color,
          categoryIcon: Icons.school,
          sourceType: ReminderSourceType.schoolClass,
          originalObject: c,
        ),
      );
    }

    setState(() {
      _allEntries = entries;
      _hideSchoolSchedule = settings.hideSchoolScheduleInCalendar;
    });
  }

  Future<void> _toggleHideSchoolSchedule() async {
    final newValue = !_hideSchoolSchedule;
    final settings = _hive.getSettings();
    await _hive.saveSettings(
      settings.copyWith(hideSchoolScheduleInCalendar: newValue),
    );
    if (!mounted) return;
    setState(() {
      _hideSchoolSchedule = newValue;
    });
    await _loadReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newValue
              ? 'Recurring school classes are hidden in Calendar and Reminders. School tasks remain visible.'
              : 'Recurring school classes are shown in Calendar and Reminders.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _allEntries.where((e) {
      if (_selectedCategory != 'All' && e.category != _selectedCategory) {
        return false;
      }
      if (_selectedFilter == 'Pending' && e.isCompleted) return false;
      if (_selectedFilter == 'Completed' && !e.isCompleted) return false;
      if (_selectedFilter == 'High' && e.priority != 'High') return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = e.title.toLowerCase().contains(query);
        final matchesSubtitle = e.subtitle.toLowerCase().contains(query);
        final matchesCat = e.category.toLowerCase().contains(query);
        if (!matchesTitle && !matchesSubtitle && !matchesCat) return false;
      }
      return true;
    }).toList();

    // Sort chronologically by combined date and time
    filtered.sort((a, b) {
      final aDt = _parseEntryDateTime(a.date, a.time);
      final bDt = _parseEntryDateTime(b.date, b.time);
      return aDt.compareTo(bDt);
    });
    final completedCount = _allEntries
        .where((entry) => entry.isCompleted)
        .length;
    final openCount = _allEntries.length - completedCount;
    final completionProgress = _allEntries.isEmpty
        ? 0.0
        : completedCount / _allEntries.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reminders Hub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Completion History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReminderHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: _hideSchoolSchedule
                ? 'Show school schedule in Calendar and Reminders'
                : 'Hide school schedule in Calendar and Reminders',
            onPressed: _toggleHideSchoolSchedule,
            icon: Icon(
              _hideSchoolSchedule ? Icons.school_outlined : Icons.school,
              color: _hideSchoolSchedule ? Colors.grey : null,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            initialValue: _selectedFilter,
            onSelected: (val) => setState(() => _selectedFilter = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'All', child: Text('All Reminders')),
              PopupMenuItem(value: 'Pending', child: Text('Pending Only')),
              PopupMenuItem(value: 'Completed', child: Text('Completed Only')),
              PopupMenuItem(value: 'High', child: Text('High Priority Only')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReminders,
        color: theme.colorScheme.primary,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: isDark ? .12 : .07,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          color: theme.colorScheme.primary,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$openCount open',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '$completedCount completed',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: completionProgress),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) =>
                            LinearProgressIndicator(value: value, minHeight: 5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search tasks, school, subscriptions...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF141A2E)
                      : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            // Category Chips Horizontal Scroll
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                      selectedColor: theme.colorScheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      checkmarkColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.grey.shade300 : Colors.black87),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Reminders List
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(
                      title: _searchQuery.isNotEmpty
                          ? 'No matches found'
                          : _selectedFilter == 'Pending' &&
                                _selectedCategory == 'All'
                          ? 'You’re all caught up!'
                          : 'No reminders here',
                      message: _searchQuery.isNotEmpty
                          ? 'No reminders matching "$_searchQuery"'
                          : _selectedFilter == 'Pending' &&
                                _selectedCategory == 'All'
                          ? 'Nothing needs your attention right now. Add a reminder whenever you need one.'
                          : 'There are no ${_selectedFilter.toLowerCase()} reminders in this view.',
                      icon: Icons.notifications_off_outlined,
                      actionLabel: 'Add Reminder',
                      onAction: _openAddDialog,
                    )
                  : AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final e = filtered[index];
                          final titlePreview = Formatters.previewText(e.title);
                          final now = DateTime.now();
                          final dueAt = _parseEntryDateTime(e.date, e.time);
                          final isOverdue = !e.isCompleted && dueAt.isBefore(now);
                          final isToday = DateUtils.isSameDay(e.date, now);
                          final statusLabel = e.isCompleted
                              ? 'Completed'
                              : isOverdue
                              ? 'Overdue'
                              : isToday
                              ? 'Today'
                              : 'Upcoming';
                          final statusColor = e.isCompleted
                              ? theme.colorScheme.secondary
                              : isOverdue
                              ? theme.colorScheme.error
                              : isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant;
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: Dismissible(
                                  key: Key('${e.sourceType.name}_${e.id}'),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    return await showConfirmDeleteDialog(
                                      context,
                                      title: 'Delete ${e.category}?',
                                      message:
                                          'Are you sure you want to delete "${e.title}"?',
                                    );
                                  },
                                  onDismissed: (_) async {
                                    await _deleteEntry(e);
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: CustomCard(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      onTap: () => _openEditDialog(e),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: e.categoryColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              e.categoryIcon,
                                              color: e.categoryColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                AnimatedOpacity(
                                                  duration: const Duration(
                                                    milliseconds: 220,
                                                  ),
                                                  opacity: e.isCompleted
                                                      ? .55
                                                      : 1,
                                                  child: Text(
                                                    titlePreview,
                                                    maxLines: 3,
                                                    softWrap: true,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          _calculateTitleFontSize(
                                                            e.title,
                                                          ),
                                                      height: 1.25,
                                                      decoration: e.isCompleted
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                      color: e.isCompleted
                                                          ? Colors.grey
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  children: [
                                                    AppStatusBadge(
                                                      label: statusLabel,
                                                      color: statusColor,
                                                      icon: e.isCompleted
                                                          ? Icons
                                                              .check_circle_outline
                                                          : isOverdue
                                                          ? Icons.error_outline
                                                          : Icons
                                                              .schedule_outlined,
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                            horizontal: 8,
                                                            vertical: 2.5,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: e.categoryColor
                                                            .withValues(
                                                              alpha: 0.12,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                          color: e.categoryColor
                                                              .withValues(
                                                                alpha: 0.22,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        e.category,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              e.categoryColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  e.subtitle,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? theme.colorScheme
                                                              .onSurfaceVariant
                                                        : theme.colorScheme
                                                              .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (e.sourceType ==
                                                  ReminderSourceType.general)
                                                SizedBox(
                                                  width: 48,
                                                  height: 48,
                                                  child: Checkbox(
                                                    value: e.isCompleted,
                                                    activeColor: theme
                                                        .colorScheme
                                                        .primary,
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .padded,
                                                    semanticLabel:
                                                        'Mark ${e.title} complete',
                                                    shape:
                                                        RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                    onChanged: (val) =>
                                                        _toggleCompletion(
                                                          e,
                                                          val ?? false,
                                                        ),
                                                  ),
                                                ),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 48,
                                                      minHeight: 48,
                                                    ),
                                                icon: Icon(
                                                  Icons.edit_outlined,
                                                  size: 19,
                                                  color: isDark
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade700,
                                                ),
                                                onPressed: () =>
                                                    _openEditDialog(e),
                                                tooltip: 'Edit',
                                              ),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 48,
                                                      minHeight: 48,
                                                    ),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 19,
                                                ),
                                                onPressed: () async {
                                                  final confirm =
                                                      await showConfirmDeleteDialog(
                                                        context,
                                                        title:
                                                            'Delete ${e.category}?',
                                                        message:
                                                            'Are you sure you want to delete "${e.title}"?',
                                                      );
                                                  if (confirm) _deleteEntry(e);
                                                },
                                                tooltip: 'Delete',
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
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Reminder'),
      ),
    );
  }

  Future<void> _toggleCompletion(
    UnifiedReminderEntry entry,
    bool completed,
  ) async {
    if (entry.sourceType == ReminderSourceType.general) {
      final r = entry.originalObject as Reminder;
      if (completed) {
        final success = await ReminderCompletionService.instance
            .confirmAndCompleteReminder(context, r);
        if (!success) {
          await _loadReminders();
          return;
        }
      } else {
        await ReminderCompletionService.instance.uncompleteReminder(r);
      }
      await _loadReminders();
      return;
    }
  }

  Future<void> _deleteEntry(UnifiedReminderEntry entry) async {
    switch (entry.sourceType) {
      case ReminderSourceType.general:
        final r = entry.originalObject as Reminder;
        await NotificationService.instance.cancelNotificationForId(r.id);
        await _hive.deleteReminder(r.id);
        break;
      case ReminderSourceType.aiSubscription:
        final a = entry.originalObject as AIAccount;
        await NotificationService.instance.cancelNotificationForId(a.id);
        await _hive.deleteAIAccount(a.id);
        break;
      case ReminderSourceType.schoolClass:
        final c = entry.originalObject as SchoolClass;
        await NotificationService.instance.cancelNotificationForId(c.id);
        await _hive.deleteSchoolClass(c.id);
        await WidgetService.instance.updateSchoolWidget();
        break;
    }
    _loadReminders();
  }

  Future<void> _openAddDialog() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReminderDialog(),
    );
    if (result != null) await _loadReminders();
  }

  Future<void> _openEditDialog(UnifiedReminderEntry entry) async {
    dynamic result;
    switch (entry.sourceType) {
      case ReminderSourceType.general:
        result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              ReminderDialog(reminder: entry.originalObject as Reminder),
        );
        break;
      case ReminderSourceType.aiSubscription:
        result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              AIAccountDialog(account: entry.originalObject as AIAccount),
        );
        break;
      case ReminderSourceType.schoolClass:
        result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SchoolClassDialog(
            schoolClass: entry.originalObject as SchoolClass,
          ),
        );
        break;
    }
    if (result != null) await _loadReminders();
  }

  double _calculateTitleFontSize(String title) {
    final trimmed = title.trim();
    final length = trimmed.length;
    if (length == 0) return 15.0;
    final words = trimmed.split(RegExp(r'\s+'));
    int maxWordLength = 0;
    for (final w in words) {
      if (w.length > maxWordLength) maxWordLength = w.length;
    }

    if (length > 70 || maxWordLength >= 22) return 10.5;
    if (length > 48 || maxWordLength >= 16) return 11.5;
    if (length > 32 || maxWordLength >= 12) return 12.5;
    if (length > 18 || maxWordLength >= 8) return 13.5;
    return 15.0;
  }
}
