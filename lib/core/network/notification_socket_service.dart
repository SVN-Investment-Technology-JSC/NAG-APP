import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vehicle_management/core/network/app_endpoints.dart';
import 'package:vehicle_management/features/notifications/data/models/notification_model.dart';

class NotificationSocketService {
  io.Socket? _socket;

  List<NotificationModel> notifications = [];
  int get unreadCount => notifications.where((n) => !n.read).length;
  bool get isConnected => _socket?.connected ?? false;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void _notify() {
    for (final l in List<VoidCallback>.from(_listeners)) {
      l();
    }
  }

  Future<void> connect() async {
    _socket?.dispose();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final opts = io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': 'Bearer ${token ?? ''}'})
        .enableReconnection()
        .setReconnectionAttempts(double.infinity)
        .setReconnectionDelay(2000)
        .setReconnectionDelayMax(5000)
        .enableAutoConnect()
        .build();
    opts['path'] = '/gateways';

    _socket = io.io(
      '${AppEndpoints.socketUrl}/notifications',
      opts,
    );

    _socket!.onConnect((_) {
      debugPrint('[NOTIF] Connected to /notifications');
      _socket!.emit('notification:get_all');
    });

    _socket!.onDisconnect((_) {
      debugPrint('[NOTIF] Disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('[NOTIF] Connect error: $err');
    });

    _socket!.on('notification:list', _onList);
    _socket!.on('notification:new', _onNew);
    _socket!.on('notification:updated', _onUpdated);
    _socket!.on('notification:removed', _onRemoved);
    _socket!.on('notification:cleared', _onCleared);
    _socket!.on('notification:refresh', _onRefresh);
  }

  // ── Event handlers ──────────────────────────────────────────────────────────

  void _onList(dynamic raw) {
    if (raw is! List) return;
    final parsed = _parseList(raw);
    parsed.sort(_compareByTime);
    notifications = parsed;
    _notify();
  }

  void _onNew(dynamic raw) {
    final n = _parseSingle(raw);
    if (n == null) return;
    // Tránh duplicate
    notifications.removeWhere((e) => e.id.toString() == n.id.toString());
    notifications.insert(0, n);
    _notify();
  }

  void _onUpdated(dynamic raw) {
    final n = _parseSingle(raw);
    if (n == null) return;
    final idx = notifications.indexWhere((e) => e.id.toString() == n.id.toString());
    if (idx >= 0) {
      notifications[idx] = n;
    } else {
      notifications.insert(0, n);
    }
    _notify();
  }

  void _onRemoved(dynamic raw) {
    String? targetId;
    if (raw is Map) {
      targetId = raw['id']?.toString();
    } else {
      targetId = raw?.toString();
    }
    if (targetId == null) return;
    notifications.removeWhere((e) => e.id.toString() == targetId);
    _notify();
  }

  void _onCleared(dynamic _) {
    notifications = [];
    _notify();
  }

  void _onRefresh(dynamic raw) {
    if (raw == null) {
      _socket?.emit('notification:get_all');
      return;
    }
    if (raw is List) {
      _onList(raw);
    } else if (raw is Map) {
      _onNew(raw);
    }
  }

  // ── Mark as read ─────────────────────────────────────────────────────────────

  Future<void> markAsRead(Object notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return;

    _socket?.emit('notification:mark_read', {
      'user_id': userId.toString(),
      'noti_id': notificationId,
    });

    // Optimistic update
    final idx = notifications.indexWhere(
      (e) => e.id.toString() == notificationId.toString(),
    );
    if (idx >= 0) {
      notifications[idx] = notifications[idx].copyWith(read: true);
      _notify();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  List<NotificationModel> _parseList(List<dynamic> raw) {
    final result = <NotificationModel>[];
    for (final item in raw) {
      final n = _parseSingle(item);
      if (n != null) result.add(n);
    }
    return result;
  }

  NotificationModel? _parseSingle(dynamic raw) {
    if (raw is! Map) return null;
    try {
      return NotificationModel.fromJson(raw);
    } catch (e) {
      debugPrint('[NOTIF] Parse error: $e');
      return null;
    }
  }

  /// Mới nhất lên đầu — giống web sort by timestamp descending
  int _compareByTime(NotificationModel a, NotificationModel b) {
    final ta = a.getParsedTime()?.millisecondsSinceEpoch ?? 0;
    final tb = b.getParsedTime()?.millisecondsSinceEpoch ?? 0;
    return tb.compareTo(ta);
  }

  void dispose() {
    _listeners.clear();
    _socket?.dispose();
    _socket = null;
  }
}
