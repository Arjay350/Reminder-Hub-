import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../models/diary_models.dart';
import '../../services/hive_service.dart';
import '../../services/notebook_service.dart';
import '../../widgets/diary_mood_filter.dart';
import '../../widgets/diary_mini_calendar.dart';
import 'notebook_detail_screen.dart';
import 'notebook_editor_screen.dart';

class DiaryNotesScreen extends StatefulWidget {
  const DiaryNotesScreen({
    super.key,
    this.initialDate,
    this.initialTab = 0,
    this.initialDiaryEntryId,
    this.initialNoteId,
  });

  final DateTime? initialDate;
  final int initialTab;
  final String? initialDiaryEntryId;
  final String? initialNoteId;

  @override
  State<DiaryNotesScreen> createState() => _DiaryNotesScreenState();
}

class _DiaryNotesScreenState extends State<DiaryNotesScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;
  List<DiaryEntry> _entries = [];
  List<NotebookNote> _notes = [];
  List<SchoolClass> _schoolClasses = [];
  Map<DateTime, int> _dateCounts = {};
  String _query = '';
  String? _selectedMood;
  String _diaryCategory = 'All';
  String _noteCategory = 'All';
  String _noteSubject = 'All';
  String _noteSort = 'Pinned first';
  late DateTime? _selectedDate;
  late DateTime _displayedMonth;
  bool _loading = true;
  bool _openingInitialItem = false;

  @override
  void initState() {
    super.initState();
    final initialDate = widget.initialDate?.toLocal() ?? DateTime.now();
    _selectedDate = _dateOnly(initialDate);
    _displayedMonth = DateTime(initialDate.year, initialDate.month);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == 1 ? 1 : 0,
    );
    _searchController.addListener(() {
      if (mounted) setState(() => _query = _searchController.text);
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await HiveService.instance.ensureInitialized();
    if (!mounted) return;
    final loadAllEntries =
        (widget.initialDiaryEntryId != null && !_openingInitialItem) ||
        _selectedDate == null;
    final entries = loadAllEntries
        ? NotebookService.instance.getDiaryEntries()
        : HiveService.instance.getDiaryEntriesForDate(_selectedDate!);
    setState(() {
      _entries = entries..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _dateCounts = HiveService.instance.getDiaryEntryDateCounts();
      _notes = NotebookService.instance.getNotes();
      _schoolClasses = HiveService.instance.getSchoolClasses();
      _loading = false;
    });
    if (_openingInitialItem) return;
    final entryId = widget.initialDiaryEntryId;
    final noteId = widget.initialNoteId;
    if (entryId != null || noteId != null) {
      _openingInitialItem = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (entryId != null) {
          for (final entry in _entries) {
            if (entry.id == entryId) {
              _setSelectedDate(_entryDate(entry));
              _openDiary(entry);
              break;
            }
          }
        } else if (noteId != null) {
          for (final note in _notes) {
            if (note.id == noteId) {
              _openNote(note);
              break;
            }
          }
        }
      });
    }
  }

  Future<void> _createDiaryEntry() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NotebookEditorScreen(isDiary: true, initialDate: _selectedDate),
      ),
    );
    await _load();
  }

  Future<void> _createNote() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotebookEditorScreen(isDiary: false),
      ),
    );
    await _load();
  }

  Future<void> _openDiary(DiaryEntry entry) async {
    try {
      final opened = await NotebookService.instance.openDiaryEntry(entry);
      if (!mounted) return;
      if (opened == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication was cancelled.')),
        );
        return;
      }
      await Navigator.of(context).push<Object?>(
        MaterialPageRoute(
          builder: (_) => NotebookDetailScreen.diary(entry: opened),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open this diary entry: $error')),
        );
      }
    }
  }

  Future<void> _openNote(NotebookNote note) async {
    try {
      final opened = await NotebookService.instance.openNote(note);
      if (!mounted) return;
      if (opened == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication was cancelled.')),
        );
        return;
      }
      await Navigator.of(context).push<Object?>(
        MaterialPageRoute(
          builder: (_) => NotebookDetailScreen.note(note: opened),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open this note: $error')),
        );
      }
    }
  }

  Future<void> _setSelectedDate(DateTime date) async {
    final localDate = _dateOnly(date.toLocal());
    setState(() {
      _selectedDate = localDate;
      _displayedMonth = DateTime(localDate.year, localDate.month);
      _loading = true;
    });
    await _load();
  }

  Future<void> _showToday() => _setSelectedDate(DateTime.now());

  Future<void> _showAllDates() async {
    setState(() {
      _selectedDate = null;
      _loading = true;
    });
    await _load();
  }

  void _clearDiaryFilters() {
    _searchController.clear();
    setState(() {
      _selectedMood = null;
      _diaryCategory = 'All';
    });
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _entryDate(DiaryEntry entry) => _dateOnly(entry.createdAt.toLocal());

  Future<void> _confirmAndDelete(String id, {required bool diary}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete this ${diary ? 'diary entry' : 'note'}?'),
        content: const Text('This item will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (diary) {
      await NotebookService.instance.deleteDiaryEntry(id);
    } else {
      await NotebookService.instance.deleteNote(id);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Diary & Notes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Diary'),
            Tab(icon: Icon(Icons.notes_outlined), text: 'Notes'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildDiaryTab(theme), _buildNotesTab(theme)],
            ),
    );
  }

  Widget _buildDiaryTab(ThemeData theme) {
    final matchingEntries = _entries.where((entry) {
      if (entry.isLocked) {
        if (_selectedMood != null || _diaryCategory != 'All') {
          return false;
        }
        if (_selectedDate != null &&
            !_sameDay(_entryDate(entry), _selectedDate!)) {
          return false;
        }
        return _query.trim().isEmpty;
      }
      if (!NotebookService.instance.diaryMatches(entry, _query)) return false;
      if (_selectedMood != null && entry.mood != _selectedMood) return false;
      if (_diaryCategory != 'All' && entry.category != _diaryCategory) {
        return false;
      }
      if (_selectedDate != null &&
          !_sameDay(_entryDate(entry), _selectedDate!)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final selectedDateCount = _selectedDate == null
        ? null
        : _dateCounts[_selectedDate!] ?? 0;
    final hasAdditionalFilters =
        _selectedMood != null ||
        _diaryCategory != 'All' ||
        _query.trim().isNotEmpty;
    final hasDiaryEntries = _dateCounts.isNotEmpty;
    final shouldOfferFilterReset =
        hasAdditionalFilters &&
        (_selectedDate == null
            ? hasDiaryEntries
            : (selectedDateCount ?? 0) > 0);
    final historyWidgets = <Widget>[];
    if (_selectedDate == null) {
      DateTime? currentDate;
      for (final entry in matchingEntries) {
        final entryDate = _entryDate(entry);
        if (currentDate == null || !_sameDay(entryDate, currentDate)) {
          currentDate = entryDate;
          historyWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(
                DateFormat('EEEE, MMMM d, y').format(entryDate),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }
        historyWidgets.add(_diaryCard(entry));
      }
    } else {
      historyWidgets.addAll(matchingEntries.map((entry) => _diaryCard(entry)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        Text(
          'Your thoughts, memories & everyday moments',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        DiaryMiniCalendar(
          displayedMonth: _displayedMonth,
          selectedDate: _selectedDate,
          entryCounts: _dateCounts,
          onMonthChanged: (month) {
            setState(() {
              _displayedMonth = DateTime(month.year, month.month);
            });
          },
          onDateSelected: (date) => _setSelectedDate(date),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: _showToday,
              icon: const Icon(Icons.today_outlined, size: 18),
              label: const Text('Today'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _selectedDate == null ? null : _showAllDates,
              child: const Text('All dates'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    _selectedDate?.isAfter(_dateOnly(DateTime.now())) == true
                    ? null
                    : _createDiaryEntry,
                icon: const Icon(Icons.edit_note),
                label: Text(
                  _selectedDate == null ||
                          _sameDay(_selectedDate!, _dateOnly(DateTime.now()))
                      ? "Write Today's Entry"
                      : _selectedDate!.isAfter(_dateOnly(DateTime.now()))
                      ? 'Future date'
                      : 'Write Entry',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          _selectedDate == null
              ? 'Diary History'
              : DateFormat('MMMM d, y').format(_selectedDate!),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _selectedDate == null
              ? '${matchingEntries.length} ${matchingEntries.length == 1 ? 'entry' : 'entries'}'
              : hasAdditionalFilters
              ? '${matchingEntries.length} of $selectedDateCount ${selectedDateCount == 1 ? 'entry' : 'entries'}'
              : selectedDateCount == 0
              ? 'No diary entries'
              : '$selectedDateCount ${selectedDateCount == 1 ? 'diary entry' : 'diary entries'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _searchField('Search your diary...'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _diaryCategory,
          decoration: const InputDecoration(
            labelText: 'Category',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: const ['All', 'Personal', 'School', 'Work', 'Ideas', 'Other']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _diaryCategory = value);
          },
        ),
        const SizedBox(height: 12),
        DiaryMoodFilter(
          selectedMood: _selectedMood,
          onChanged: (mood) => setState(() => _selectedMood = mood),
        ),
        const SizedBox(height: 20),
        if (matchingEntries.isEmpty)
          _emptyState(
            icon: _selectedDate == null
                ? Icons.menu_book_outlined
                : Icons.event_note_outlined,
            title: _emptyDiaryTitle(
              selectedDateCount: selectedDateCount,
              hasAdditionalFilters: hasAdditionalFilters,
            ),
            message: _emptyDiaryMessage(
              selectedDateCount: selectedDateCount,
              hasAdditionalFilters: hasAdditionalFilters,
            ),
            actionLabel:
                _selectedDate != null &&
                    (selectedDateCount ?? 0) > 0 &&
                    hasAdditionalFilters
                ? _selectedMood != null
                      ? 'Clear Mood Filter'
                      : _query.trim().isNotEmpty
                      ? 'Clear Search'
                      : 'Reset Category'
                : _selectedDate == null && shouldOfferFilterReset
                ? _selectedMood != null
                      ? 'Clear Mood Filter'
                      : _query.trim().isNotEmpty
                      ? 'Clear Search'
                      : 'Reset Category'
                : _emptyDiaryAction(),
            onPressed:
                _selectedDate != null &&
                    _selectedDate!.isAfter(_dateOnly(DateTime.now()))
                ? _showToday
                : _selectedDate != null &&
                      (selectedDateCount ?? 0) > 0 &&
                      hasAdditionalFilters
                ? _clearDiaryFilters
                : _selectedDate == null && shouldOfferFilterReset
                ? _clearDiaryFilters
                : _createDiaryEntry,
          )
        else
          ...historyWidgets,
      ],
    );
  }

  String _emptyDiaryTitle({
    required int? selectedDateCount,
    required bool hasAdditionalFilters,
  }) {
    if (_selectedDate == null) {
      return _dateCounts.isNotEmpty && hasAdditionalFilters
          ? 'No entries match these filters'
          : 'Your diary is empty';
    }
    if (_selectedDate!.isAfter(_dateOnly(DateTime.now()))) {
      return 'This date is in the future';
    }
    if ((selectedDateCount ?? 0) > 0 && hasAdditionalFilters) {
      return 'No entries match these filters';
    }
    if (_selectedMood != null) {
      return 'No ${_selectedMood!.toLowerCase()} entries on this date';
    }
    return _sameDay(_selectedDate!, _dateOnly(DateTime.now()))
        ? "You haven't written today's entry yet"
        : 'No diary entries for this day';
  }

  String _emptyDiaryMessage({
    required int? selectedDateCount,
    required bool hasAdditionalFilters,
  }) {
    if (_selectedDate == null) {
      return _dateCounts.isNotEmpty && hasAdditionalFilters
          ? 'Clear or adjust the filters to see your diary entries.'
          : 'Start writing about your day, thoughts, or memories. Your entries will appear here in date order.';
    }
    if (_selectedDate!.isAfter(_dateOnly(DateTime.now()))) {
      return 'Diary entries can be created for today or an earlier date.';
    }
    if ((selectedDateCount ?? 0) > 0 && hasAdditionalFilters) {
      return 'Clear or adjust the filters to see entries from this date.';
    }
    if (_selectedMood != null && (_dateCounts[_selectedDate!] ?? 0) > 0) {
      return 'Try another mood or clear the mood filter to see the other entries for this date.';
    }
    return 'Nothing written here yet. You can add an entry for this date.';
  }

  String _emptyDiaryAction() {
    if (_selectedDate == null) return 'Write Your First Entry';
    if (_selectedDate!.isAfter(_dateOnly(DateTime.now()))) {
      return 'Choose another date';
    }
    return _sameDay(_selectedDate!, _dateOnly(DateTime.now()))
        ? "Write Today's Entry"
        : 'Write an Entry';
  }

  Widget _buildNotesTab(ThemeData theme) {
    final subjects =
        _notes
            .where((note) => note.linkedSubjectName?.trim().isNotEmpty == true)
            .map((note) => note.linkedSubjectName!)
            .toSet()
            .toList()
          ..sort();
    final notes = _notes.where((note) {
      if (note.isLocked) {
        return _query.trim().isEmpty &&
            _noteCategory == 'All' &&
            _noteSubject == 'All';
      }
      if (!NotebookService.instance.noteMatches(note, _query)) return false;
      if (_noteCategory != 'All' && note.category != _noteCategory) {
        return false;
      }
      if (_noteSubject != 'All' && note.linkedSubjectName != _noteSubject) {
        return false;
      }
      return true;
    }).toList();
    notes.sort((a, b) {
      if (_noteSort == 'Pinned first' && a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      if (_noteSort == 'Alphabetical') {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      if (_noteSort == 'Recently created') {
        return b.createdAt.compareTo(a.createdAt);
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        Text(
          'A home for school notes, plans, and ideas',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _createNote,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('New Note'),
        ),
        const SizedBox(height: 12),
        _searchField('Search notes, tags, or subjects...'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _noteCategory,
          decoration: const InputDecoration(
            labelText: 'Category',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: ['All', ...NotebookNote.categories.keys]
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _noteCategory = value);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _noteSubject,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: ['All', ...subjects]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _noteSubject = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _noteSort,
                decoration: const InputDecoration(
                  labelText: 'Sort',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items:
                    const [
                          'Pinned first',
                          'Recently updated',
                          'Recently created',
                          'Alphabetical',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _noteSort = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Your Notes',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (notes.isEmpty)
          _emptyState(
            icon: Icons.sticky_note_2_outlined,
            title: 'No notes yet',
            message:
                'Keep your ideas, school notes, and important information here.',
            actionLabel: 'Create a Note',
            onPressed: _createNote,
          )
        else
          ...notes.map(_noteCard),
        const SizedBox(height: 8),
        if (_schoolClasses.isNotEmpty)
          Text(
            'Linked subjects come from your existing school schedule.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _searchField(String hint) => TextField(
    controller: _searchController,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: _searchController.clear,
              icon: const Icon(Icons.clear),
            ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  Widget _diaryCard(DiaryEntry entry) {
    final private = entry.isLocked;
    final title = private ? 'Private Diary Entry' : entry.displayTitle;
    final preview = private
        ? 'Locked content'
        : entry.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final mood = private || entry.mood == null
        ? null
        : '${DiaryEntry.moods[entry.mood]} ${entry.mood}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openDiary(entry),
        leading: CircleAvatar(
          child: Icon(private ? Icons.lock_outline : Icons.menu_book_outlined),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('h:mm a').format(entry.createdAt.toLocal())),
            if (mood != null)
              Text(
                mood,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Delete diary entry',
          onPressed: () => _confirmAndDelete(entry.id, diary: true),
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  Widget _noteCard(NotebookNote note) {
    final private = note.isLocked;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openNote(note),
        leading: CircleAvatar(
          child: Icon(private ? Icons.lock_outline : Icons.notes_outlined),
        ),
        title: Row(
          children: [
            if (note.isPinned && !private) ...[
              const Icon(Icons.push_pin, size: 15),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                private
                    ? 'Private Note'
                    : (note.title.trim().isEmpty
                          ? 'Untitled note'
                          : note.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          private
              ? 'Locked content'
              : [
                  note.category,
                  if (note.linkedSubjectName?.isNotEmpty == true)
                    note.linkedSubjectName!,
                  note.content.replaceAll(RegExp(r'\s+'), ' ').trim(),
                ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Delete note',
          onPressed: () => _confirmAndDelete(note.id, diary: false),
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onPressed,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    ),
  );

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
