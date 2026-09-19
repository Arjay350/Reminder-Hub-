import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class ReminderDialog extends StatefulWidget {
  const ReminderDialog({super.key, this.reminder});

  final Reminder? reminder;

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _title;
  late String _category;
  late String _description;
  late DateTime _date;
  late TimeOfDay _time;
  late String _repeat;
  late String _reminderBefore;
  late String _priority;
  late String _notes;

  final TextEditingController _customMinutesController = TextEditingController(text: '45');
  bool _canExactAlarm = true;

  final List<String> _categories = [
    'Bills',
    'AI Reset',
    'Subscriptions',
    'Gaming',
    'Work',
    'School',
    'Personal',
    'Household',
    'Custom'
  ];

  final List<String> _repeats = [
    'None',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  final List<String> _reminderBefores = [
    'At time',
    '5 minutes',
    '10 minutes',
    '15 minutes',
    '30 minutes',
    '45 minutes',
    '1 hour',
    '2 hours',
    '1 day',
    '2 days',
    '1 week',
    'Custom',
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _title = r?.title ?? '';
    _category = r?.category ?? 'Bills';
    _description = r?.description ?? '';
    _date = r?.date ?? DateTime.now().add(const Duration(days: 1));
    _time = r != null
        ? TimeOfDay(
            hour: int.tryParse(r.time.split(':')[0]) ?? 9,
            minute: int.tryParse(r.time.split(':')[1].split(' ')[0]) ?? 0,
          )
        : const TimeOfDay(hour: 9, minute: 0);
    _repeat = r?.repeat ?? 'None';
    _priority = r?.priority ?? 'Medium';
    _notes = r?.notes ?? '';

    // Handle custom timing strings (e.g. "45 minutes", "Custom: 45m")
    final initialReminderBefore = r?.reminderBefore ?? '1 day';
    if (_reminderBefores.contains(initialReminderBefore)) {
      _reminderBefore = initialReminderBefore;
    } else {
      _reminderBefore = 'Custom';
      final match = RegExp(r'\d+').firstMatch(initialReminderBefore);
      if (match != null) {
        _customMinutesController.text = match.group(0)!;
      }
    }

    _checkExactAlarmStatus();
  }

  Future<void> _checkExactAlarmStatus() async {
    final canExact = await NotificationService.instance.canScheduleExactAlarms();
    if (mounted) {
      setState(() => _canExactAlarm = canExact);
    }
  }

  @override
  void dispose() {
    _customMinutesController.dispose();
    super.dispose();
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  String _getRecurrenceHint(ThemeData theme) {
    final formattedTime = _time.format(context);
    switch (_repeat) {
      case 'Daily':
        return '🔔 Repeats every day at $formattedTime';
      case 'Weekly':
        final weekdayName = DateFormat('EEEE').format(_date);
        return '🔔 Repeats every $weekdayName at $formattedTime';
      case 'Monthly':
        return '🔔 Repeats on the ${_getOrdinal(_date.day)} of every month at $formattedTime';
      case 'Yearly':
        final dateStr = DateFormat('MMMM d').format(_date);
        return '🔔 Repeats every year on $dateStr at $formattedTime';
      default:
        return '🔔 Fires once on ${DateFormat('MMM dd, yyyy').format(_date)} at $formattedTime';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.reminder != null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
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
                    isEditing ? 'Edit Reminder' : 'New Reminder',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                initialValue: _title,
                decoration: InputDecoration(
                  labelText: 'Reminder Title *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                onSaved: (val) => _title = val!.trim(),
              ),
              const SizedBox(height: 12),

              // Category
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
              ),
              const SizedBox(height: 12),

              // Date & Time pickers
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 1825)),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat('MMM dd, yyyy').format(_date)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        child: Text(_time.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Repeat & Priority
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _repeat,
                      decoration: InputDecoration(
                        labelText: 'Repeat (Offline)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.repeat),
                      ),
                      items: _repeats
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) => setState(() => _repeat = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.flag),
                      ),
                      items: _priorities
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) => setState(() => _priority = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Recurrence schedule helper badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  _getRecurrenceHint(theme),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reminder Before
              DropdownButtonFormField<String>(
                initialValue: _reminderBefore,
                decoration: InputDecoration(
                  labelText: 'Notification Offset',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.alarm),
                ),
                items: _reminderBefores
                    .map((rb) => DropdownMenuItem(value: rb, child: Text(rb)))
                    .toList(),
                onChanged: (val) => setState(() => _reminderBefore = val!),
              ),

              // Custom offset minutes input
              if (_reminderBefore == 'Custom') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Custom Offset (Minutes before event)',
                    hintText: 'e.g. 45',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(Icons.timer_outlined),
                    suffixText: 'minutes before',
                  ),
                  validator: (val) {
                    if (_reminderBefore == 'Custom') {
                      final n = int.tryParse(val ?? '');
                      if (n == null || n <= 0) return 'Enter a valid number of minutes';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),

              // Description
              TextFormField(
                initialValue: _description,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.notes),
                ),
                onSaved: (val) => _description = val ?? '',
              ),

              // Exact alarm info notice if disabled on device
              if (!_canExactAlarm && Platform.isAndroid) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Exact Alarms access is off. Alarms will use battery-saving mode.',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                        ),
                      ),
                      TextButton(
                        onPressed: () => NotificationService.instance.openExactAlarmSettings(),
                        child: const Text('Enable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEditing ? 'Update Reminder' : 'Save Reminder',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final reminderTime =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    final effectiveReminderBefore = _reminderBefore == 'Custom'
        ? '${_customMinutesController.text.trim()} minutes'
        : _reminderBefore;

    final reminder = Reminder(
      id: widget.reminder?.id ?? const Uuid().v4(),
      title: _title,
      category: _category,
      description: _description,
      date: DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
      time: reminderTime,
      repeat: _repeat,
      reminderBefore: effectiveReminderBefore,
      priority: _priority,
      notes: _notes,
      completed: widget.reminder?.completed ?? false,
    );

    await HiveService.instance.saveReminder(reminder);
    await NotificationService.instance.scheduleReminderNotification(reminder);
    if (mounted) Navigator.pop(context, reminder);
  }
}

