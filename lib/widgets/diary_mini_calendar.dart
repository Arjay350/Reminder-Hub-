import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DiaryMiniCalendar extends StatelessWidget {
  const DiaryMiniCalendar({
    super.key,
    required this.displayedMonth,
    required this.selectedDate,
    required this.entryCounts,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final DateTime displayedMonth;
  final DateTime? selectedDate;
  final Map<DateTime, int> entryCounts;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final monthStart = DateTime(displayedMonth.year, displayedMonth.month);
    final daysInMonth = DateUtils.getDaysInMonth(
      displayedMonth.year,
      displayedMonth.month,
    );
    final leadingDays = monthStart.weekday - DateTime.monday;
    final weekCount = weeksInDisplayedMonth(monthStart);
    final today = dateOnly(DateTime.now());
    final normalizedCounts = <DateTime, int>{
      for (final entry in entryCounts.entries) dateOnly(entry.key): entry.value,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('MMMM y').format(monthStart),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                onPressed: () => onMonthChanged(
                  DateTime(displayedMonth.year, displayedMonth.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                onPressed: () => onMonthChanged(
                  DateTime(displayedMonth.year, displayedMonth.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final weekday in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < weekCount; row++)
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _buildDateCell(
                      context,
                      dayNumber: row * 7 + column - leadingDays + 1,
                      daysInMonth: daysInMonth,
                      today: today,
                      normalizedCounts: normalizedCounts,
                      primary: primary,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateCell(
    BuildContext context, {
    required int dayNumber,
    required int daysInMonth,
    required DateTime today,
    required Map<DateTime, int> normalizedCounts,
    required Color primary,
  }) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 38);
    }

    final theme = Theme.of(context);
    final date = DateTime(displayedMonth.year, displayedMonth.month, dayNumber);
    final selected =
        selectedDate != null && DateUtils.isSameDay(date, selectedDate);
    final isToday = DateUtils.isSameDay(date, today);
    final count = normalizedCounts[date] ?? 0;

    return SizedBox(
      height: 38,
      child: Semantics(
        key: ValueKey(
          'diary-date-semantics-${date.year}-${date.month}-${date.day}',
        ),
        button: true,
        selected: selected,
        label: [
          DateFormat('EEEE, MMMM d, y').format(date),
          if (count == 1) '1 diary entry',
          if (count > 1) '$count diary entries',
          if (isToday) 'today',
        ].join(', '),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Material(
              color: selected ? primary : Colors.transparent,
              shape: CircleBorder(
                side: BorderSide(
                  color: isToday && !selected ? primary : Colors.transparent,
                  width: 1.3,
                ),
              ),
              child: InkWell(
                key: ValueKey(
                  'diary-date-${date.year}-${date.month}-${date.day}',
                ),
                customBorder: const CircleBorder(),
                onTap: () => onDateSelected(date),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight: selected || isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: count > 0 ? 4 : 2,
                      height: 2,
                      decoration: BoxDecoration(
                        color: count > 0
                            ? selected
                                  ? theme.colorScheme.onPrimary
                                  : primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
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

  static int daysInDisplayedMonth(DateTime month) =>
      DateUtils.getDaysInMonth(month.year, month.month);

  static int weeksInDisplayedMonth(DateTime month) {
    final leadingDays =
        DateTime(month.year, month.month).weekday - DateTime.monday;
    return ((leadingDays + daysInDisplayedMonth(month)) / 7).ceil();
  }
}
