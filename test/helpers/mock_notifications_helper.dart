import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class MockNotificationsHelper {
  static const MethodChannel notificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  static const MethodChannel timezoneChannel =
      MethodChannel('flutter_timezone');

  final List<MethodCall> notificationsLog = <MethodCall>[];
  final List<MethodCall> timezoneLog = <MethodCall>[];

  final Map<int, Map<String, dynamic>> scheduledNotifications = {};

  bool shouldFailInitialize = false;
  bool shouldThrowOnInitialize = false;
  bool shouldThrowOnTimezone = false;
  bool notificationsPermissionGranted = true;
  bool exactAlarmsPermissionGranted = true;

  void setUp() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();

    notificationsLog.clear();
    timezoneLog.clear();
    scheduledNotifications.clear();
    shouldFailInitialize = false;
    shouldThrowOnInitialize = false;
    shouldThrowOnTimezone = false;
    notificationsPermissionGranted = true;
    exactAlarmsPermissionGranted = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, (MethodCall call) async {
      timezoneLog.add(call);
      if (call.method == 'getLocalTimezone') {
        if (shouldThrowOnTimezone) {
          throw PlatformException(
            code: 'TIMEZONE_FAIL',
            message: 'Failed to get local timezone',
          );
        }
        return 'America/New_York';
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (MethodCall call) async {
      notificationsLog.add(call);

      if (call.method == 'initialize') {
        if (shouldThrowOnInitialize) {
          throw PlatformException(code: 'INIT_FAIL', message: 'Failed to initialize notifications');
        }
        if (shouldFailInitialize) {
          return false;
        }
        return true;
      }

      if (call.method == 'areNotificationsEnabled') {
        return notificationsPermissionGranted;
      }

      if (call.method == 'requestNotificationsPermission') {
        return notificationsPermissionGranted;
      }

      if (call.method == 'requestExactAlarmsPermission') {
        return exactAlarmsPermissionGranted;
      }

      if (call.method == 'zonedSchedule') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final id = args['id'] as int;
        scheduledNotifications[id] = args;
        return null;
      }

      if (call.method == 'cancel') {
        final dynamic rawArgs = call.arguments;
        final int? id = rawArgs is int
            ? rawArgs
            : (rawArgs is Map ? rawArgs['id'] as int? : null);
        if (id != null) {
          scheduledNotifications.remove(id);
        }
        return null;
      }

      if (call.method == 'cancelAll') {
        scheduledNotifications.clear();
        return null;
      }

      if (call.method == 'pendingNotificationRequests') {
        return scheduledNotifications.entries.map((entry) {
          return <String, dynamic>{
            'id': entry.key,
            'title': entry.value['title'],
            'body': entry.value['body'],
            'payload': entry.value['payload'],
          };
        }).toList();
      }

      if (call.method == 'getActiveNotifications') {
        return <Map<String, dynamic>>[];
      }

      if (call.method == 'getNotificationAppLaunchDetails') {
        return null;
      }

      return null;
    });
  }

  void tearDown() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, null);
    notificationsLog.clear();
    timezoneLog.clear();
    scheduledNotifications.clear();
  }
}
