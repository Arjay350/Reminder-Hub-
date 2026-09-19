import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../services/hive_service.dart';
import '../utils/password_strength.dart';

class UserAccountDialog extends StatefulWidget {
  const UserAccountDialog({super.key, this.account});

  final UserAccount? account;

  @override
  State<UserAccountDialog> createState() => _UserAccountDialogState();
}

class _UserAccountDialogState extends State<UserAccountDialog> {
  final _formKey = GlobalKey<FormState>();

  late String
  _authMethod; // 'Password', 'Google', 'OAuth / SSO', 'API Key / Token'
  late String _serviceName;
  late String _accountName;
  late String _username;
  late String _email;
  late TextEditingController _emailController;
  late String _password;
  bool _obscurePassword = true;
  late String _website;
  late String _category;
  late String _notes;
  late String _recoveryEmail;
  late TextEditingController _recoveryEmailController;
  late String _recoveryPhone;
  late String _securityQuestion;
  late String _pin;
  late String _accountNumber;
  final LocalAuthentication _localAuthentication = LocalAuthentication();

  final List<String> _categories = [
    'Websites',
    'Apps',
    'Gaming',
    'Finance',
    'Email',
    'Work',
    'School',
    'Shopping',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _serviceName = a?.serviceName ?? '';
    _accountName = a?.accountName ?? 'Personal';
    _authMethod =
        a?.authMethod ?? (a?.isGoogleAuth == true ? 'Google' : 'Password');
    _username = a?.username ?? '';
    _email = a?.email ?? '';
    _emailController = TextEditingController(text: _email);
    _password = a?.password ?? '';
    _website = a?.website ?? '';
    _category = a?.category ?? 'Websites';
    _notes = a?.notes ?? '';
    _recoveryEmail = a?.recoveryEmail ?? '';
    _recoveryEmailController = TextEditingController(text: _recoveryEmail);
    _recoveryPhone = a?.recoveryPhone ?? '';
    _securityQuestion = a?.securityQuestion ?? '';
    _pin = a?.pin ?? '';
    _accountNumber = a?.accountNumber ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _recoveryEmailController.dispose();
    super.dispose();
  }

  void _signInWithGoogle() {
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
      _email = googleEmail;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPasswordRequired = _authMethod == 'Password';

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
                            : Icons.lock_outline_rounded,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Edit Saved Account' : 'New Saved Account',
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
              TextFormField(
                initialValue: _serviceName,
                decoration: InputDecoration(
                  labelText: 'Service / App / Website Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Please enter service name'
                    : null,
                onSaved: (val) => _serviceName = val!,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _accountName,
                      decoration: InputDecoration(
                        labelText: 'Account Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please enter account name'
                          : null,
                      onSaved: (val) => _accountName = val!,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _username,
                decoration: InputDecoration(
                  labelText: 'Username (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                onSaved: (val) => _username = val ?? '',
              ),
              const SizedBox(height: 12),

              if (_category == 'Finance') ...[
                TextFormField(
                  initialValue: _accountNumber,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Account Number (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                  ),
                  onSaved: (val) => _accountNumber = val?.trim() ?? '',
                ),
                const SizedBox(height: 12),
              ],

              // Email Address with Google Sign-in Option
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
                onSaved: (val) => _email = val ?? '',
              ),
              const SizedBox(height: 8),

              // Google Sign-In Action Button
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: _signInWithGoogle,
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
                            ? 'Authenticated with Google (No Password Needed)'
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

              // Password field
              TextFormField(
                initialValue: _password,
                obscureText: _obscurePassword,
                onChanged: (val) => setState(() => _password = val),
                decoration: InputDecoration(
                  labelText: isPasswordRequired
                      ? 'Password'
                      : 'Password (Optional for Google / SSO)',
                  hintText: isPasswordRequired ? null : 'Optional',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.key),
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
                    onPressed: _togglePasswordVisibility,
                  ),
                ),
                validator: (val) {
                  if (isPasswordRequired && (val == null || val.isEmpty)) {
                    return 'Please enter password';
                  }
                  return null;
                },
                onSaved: (val) => _password = val ?? '',
              ),
              // Password Strength Indicator
              if (_authMethod == 'Password' && _password.isNotEmpty) ...[
                const SizedBox(height: 8),
                PasswordStrengthIndicator(password: _password),
              ],
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _website,
                decoration: InputDecoration(
                  labelText: 'Website URL (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.link),
                ),
                onSaved: (val) => _website = val ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recoveryEmailController,
                decoration: InputDecoration(
                  labelText: 'Recovery Email (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.mark_email_read_outlined),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      tooltip: 'Append @gmail.com',
                      onPressed: () {
                        final text = _recoveryEmailController.text.trim();
                        if (text.isEmpty) {
                          _recoveryEmailController.text = '@gmail.com';
                        } else if (text.contains('@')) {
                          final prefix = text.split('@').first;
                          _recoveryEmailController.text = '$prefix@gmail.com';
                        } else {
                          _recoveryEmailController.text = '$text@gmail.com';
                        }
                        _recoveryEmailController.selection =
                            TextSelection.fromPosition(
                              TextPosition(
                                offset: _recoveryEmailController.text.length,
                              ),
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
                onSaved: (val) => _recoveryEmail = val ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _notes,
                decoration: InputDecoration(
                  labelText: 'Notes / Security Details (optional)',
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
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEditing ? 'Update Account' : 'Save Account',
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

    final now = DateTime.now();
    final account = UserAccount(
      id: widget.account?.id ?? const Uuid().v4(),
      serviceName: _serviceName,
      accountName: _accountName,
      username: _username,
      email: _emailController.text.trim(),
      password: _password,
      authMethod: _authMethod,
      website: _website,
      category: _category,
      notes: _notes,
      recoveryEmail: _recoveryEmailController.text.trim(),
      recoveryPhone: _recoveryPhone,
      securityQuestion: _securityQuestion,
      pin: _pin,
      accountNumber: _category == 'Finance' ? _accountNumber : '',
      createdAt: widget.account?.createdAt ?? now,
      updatedAt: now,
    );

    await HiveService.instance.saveUserAccount(account);
    if (mounted) Navigator.pop(context, account);
  }

  Future<void> _togglePasswordVisibility() async {
    if (!_obscurePassword) {
      setState(() => _obscurePassword = true);
      return;
    }

    if (kIsWeb) return;
    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Authenticate to reveal the saved password',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
      if (authenticated && mounted) {
        setState(() => _obscurePassword = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication is unavailable.'),
          ),
        );
      }
    }
  }
}
