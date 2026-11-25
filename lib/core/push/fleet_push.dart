import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/push/firebase_config.dart';

/// Background messages: the system tray shows "notification" payloads by itself; nothing else to do here.
@pragma('vm:entry-point')
Future<void> fleetPushBackgroundHandler(RemoteMessage message) async {}

/// What a tapped fleet notification asks the app to open.
class FleetPushTarget {
  final String? eventId;
  final String category; // fuel | concrete
  const FleetPushTarget({this.eventId, required this.category});
}

/// Real-time push for "Giám sát xe" alerts (Firebase Cloud Messaging).
///
/// * The backend (module fleet-push) watches the fleet alerts and sends them only to users whose role has the
///   fleet-monitoring permissions (same keys as "Phân quyền").
/// * This class: initialises Firebase, shows notifications while the app is open (Android channel "fleet_alerts"),
///   registers this phone's token for the logged-in user, and opens the alert when a notification is tapped.
class FleetPush extends ChangeNotifier {
  FleetPush._();
  static final FleetPush instance = FleetPush._();

  static const channelId = 'fleet_alerts';
  static const _channel = AndroidNotificationChannel(
    channelId,
    'Cảnh báo giám sát xe',
    description: 'Tụt dầu bất thường, bê tông thừa cần kiểm tra',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _token;
  bool _registered = false;
  StreamSubscription<String>? _refreshSub;

  /// Opens a tapped alert. Set by the app (needs the fleet screens); called with the navigator ready.
  void Function(FleetPushTarget target)? onOpen;
  FleetPushTarget? _pending;

  /// Incremented on every fleet push received while the app runs (the alert bell reloads on change).
  int pushTick = 0;

  bool get available => _ready;
  bool get registered => _registered;

  /// Call once at startup (after ApiClient.init). Never throws: without Firebase config push is just off.
  static Future<void> init() => instance._init();

  Future<void> _init() async {
    if (_ready || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    final options = Platform.isIOS ? kFirebaseIosOptions : kFirebaseAndroidOptions;
    if (options == null) {
      debugPrint('[FleetPush] Firebase not configured for this platform (lib/core/push/firebase_config.dart) — push off');
      return;
    }
    try {
      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(fleetPushBackgroundHandler);

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_fleet'),
          // permission is asked by FirebaseMessaging.requestPermission (once, with the user's login)
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) => _handleData(_decodePayload(r.payload)),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // foreground: iOS shows the banner itself with these options; Android needs us to show it (see _showForeground)
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleData(m.data));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleData(initial.data);
      _ready = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[FleetPush] init failed: $e');
    }
  }

  void _showForeground(RemoteMessage m) {
    if (m.data['type'] == 'fleet_alert') {
      pushTick++;
      notifyListeners();
    }
    final n = m.notification;
    if (n == null || Platform.isIOS) return; // iOS already presented it (options above)
    _local.show(
      id: m.hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      payload: _encodePayload(m.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_fleet',
          color: const Color(0xFFDC2626),
          styleInformation: BigTextStyleInformation(n.body ?? ''),
        ),
      ),
    );
  }

  static String _encodePayload(Map<String, dynamic> d) =>
      '${d['type'] ?? ''}|${d['category'] ?? ''}|${d['event_id'] ?? ''}';

  static Map<String, dynamic> _decodePayload(String? p) {
    final parts = (p ?? '').split('|');
    return {
      'type': parts.isNotEmpty ? parts[0] : '',
      'category': parts.length > 1 ? parts[1] : '',
      'event_id': parts.length > 2 ? parts[2] : '',
    };
  }

  void _handleData(Map<String, dynamic> d) {
    if (d['type'] != 'fleet_alert' && d['type'] != 'fleet_test') return;
    final id = (d['event_id'] ?? '').toString();
    final target = FleetPushTarget(eventId: id.isEmpty ? null : id, category: (d['category'] ?? 'fuel').toString());
    if (onOpen != null && ApiClient.navigatorKey.currentState != null) {
      onOpen!(target);
    } else {
      _pending = target; // opened once the shell is ready (see takePending)
    }
  }

  /// A notification tapped before the app was ready (cold start).
  FleetPushTarget? takePending() {
    final p = _pending;
    _pending = null;
    return p;
  }

  /// Register (or unregister) this phone for the logged-in user. [allowed] = the user has a fleet permission.
  Future<void> syncForUser({required bool allowed}) async {
    if (!_ready) return;
    try {
      if (!allowed) {
        await unregister();
        return;
      }
      final perm = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (perm.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FleetPush] notifications denied by the user');
      }
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      if (Platform.isIOS) {
        // the FCM token needs the APNs token first (arrives a moment after permission is granted)
        String? apns;
        for (var i = 0; i < 10 && apns == null; i++) {
          apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns == null) await Future.delayed(const Duration(milliseconds: 500));
        }
        if (apns == null) {
          debugPrint('[FleetPush] no APNs token (simulator, missing Push capability, or notifications denied)');
          return;
        }
      }
      _token = await FirebaseMessaging.instance.getToken();
      if (_token == null) return;
      await _register(_token!);
      _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        _register(t);
      });
    } catch (e) {
      debugPrint('[FleetPush] sync failed: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await ApiClient.dio.post('/fleet-push/devices', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app_version': '2.2.2',
      });
      _registered = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[FleetPush] register failed: $e');
    }
  }

  /// On logout / when the permission was removed: forget this phone on the server and drop the token.
  Future<void> unregister() async {
    if (!_ready) return;
    // read the session token first: on logout the app clears it right after calling us
    final access = (await SharedPreferences.getInstance()).getString('access_token');
    final t = _token ?? await FirebaseMessaging.instance.getToken().catchError((_) => null);
    if (t != null && access != null) {
      try {
        await ApiClient.dio.post('/fleet-push/devices/remove',
            data: {'token': t}, options: Options(headers: {'Authorization': 'Bearer $access'}));
      } catch (_) {}
    }
    // a deleted FCM token can never be reached again (the server forgets it on its next send)
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
    _registered = false;
    notifyListeners();
  }

  /// Server status for the current user (push configured, my devices, my permission).
  Future<Map<String, dynamic>?> status() async {
    try {
      final r = await ApiClient.dio.get('/fleet-push/status');
      final d = r.data is Map ? (r.data['data'] ?? r.data) : null;
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } catch (_) {
      return null;
    }
  }

  /// Ask the server to send a test notification to my phones. Returns the number of phones reached.
  Future<int?> sendTest() async {
    try {
      final r = await ApiClient.dio.post('/fleet-push/test');
      final d = r.data is Map ? (r.data['data'] ?? r.data) : null;
      return d is Map ? (d['sent'] as num?)?.toInt() : null;
    } catch (_) {
      return null;
    }
  }
}
