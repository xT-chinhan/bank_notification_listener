import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_notification_listener/models/raw_notification.dart';
import 'package:bank_notification_listener/services/notification_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationBridge Tests', () {
    const MethodChannel methodChannel =
        MethodChannel('com.chinhan.xt_manager/methods');
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        if (methodCall.method == 'isPermissionGranted') {
          return true;
        } else if (methodCall.method == 'openPermissionSettings') {
          return null;
        } else if (methodCall.method == 'openAppDetails') {
          return null;
        } else if (methodCall.method == 'getSavedNotifications') {
          return [
            {
              'id': 'saved-1',
              'packageName': 'com.VCB',
              'title': 'Vietcombank',
              'text': 'TK 0123 +1,000,000VND',
              'subText': 'GD: 1,000,000VND',
              'timestamp': 1710000000000,
              'postTime': 1710000000000,
            }
          ];
        } else if (methodCall.method == 'clearSavedNotifications') {
          return true;
        } else if (methodCall.method == 'isIgnoringBatteryOptimizations') {
          return true;
        } else if (methodCall.method == 'requestIgnoreBatteryOptimizations') {
          return null;
        } else if (methodCall.method == 'openAutostartSettings') {
          return null;
        } else if (methodCall.method == 'startForegroundService') {
          return null;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    test('is singleton instance', () {
      final instance1 = NotificationBridge.instance;
      final instance2 = NotificationBridge.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('isPermissionGranted calls method channel', () async {
      final bridge = NotificationBridge.instance;
      final granted = await bridge.isPermissionGranted();
      expect(granted, isTrue);
      expect(methodCalls.any((call) => call.method == 'isPermissionGranted'), isTrue);
    });

    test('openSettings calls method channel', () async {
      final bridge = NotificationBridge.instance;
      await bridge.openSettings();
      expect(methodCalls.any((call) => call.method == 'openPermissionSettings'), isTrue);
    });

    test('openAppDetails calls method channel', () async {
      final bridge = NotificationBridge.instance;
      await bridge.openAppDetails();
      expect(methodCalls.any((call) => call.method == 'openAppDetails'), isTrue);
    });

    test('getSavedNotifications parses and returns saved list', () async {
      final bridge = NotificationBridge.instance;
      final list = await bridge.getSavedNotifications();
      expect(list.length, 1);
      expect(list.first.packageName, 'com.VCB');
      expect(list.first.title, 'Vietcombank');
      expect(list.first.isBankNotification, isTrue);
      expect(methodCalls.any((call) => call.method == 'getSavedNotifications'), isTrue);
    });

    test('clearSavedNotifications calls method channel', () async {
      final bridge = NotificationBridge.instance;
      final cleared = await bridge.clearSavedNotifications();
      expect(cleared, isTrue);
      expect(methodCalls.any((call) => call.method == 'clearSavedNotifications'), isTrue);
    });

    test('isIgnoringBatteryOptimizations and request calls work', () async {
      final bridge = NotificationBridge.instance;
      final ignoring = await bridge.isIgnoringBatteryOptimizations();
      expect(ignoring, isTrue);
      await bridge.requestIgnoreBatteryOptimizations();
      expect(methodCalls.any((call) => call.method == 'requestIgnoreBatteryOptimizations'), isTrue);
    });

    test('openAutostartSettings and startForegroundService invoke method channels', () async {
      final bridge = NotificationBridge.instance;
      await bridge.openAutostartSettings();
      await bridge.startForegroundService();
      expect(methodCalls.any((call) => call.method == 'openAutostartSettings'), isTrue);
      expect(methodCalls.any((call) => call.method == 'startForegroundService'), isTrue);
    });

    test('injectSimulatedNotification adds notification to stream', () async {
      final bridge = NotificationBridge.instance;
      const sample = RawNotification(
        id: 'mock-1',
        packageName: 'com.VCB',
        title: 'Vietcombank',
        text: 'So du TK 001100... thay doi +500,000 VND',
        subText: 'GD: 500,000 VND',
        timestamp: 1710000000000,
        isBankNotification: true,
      );

      expectLater(
        bridge.notificationStream,
        emits(sample),
      );

      bridge.injectSimulatedNotification(sample);
    });
  });
}
