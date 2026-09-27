import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class AIAccountDialog extends StatefulWidget {
  const AIAccountDialog({super.key, this.account});

  final AIAccount? account;

  @override
  State<AIAccountDialog> createState() => _AIAccountDialogState();
}

class _AIAccountDialogState extends State<AIAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;

  late String _authMethod; // 'Password', 'Google', 'OAuth', 'API Key'
  late String _service;
  late String _accountName;
  late String _username;
  late String _password;
  bool _obscurePassword = true;
  late String _plan;
  late DateTime _resetDate;
  late TimeOfDay _resetTime;
  late String _resetSchedule;
  late DateTime _renewalDate;
  late String _notes;

  final List<String> _resetSchedules = [
    'Exact Date/Time',
    'Daily',
    'Weekly',
    'Monthly',
  ];

  final List<String> _services = [
    'ChatGPT',
    'Claude',
    'Gemini',
    'Grok',
    'Cursor',
    'GitHub Copilot',
    'Perplexity',
    'DeepSeek',
    'Custom',
  ];

  final List<String> _plans = [
    'Free',
    'Plus',
    'Pro',
    'Team',
    'Enterprise',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _service = a?.service ?? 'ChatGPT';
    _accountName = a?.accountName ?? 'Personal';
    _authMethod =
        a?.authMethod ?? (a?.isGoogleAuth == true ? 'Google' : 'Password');
    _emailController = TextEditingController(text: a?.email ?? '');
    _username = a?.username ?? '';
    // Never preload a persisted password into an editable or visible field.
    // An empty edit value means keep the existing saved password unchanged.
    _password = '';
    _plan = a?.plan ?? 'Plus';
    _resetDate = a?.resetDate ?? DateTime.now().add(const Duration(days: 30));
    _resetTime = a != null
        ? _parseTimeOfDay(a.resetTime)
        : const TimeOfDay(hour: 22, minute: 0);
    final rawSched = a?.resetSchedule ?? 'Exact Date/Time';
    if (_resetSchedules.any((s) => s.toLowerCase() == rawSched.toLowerCase())) {
      _resetSchedule = _resetSchedules.firstWhere(
        (s) => s.toLowerCase() == rawSched.toLowerCase(),
      );
    } else {
      _resetSchedule = 'Exact Date/Time';
    }
    _renewalDate =
        a?.renewalDate ?? DateTime.now().add(const Duration(days: 30));
    _notes = a?.notes ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
      return const TimeOfDay(hour: 22, minute: 0); // 10:00 PM
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _getResetScheduleDescription(String schedule) {
    switch (schedule) {
      case 'Daily':
        return 'Repeats every day at the selected reset time.';
      case 'Weekly':
        return 'Repeats every week on this day at the selected reset time.';
      case 'Monthly':
        return 'Repeats every month on this date at the selected reset time.';
      case 'Exact Date/Time':
      default:
        return 'Notifies once on this exact date and time. Will not repeat daily.';
    }
  }

  void _toggleGoogleAuth() {
    if (_authMethod == 'Google') {
      setState(() => _authMethod = 'Password');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google authentication disabled')),
      );
      return;
    }

    final settings = HiveService.instance.getSettings();
    final nameClean = settings.userName.toLowerCase().replaceAll(' ', '.');
    final currentEmail = _emailController.text.trim();
    String googleEmail = currentEmail;

    if (googleEmail.isEmpty) {
      googleEmail = '$nameClean@gmail.com';
    } else if (!googleEmail.contains('@')) {
      googleEmail = '$googleEmail@gmail.com';
    } else if (!googleEmail.endsWith('@gmail.com')) {
      final prefix = googleEmail.split('@').first;
      googleEmail = '$prefix@gmail.com';
    }

    setState(() {
      _authMethod = 'Google';
      _emailController.text = googleEmail;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Linked with Google Account ($googleEmail)')),
          ],
        ),
        backgroundColor: const Color(0xFF4285F4),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;
    final isFreePlan = _plan.toLowerCase() == 'free';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                        isEditing
                            ? Icons.edit_rounded
                            : Icons.smart_toy_outlined,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Edit AI Account' : 'New AI Account',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
              DropdownButtonFormField<String>(
                initialValue: _service,
                decoration: InputDecoration(
                  labelText: 'AI Service',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.smart_toy),
                ),
                items: _services
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _service = val!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _accountName,
                decoration: InputDecoration(
                  labelText: 'Account Label (e.g. Personal, School, Work)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Please enter account label'
                    : null,
                onSaved: (val) => _accountName = val!,
              ),
              const SizedBox(height: 12),

              // Email Address with Google Sign-In Option
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      tooltip: 'Append @gmail.com',
                      onPressed: () {
                        final text = _emailController.text.trim();
                        if (text.isEmpty) {
                          _emailController.text = '@gmail.com';
                        } else if (text.contains('@')) {
                          final prefix = text.split('@').first;
                          _emailController.text = '$prefix@gmail.com';
                        } else {
                          _emailController.text = '$text@gmail.com';
                        }
                        _emailController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _emailController.text.length),
                        );
                      },
                      icon: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4285F4),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'G',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please enter email'
                    : null,
              ),
              const SizedBox(height: 8),

              // Google Sign-In Action Button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: _toggleGoogleAuth,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    side: BorderSide(
                      color: _authMethod == 'Google'
                          ? const Color(0xFF4285F4)
                          : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1)),
                      width: _authMethod == 'Google' ? 1.8 : 1.0,
                    ),
                    backgroundColor: _authMethod == 'Google'
                        ? const Color(0xFF4285F4).withValues(alpha: 0.12)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_authMethod == 'Google') ...[
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4285F4),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.g_mobiledata_rounded,
                            color: Color(0xFF4285F4),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        _authMethod == 'Google'
                            ? 'Google authentication enabled (Tap to disable)'
                            : 'Continue with Google',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _authMethod == 'Google'
                              ? const Color(0xFF4285F4)
                              : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_authMethod != 'Google') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _username,
                        decoration: InputDecoration(
                          labelText: 'Username (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onSaved: (val) => _username = val ?? '',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _password,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: widget.account?.password.isNotEmpty == true
                              ? 'New Password (optional)'
                              : 'Password',
                          helperText:
                              widget.account?.password.isNotEmpty == true
                              ? 'Leave blank to keep the saved password'
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (val) {
                          final hasSavedPassword =
                              widget.account?.password.isNotEmpty == true;
                          if ((val == null || val.isEmpty) &&
                              !hasSavedPassword) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                        onSaved: (val) => _password = val ?? '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              DropdownButtonFormField<String>(
                initialValue: _plan,
                decoration: InputDecoration(
                  labelText: 'Subscription Plan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.workspace_premium_outlined),
                ),
                items: _plans
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _plan = val);
                },
              ),
              const SizedBox(height: 14),

              Text(
                'AI Quota / Usage Reset Schedule',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _resetSchedule,
                decoration: InputDecoration(
                  labelText: 'Reset Frequency',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.repeat),
                ),
                items: _resetSchedules
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _resetSchedule = val);
                },
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _resetSchedule == 'Exact Date/Time'
                          ? Icons.event_available_outlined
                          : Icons.info_outline,
                      size: 16,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getResetScheduleDescription(_resetSchedule),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _resetDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 1825),
                          ),
                        );
                        if (picked != null) setState(() => _resetDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Reset Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          prefixIcon: const Icon(Icons.event),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(_resetDate),
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
                          initialTime: _resetTime,
                        );
                        if (picked != null) setState(() => _resetTime = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Reset Time',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        child: Text(_formatTimeOfDay(_resetTime)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Subscription Renewal Date (HIDDEN when Free plan is selected)
              if (!isFreePlan) ...[
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _renewalDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 1825)),
                    );
                    if (picked != null) setState(() => _renewalDate = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Subscription Renewal Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      prefixIcon: const Icon(Icons.event_repeat),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_renewalDate),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                initialValue: _notes,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.notes),
                ),
                onSaved: (val) => _notes = val ?? '',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEditing ? 'Update AI Account' : 'Save AI Account',
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

    final account = AIAccount(
      id: widget.account?.id ?? const Uuid().v4(),
      service: _service,
      accountName: _accountName,
      email: _emailController.text.trim(),
      username: _username,
      password: _password.isEmpty && widget.account != null
          ? widget.account!.password
          : _password,
      authMethod: _authMethod,
      plan: _plan,
      resetDate: _resetDate,
      resetTime: _formatTimeOfDay(_resetTime),
      resetSchedule: _resetSchedule,
      renewalDate: _renewalDate,
      notes: _notes,
      resetState: widget.account?.resetState ?? 'none',
      resetCooldownUntil: widget.account?.resetCooldownUntil,
    );

    await HiveService.instance.saveAIAccount(account);
    await NotificationService.instance.scheduleAIResetNotification(account);
    if (mounted) Navigator.pop(context, account);
  }
}
