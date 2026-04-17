import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vehicle_management/core/network/app_endpoints.dart';

class SocketService {
  io.Socket? _socket;
  VoidCallback? _onUpdate;
  VoidCallback? _onStatusChanged;

  bool get isConnected => _socket?.connected ?? false;

  void connect({required VoidCallback onUpdate, VoidCallback? onStatusChanged}) {
    _onUpdate = onUpdate;
    _onStatusChanged = onStatusChanged;
    _initSocket();
  }

  Future<void> _initSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      debugPrint('[SOCKET] No token, skipping connection');
      return;
    }

    _socket?.dispose();

    final opts = io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': 'Bearer $token'})
        .enableReconnection()
        .setReconnectionAttempts(double.infinity)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .enableAutoConnect()
        .build();

    _socket = io.io(
      '${AppEndpoints.socketUrl}/updates',
      opts,
    );

    _socket!.onConnect((_) {
      debugPrint('[SOCKET] Connected');
      _onStatusChanged?.call();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SOCKET] Disconnected');
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
  }

  void dispose() {
    _onUpdate = null;
    _onStatusChanged = null;
    _socket?.dispose();
    _socket = null;
  }
}
