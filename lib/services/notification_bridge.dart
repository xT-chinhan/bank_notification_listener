import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/raw_notification.dart';
import 'bank_notification_parser.dart';

class NotificationBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.chinhan.xt_manager/methods');
  static const EventChannel _eventChannel =
      EventChannel('com.chinhan.xt_manager/events');

  static final NotificationBridge _instance = NotificationBridge._internal();
  static NotificationBridge get instance => _instance;

  final StreamController<RawNotification> _controller =
      StreamController<RawNotification>.broadcast();

  StreamSubscription<dynamic>? _nativeSubscription;
  final Uuid _uuid = const Uuid();

  NotificationBridge._internal() {
    _initNativeStream();
  }

  /// Stream emitting both real incoming notifications from Android Native
  /// and simulated notifications injected for testing.
  Stream<RawNotification> get notificationStream => _controller.stream;

  void _initNativeStream() {
    if (kIsWeb) return;
    try {
      _nativeSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            try {
              final map = Map<dynamic, dynamic>.from(event);
              final rawTimestamp = map['timestamp'] ?? map['postTime'];
              final parsedTimestamp = rawTimestamp is num
                  ? rawTimestamp.toInt()
                  : int.tryParse(rawTimestamp?.toString() ?? '') ??
                      DateTime.now().millisecondsSinceEpoch;

              final packageName = map['packageName']?.toString() ?? '';
              final title = map['title']?.toString() ?? '';
              final text = map['text']?.toString() ?? '';

              final notification = RawNotification(
                id: map['id']?.toString() ?? _uuid.v4(),
                packageName: packageName,
                title: title,
                text: text,
                subText: map['subText']?.toString(),
                timestamp: parsedTimestamp,
                isBankNotification: map['isBankNotification'] == true ||
                    BankNotificationParser.isBankApp(packageName, title, text),
              );
              _controller.add(notification);
            } catch (e, st) {
              debugPrint('NotificationBridge: Error parsing notification event: $e\n$st');
            }
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('NotificationBridge: EventChannel stream error: $error\n$stackTrace');
        },
      );
    } catch (e, st) {
      debugPrint('NotificationBridge: Failed to initialize native stream: $e\n$st');
    }
  }

  /// Inject a mock/simulated notification into the stream.
  void injectSimulatedNotification(RawNotification notif) {
    _controller.add(notif);
  }

  /// Check if the Android NotificationListenerService permission has been granted.
  Future<bool> isPermissionGranted() async {
    if (kIsWeb) return true; // Web simulation mode
    try {
      final bool? result =
          await _methodChannel.invokeMethod<bool>('isPermissionGranted');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('NotificationBridge: Error checking permission: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('NotificationBridge: Unexpected error checking permission: $e');
      return false;
    }
  }

  /// Open Android system settings to allow the user to enable NotificationListenerService.
  Future<void> openSettings() async {
    if (kIsWeb) return;
    try {
      await _methodChannel.invokeMethod<void>('openPermissionSettings');
    } on PlatformException catch (e) {
      debugPrint('NotificationBridge: Error opening settings: ${e.message}');
    } catch (e) {
      debugPrint('NotificationBridge: Unexpected error opening settings: $e');
    }
  }

  /// Open Android App Info screen to unlock "Restricted settings" (dấu 3 chấm ⋮) on Android 13/14/15.
  Future<void> openAppDetails() async {
    if (kIsWeb) return;
    try {
      await _methodChannel.invokeMethod<void>('openAppDetails');
    } on PlatformException catch (e) {
      debugPrint('NotificationBridge: Error opening app details: ${e.message}');
    } catch (e) {
      debugPrint('NotificationBridge: Unexpected error opening app details: $e');
    }
  }

  /// Retrieve notifications that were captured and saved in Native persistent storage while the app was closed or killed.
  Future<List<RawNotification>> getSavedNotifications() async {
    if (kIsWeb) return [];
    try {
      final dynamic rawList =
          await _methodChannel.invokeMethod<dynamic>('getSavedNotifications');
      if (rawList is! List) return [];

      final result = <RawNotification>[];
      for (final item in rawList) {
        if (item is Map) {
          final map = Map<dynamic, dynamic>.from(item);
          final rawTimestamp = map['timestamp'] ?? map['postTime'];
          final parsedTimestamp = rawTimestamp is num
              ? rawTimestamp.toInt()
              : int.tryParse(rawTimestamp?.toString() ?? '') ??
                  DateTime.now().millisecondsSinceEpoch;
          final packageName = map['packageName']?.toString() ?? '';
          final title = map['title']?.toString() ?? '';
          final text = map['text']?.toString() ?? '';

          result.add(RawNotification(
            id: map['id']?.toString() ?? _uuid.v4(),
            packageName: packageName,
            title: title,
            text: text,
            subText: map['subText']?.toString(),
            timestamp: parsedTimestamp,
            isBankNotification: map['isBankNotification'] == true ||
                BankNotificationParser.isBankApp(packageName, title, text),
          ));
        }
      }
      return result;
    } on PlatformException catch (e) {
      debugPrint('NotificationBridge: Error getting saved notifications: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('NotificationBridge: Unexpected error getting saved notifications: $e');
      return [];
    }
  }

  /// Clear persistent stored notifications in Native storage.
  Future<bool> clearSavedNotifications() async {
    if (kIsWeb) return true;
    try {
      final bool? result =
          await _methodChannel.invokeMethod<bool>('clearSavedNotifications');
      return result ?? false;
    } catch (e) {
      debugPrint('NotificationBridge: Error clearing saved notifications: $e');
      return false;
    }
  }

  /// Check if the app is currently excluded from Android battery optimizations.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb) return true;
    try {
      final bool? result =
          await _methodChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      debugPrint('NotificationBridge: Error checking battery optimization: $e');
      return false;
    }
  }

  /// Prompt the user to whitelist the app from battery optimizations (Doze mode bypass).
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb) return;
    try {
      await _methodChannel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('NotificationBridge: Error requesting battery optimization: $e');
    }
  }

  /// Open vendor-specific autostart settings (Xiaomi, Oppo, Vivo, Samsung, Huawei).
  Future<void> openAutostartSettings() async {
    if (kIsWeb) return;
    try {
      await _methodChannel.invokeMethod<void>('openAutostartSettings');
    } catch (e) {
      debugPrint('NotificationBridge: Error opening autostart settings: $e');
    }
  }

  /// Trigger the Native Foreground Service to start / re-verify.
  Future<void> startForegroundService() async {
    if (kIsWeb) return;
    try {
      await _methodChannel.invokeMethod<void>('startForegroundService');
    } catch (e) {
      debugPrint('NotificationBridge: Error starting foreground service: $e');
    }
  }

  /// Clean up resources if necessary.
  void dispose() {
    _nativeSubscription?.cancel();
    _controller.close();
  }
}
