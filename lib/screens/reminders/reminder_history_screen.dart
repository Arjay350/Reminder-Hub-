import 'package:flutter/material.dart';
import '../../core/utilities/formatters.dart';
import '../../models/app_models.dart';
import '../../services/hive_service.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/empty_state.dart';

class ReminderHistoryScreen extends StatefulWidget {
  const ReminderHistoryScreen({super.key});

  @override
  State<ReminderHistoryScreen> createState() => _ReminderHistoryScreenState();
}

class _ReminderHistoryScreenState extends State<ReminderHistoryScreen> {
  final HiveService _hive = HiveService.instance;
  List<ReminderHistoryRecord> _records = [];
  String _searchQuery = '';
  String _selectedRecurrenceFilter = 'All'; // All, One-time, Recurring
  String _sortOrder = 'newest'; // newest, oldest, due_date

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _hive.remindersChangedNotifier.addListener(_loadHistory);
  }

  @override
  void dispose() {
    _hive.remindersChangedNotifier.removeListener(_loadHistory);
    super.dispose();
  }

  void _loadHistory() {
    if (!mounted) return;
    setState(() {
      _records = _hive.getReminderHistory();
    });
  }

  Future<void> _deleteRecord(ReminderHistoryRecord record) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete History Record?',
      message:
          'Are you sure you want to remove this completion record for "${record.title}"? '
          'The active reminder and its future occurrences will not be changed.',
      deleteButtonText: 'Delete',
    );

    if (confirmed) {
      await _hive.deleteReminderHistoryRecord(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History record removed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _clearAllHistory() async {
    if (_records.isEmpty) return;

    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Clear All Completion History?',
      message:
          'This will permanently delete all ${_records.length} completed reminder history records. '
          'Active and recurring reminders, bills, school classes, and other data will NOT be deleted.',
      deleteButtonText: 'Clear All History',
    );

    if (confirmed) {
      await _hive.clearReminderHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completion history cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _records.where((r) {
      if (_selectedRecurrenceFilter == 'One-time' &&
          r.repeat.trim().isNotEmpty &&
          r.repeat.trim().toLowerCase() != 'none') {
        return false;
      }
      if (_selectedRecurrenceFilter == 'Recurring' &&
          (r.repeat.trim().isEmpty ||
              r.repeat.trim().toLowerCase() == 'none')) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = r.title.toLowerCase().contains(q);
        final matchesCat = r.category.toLowerCase().contains(q);
        final matchesNotes = r.notes.toLowerCase().contains(q);
        if (!matchesTitle && !matchesCat && !matchesNotes) return false;
      }
      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      if (_sortOrder == 'oldest') {
        return a.completedAt.compareTo(b.completedAt);
      } else if (_sortOrder == 'due_date') {
        return b.originalDueDate.compareTo(a.originalDueDate);
      }
      // default: newest completed first
      return b.completedAt.compareTo(a.completedAt);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Completion History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              tooltip: 'Clear All History',
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search completed reminders...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
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

          // Filters & Sort Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'One-time', 'Recurring'].map((filter) {
                        final isSelected = _selectedRecurrenceFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (_) => setState(
                              () => _selectedRecurrenceFilter = filter,
                            ),
                            selectedColor: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                            checkmarkColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.3,
                                      )
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort_rounded, size: 20),
                  tooltip: 'Sort By',
                  initialValue: _sortOrder,
                  onSelected: (val) => setState(() => _sortOrder = val),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'newest',
                      child: Text('Most Recently Completed'),
                    ),
                    PopupMenuItem(
                      value: 'oldest',
                      child: Text('Oldest Completed First'),
                    ),
                    PopupMenuItem(
                      value: 'due_date',
                      child: Text('Original Due Date'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // History List
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    title: _searchQuery.isNotEmpty
                        ? 'No matching records'
                        : _records.isEmpty
                        ? 'No completion history yet'
                        : 'No ${_selectedRecurrenceFilter.toLowerCase()} history',
                    message: _searchQuery.isNotEmpty
                        ? 'No completed reminders match "$_searchQuery"'
                        : _records.isEmpty
                        ? 'When you mark reminders as complete, a permanent record of each completion will be safely stored here.'
                        : 'No completed records in this filter view.',
                    icon: Icons.history_rounded,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isRecurring =
                          item.repeat.trim().isNotEmpty &&
                          item.repeat.trim().toLowerCase() != 'none';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: CustomCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: item.categoryColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.categoryIcon,
                                  color: item.categoryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            softWrap: true,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: _calculateTitleFontSize(
                                                item.title,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: item.categoryColor
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            item.category,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: item.categoryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        AppStatusBadge(
                                          label: 'Completed',
                                          color: Colors.green,
                                          icon: Icons.check_circle_outline,
                                        ),
                                        if (isRecurring)
                                          AppStatusBadge(
                                            label: item.repeat,
                                            color: theme.colorScheme.primary,
                                            icon: Icons.repeat_rounded,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Due: ${Formatters.formatDate(item.originalDueDate)}${item.time.isNotEmpty ? " • ${item.time}" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Completed: ${Formatters.formatDate(item.completedAt)} at ${Formatters.formatTime(item.completedAt)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                    if (item.notes.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.notes,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.8),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip: 'Delete this history record',
                                onPressed: () => _deleteRecord(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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
