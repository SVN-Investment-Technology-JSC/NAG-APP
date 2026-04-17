import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vehicle_management/core/network/app_endpoints.dart';

class DeviceStationStatus {
  final String stationId;
  final String deviceStatus;
  final String cameraStatus;
  final String ledStatus;

  const DeviceStationStatus({
    required this.stationId,
    this.deviceStatus = 'disconnected',
    this.cameraStatus = 'disconnected',
    this.ledStatus = 'disconnected',
  });

  DeviceStationStatus copyWith({
    String? deviceStatus,
    String? cameraStatus,
    String? ledStatus,
  }) {
    return DeviceStationStatus(
      stationId: stationId,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      cameraStatus: cameraStatus ?? this.cameraStatus,
      ledStatus: ledStatus ?? this.ledStatus,
    );
  }
}

class DeviceSocketService {
  io.Socket? _socket;
  VoidCallback? _onStatusChanged;

  final Map<String, DeviceStationStatus> stationStatusMap = {};

  bool get isConnected => _socket?.connected ?? false;

  bool get isLedConnected =>
      stationStatusMap['4']?.deviceStatus == 'connected';

  static const _validTypes = ['camera_checks', 'led_checks', 'led', 'led_status'];

  void connect({VoidCallback? onStatusChanged}) {
    _onStatusChanged = onStatusChanged;
    _initSocket();
  }

  Future<void> _initSocket() async {
    _socket?.dispose();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    _socket = io.io(
      '${AppEndpoints.socketUrl}/updates',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': 'Bearer ${token ?? ''}'})
          .enableReconnection()
          .setReconnectionAttempts(double.infinity)
          .setReconnectionDelay(2000)
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[DEVICE_SOCKET] Connected to main backend');
      _onStatusChanged?.call();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[DEVICE_SOCKET] Disconnected');
      _onStatusChanged?.call();
    });

    _socket!.onConnectError((err) {
      debugPrint('[DEVICE_SOCKET] Connection error: $err');
    });

    // Xử lý event camera-status (giống web)
    _socket!.on('camera-status', _handleCameraStatus);

    // Xử lý heartbeat events dạng update_type
    _socket!.on('update', _handleHeartbeat);
    _socket!.onAny((event, data) {
      if (event == 'update' || event == 'camera-status') return;
      _handleHeartbeat(data);
    });
  }

  /// Xử lý camera-status events từ main backend
  /// Payload có thể là array hoặc object, giống web useDeviceHeartbeat
  void _handleCameraStatus(dynamic rawPayload) {
    List<dynamic> items = [];

    if (rawPayload is List) {
      items = rawPayload.isNotEmpty && rawPayload[0] is List
          ? rawPayload[0] as List
          : rawPayload;
    } else if (rawPayload is Map) {
      final stationId = rawPayload['station_id'] ?? rawPayload['id'];
      if (stationId != null) {
        items = [rawPayload];
      }
    }

    for (final item in items) {
      if (item is! Map) continue;
      final stationId = (item['station_id'] ?? item['id'])?.toString();
      if (stationId == null || stationId.isEmpty) continue;

      final statusStr = (item['status'] ?? item['device_status'] ?? '').toString().toLowerCase();
      final status = statusStr == 'connected' ? 'connected' : 'disconnected';

      final existing = stationStatusMap[stationId] ??
          DeviceStationStatus(stationId: stationId);
      stationStatusMap[stationId] = existing.copyWith(
        deviceStatus: status,
        cameraStatus: status,
      );

      debugPrint('[DEVICE_SOCKET] camera-status station $stationId = $status');
    }

    _onStatusChanged?.call();
  }

  /// Xử lý heartbeat events dạng { update_type, device_status, station_id }
  void _handleHeartbeat(dynamic rawPayload) {
    final payload = _normalizePayload(rawPayload);
    if (payload == null) return;

    final updateType = payload['update_type'] as String?;
    final deviceStatus = payload['device_status'] as String?;
    final stationId = payload['station_id']?.toString();

    if (updateType == null ||
        !_validTypes.contains(updateType) ||
        stationId == null ||
        stationId.isEmpty) {
      return;
    }

    final status = deviceStatus == 'connected' ? 'connected' : 'disconnected';

    final existing = stationStatusMap[stationId] ??
        DeviceStationStatus(stationId: stationId);

    stationStatusMap[stationId] = existing.copyWith(
      deviceStatus: status,
    );

    debugPrint('[DEVICE_SOCKET] Station $stationId: $updateType = $status');
    _onStatusChanged?.call();
  }

  Map<String, dynamic>? _normalizePayload(dynamic raw) {
    if (raw == null || raw is! Map) return null;

    final source = raw.containsKey('update') && raw['update'] is Map
        ? raw['update'] as Map
        : raw;

    return {
      'update_type': source['update_type'],
      'device_status': source['device_status'],
      'station_id': source['station_id'],
    };
  }

  void dispose() {
    _onStatusChanged = null;
    _socket?.dispose();
    _socket = null;
  }
}
