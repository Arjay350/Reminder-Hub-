import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/diary_models.dart';
import 'notebook_service.dart';

enum NotebookExportFormat { markdown, text, pdf }

class NotebookExportService {
  NotebookExportService._();
  static final NotebookExportService instance = NotebookExportService._();

  Future<void> shareDiary(
    DiaryEntry entry,
    NotebookExportFormat format,
  ) async {
    final markdown = await NotebookService.instance.exportDiaryMarkdown(entry);
    await _share(
      title: entry.displayTitle,
      contents: markdown,
      format: format,
    );
  }

  Future<void> shareNote(
    NotebookNote note,
    NotebookExportFormat format,
  ) async {
    final markdown = await NotebookService.instance.exportNoteMarkdown(note);
    await _share(
      title: note.title.trim().isEmpty ? 'Untitled note' : note.title.trim(),
      contents: markdown,
      format: format,
    );
  }

  Future<void> _share({
    required String title,
    required String contents,
    required NotebookExportFormat format,
  }) async {
    final safeName = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final Directory directory = await getTemporaryDirectory();
    late final File file;
    late final String mimeType;
    late final String extension;

    switch (format) {
      case NotebookExportFormat.markdown:
        extension = 'md';
        mimeType = 'text/markdown';
        file = File('${directory.path}${Platform.pathSeparator}$safeName.md');
        await file.writeAsString(contents, flush: true);
      case NotebookExportFormat.text:
        extension = 'txt';
        mimeType = 'text/plain';
        file = File('${directory.path}${Platform.pathSeparator}$safeName.txt');
        await file.writeAsString(contents, flush: true);
      case NotebookExportFormat.pdf:
        extension = 'pdf';
        mimeType = 'application/pdf';
        file = File('${directory.path}${Platform.pathSeparator}$safeName.pdf');
        await file.writeAsBytes(await _makePdf(contents), flush: true);
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        text: 'Reminder Hub ${format.name.toUpperCase()} export',
        title: '$safeName.$extension',
      ),
    );
  }

  Future<Uint8List> _makePdf(String markdown) async {
    final document = pw.Document();
    final sections = markdown
        .split('\n')
        .map((line) => line.trimRight())
        .toList();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          for (final line in sections)
            if (line.startsWith('# '))
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  line.substring(2),
                  style: pw.Theme.of(context).header1,
                ),
              )
            else if (line.startsWith('## '))
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
                child: pw.Text(
                  line.substring(3),
                  style: pw.Theme.of(context).header2,
                ),
              )
            else if (line.startsWith('- [x] '))
              pw.Bullet(text: '[x] ${line.substring(6)}')
            else if (line.startsWith('- [ ] '))
              pw.Bullet(text: '[ ] ${line.substring(6)}')
            else if (line.startsWith('- '))
              pw.Bullet(text: line.substring(2))
            else if (line.isEmpty)
              pw.SizedBox(height: 6)
            else
              pw.Text(line),
        ],
      ),
    );
    return document.save();
  }
}
