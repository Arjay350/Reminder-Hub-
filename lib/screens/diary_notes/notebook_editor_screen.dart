import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';
import '../../models/diary_models.dart';
import '../../services/hive_service.dart';
import '../../services/notebook_service.dart';

class NotebookEditorScreen extends StatefulWidget {
  const NotebookEditorScreen({
    super.key,
    required this.isDiary,
    this.diaryEntry,
    this.note,
    this.initialTitle,
    this.initialContent,
    this.initialSubject,
    this.initialDate,
  });

  final bool isDiary;
  final DiaryEntry? diaryEntry;
  final NotebookNote? note;
  final String? initialTitle;
  final String? initialContent;
  final String? initialSubject;
  final DateTime? initialDate;

  @override
  State<NotebookEditorScreen> createState() => _NotebookEditorScreenState();
}

class _NotebookEditorScreenState extends State<NotebookEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _checklistController = TextEditingController();
  final _scrollController = ScrollController();
  final List<NotebookChecklistItem> _checklist = [];
  List<SchoolClass> _schoolClasses = [];
  String? _mood;
  String? _subjectId;
  String? _subjectName;
  String _category = 'Personal';
  bool _isLocked = false;
  bool _isPinned = false;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;

  bool get _isEditing => widget.diaryEntry != null || widget.note != null;
  String get _screenTitle => widget.isDiary
      ? (_isEditing ? 'Edit Diary Entry' : 'New Diary Entry')
      : (_isEditing ? 'Edit Note' : 'New Note');

  @override
  void initState() {
    super.initState();
    final entry = widget.diaryEntry;
    final note = widget.note;
    _titleController.text =
        entry?.title ?? note?.title ?? widget.initialTitle ?? '';
    _contentController.text =
        entry?.content ?? note?.content ?? widget.initialContent ?? '';
    _tagsController.text = (entry?.tags ?? note?.tags ?? const []).join(', ');
    _mood = entry?.mood;
    _category =
        entry?.category ??
        note?.category ??
        (widget.isDiary ? 'Personal' : 'Study');
    _subjectId = entry?.linkedSubjectId ?? note?.linkedSubjectId;
    _subjectName =
        entry?.linkedSubjectName ??
        note?.linkedSubjectName ??
        widget.initialSubject;
    _checklist.addAll(
      entry?.checklistItems ?? note?.checklistItems ?? const [],
    );
    _isLocked = entry?.isLocked ?? note?.isLocked ?? false;
    _isPinned = note?.isPinned ?? false;
    for (final controller in [
      _titleController,
      _contentController,
      _tagsController,
    ]) {
      controller.addListener(_markDirty);
    }
    _loadSchoolClasses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _checklistController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  Future<void> _loadSchoolClasses() async {
    await HiveService.instance.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _schoolClasses = HiveService.instance.getSchoolClasses();
    });
  }

  List<SchoolClass> get _subjects {
    final bySubject = <String, SchoolClass>{};
    for (final item in _schoolClasses) {
      final name = item.subject.trim();
      if (name.isNotEmpty) bySubject.putIfAbsent(name, () => item);
    }
    return bySubject.values.toList()..sort(
      (a, b) => a.subject.toLowerCase().compareTo(b.subject.toLowerCase()),
    );
  }

  void _addChecklistItem() {
    final text = _checklistController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(NotebookChecklistItem(id: const Uuid().v4(), text: text));
      _checklistController.clear();
      _dirty = true;
    });
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('You have unsaved changes'),
        content: const Text('Do you want to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (action == 'save') {
      await _save();
      return false;
    }
    return action == 'discard';
  }

  Future<void> _requestPop() async {
    if (_saving || _allowPop || !mounted) return;
    if (await _confirmLeave() && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final content = _contentController.text.trim();
    if (content.isEmpty && _checklist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write something or add a checklist item first.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    try {
      if (widget.isDiary) {
        final old = widget.diaryEntry;
        final entry = DiaryEntry(
          id: old?.id ?? const Uuid().v4(),
          title: _titleController.text.trim(),
          content: content,
          createdAt: old?.createdAt ?? _newDiaryEntryDate(now),
          updatedAt: now,
          mood: _mood,
          category: _category,
          tags: tags,
          linkedSubjectId: _subjectId,
          linkedSubjectName: _subjectName,
          checklistItems: List.unmodifiable(_checklist),
          isLocked: _isLocked,
          encryptedPayload: old?.encryptedPayload,
          isUnlockedInMemory: _isLocked,
        );
        await NotebookService.instance.saveDiaryEntry(
          entry,
          isNew: old == null,
        );
        if (mounted) {
          setState(() => _allowPop = true);
          Navigator.of(context).pop(entry);
        }
      } else {
        final old = widget.note;
        final note = NotebookNote(
          id: old?.id ?? const Uuid().v4(),
          title: _titleController.text.trim(),
          content: content,
          createdAt: old?.createdAt ?? now,
          updatedAt: now,
          category: _category,
          tags: tags,
          linkedSubjectId: _subjectId,
          linkedSubjectName: _subjectName,
          checklistItems: List.unmodifiable(_checklist),
          isPinned: _isPinned,
          isLocked: _isLocked,
          encryptedPayload: old?.encryptedPayload,
          isUnlockedInMemory: _isLocked,
        );
        await NotebookService.instance.saveNote(note);
        if (mounted) {
          setState(() => _allowPop = true);
          Navigator.of(context).pop(note);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save this entry: $error')),
        );
      }
    }
  }

  DateTime _newDiaryEntryDate(DateTime now) {
    final selectedDate = widget.initialDate?.toLocal();
    if (selectedDate == null) return now;
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<Object?>(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_screenTitle),
          leading: IconButton(
            tooltip: 'Close editor',
            onPressed: _requestPop,
            icon: const Icon(Icons.close),
          ),
          actions: [
            IconButton(
              tooltip: 'Save',
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: widget.isDiary
                                ? 'Title (optional)'
                                : 'Note title',
                            border: InputBorder.none,
                          ),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.isDiary)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              DateFormat('EEEE, MMMM d, y').format(
                                widget.diaryEntry?.createdAt ??
                                    widget.initialDate ??
                                    DateTime.now(),
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _contentController,
                          minLines: 10,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: widget.isDiary
                                ? 'Write about your day, thoughts, or memories...'
                                : 'Write your note...',
                            alignLabelWithHint: true,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (widget.isDiary) ...[
                          Text(
                            'How are you feeling?',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _moodChip(null, 'No Mood'),
                              for (final entry in DiaryEntry.moods.entries)
                                _moodChip(
                                  entry.key,
                                  '${entry.value} ${entry.key}',
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                const [
                                      'Personal',
                                      'School',
                                      'Work',
                                      'Ideas',
                                      'Other',
                                    ]
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _category = value;
                                  _dirty = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 18),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: NotebookNote.categories.keys
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      '${NotebookNote.categories[value]} $value',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _category = value;
                                  _dirty = true;
                                });
                              }
                            },
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Pin note'),
                            value: _isPinned,
                            onChanged: (value) => setState(() {
                              _isPinned = value;
                              _dirty = true;
                            }),
                          ),
                        ],
                        TextField(
                          controller: _tagsController,
                          decoration: const InputDecoration(
                            labelText: 'Tags',
                            hintText: 'Comma-separated tags',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String?>(
                          initialValue: _subjectId,
                          decoration: const InputDecoration(
                            labelText: 'Link to a school subject (optional)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('No linked subject'),
                            ),
                            ..._subjects.map(
                              (subject) => DropdownMenuItem<String?>(
                                value: subject.id,
                                child: Text(subject.subject),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _subjectId = value;
                              _subjectName = value == null
                                  ? null
                                  : _subjects
                                        .firstWhere((item) => item.id == value)
                                        .subject;
                              _dirty = true;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        Text('Checklist', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ..._checklist.map(
                          (item) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: item.isChecked,
                            title: Text(item.text),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) {
                              setState(() {
                                final index = _checklist.indexWhere(
                                  (current) => current.id == item.id,
                                );
                                if (index >= 0) {
                                  _checklist[index] = item.copyWith(
                                    isChecked: value ?? false,
                                  );
                                  _dirty = true;
                                }
                              });
                            },
                            secondary: IconButton(
                              tooltip: 'Remove checklist item',
                              onPressed: () => setState(() {
                                _checklist.removeWhere(
                                  (current) => current.id == item.id,
                                );
                                _dirty = true;
                              }),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _checklistController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Add checklist item',
                                ),
                                onSubmitted: (_) => _addChecklistItem(),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Add checklist item',
                              onPressed: _addChecklistItem,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Private / Locked'),
                          subtitle: const Text(
                            'Encrypt the entry and require device authentication to open it.',
                          ),
                          secondary: const Icon(Icons.lock_outline),
                          value: _isLocked,
                          onChanged: (value) => setState(() {
                            _isLocked = value;
                            _dirty = true;
                          }),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving...' : 'Save'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _moodChip(String? mood, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _mood == mood,
      onSelected: (_) => setState(() {
        _mood = mood;
        _dirty = true;
      }),
    );
  }
}
