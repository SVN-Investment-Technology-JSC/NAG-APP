import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vehicle_management/core/network/app_endpoints.dart';

class SocketService {
  io.Socket? _socket;
  VoidCallback? _onUpdate;
  VoidCallback? _onStatusChanged;

  /// stationId (String) -> 'connected' | 'disconnected'
  final Map<String, String> cameraStatusMap = {};

  bool get isConnected => _socket?.connected ?? false;

  void connect({required VoidCallback onUpdate, VoidCallback? onStatusChanged}) {
    _onUpdate = onUpdate;
    _onStatusChanged = onStatusChanged;
    _initSocket();
  }

  Future<void> _initSocket() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString('access_token') ?? '').isEmpty) {
      debugPrint('[SOCKET] No token, skipping connection');
      return;
    }

    _socket?.dispose();

    final opts = io.OptionBuilder()
        .setTransports(['websocket'])
        .enableReconnection()
        .setReconnectionAttempts(double.infinity)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .enableAutoConnect()
        .build();
    opts['auth'] = (void Function(dynamic) cb) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      cb({'token': 'Bearer $token'});
    };

    _socket = io.io(
      '${AppEndpoints.socketUrl}/updates',
      opts,
    );

    _socket!.onConnect((_) {
      debugPrint('[SOCKET] Connected');
      _onStatusChanged?.call();
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[SOCKET] Disconnected: $reason');
      _onStatusChanged?.call();
    });

    _socket!.onConnectError((err) {
      debugPrint('[SOCKET] Connection error: $err');
      _onStatusChanged?.call();
    });

    _socket!.on('update', (_) {
      debugPrint('[SOCKET] Received update event');
      _onUpdate?.call();
    });

    _socket!.on('ping', (_) {
      debugPrint('[SOCKET] Received ping');
      _onUpdate?.call();
    });

    _socket!.on('camera-status', _onCameraStatus);
  }

  void _onCameraStatus(dynamic raw) {
    dynamic payload = raw;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (e) {
        debugPrint('[SOCKET] camera-status parse error: $e');
        return;
      }
    }

    List<dynamic> items = [];
    if (payload is List) {
      items = payload.isNotEmpty && payload.first is List
          ? payload.first as List
          : payload;
    } else if (payload is Map) {
      if (payload.containsKey('station_id') || payload.containsKey('id')) {
        items = [payload];
      } else {
        final nested = payload.values.whereType<List>().cast<List>().firstOrNull;
        if (nested != null) items = nested;
      }
    }

    var updated = false;
    for (final item in items) {
      if (item is! Map) continue;
      final stationId = (item['station_id'] ?? item['id'])?.toString();
      if (stationId == null || stationId.isEmpty) continue;

      final statusRaw = (item['status'] ?? item['device_status'] ?? '').toString().trim().toLowerCase();
      final status = statusRaw == 'connected' ? 'connected' : 'disconnected';

      if (cameraStatusMap[stationId] != status) {
        cameraStatusMap[stationId] = status;
        updated = true;
      }
    }

    if (updated) _onStatusChanged?.call();
  }

  void dispose() {
    _onUpdate = null;
    _onStatusChanged = null;
    _socket?.dispose();
    _socket = null;
  }
}
