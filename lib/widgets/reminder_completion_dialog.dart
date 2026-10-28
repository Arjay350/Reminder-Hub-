import 'package:flutter/material.dart';

Future<bool> showReminderCompletionDialog(
  BuildContext context, {
  required String reminderTitle,
}) async {
  final theme = Theme.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Complete this reminder?',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Are you sure you want to mark "$reminderTitle" as completed? '
        'You can view this reminder later in Completion History.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Mark as Complete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
