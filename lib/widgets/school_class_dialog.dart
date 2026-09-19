import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';

class SchoolClassDialog extends StatefulWidget {
  const SchoolClassDialog({
    super.key,
    this.schoolClass,
    this.initialDay,
    this.initialStartTime,
    this.initialEndTime,
  });

  final SchoolClass? schoolClass;
  final int? initialDay;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;

  @override
  State<SchoolClassDialog> createState() => _SchoolClassDialogState();
}

class _SchoolClassDialogState extends State<SchoolClassDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _subject;
  late String _courseCode;
  late String _teacher;
  late String _room;
  late List<int> _daysOfWeek;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _reminderBefore;
  late String _notes;
  late int _colorValue;

  final List<String> _reminderBefores = [
    'At start',
    '5 minutes',
    '10 minutes',
    '15 minutes',
    '30 minutes',
    '45 minutes',
    '1 hour',
  ];

  final List<int> _availableColors = [
    0xFF14B8A6, // Teal
    0xFF6366F1, // Indigo
    0xFF8B5CF6, // Purple
    0xFF3B82F6, // Blue
    0xFF10B981, // Emerald
    0xFFF59E0B, // Amber
    0xFFEC4899, // Pink
    0xFFEF4444, // Red
  ];

  final List<Map<String, dynamic>> _days = [
    {'day': 1, 'label': 'Mon'},
    {'day': 2, 'label': 'Tue'},
    {'day': 3, 'label': 'Wed'},
    {'day': 4, 'label': 'Thu'},
    {'day': 5, 'label': 'Fri'},
    {'day': 6, 'label': 'Sat'},
    {'day': 7, 'label': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.schoolClass;
    _subject = c?.subject ?? '';
    _courseCode = c?.courseCode ?? '';
    _teacher = c?.teacher ?? '';
    _room = c?.room ?? '';
    _daysOfWeek = c != null
        ? List<int>.from(c.daysOfWeek)
        : (widget.initialDay != null ? [widget.initialDay!] : [1, 3, 5]); // Default Mon, Wed, Fri or initialDay
    _startTime = c != null
        ? _parseTimeOfDay(c.startTime)
        : (widget.initialStartTime ?? const TimeOfDay(hour: 8, minute: 0));
    _endTime = c != null
        ? _parseTimeOfDay(c.endTime)
        : (widget.initialEndTime ??
            (widget.initialStartTime != null
                ? TimeOfDay(
                    hour: (widget.initialStartTime!.hour + 1).clamp(0, 23),
                    minute: widget.initialStartTime!.minute,
                  )
                : const TimeOfDay(hour: 10, minute: 0)));
    _reminderBefore = c?.reminderBefore ?? '15 minutes';
    _notes = c?.notes ?? '';
    _colorValue = c?.colorValue ?? 0xFF14B8A6;
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final numPart = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = numPart.split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.schoolClass != null;

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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEditing ? Icons.edit_rounded : Icons.school_rounded,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Edit Class Schedule' : 'New Class Schedule',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Subject / Class Name
              TextFormField(
                initialValue: _subject,
                decoration: InputDecoration(
                  labelText: 'Subject Name *',
                  hintText: 'e.g. Database Management Systems',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.school_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter subject name' : null,
                onSaved: (val) => _subject = val!.trim(),
              ),
              const SizedBox(height: 12),

              // Course Code
              TextFormField(
                initialValue: _courseCode,
                decoration: InputDecoration(
                  labelText: 'Course Code',
                  hintText: 'e.g. IT 214',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.tag_rounded),
                ),
                onSaved: (val) => _courseCode = val?.trim() ?? '',
              ),
              const SizedBox(height: 12),

              // Teacher & Room
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _teacher,
                      decoration: InputDecoration(
                        labelText: 'Teacher / Instructor (Optional)',
                        hintText: 'e.g. Prof. Smith',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      onSaved: (val) => _teacher = val?.trim() ?? '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _room,
                      decoration: InputDecoration(
                        labelText: 'Room / Location (Optional)',
                        hintText: 'e.g. Room 302',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.meeting_room_outlined),
                      ),
                      onSaved: (val) => _room = val?.trim() ?? '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Days of Week Selection
              Text(
                'Schedule Days (Recurring)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _days.map((d) {
                  final int day = d['day'] as int;
                  final String label = d['label'] as String;
                  final isSelected = _daysOfWeek.contains(day);

                  return FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (!_daysOfWeek.contains(day)) _daysOfWeek.add(day);
                        } else {
                          if (_daysOfWeek.length > 1) {
                            _daysOfWeek.remove(day);
                          }
                        }
                      });
                    },
                    selectedColor: Color(_colorValue).withValues(alpha: 0.2),
                    checkmarkColor: Color(_colorValue),
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Color(_colorValue) : (isDark ? Colors.grey.shade300 : Colors.black87),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Color(_colorValue).withValues(alpha: 0.4) : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Time Range (Start Time & End Time)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Time',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        child: Text(
                          _formatTimeOfDay(_startTime),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (picked != null) setState(() => _endTime = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Time',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.schedule),
                        ),
                        child: Text(
                          _formatTimeOfDay(_endTime),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Reminder Before Dropdown
              DropdownButtonFormField<String>(
                initialValue: _reminderBefore,
                decoration: InputDecoration(
                  labelText: 'Notification Timing',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.alarm),
                ),
                items: _reminderBefores
                    .map((rb) => DropdownMenuItem(value: rb, child: Text(rb)))
                    .toList(),
                onChanged: (val) => setState(() => _reminderBefore = val!),
              ),
              const SizedBox(height: 12),

              // Color Tag Selection
              Text(
                'Subject Color Tag',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _availableColors.map((colorVal) {
                  final isSelected = _colorValue == colorVal;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = colorVal),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(colorVal).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                initialValue: _notes,
                decoration: InputDecoration(
                  labelText: 'Notes / Zoom link / Syllabus (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.notes),
                ),
                onSaved: (val) => _notes = val?.trim() ?? '',
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(_colorValue),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEditing ? 'Update Class Schedule' : 'Save Class Schedule',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    if (_daysOfWeek.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day for the class')),
      );
      return;
    }
    _formKey.currentState!.save();

    final schoolClass = SchoolClass(
      id: widget.schoolClass?.id ?? const Uuid().v4(),
      subject: _subject,
      courseCode: _courseCode,
      teacher: _teacher,
      room: _room,
      daysOfWeek: _daysOfWeek,
      startTime: _formatTimeOfDay(_startTime),
      endTime: _formatTimeOfDay(_endTime),
      reminderBefore: _reminderBefore,
      notes: _notes,
      colorValue: _colorValue,
    );

    await HiveService.instance.saveSchoolClass(schoolClass);
    await NotificationService.instance.scheduleSchoolClassNotification(schoolClass);
    await WidgetService.instance.updateSchoolWidget();
    if (mounted) Navigator.pop(context, schoolClass);
  }
}
