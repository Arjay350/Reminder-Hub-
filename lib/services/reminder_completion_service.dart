import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import 'hive_service.dart';
import 'notification_service.dart';
import 'pet_service.dart';
import '../widgets/reminder_completion_dialog.dart';

class ReminderCompletionService {
  static final ReminderCompletionService instance =
      ReminderCompletionService._internal();
  ReminderCompletionService._internal();

  static const _uuid = Uuid();
  final Set<String> _inFlightIds = <String>{};

  /// Prompts the user with a confirmation dialog and completes the reminder if confirmed.
  /// Returns `true` if the reminder was completed, `false` otherwise.
  Future<bool> confirmAndCompleteReminder(
    BuildContext context,
    Reminder reminder,
  ) async {
    if (_inFlightIds.contains(reminder.id)) return false;
    _inFlightIds.add(reminder.id);

    try {
      final confirmed = await showReminderCompletionDialog(
        context,
        reminderTitle: reminder.title,
      );
      if (!confirmed) return false;

      return await _executeCompletion(reminder);
    } finally {
      _inFlightIds.remove(reminder.id);
    }
  }

  /// Directly executes the completion workflow without showing a dialog.
  /// Protected against rapid double-invocations for the same reminder ID.
  Future<bool> completeReminder(Reminder reminder) async {
    if (_inFlightIds.contains(reminder.id)) return false;
    _inFlightIds.add(reminder.id);

    try {
      return await _executeCompletion(reminder);
    } finally {
      _inFlightIds.remove(reminder.id);
    }
  }

  Future<bool> _executeCompletion(Reminder reminder) async {
    try {
      final hive = HiveService.instance;
      await hive.ensureInitialized();

      final now = DateTime.now();
      final historyRecord = ReminderHistoryRecord(
        id: _uuid.v4(),
        reminderId: reminder.id,
        title: reminder.title,
        category: reminder.category,
        originalDueDate: reminder.dueDateTime,
        completedAt: now,
        time: reminder.time,
        repeat: reminder.repeat,
        priority: reminder.priority,
        notes: reminder.notes,
      );

      // Persist completion record
      await hive.saveReminderHistoryRecord(historyRecord);

      if (reminder.isRecurring) {
        // Calculate the next occurrence preserving anchor day
        final nextOccurrence = reminder.calculateNextOccurrence(now);

        final updatedReminder = reminder.copyWith(
          date: nextOccurrence,
          completed: false,
          targetDayOfMonth: reminder.targetDayOfMonth ?? reminder.date.day,
        );

        // Save updated reminder with advanced occurrence date
        await hive.saveReminder(updatedReminder);

        // Schedule notification for the new upcoming occurrence
        await NotificationService.instance.scheduleReminderNotification(
          updatedReminder,
        );
      } else {
        // One-time reminder
        final updatedReminder = reminder.copyWith(completed: true);
        await hive.saveReminder(updatedReminder);

        // Cancel pending notification for this completed one-time reminder
        await NotificationService.instance.cancelNotificationForId(reminder.id);
      }

      // Pet companion progress
      PetService.instance.onReminderCompleted(reminder);

      // Notify any listeners across the app
      hive.notifyRemindersChanged();

      return true;
    } catch (e) {
      debugPrint('Error completing reminder ${reminder.id}: $e');
      return false;
    }
  }

  /// Reverts a completed one-time reminder back to active/pending status.
  Future<bool> uncompleteReminder(Reminder reminder) async {
    if (_inFlightIds.contains(reminder.id)) return false;
    _inFlightIds.add(reminder.id);

    try {
      final hive = HiveService.instance;
      await hive.ensureInitialized();

      final updated = reminder.copyWith(completed: false);
      await hive.saveReminder(updated);

      // Attempt to reschedule notification if due date/time is in the future
      await NotificationService.instance.scheduleReminderNotification(updated);

      hive.notifyRemindersChanged();
      return true;
    } catch (e) {
      debugPrint('Error uncompleting reminder ${reminder.id}: $e');
      return false;
    } finally {
      _inFlightIds.remove(reminder.id);
    }
  }
}
