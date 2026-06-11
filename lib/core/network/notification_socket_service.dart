import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/notifications/data/models/notification_model.dart';

class NotificationSocketService {
  io.Socket? _socket;
  Timer? _refreshTimer;

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

    final opts = io.OptionBuilder()
        .setTransports(['websocket'])
        .enableReconnection()
        .setReconnectionAttempts(double.infinity)
        .setReconnectionDelay(2000)
        .setReconnectionDelayMax(5000)
        .enableAutoConnect()
        .build();
    opts['path'] = '/gateways';
    opts['auth'] = (void Function(dynamic) cb) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      cb({'token': 'Bearer $token'});
    };

    _socket = io.io(
      '${AppEndpoints.socketUrl}/notifications',
      opts,
    );

    _socket!.onConnect((_) {
      debugPrint('[NOTIF] Connected to /notifications');
      _socket!.emit('notification:get_all');
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[NOTIF] Disconnected: $reason');
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
    
    // Check if there are new notifications to show toast
    if (notifications.isNotEmpty && parsed.isNotEmpty) {
      final existingIds = notifications.map((e) => e.id.toString()).toSet();
      final newNotifs = parsed.where((n) => !existingIds.contains(n.id.toString())).toList();
      if (newNotifs.isNotEmpty) {
        _showTopToast(newNotifs.first.getText());
      }
    }
    
    notifications = parsed;
    _notify();
  }

  void _showTopToast(String message) {
    final overlay = ApiClient.navigatorKey.currentState?.overlay;
    final context = ApiClient.navigatorKey.currentContext;
    if (overlay == null || context == null) return;
    
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) {
              if (entry.mounted) entry.remove();
            },
            child: GestureDetector(
              onTap: () {
                if (entry.mounted) entry.remove();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer, 
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _onNew(dynamic raw) {
    final n = _parseSingle(raw);
    if (n == null) return;
    
    // Tránh duplicate
    final bool isDuplicate = notifications.any((e) => e.id.toString() == n.id.toString());
    notifications.removeWhere((e) => e.id.toString() == n.id.toString());
    notifications.insert(0, n);
    _notify();
    
    if (!isDuplicate) {
      _showTopToast(n.getText());
    }
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
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(milliseconds: 1000), () {
        _socket?.emit('notification:get_all');
      });
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

    final targetIdx = notifications.indexWhere(
      (e) => e.id.toString() == notificationId.toString(),
    );
    if (targetIdx < 0) return;

    final target = notifications[targetIdx];
    dynamic ownerId = 'all';
    
    // Nếu userId của thông báo trùng khớp với userId hiện tại của người dùng đăng nhập
    // thì gửi đi userId của người dùng, ngược lại (là thông báo chung / của người khác) thì gửi 'all'
    if (target.userId != null) {
      dynamic parsedTargetUserId = target.userId;
      if (parsedTargetUserId is String && int.tryParse(parsedTargetUserId) != null) {
        parsedTargetUserId = int.parse(parsedTargetUserId);
      }
      if (parsedTargetUserId == userId) {
        ownerId = userId;
      }
    }

    dynamic notiId = notificationId;
    if (notiId is String && int.tryParse(notiId) != null) {
      notiId = int.parse(notiId);
    }

    _socket?.emit('notification:mark_read', {
      'user_id': ownerId,
      'noti_id': notiId,
    });

    notifications[targetIdx] = target.copyWith(read: true);
    _notify();
  }

  Future<void> markAllAsRead() async {
    final unreadItems = notifications.where((n) => !n.read).toList();
    if (unreadItems.isEmpty) return;

    // Cập nhật giao diện lập tức cho tất cả
    notifications = notifications.map((n) => n.read ? n : n.copyWith(read: true)).toList();
    _notify();

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return;

    for (final item in unreadItems) {
      dynamic ownerId = 'all';
      if (item.userId != null) {
        dynamic parsedTargetUserId = item.userId;
        if (parsedTargetUserId is String && int.tryParse(parsedTargetUserId) != null) {
          parsedTargetUserId = int.parse(parsedTargetUserId);
        }
        if (parsedTargetUserId == userId) {
          ownerId = userId;
        }
      }

      dynamic notiId = item.id;
      if (notiId is String && int.tryParse(notiId) != null) {
        notiId = int.parse(notiId);
      }

      _socket?.emit('notification:mark_read', {
        'user_id': ownerId,
        'noti_id': notiId,
      });
      
      // Delay nhỏ để tránh spam socket khiến server bỏ qua (rate-limit)
      await Future.delayed(const Duration(milliseconds: 30));
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
