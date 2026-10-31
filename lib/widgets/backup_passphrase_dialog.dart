import 'package:flutter/material.dart';

class BackupPassphraseDialog extends StatefulWidget {
  const BackupPassphraseDialog({
    super.key,
    required this.restoring,
  });

  final bool restoring;

  @override
  State<BackupPassphraseDialog> createState() =>
      _BackupPassphraseDialogState();
}

Future<String?> showBackupPassphraseDialog(
  BuildContext context, {
  required bool restoring,
}) => showDialog<String>(
  context: context,
  builder: (context) => BackupPassphraseDialog(restoring: restoring),
);

class _BackupPassphraseDialogState extends State<BackupPassphraseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.restoring ? 'Enter backup passphrase' : 'Protect this backup',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.restoring
                      ? 'Enter the passphrase used when this backup was created. Older unencrypted backups can be restored with a blank passphrase.'
                      : 'Use a passphrase you can keep safe and enter again on another device. Reminder Hub will not store it.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'If you forget the passphrase, protected backup contents may be unrecoverable.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passphraseController,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Backup passphrase',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (widget.restoring) {
                      return null;
                    }
                    if ((value ?? '').trim().runes.length < 12) {
                      return 'Use at least 12 characters';
                    }
                    return null;
                  },
                ),
                if (!widget.restoring) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm passphrase',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value != _passphraseController.text
                        ? 'Passphrases do not match'
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_passphraseController.text);
          },
          child: Text(widget.restoring ? 'Continue' : 'Encrypt backup'),
        ),
      ],
    );
  }
}
