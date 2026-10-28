import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/diary_models.dart';
import '../../services/notebook_export_service.dart';
import '../../services/notebook_service.dart';
import 'notebook_editor_screen.dart';

class NotebookDetailScreen extends StatefulWidget {
  const NotebookDetailScreen.diary({
    super.key,
    required DiaryEntry entry,
  }) : diaryEntry = entry,
       note = null;

  const NotebookDetailScreen.note({
    super.key,
    required this.note,
  }) : diaryEntry = null;

  final DiaryEntry? diaryEntry;
  final NotebookNote? note;

  @override
  State<NotebookDetailScreen> createState() => _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends State<NotebookDetailScreen> {
  late DiaryEntry? _entry = widget.diaryEntry;
  late NotebookNote? _note = widget.note;

  bool get _isDiary => _entry != null;
  String get _title => _entry?.displayTitle ??
      (_note!.title.trim().isEmpty ? 'Untitled note' : _note!.title.trim());
  String get _content => _entry?.content ?? _note!.content;
  DateTime get _createdAt => _entry?.createdAt ?? _note!.createdAt;
  DateTime get _updatedAt => _entry?.updatedAt ?? _note!.updatedAt;
  bool get _isLocked => _entry?.isLocked ?? _note!.isLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Entry actions',
            onSelected: (value) {
              if (value == 'edit') _edit();
              if (value == 'export') _chooseExport();
              if (value == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'export', child: Text('Export')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            Row(
              children: [
                Icon(
                  _isLocked ? Icons.lock_outline : (_isDiary ? Icons.menu_book : Icons.notes),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isLocked ? 'Private / Locked' : (_isDiary ? 'Diary' : 'Note'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (_note?.isPinned == true) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.push_pin, size: 16),
                  const Text('Pinned'),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Created ${DateFormat('MMMM d, y • h:mm a').format(_createdAt)}'),
            Text('Modified ${DateFormat('MMMM d, y • h:mm a').format(_updatedAt)}'),
            if (_entry?.mood != null) ...[
              const SizedBox(height: 16),
              Chip(
                avatar: Text(DiaryEntry.moods[_entry!.mood] ?? ''),
                label: Text(_entry!.mood!),
              ),
            ],
            if ((_entry?.category ?? _note?.category)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text('Category: ${_entry?.category ?? _note?.category}'),
            ],
            if ((_entry?.linkedSubjectName ?? _note?.linkedSubjectName)
                    ?.isNotEmpty ==
                true) ...[
              const SizedBox(height: 4),
              Text('Subject: ${_entry?.linkedSubjectName ?? _note?.linkedSubjectName}'),
            ],
            if ((_entry?.tags ?? _note?.tags ?? const []).isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: (_entry?.tags ?? _note?.tags ?? const [])
                    .map((tag) => Chip(label: Text('#$tag')))
                    .toList(),
              ),
            ],
            const Divider(height: 32),
            _FormattedNotebookContent(
              content: _content,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            ...(_entry?.checklistItems ?? _note?.checklistItems ?? const [])
                .map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.isChecked
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                    ),
                    title: Text(item.text),
                  ),
                ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => NotebookEditorScreen(
          isDiary: _isDiary,
          diaryEntry: _entry,
          note: _note,
        ),
      ),
    );
    if (!mounted) return;
    if (updated is DiaryEntry) setState(() => _entry = updated);
    if (updated is NotebookNote) setState(() => _note = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete this ${_isDiary ? 'diary entry' : 'note'}?'),
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
    if (confirmed != true || !mounted) return;
    try {
      if (_isDiary) {
        await NotebookService.instance.deleteDiaryEntry(_entry!.id);
      } else {
        await NotebookService.instance.deleteNote(_note!.id);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete this item: $error')),
        );
      }
    }
  }

  Future<void> _chooseExport() async {
    if (_isLocked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Export private content?'),
          content: const Text(
            'The exported file will contain the unlocked content and will not be encrypted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final format = await showModalBottomSheet<NotebookExportFormat>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Markdown (.md)'),
              onTap: () => Navigator.pop(sheetContext, NotebookExportFormat.markdown),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Plain text (.txt)'),
              onTap: () => Navigator.pop(sheetContext, NotebookExportFormat.text),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF (.pdf)'),
              onTap: () => Navigator.pop(sheetContext, NotebookExportFormat.pdf),
            ),
          ],
        ),
      ),
    );
    if (format == null || !mounted) return;
    try {
      if (_isDiary) {
        await NotebookExportService.instance.shareDiary(_entry!, format);
      } else {
        await NotebookExportService.instance.shareNote(_note!, format);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export this item: $error')),
        );
      }
    }
  }
}

/// Displays the small Markdown subset written by the diary toolbar. Content
/// remains plain text/Markdown in Hive, so old entries and JSON backups remain
/// compatible while headings and emphasis render after reload.
class _FormattedNotebookContent extends StatelessWidget {
  const _FormattedNotebookContent({required this.content, required this.style});

  final String content;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines) _line(line, context),
      ],
    );
  }

  Widget _line(String line, BuildContext context) {
    final heading = RegExp(r'^#{1,3}\s+').firstMatch(line);
    final text = heading == null ? line : line.substring(heading.end);
    final base = heading == null
        ? style
        : Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.6,
          );
    final spans = <InlineSpan>[];
    final expression = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    var offset = 0;
    for (final match in expression.allMatches(text)) {
      if (match.start > offset) spans.add(TextSpan(text: text.substring(offset, match.start)));
      final isBold = match.group(1) != null;
      spans.add(TextSpan(
        text: match.group(isBold ? 1 : 2),
        style: TextStyle(fontWeight: isBold ? FontWeight.bold : null, fontStyle: isBold ? null : FontStyle.italic),
      ));
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return SelectableText.rich(
      TextSpan(style: base, children: spans),
    );
  }
}
