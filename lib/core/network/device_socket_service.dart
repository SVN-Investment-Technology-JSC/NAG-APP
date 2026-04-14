import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vehicle_management/core/network/app_endpoints.dart';

class DeviceStationStatus {
  final String stationId;
  final String deviceStatus;
  final String rfidStatus;
  final String ledStatus;

  const DeviceStationStatus({
    required this.stationId,
    this.deviceStatus = 'disconnected',
    this.rfidStatus = 'disconnected',
    this.ledStatus = 'disconnected',
  });

  DeviceStationStatus copyWith({
    String? deviceStatus,
    String? rfidStatus,
    String? ledStatus,
  }) {
    return DeviceStationStatus(
      stationId: stationId,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      rfidStatus: rfidStatus ?? this.rfidStatus,
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
      stationStatusMap['1']?.deviceStatus == 'connected';

  static const _validTypes = ['rfid_checks', 'led_checks', 'led', 'led_status'];

  void connect({VoidCallback? onStatusChanged}) {
    _onStatusChanged = onStatusChanged;
    _initSocket();
  }

  void _initSocket() {
    _socket?.dispose();

    _socket = io.io(
      AppEndpoints.deviceSocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(double.infinity)
          .setReconnectionDelay(2000)
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[DEVICE_SOCKET] Connected');
      _onStatusChanged?.call();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[DEVICE_SOCKET] Disconnected');
      _onStatusChanged?.call();
    });

    _socket!.onConnectError((err) {
      debugPrint('[DEVICE_SOCKET] Connection error: $err');
    });

    _socket!.on('update', _handleUpdate);

    _socket!.onAny((event, data) {
      if (event == 'update') return;
      _handleUpdate(data);
    });
  }

  void _handleUpdate(dynamic rawPayload) {
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

    final isConnected = deviceStatus == 'connected';
    final status = isConnected ? 'connected' : 'disconnected';

    final existing = stationStatusMap[stationId] ??
        DeviceStationStatus(stationId: stationId);

    stationStatusMap[stationId] = existing.copyWith(
      deviceStatus: status,
    );

    debugPrint(
        '[DEVICE_SOCKET] Station $stationId: $updateType = $status');
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
