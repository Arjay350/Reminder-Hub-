import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/security/security_service.dart';
import '../services/hive_service.dart';

/// Small in-place PIN gate for sensitive actions. It leaves the current route
/// visible behind a dialog and optionally offers the configured biometric.
Future<bool> showSecureActionGate(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SecureActionDialog(title: title, message: message),
      ) ??
      false;
}

class _SecureActionDialog extends StatefulWidget {
  const _SecureActionDialog({required this.title, required this.message});
  final String title;
  final String message;

  @override
  State<_SecureActionDialog> createState() => _SecureActionDialogState();
}

class _SecureActionDialogState extends State<_SecureActionDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final settings = HiveService.instance.getSettings();
    final available = settings.biometricEnabled &&
        await SecurityService.instance.isBiometricsAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _verifyPin() async {
    if (_busy) return;
    setState(() => _busy = true);
    final valid = await SecurityService.instance.verifyPin(_controller.text);
    if (!mounted) return;
    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Incorrect PIN';
        _controller.clear();
      });
    }
  }

  Future<void> _verifyBiometric() async {
    if (_busy) return;
    setState(() => _busy = true);
    final valid = await SecurityService.instance.authenticate(
      reason: widget.message,
    );
    if (!mounted) return;
    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Authentication was not completed';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.lock_outline_rounded),
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.message),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '4-digit app PIN',
            errorText: _error,
            counterText: '',
          ),
          onSubmitted: (_) => _verifyPin(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      if (_biometricAvailable)
        IconButton(
          tooltip: 'Use fingerprint',
          onPressed: _busy ? null : _verifyBiometric,
          icon: const Icon(Icons.fingerprint_rounded),
        ),
      FilledButton(onPressed: _busy ? null : _verifyPin, child: const Text('Unlock')),
    ],
  );
}
