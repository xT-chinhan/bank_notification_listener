import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/raw_notification.dart';
import 'bank_notification_parser.dart';

class NotificationBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('vn.finance.notification_listener/methods');
  static const EventChannel _eventChannel =
      EventChannel('vn.finance.notification_listener/events');

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
    try {
      await _methodChannel.invokeMethod<void>('openPermissionSettings');
    } on PlatformException catch (e) {
      debugPrint('NotificationBridge: Error opening settings: ${e.message}');
    } catch (e) {
      debugPrint('NotificationBridge: Unexpected error opening settings: $e');
    }
  }

  /// Clean up resources if necessary.
  void dispose() {
    _nativeSubscription?.cancel();
    _controller.close();
  }
}
