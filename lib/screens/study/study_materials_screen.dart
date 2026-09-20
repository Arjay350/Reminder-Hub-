import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/study_material_models.dart';
import '../../services/hive_service.dart';
import '../../services/study_material_service.dart';

List<StudyFlashcard> replaceFlashcardPreservingOrder(
  List<StudyFlashcard> cards,
  StudyFlashcard updatedCard,
) {
  return cards
      .map((card) => card.id == updatedCard.id ? updatedCard : card)
      .toList();
}

class StudyMaterialsScreen extends StatefulWidget {
  const StudyMaterialsScreen({super.key});

  @override
  State<StudyMaterialsScreen> createState() => _StudyMaterialsScreenState();
}

class _StudyMaterialsScreenState extends State<StudyMaterialsScreen> {
  final StudyMaterialService _service = StudyMaterialService.instance;
  List<StudyMaterial> _materials = [];
  bool _processing = false;
  String _progressMessage = '';
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  void _loadMaterials() {
    setState(() => _materials = HiveService.instance.getStudyMaterials());
  }

  Future<void> _importMaterial() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
    );
    if (!mounted || files.isEmpty) return;
    final file = files.first;
    final filePath = file.path;
    if (filePath == null || filePath.trim().isEmpty) {
      _showMessage('This platform did not provide a local file path.');
      return;
    }
    final existing = HiveService.instance.getStudyMaterials();
    if (existing.any((material) => material.filePath == filePath)) {
      _showMessage('This study material is already in your library.');
      return;
    }
    final fileSize = await File(filePath).length();
    if (fileSize > 50 * 1024 * 1024) {
      _showMessage(
        'This file is larger than 50 MB. Choose a smaller document to keep local processing responsive.',
      );
      return;
    }

    setState(() {
      _processing = true;
      _progress = 0;
      _progressMessage = 'Preparing local processing...';
    });
    final material = await _service.importMaterial(
      filePath,
      onProgress: (message, value) {
        if (!mounted) return;
        setState(() {
          _progressMessage = message;
          _progress = value;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _processing = false;
      _progress = 1;
      _progressMessage = '';
      _materials = HiveService.instance.getStudyMaterials();
    });
    if (material.status == MaterialProcessingStatus.failed) {
      _showMessage(material.errorMessage ?? 'The material could not be read.');
    } else {
      _showMessage('Material imported and analyzed locally.');
    }
  }

  Future<void> _deleteMaterial(StudyMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove material?'),
        content: const Text(
          'This removes the local library record and generated content. '
          'The original file will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await HiveService.instance.deleteStudyMaterial(material.id);
    if (mounted) _loadMaterials();
  }

  Future<void> _renameMaterial(StudyMaterial material) async {
    final controller = TextEditingController(text: material.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Material'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Material name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null || name.trim().isEmpty) return;
    await HiveService.instance.saveStudyMaterial(
      material.copyWith(
        displayName: name.trim().isEmpty ? material.fileName : name.trim(),
      ),
    );
    if (mounted) _loadMaterials();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Materials')),
      body: SafeArea(
        child: _processing
            ? _ProcessingView(message: _progressMessage, progress: _progress)
            : _materials.isEmpty
            ? _EmptyMaterials(onImport: _importMaterial)
            : RefreshIndicator(
                onRefresh: () async => _loadMaterials(),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _OfflineNotice(
                      text:
                          'Generated locally from your study material. Results depend on document quality and structure.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _importMaterial,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Import Study Material'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'My Materials',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._materials.map(
                      (material) => _MaterialTile(
                        material: material,
                        onOpen: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  StudyMaterialDetailScreen(material: material),
                            ),
                          );
                          if (mounted) _loadMaterials();
                        },
                        onDelete: () => _deleteMaterial(material),
                        onRename: () => _renameMaterial(material),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: _processing || _materials.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _importMaterial,
              icon: const Icon(Icons.add),
              label: const Text('Import'),
            ),
    );
  }
}

class StudyMaterialDetailScreen extends StatefulWidget {
  const StudyMaterialDetailScreen({super.key, required this.material});

  final StudyMaterial material;

  @override
  State<StudyMaterialDetailScreen> createState() =>
      _StudyMaterialDetailScreenState();
}

class _StudyMaterialDetailScreenState extends State<StudyMaterialDetailScreen> {
  final StudyMaterialService _service = StudyMaterialService.instance;
  late StudyMaterial _material;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _material = widget.material;
  }

  Future<void> _generateReviewer() async {
    setState(() => _working = true);
    final updated = await _service.saveReviewer(_material);
    if (!mounted) return;
    setState(() {
      _material = updated;
      _working = false;
    });
  }

  Future<void> _generateFlashcards() async {
    setState(() => _working = true);
    final updated = await _service.saveFlashcards(_material);
    if (!mounted) return;
    setState(() {
      _material = updated;
      _working = false;
    });
  }

  Future<void> _generateQuiz() async {
    final options = await _showQuizOptions();
    if (!mounted || options == null) return;
    setState(() => _working = true);
    final updated = await _service.saveQuiz(
      _material,
      requestedCount: options.count,
      difficulty: options.difficulty,
      type: options.type,
    );
    if (!mounted) return;
    setState(() {
      _material = updated;
      _working = false;
    });
    if (updated.quiz.isEmpty) {
      _showMessage(
        options.difficulty == 'hard'
            ? 'Not enough material was available to reliably generate advanced questions.'
            : 'Not enough reliable information was found to generate questions.',
      );
    }
  }

  Future<_QuizOptions?> _showQuizOptions() async {
    var count = 10;
    var difficulty = 'easy';
    var type = 'mixed';
    return showDialog<_QuizOptions>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Generate Quiz'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: count,
                items: [5, 10, 15, 20]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value questions'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => count = value ?? 10),
                decoration: const InputDecoration(
                  labelText: 'Number of questions',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: difficulty,
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'hard', child: Text('Hard')),
                ],
                onChanged: (value) =>
                    setDialogState(() => difficulty = value ?? 'easy'),
                decoration: const InputDecoration(labelText: 'Difficulty'),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
                  DropdownMenuItem(
                    value: 'multipleChoice',
                    child: Text('Multiple Choice'),
                  ),
                  DropdownMenuItem(
                    value: 'trueFalse',
                    child: Text('True / False'),
                  ),
                  DropdownMenuItem(
                    value: 'fillInBlank',
                    child: Text('Fill in the Blank'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => type = value ?? 'mixed'),
                decoration: const InputDecoration(labelText: 'Question type'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _QuizOptions(count: count, difficulty: difficulty, type: type),
              ),
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _material.analysis;
    return Scaffold(
      appBar: AppBar(title: Text(_material.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _OfflineNotice(
              text:
                  'This is a local rule-based analyzer, not an AI assistant. No material is uploaded.',
            ),
            const SizedBox(height: 16),
            Text(
              _material.fileName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${_material.fileType.toUpperCase()} • ${_fileSize(_material.fileSizeBytes)}',
            ),
            if (_material.fileType == 'pdf' &&
                _material.extractedText.contains('[Page '))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Source: Scanned PDF • Extraction: On-device OCR'),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${analysis.wordCount} words')),
                Chip(label: Text('${analysis.topics.length} topics')),
                Chip(label: Text('${analysis.terms.length} terms')),
                Chip(
                  label: Text(
                    '${analysis.potentialQuestionCount} potential questions',
                  ),
                ),
              ],
            ),
            if (_material.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _material.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _working ? null : _generateReviewer,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Generate Reviewer'),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : _generateQuiz,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Generate Quiz'),
                ),
                OutlinedButton.icon(
                  onPressed: _working ? null : _generateFlashcards,
                  icon: const Icon(Icons.style_outlined),
                  label: const Text('Generate Flashcards'),
                ),
              ],
            ),
            if (_working) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Generating locally...'),
            ],
            if (_material.reviewer != null) ...[
              const SizedBox(height: 24),
              _SectionTitle(title: 'Reviewer'),
              SelectableText(_material.reviewer!),
            ],
            if (_material.quiz.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Quiz (${_material.quiz.length} reliable questions)',
              ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudyQuizScreen(material: _material),
                    ),
                  );
                  if (mounted) {
                    final refreshed = HiveService.instance
                        .getStudyMaterials()
                        .where((item) => item.id == _material.id)
                        .firstOrNull;
                    if (refreshed != null) {
                      setState(() => _material = refreshed);
                    }
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  _material.quizScore == null
                      ? 'Take Quiz'
                      : 'Retake Quiz (score ${_material.quizScore})',
                ),
              ),
              ..._material.quiz.map(
                (question) => _QuestionTile(question: question),
              ),
            ],
            if (_material.flashcards.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Flashcards (${_material.flashcards.length})',
              ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudyFlashcardScreen(material: _material),
                    ),
                  );
                  if (mounted) {
                    final refreshed = HiveService.instance
                        .getStudyMaterials()
                        .where((item) => item.id == _material.id)
                        .firstOrNull;
                    if (refreshed != null) {
                      setState(() => _material = refreshed);
                    }
                  }
                },
                icon: const Icon(Icons.flip),
                label: const Text('Open Flashcards'),
              ),
            ],
            const SizedBox(height: 24),
            _SectionTitle(title: 'Extracted Text Preview'),
            SelectableText(
              _material.extractedText.isEmpty
                  ? 'No readable text was extracted.'
                  : _material.extractedText.length > 4000
                  ? '${_material.extractedText.substring(0, 4000)}\n\n[Preview truncated]'
                  : _material.extractedText,
            ),
          ],
        ),
      ),
    );
  }
}

