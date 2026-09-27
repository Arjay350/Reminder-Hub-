import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';
import '../services/password_route_observer.dart';

class PasswordTextField extends StatefulWidget {
  const PasswordTextField({
    super.key,
    required this.password,
    this.label = 'Password',
    this.authenticateOnReveal = false,
    this.authenticateOnCopy = true,
    this.hideOnBackground = false,
    this.isScreenActive = true,
  });

  final String password;
  final String label;
  final bool authenticateOnReveal;
  final bool authenticateOnCopy;
  final bool hideOnBackground;
  final bool isScreenActive;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField>
    with WidgetsBindingObserver, RouteAware {
  bool _obscured = true;
  bool _authenticating = false;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    passwordRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.hideOnBackground) return;
    final route = ModalRoute.of(context);
    if (_route != route) {
      if (_route != null) passwordRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) passwordRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant PasswordTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hideOnBackground &&
        ((!widget.isScreenActive && oldWidget.isScreenActive) ||
            widget.password != oldWidget.password) &&
        !_obscured) {
      _obscured = true;
    }
  }

  @override
  void didPushNext() => _hideSavedPassword();

  @override
  void didPop() => _hideSavedPassword();

  void _hideSavedPassword() {
    if (mounted && !_obscured) setState(() => _obscured = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.hideOnBackground &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        !_obscured &&
        mounted) {
      setState(() => _obscured = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _obscured ? '••••••••••••' : widget.password,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: _obscured ? 2.0 : 0.5,
                    fontFamily: _obscured ? 'Monospace' : null,
                  ),
                ),
              ],
            ),
          ),

          // Eye button — shows spinner while biometric prompt is open
          if (_authenticating)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                _obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              tooltip: _obscured ? 'Show password' : 'Hide password',
              onPressed: _toggleVisibility,
            ),

          // Copy button
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copy password',
            onPressed: _copyPassword,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleVisibility() async {
    if (!_obscured) {
      setState(() => _obscured = true);
      return;
    }
    if (!widget.authenticateOnReveal) {
      setState(() => _obscured = false);
      return;
    }

    final authenticated = await _authenticate(
      'Authenticate to reveal the saved password',
    );
    if (authenticated && mounted) setState(() => _obscured = false);
  }

  Future<void> _copyPassword() async {
    if (!widget.authenticateOnCopy) {
      await Clipboard.setData(ClipboardData(text: widget.password));
      if (mounted) _showCopiedMessage();
      return;
    }

    final authenticated = await _authenticate(
      'Verify your identity to copy the password',
    );
    if (!authenticated || !mounted) return;

    await Clipboard.setData(ClipboardData(text: widget.password));
    if (mounted) _showCopiedMessage();
  }

  Future<bool> _authenticate(String reason) async {
    if (_authenticating) return false;
    setState(() => _authenticating = true);

    try {
      return await BiometricService.instance.authenticate(
        reason: reason,
      );
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  void _showCopiedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
