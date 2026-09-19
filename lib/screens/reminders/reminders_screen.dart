import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/utilities/formatters.dart';
import '../../models/app_models.dart';
import '../../services/hive_service.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../widgets/ai_account_dialog.dart';
import '../../widgets/bill_dialog.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/reminder_dialog.dart';
import '../../widgets/school_class_dialog.dart';

enum ReminderSourceType { general, bill, aiReset, aiSubscription, schoolClass }

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

  final List<String> _categories = [
    'All',
    'Bills',
    'AI Reset',
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
    _loadReminders();
  }

  @override
  void dispose() {
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
    int hour = 9;
    int minute = 0;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final numPart = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = numPart.split(':');
      hour = int.parse(parts[0]);
      if (parts.length > 1) {
        minute = int.parse(parts[1]);
      }
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
    } catch (_) {
      hour = 9;
      minute = 0;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<void> _loadReminders() async {
    await _hive.ensureInitialized();
    if (!mounted) return;

    final reminders = _hive.getReminders();
    final bills = _hive.getBills();
    final aiAccounts = _hive.getAIAccounts();
    final schoolClasses = _hive.getSchoolClasses();
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

    // 2. Connected Bills (Dynamic aggregation from Bills Tracker)
    for (final b in bills) {
      final repeatLabel = b.repeat == 'None' || b.repeat.isEmpty
          ? 'One-time'
          : '${b.repeat} recurring';
      final statusLabel = b.statusLabel;

      entries.add(
        UnifiedReminderEntry(
          id: b.id,
          title: 'Bill: ${b.name}',
          category: 'Bills',
          subtitle:
              '${Formatters.formatCurrency(b.amount)} • Due ${Formatters.formatDate(b.dueDate)} • $repeatLabel • $statusLabel',
          date: b.dueDate,
          time: '09:00 AM',
          priority: b.isOverdue ? 'High' : (b.paid ? 'Low' : 'Medium'),
          isCompleted: b.paid,
          categoryColor: const Color(0xFF10B981),
          categoryIcon: Icons.receipt_long,
          sourceType: ReminderSourceType.bill,
          originalObject: b,
        ),
      );
    }

    // 3. Connected AI Resets (Dynamic aggregation from AI Accounts)
    for (final a in aiAccounts) {
      final sched = a.resetSchedule.trim().toLowerCase();
      DateTime targetDate = a.resetDate;
      String subtitle;
      if (sched == 'daily') {
        final resetToday = _parseEntryDateTime(now, a.resetTime);
        targetDate = resetToday.isBefore(now)
            ? DateTime(now.year, now.month, now.day + 1)
            : DateTime(now.year, now.month, now.day);
        subtitle =
            '${a.accountName} (${a.plan}) • Usage reset daily at ${a.resetTime}';
      } else if (sched == 'weekly') {
        int diff = a.resetDate.weekday - now.weekday;
        if (diff < 0) diff += 7;
        if (diff == 0) {
          final resetToday = _parseEntryDateTime(now, a.resetTime);
          if (resetToday.isBefore(now)) diff = 7;
        }
        targetDate = DateTime(now.year, now.month, now.day + diff);
        subtitle =
            '${a.accountName} (${a.plan}) • Usage reset weekly at ${a.resetTime}';
      } else if (sched == 'monthly') {
        DateTime candidate = DateTime(now.year, now.month, a.resetDate.day);
        final resetCandidate = _parseEntryDateTime(candidate, a.resetTime);
        if (resetCandidate.isBefore(now)) {
          candidate = DateTime(now.year, now.month + 1, a.resetDate.day);
        }
        targetDate = candidate;
        subtitle =
            '${a.accountName} (${a.plan}) • Usage reset monthly at ${a.resetTime}';
      } else {
        targetDate = a.resetDate;
        subtitle =
            '${a.accountName} (${a.plan}) • Usage reset on ${Formatters.formatShortDate(a.resetDate)} at ${a.resetTime}';
      }

      entries.add(
        UnifiedReminderEntry(
          id: 'ai_reset_${a.id}',
          title: 'AI Reset: ${a.service}',
          category: 'AI Reset',
          subtitle: subtitle,
          date: targetDate,
          time: a.resetTime,
          priority: 'Medium',
          isCompleted: false,
          categoryColor: a.serviceColor,
          categoryIcon: Icons.smart_toy,
          sourceType: ReminderSourceType.aiReset,
          originalObject: a,
        ),
      );
    }

    // 4. Connected AI Subscription Renewals (for Paid plans only)
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

    // 5. Connected School Classes (Next recurring occurrence)
    for (final c in schoolClasses) {
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
    });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reminders Hub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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
            // Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search tasks, bills, AI resets, school...',
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
                      title: 'No reminders found',
                      message: _searchQuery.isNotEmpty
                          ? 'No reminders matching "$_searchQuery"'
                          : 'Create your first reminder to keep track of tasks, bills, AI resets & school.',
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
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
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
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                e.title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
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
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: e.categoryColor
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                e.category,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: e.categoryColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Text(
                                            e.subtitle,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (e.sourceType ==
                                                    ReminderSourceType
                                                        .general ||
                                                e.sourceType ==
                                                    ReminderSourceType.bill)
                                              Transform.scale(
                                                scale: 0.9,
                                                child: Checkbox(
                                                  value: e.isCompleted,
                                                  activeColor:
                                                      theme.colorScheme.primary,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  onChanged: (val) =>
                                                      _toggleCompletion(
                                                        e,
                                                        val ?? false,
                                                      ),
                                                ),
                                              ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                size: 20,
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade700,
                                              ),
                                              onPressed: () =>
                                                  _openEditDialog(e),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 20,
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
                                            ),
                                          ],
                                        ),
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

  /// Shows the recurring-payment confirmation dialog.
  /// Returns true when the user confirms, false on cancel.
  Future<bool> _showRecurringPayConfirmation(
    Bill bill,
    DateTime currentDate,
    DateTime nextDate,
  ) async {
    final currentDateStr = Formatters.formatDate(currentDate);
    final nextDateStr = Formatters.formatDate(nextDate);
    final settings = HiveService.instance.getSettings();
    final currency = settings.currency;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Mark Bill as Paid?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bill.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '$currency${bill.amount.toStringAsFixed(2)} • Due $currentDateStr',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'After marking as paid:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _confirmBullet(
              '$currentDateStr will be recorded in payment history',
            ),
            _confirmBullet('The next bill will be due $nextDateStr'),
            _confirmBullet('The new $nextDateStr bill will be marked UNPAID'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _confirmBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _toggleCompletion(
    UnifiedReminderEntry entry,
    bool completed,
  ) async {
    if (entry.sourceType == ReminderSourceType.general) {
      // General reminder: simple completed toggle.
      final r = (entry.originalObject as Reminder).copyWith(
        completed: completed,
      );
      await _hive.saveReminder(r);
      if (completed) {
        await NotificationService.instance.cancelNotificationForId(r.id);
      } else {
        // Attempt to reschedule — this silently skips if the date is in the past.
        await NotificationService.instance.scheduleReminderNotification(r);

        // Warn the user if the reminder time has already passed so they know
        // to update the date (the notification won't fire for a past one-time reminder).
        final parts = r.time.split(':');
        final hour = int.tryParse(parts[0]) ?? 9;
        final minute = parts.length > 1
            ? (int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
            : 0;
        final notifyAt = DateTime(
          r.date.year,
          r.date.month,
          r.date.day,
          hour,
          minute,
        );
        if (notifyAt.isBefore(DateTime.now()) &&
            r.repeat.toLowerCase() == 'none') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reminder date is in the past — update it so the notification fires.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade700,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Edit',
                  textColor: Colors.white,
                  onPressed: () {
                    // Re-use the existing open-edit flow via entry
                    _openEditDialog(entry);
                  },
                ),
              ),
            );
          }
        }
      }
      await _loadReminders();
      return;
    }

    if (entry.sourceType == ReminderSourceType.bill) {
      final bill = entry.originalObject as Bill;

      // ── Toggling OFF (currently paid non-recurring bill → mark unpaid) ───
      if (!completed) {
        if (bill.paid) {
          final updated = bill.copyWith(paid: false);
          await _hive.saveBill(updated);
          await NotificationService.instance.scheduleBillNotification(updated);
          try {
            await WidgetService.instance.updateBillsWidget();
          } catch (_) {}
          await _loadReminders();
        }
        return;
      }

      // ── Toggling ON (marking as paid) — non-recurring ─────────────────
      if (!bill.isRecurring) {
        final updated = bill.copyWith(paid: true);
        await _hive.saveBill(updated);
        await NotificationService.instance.cancelNotificationForId(bill.id);
        try {
          await WidgetService.instance.updateBillsWidget();
        } catch (_) {}
        await _loadReminders();
        return;
      }

      // ── Recurring bill: record payment for current occurrence ──────────
      final nextDate = bill.getNextOccurrence(bill.dueDate);

      // Show confirmation dialog before committing the recurring payment.
      if (!mounted) return;
      final confirmed = await _showRecurringPayConfirmation(
        bill,
        bill.dueDate,
        nextDate,
      );
      if (!confirmed || !mounted) return;

      // Step 1: Record completed occurrence in payment history.
      final payment = BillPayment(
        occurrenceDate: bill.dueDate,
        paidDate: DateTime.now(),
        amount: bill.amount,
      );
      final newHistory = [...bill.paymentHistory, payment];

      // Step 2 & 3: Advance dueDate to next occurrence and reset paid to false.
      final updated = bill.copyWith(
        dueDate: nextDate,
        paid: false,
        paymentHistory: newHistory,
      );

      // Step 4: Save to Hive
      await _hive.saveBill(updated);

      // Step 5: Cancel old notification and schedule for the next due date
      await NotificationService.instance.cancelNotificationForId(bill.id);
      await NotificationService.instance.scheduleBillNotification(updated);

      // Step 6: Update widgets and reload
      try {
        await WidgetService.instance.updateBillsWidget();
      } catch (_) {}
      _loadReminders();
    }
  }

  Future<void> _deleteEntry(UnifiedReminderEntry entry) async {
    switch (entry.sourceType) {
      case ReminderSourceType.general:
        final r = entry.originalObject as Reminder;
        await NotificationService.instance.cancelNotificationForId(r.id);
        await _hive.deleteReminder(r.id);
        break;
      case ReminderSourceType.bill:
        final b = entry.originalObject as Bill;
        await NotificationService.instance.cancelNotificationForId(b.id);
        await _hive.deleteBill(b.id);
        // Update Bills widget
        try {
          await WidgetService.instance.updateBillsWidget();
        } catch (e) {
          debugPrint('WidgetService.updateBillsWidget error: $e');
        }
        break;
      case ReminderSourceType.aiReset:
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
      case ReminderSourceType.bill:
        result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BillDialog(bill: entry.originalObject as Bill),
        );
        break;
      case ReminderSourceType.aiReset:
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
}
