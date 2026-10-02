import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class BirthdayDialog extends StatefulWidget {
  const BirthdayDialog({super.key, this.birthday, this.initialDate});

  final Birthday? birthday;
  final DateTime? initialDate;

  @override
  State<BirthdayDialog> createState() => _BirthdayDialogState();
}

class _BirthdayDialogState extends State<BirthdayDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _giftIdeasController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late String _relationship;
  late bool _yearKnown;
  late bool _isUserBirthday;
  late DateTime _birthDate;
  late bool _remind7DaysBefore;
  late bool _remind1DayBefore;
  late bool _remindOnDay;
  late TimeOfDay _reminderTime;

  @override
  void initState() {
    super.initState();
    final current = widget.birthday;
    _nameController.text = current?.name ?? '';
    _relationship = current?.relationship ?? 'Family';
    _yearKnown = current?.yearKnown ?? true;
    _isUserBirthday = current?.isUserBirthday ?? false;
    _birthDate =
        current?.birthDate ??
        widget.initialDate ??
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _remind7DaysBefore = current?.remind7DaysBefore ?? true;
    _remind1DayBefore = current?.remind1DayBefore ?? true;
    _remindOnDay = current?.remindOnDay ?? true;
    _reminderTime = TimeOfDay(
      hour: _parseHour(current?.reminderTime ?? '09:00 AM'),
      minute: _parseMinute(current?.reminderTime ?? '09:00 AM'),
    );
    _giftIdeasController.text = current?.giftIdeas ?? '';
    _notesController.text = current?.customNotes ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _giftIdeasController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.birthday != null;

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Birthday' : 'New Birthday',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('🎂 This is my birthday'),
                subtitle: const Text(
                  'Only one birthday can be marked as yours.',
                ),
                value: _isUserBirthday,
                onChanged: _setUserBirthday,
              ),
              const SizedBox(height: 8),
              Text(
                'Relationship',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Birthday.relationshipOptions.map((option) {
                  final selected = _relationship == option;
                  return ChoiceChip(
                    label: Text(option),
                    selected: selected,
                    onSelected: (_) => setState(() => _relationship = option),
                    selectedColor: const Color(
                      0xFFF9A8D4,
                    ).withValues(alpha: 0.35),
                    backgroundColor: isDark
                        ? const Color(0xFF1E294B)
                        : const Color(0xFFF8FAFC),
                    labelStyle: TextStyle(
                      color: selected
                          ? const Color(0xFFEC4899)
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Birthday',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.cake_rounded),
                  ),
                  child: Text(
                    _yearKnown
                        ? DateFormat('MMMM d, y').format(_birthDate)
                        : DateFormat('MMMM d').format(_birthDate),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('I don’t know the birth year'),
                subtitle: Text(
                  _yearKnown
                      ? 'Birthday will include the year for age tracking.'
                      : 'Birthday will be treated as month/day only.',
                ),
                value: !_yearKnown,
                onChanged: (value) {
                  setState(() {
                    _yearKnown = !value;
                    if (!_yearKnown) {
                      _birthDate = DateTime(
                        2000,
                        _birthDate.month,
                        _birthDate.day,
                      );
                    } else {
                      _birthDate = DateTime(
                        DateTime.now().year,
                        _birthDate.month,
                        _birthDate.day,
                      );
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('7 days before'),
                value: _remind7DaysBefore,
                onChanged: (value) =>
                    setState(() => _remind7DaysBefore = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('1 day before'),
                value: _remind1DayBefore,
                onChanged: (value) =>
                    setState(() => _remind1DayBefore = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('On the day'),
                value: _remindOnDay,
                onChanged: (value) =>
                    setState(() => _remindOnDay = value ?? false),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Reminder time',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.access_time_rounded),
                  ),
                  child: Text(_reminderTime.format(context)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _giftIdeasController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Gift ideas',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (isEditing)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete'),
                      ),
                    ),
                  if (isEditing) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saveBirthday,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(
                        isEditing ? Icons.edit_rounded : Icons.add_rounded,
                      ),
                      label: Text(isEditing ? 'Save Changes' : 'Save Birthday'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _setUserBirthday(bool? value) async {
    final shouldBeUserBirthday = value ?? false;
    if (!shouldBeUserBirthday) {
      setState(() => _isUserBirthday = false);
      return;
    }

    final existing = Birthday.findUserBirthday(
      HiveService.instance.getBirthdays(),
    );
    if (existing != null && existing.id != widget.birthday?.id) {
      final shouldEdit = await _askToEditExistingBirthday();
      if (!mounted) return;
      if (shouldEdit) Navigator.pop(context, existing);
      return;
    }

    setState(() => _isUserBirthday = true);
  }

  Future<bool> _askToEditExistingBirthday() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Birthday already saved'),
        content: const Text(
          'You already have a birthday saved. Would you like to edit it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Edit Birthday'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _saveBirthday() async {
    if (!_formKey.currentState!.validate()) return;

    final existingUserBirthday = _isUserBirthday
        ? Birthday.findUserBirthday(HiveService.instance.getBirthdays())
        : null;
    if (existingUserBirthday != null &&
        existingUserBirthday.id != widget.birthday?.id) {
      if (await _askToEditExistingBirthday() && mounted) {
        Navigator.pop(context, existingUserBirthday);
      }
      return;
    }

    final name = _nameController.text.trim();
    final finalBirthDate = _yearKnown
        ? DateTime(_birthDate.year, _birthDate.month, _birthDate.day)
        : DateTime(2000, _birthDate.month, _birthDate.day);
    final birthday =
        (widget.birthday ??
                Birthday(
                  id: const Uuid().v4(),
                  name: name,
                  birthDate: finalBirthDate,
                ))
            .copyWith(
              name: name,
              birthDate: finalBirthDate,
              relationship: _relationship,
              giftIdeas: _giftIdeasController.text.trim(),
              remind7DaysBefore: _remind7DaysBefore,
              remind1DayBefore: _remind1DayBefore,
              remindOnDay: _remindOnDay,
              reminderTime: _formatTime(_reminderTime),
              customNotes: _notesController.text.trim(),
              yearKnown: _yearKnown,
              isUserBirthday: _isUserBirthday,
            );

    final hive = HiveService.instance;
    await hive.saveBirthday(birthday);
    await NotificationService.instance.scheduleBirthdayNotifications(birthday);
    if (!mounted) return;
    Navigator.pop(context, birthday);
  }

  Future<void> _confirmDelete() async {
    final birthday = widget.birthday;
    if (birthday == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this birthday?'),
        content: const Text(
          'This birthday will be removed from your Birthday Tracker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await NotificationService.instance.cancelBirthdayNotifications(birthday);
    await HiveService.instance.deleteBirthday(birthday.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  int _parseHour(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return 9;
    var hour = int.parse(match.group(1)!);
    final period = match.group(3)?.toLowerCase();
    if (period == 'pm' && hour < 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;
    return hour;
  }

  int _parseMinute(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return 0;
    return int.parse(match.group(2)!);
  }
}