class StudyQuizScreen extends StatefulWidget {
  const StudyQuizScreen({super.key, required this.material});

  final StudyMaterial material;

  @override
  State<StudyQuizScreen> createState() => _StudyQuizScreenState();
}

class _StudyQuizScreenState extends State<StudyQuizScreen> {
  final TextEditingController _answerController = TextEditingController();
  int _index = 0;
  int _score = 0;
  String? _selectedAnswer;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = widget.material.quiz[_index];
    final answer = question.options.isEmpty
        ? _answerController.text.trim()
        : _selectedAnswer;
    if (answer == null || answer.isEmpty) return;
    final isCorrect = _normalize(answer) == _normalize(question.answer);
    final newScore = _score + (isCorrect ? 1 : 0);
    if (_index == widget.material.quiz.length - 1) {
      await HiveService.instance.saveStudyMaterial(
        widget.material.copyWith(quizScore: newScore),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quiz complete'),
          content: Text('$newScore of ${widget.material.quiz.length} correct.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _score = newScore;
      _index++;
      _selectedAnswer = null;
      _answerController.clear();
    });
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final question = widget.material.quiz[_index];
    return Scaffold(
      appBar: AppBar(title: const Text('Study Quiz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${_index + 1} of ${widget.material.quiz.length}'),
              const SizedBox(height: 20),
              Text(
                question.prompt,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              if (question.options.isEmpty)
                TextField(
                  controller: _answerController,
                  decoration: const InputDecoration(labelText: 'Your answer'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: question.options
                      .map(
                        (option) => ChoiceChip(
                          label: Text(option),
                          selected: _selectedAnswer == option,
                          onSelected: (_) =>
                              setState(() => _selectedAnswer = option),
                        ),
                      )
                      .toList(),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _submit,
                child: Text(
                  _index == widget.material.quiz.length - 1
                      ? 'Finish Quiz'
                      : 'Next Question',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Questions and answers are based only on the imported material.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudyFlashcardScreen extends StatefulWidget {
  const StudyFlashcardScreen({super.key, required this.material});

  final StudyMaterial material;

  @override
  State<StudyFlashcardScreen> createState() => _StudyFlashcardScreenState();
}

class _StudyFlashcardScreenState extends State<StudyFlashcardScreen> {
  final StudyMaterialService _service = StudyMaterialService.instance;
  late List<StudyFlashcard> _cards;
  int _index = 0;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _cards = List<StudyFlashcard>.from(widget.material.flashcards);
  }

  Future<void> _mark({bool? known, bool? needsReview}) async {
    if (_cards.isEmpty) return;
    final card = _cards[_index];
    final updated = await _service.updateFlashcard(
      widget.material,
      card.id,
      known: known,
      needsReview: needsReview,
    );
    if (!mounted) return;
    final updatedCard = updated.flashcards.firstWhere(
      (item) => item.id == card.id,
      orElse: () => card,
    );
    final currentIndex = _index;
    setState(() {
      _cards = replaceFlashcardPreservingOrder(_cards, updatedCard);
      _index = currentIndex.clamp(0, _cards.length - 1);
    });
  }

  void _next() {
    if (_cards.isEmpty) return;
    setState(() {
      _index = (_index + 1) % _cards.length;
      _showBack = false;
    });
  }

  void _previous() {
    if (_cards.isEmpty) return;
    setState(() {
      _index = (_index - 1 + _cards.length) % _cards.length;
      _showBack = false;
    });
  }

  void _shuffle() {
    setState(() {
      _cards.shuffle();
      _index = 0;
      _showBack = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcards')),
        body: const Center(child: Text('No reliable flashcards were found.')),
      );
    }
    final card = _cards[_index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          IconButton(
            onPressed: _shuffle,
            tooltip: 'Shuffle',
            icon: const Icon(Icons.shuffle),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('${_index + 1} of ${_cards.length}'),
              const SizedBox(height: 20),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _showBack = !_showBack),
                  child: Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _showBack ? card.back : card.front,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  IconButton(
                    onPressed: _previous,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _mark(known: true, needsReview: false),
                    child: const Text('Known'),
                  ),
                  OutlinedButton(
                    onPressed: () => _mark(known: false, needsReview: true),
                    child: const Text('Needs Review'),
                  ),
                  IconButton(
                    onPressed: _next,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({
    required this.material,
    required this.onOpen,
    required this.onDelete,
    required this.onRename,
  });

  final StudyMaterial material;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final analysis = material.analysis;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onOpen,
        leading: Icon(_iconForType(material.fileType)),
        title: Text(material.name),
        subtitle: Text(
          '${material.fileType.toUpperCase()} • ${analysis.wordCount} words • '
          '${analysis.topics.length} topics • ${_date(material.importedAt)} • '
          '${material.status.name}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'open') onOpen();
            if (value == 'rename') onRename();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'open', child: Text('Open')),
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'delete', child: Text('Delete record')),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'docx' => Icons.description_outlined,
    'txt' => Icons.notes_outlined,
    'jpg' || 'jpeg' || 'png' => Icons.image_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _EmptyMaterials extends StatelessWidget {
  const _EmptyMaterials({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_books_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'No study materials yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Import a PDF, DOCX, TXT, or image. Processing stays on this device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import Study Material'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.message, required this.progress});

  final String message;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(message),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 12),
            Text('${(progress * 100).round()}%'),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.offline_bolt_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
  );
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question});

  final StudyQuizQuestion question;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.prompt,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (question.options.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...question.options.map((option) => Text('- $option')),
          ],
          const SizedBox(height: 8),
          Text('Answer: ${question.answer}'),
          Text('Source: ${question.sourceText}'),
        ],
      ),
    ),
  );
}

class _QuizOptions {
  const _QuizOptions({
    required this.count,
    required this.difficulty,
    required this.type,
  });

  final int count;
  final String difficulty;
  final String type;
}
