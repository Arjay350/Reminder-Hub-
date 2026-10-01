import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import '../../core/utilities/formatters.dart';
import '../../models/app_models.dart';
import '../../services/hive_service.dart';
import '../../widgets/custom_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final HiveService _hive = HiveService.instance;

  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  List<Reminder> _reminders = [];
  List<SchoolClass> _schoolClasses = [];
  List<Bill> _bills = [];
  List<AIAccount> _aiAccounts = [];
  List<Birthday> _birthdays = [];
  bool _hideSchoolSchedule = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    await _hive.ensureInitialized();
    if (!mounted) return;
    final settings = _hive.getSettings();
    setState(() {
      _hideSchoolSchedule = settings.hideSchoolScheduleInCalendar;
      _reminders = _hive.getReminders();
      _schoolClasses = _hive.getSchoolClasses();
      _bills = _hive.getBills();
      _aiAccounts = _hive.getAIAccounts();
      _birthdays = _hive.getBirthdays();
    });
  }

  Future<void> _toggleHideSchoolSchedule() async {
    final newValue = !_hideSchoolSchedule;
    setState(() {
      _hideSchoolSchedule = newValue;
    });
    final settings = _hive.getSettings();
    await _hive.saveSettings(
      settings.copyWith(hideSchoolScheduleInCalendar: newValue),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newValue
              ? 'School schedule hidden from calendar (School reminders like assignments & projects remain visible)'
              : 'School schedule shown in calendar',
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: _toggleHideSchoolSchedule,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final eventsForSelected = _getEventsForDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _hideSchoolSchedule
                      ? Icons.school_outlined
                      : Icons.school_rounded,
                  color: _hideSchoolSchedule
                      ? Colors.grey
                      : const Color(0xFF14B8A6),
                ),
                if (_hideSchoolSchedule)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: _hideSchoolSchedule
                ? 'Show School Schedule (Classes Hidden)'
                : 'Hide School Schedule',
            onPressed: _toggleHideSchoolSchedule,
          ),
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Go to Today',
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
                _focusedMonth = DateTime.now();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month navigation header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month - 1,
                          );
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month + 1,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Days of week header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildCalendarGrid(),
          ),

          const Divider(height: 24, thickness: 1.2),

          // Events list for selected date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          Formatters.isSameDay(_selectedDate, DateTime.now())
                              ? 'Today\'s Events'
                              : DateFormat('EEEE, MMM d').format(_selectedDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_hideSchoolSchedule) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'School schedule is hidden. Tap to show.',
                          child: InkWell(
                            onTap: _toggleHideSchoolSchedule,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.amber.shade900.withValues(
                                        alpha: 0.3,
                                      )
                                    : Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 13,
                                    color: isDark
                                        ? Colors.amber.shade300
                                        : Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Classes Hidden',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${eventsForSelected.length} events',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: eventsForSelected.isEmpty
                ? Center(
                    child: Text(
                      'No events scheduled for this date.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  )
                : AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      itemCount: eventsForSelected.length,
                      itemBuilder: (context, index) {
                        final item = eventsForSelected[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 300),
                          child: SlideAnimation(
                            verticalOffset: 30.0,
                            child: FadeInAnimation(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: CustomCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: item.color.withValues(
                                          alpha: 0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        item.icon,
                                        color: item.color,
                                        size: 22,
                                      ),
                                    ),
                                    title: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        item.subtitle,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: item.color.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.typeLabel,
                                        style: TextStyle(
                                          color: item.color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
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
    );
  }

  Widget _buildCalendarGrid() {
    final theme = Theme.of(context);
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final firstWeekday =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7;

    final totalCells = daysInMonth + firstWeekday;
    final totalRows = (totalCells / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalRows * 7,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        if (index < firstWeekday || index >= totalCells) {
          return const SizedBox.shrink();
        }

        final dayNumber = index - firstWeekday + 1;
        final cellDate = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          dayNumber,
        );
        final isSelected = Formatters.isSameDay(cellDate, _selectedDate);
        final isToday = Formatters.isSameDay(cellDate, DateTime.now());
        final events = _getEventsForDate(cellDate);

        return InkWell(
          onTap: () => setState(() => _selectedDate = cellDate),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: !isSelected && isToday
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: isToday && !isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                  : Border.all(color: Colors.transparent, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                    color: isSelected
                        ? Colors.white
                        : isToday
                        ? theme.colorScheme.primary
                        : null,
                  ),
                ),
                if (events.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.take(3).map((e) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : e.color,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<_CalendarEventItem> _getEventsForDate(DateTime date) {
    final List<_CalendarEventItem> items = [];

    // Reminders
    for (final r in _reminders) {
      if (Formatters.isSameDay(r.date, date)) {
        items.add(
          _CalendarEventItem(
            title: r.title,
            subtitle:
                '${r.time} • ${r.description.isEmpty ? r.notes : r.description}',
            typeLabel: r.category,
            icon: r.categoryIcon,
            color: r.categoryColor,
          ),
        );
      }
    }

    // School Classes (Recurring on day-of-week) - only when not hidden
    if (!_hideSchoolSchedule) {
      for (final c in _schoolClasses) {
        if (c.occursOnDay(date.weekday)) {
          items.add(
            _CalendarEventItem(
              title: c.subject,
              subtitle:
                  '${c.timeRange}${c.room.isNotEmpty ? " • Room: ${c.room}" : ""}${c.teacher.isNotEmpty ? " • ${c.teacher}" : ""}',
              typeLabel: 'School',
              icon: Icons.school_rounded,
              color: c.color,
            ),
          );
        }
      }
    }

    // Bills
    for (final b in _bills) {
      if (Formatters.isSameDay(b.dueDate, date)) {
        items.add(
          _CalendarEventItem(
            title: b.name,
            subtitle:
                'Amount: ${Formatters.formatCurrency(b.amount)} • ${b.statusLabel}',
            typeLabel: 'Bill',
            icon: Icons.receipt_long,
            color: b.paid
                ? Colors.green
                : (b.isOverdue ? Colors.red : const Color(0xFF10B981)),
          ),
        );
      }
      for (final p in b.paymentHistory) {
        if (Formatters.isSameDay(p.paidDate, date) &&
            !Formatters.isSameDay(b.dueDate, date)) {
          items.add(
            _CalendarEventItem(
              title: '${b.name} (Paid)',
              subtitle: 'Amount: ${Formatters.formatCurrency(p.amount)} • Paid',
              typeLabel: 'Bill Paid',
              icon: Icons.check_circle_rounded,
              color: Colors.green,
            ),
          );
        }
      }
    }

    // AI Accounts exact quota reset date
    for (final a in _aiAccounts) {
      final sched = a.resetSchedule.trim().toLowerCase();
      final matchesDate = sched == 'daily'
          ? !DateTime(date.year, date.month, date.day).isBefore(
              DateTime(a.resetDate.year, a.resetDate.month, a.resetDate.day),
            )
          : sched == 'weekly'
          ? !DateTime(date.year, date.month, date.day).isBefore(
                  DateTime(
                    a.resetDate.year,
                    a.resetDate.month,
                    a.resetDate.day,
                  ),
                ) &&
                date.weekday == a.resetDate.weekday
          : sched == 'monthly'
          ? !DateTime(date.year, date.month, date.day).isBefore(
                  DateTime(
                    a.resetDate.year,
                    a.resetDate.month,
                    a.resetDate.day,
                  ),
                ) &&
                date.day == a.resetDate.day
          : Formatters.isSameDay(a.resetDate, date);
      if (matchesDate) {
        items.add(
          _CalendarEventItem(
            title: '${a.service} Reset',
            subtitle:
                '${a.accountName} (${a.plan}) • Usage reset at ${a.resetTime}',
            typeLabel: 'AI Reset',
            icon: Icons.smart_toy,
            color: const Color(0xFF8B5CF6),
          ),
        );
      }

      // AI Accounts subscription renewal (for paid plans only)
      if (!a.isFreePlan && Formatters.isSameDay(a.renewalDate, date)) {
        items.add(
          _CalendarEventItem(
            title: '${a.service} Subscription Renewal',
            subtitle: '${a.accountName} • Plan: ${a.plan}',
            typeLabel: 'AI Renewal',
            icon: Icons.event_repeat,
            color: const Color(0xFFEC4899),
          ),
        );
      }
    }

    // Birthdays
    for (final birthday in _birthdays) {
      final birthdayDate = birthday.nextBirthdayDateFor(date);
      if (Formatters.isSameDay(birthdayDate, date)) {
        final ageText = birthday.turningAgeFor(date) == null
            ? ''
            : ' • Turns ${birthday.turningAgeFor(date)}';
        final isUser = birthday.isUserBirthday;
        items.add(
          _CalendarEventItem(
            title: isUser ? '🎂 Your Birthday' : birthday.name,
            subtitle: isUser
                ? 'Celebration day${birthday.giftIdeas.isNotEmpty ? ' • Gift: ${birthday.giftIdeas}' : ''}'
                : '${birthday.relationship}$ageText${birthday.giftIdeas.isNotEmpty ? ' • Gift: ${birthday.giftIdeas}' : ''}',
            typeLabel: isUser ? 'Your Birthday' : 'Birthday',
            icon: Icons.cake_rounded,
            color: isUser ? const Color(0xFFEC4899) : const Color(0xFFF472B6),
          ),
        );
      }
    }

    return items;
  }
}

class _CalendarEventItem {
  _CalendarEventItem({
    required this.title,
    required this.subtitle,
    required this.typeLabel,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String typeLabel;
  final IconData icon;
  final Color color;
}
