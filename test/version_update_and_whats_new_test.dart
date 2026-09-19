import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/core/constants/app_constants.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/screens/about/about_screen.dart';
import 'package:reminder_hub/widgets/whats_new_dialog.dart';

void main() {
  test('app version and release registry are 1.3.1', () {
    expect(AppConstants.appVersion, '1.3.1');
    final release = WhatsNewRegistry.getRelease('1.3.1');
    expect(release, isNotNull);
    expect(release!.appTitle, 'Reminder Hub 1.3.1');
    expect(release.items.length, 8);
    expect(
      release.items.map((item) => item.title),
      containsAll(<String>[
        'Backup and Restore',
        'School Schedule Sharing',
        'Reliable Scheduled Notifications',
        'Fresh Reminders Hub List Updates',
        'Improved School and Bills Widgets',
        'Widget Navigation Fixes',
        'Preserved Paid Bill History',
        'Removed Notification History',
      ]),
    );
  });

  test('old settings still default the release version field safely', () {
    final settings = AppSettings.fromJson({
      'themeMode': 'System',
      'notificationTime': '09:00 AM',
      'currency': 'PHP',
      'appLock': false,
      'biometricEnabled': false,
    });
    expect(settings.lastSeenWhatsNewVersion, '');
    expect(settings.gasNotificationDays, 3);
  });

  test('settings preserve the user-selected backup folder', () {
    final settings = AppSettings.fromJson({
      'themeMode': 'System',
      'notificationTime': '09:00 AM',
      'currency': 'PHP',
      'appLock': false,
      'biometricEnabled': false,
      'backupFolderPath': r'/storage/emulated/0/ReminderHub',
    });
    expect(settings.backupFolderPath, r'/storage/emulated/0/ReminderHub');
    expect(
      AppSettings.fromJson(settings.toJson()).backupFolderPath,
      settings.backupFolderPath,
    );
  });

  test('malformed legacy settings during app updates fall back safely', () {
    final settings = AppSettings.fromJson({
      'themeMode': '{bad json',
      'notificationTime': 123,
      'currency': true,
      'appLock': 'false',
      'biometricEnabled': null,
    });

    expect(settings.themeMode, 'System');
    expect(settings.currency, '₱');
    expect(settings.appLock, isFalse);
    expect(settings.notificationTime, '09:00 AM');
  });

  testWidgets('WhatsNewDialog renders the 1.3.1 release', (tester) async {
    final release = WhatsNewRegistry.getRelease('1.3.1')!;
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WhatsNewDialog(
            release: release,
            onDismissed: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What\'s New'), findsOneWidget);
    expect(find.text('Version 1.3.1'), findsOneWidget);
    expect(find.text('Backup and Restore'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Got It'));
    expect(dismissed, isTrue);
  });

  testWidgets('AboutScreen displays a compact current release flashcard', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.3.1 • 100% Offline & Private'), findsOneWidget);
    expect(find.text('What\'s New'), findsOneWidget);
    expect(
      find.text('Version 1.3.1 • See what\'s new and improved.'),
      findsOneWidget,
    );
    expect(find.text('Backup and Restore'), findsNothing);
    await tester.tap(find.text('View Updates'));
    await tester.pumpAndSettle();
    expect(find.text('Backup and Restore'), findsOneWidget);
  });

  testWidgets('AboutScreen opens the circular developer profile', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Your 6\'2 Developer'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('developer_profile_photo')));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Zoomable developer profile photo'),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
