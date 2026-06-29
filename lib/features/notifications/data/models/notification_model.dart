import 'package:flutter/foundation.dart';

class NotificationModel {
  final Object id;
  final bool read;
  final String? createdAt;
  final String? emittedAt;
  final String? visibleDate;
  final String? event;
  final String? title;
  final String? message;
  final dynamic userId;
  final int? vehicleId;
  final String? vehicleName;
  final String? vehicleLicensePlate;
  final int? stationId;
  final String? stationName;
  final int? orderId;
  final int? orderNumber;

  const NotificationModel({
    required this.id,
    required this.read,
    this.createdAt,
    this.emittedAt,
    this.visibleDate,
    this.event,
    this.title,
    this.message,
    this.userId,
    this.vehicleId,
    this.vehicleName,
    this.vehicleLicensePlate,
    this.stationId,
    this.stationName,
    this.orderId,
    this.orderNumber,
  });

  factory NotificationModel.fromJson(Map<dynamic, dynamic> json) {
    final rawId = json['id'] ?? json['_id'];
    final finalId = rawId ?? '${json['event'] ?? 'notification'}-${json['created_at'] ?? json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch}-${json['user_id'] ?? json['userId'] ?? 'all'}';
    return NotificationModel(
      id: finalId,
      read: json['read'] == true,
      createdAt: _str(json['created_at'] ?? json['createdAt']),
      emittedAt: _str(json['emitted_at'] ?? json['emittedAt']),
      visibleDate: _str(json['visible_date'] ?? json['visibleDate']),
      event: _str(json['event']),
      title: _str(json['title']),
      message: _str(json['message']),
      userId: json['user_id'] ?? json['userId'],
      vehicleId: _int(json['vehicle_id']),
      vehicleName: _str(json['vehicle_name']),
      vehicleLicensePlate: _str(json['vehicle_license_plate']),
      stationId: _int(json['station_id']),
      stationName: _str(json['station_name']),
      orderId: _int(json['order_id']),
      orderNumber: _int(json['order_number']),
    );
  }

  NotificationModel copyWith({bool? read}) {
    return NotificationModel(
      id: id,
      read: read ?? this.read,
      createdAt: createdAt,
      emittedAt: emittedAt,
      visibleDate: visibleDate,
      event: event,
      title: title,
      message: message,
      userId: userId,
      vehicleId: vehicleId,
      vehicleName: vehicleName,
      vehicleLicensePlate: vehicleLicensePlate,
      stationId: stationId,
      stationName: stationName,
      orderId: orderId,
      orderNumber: orderNumber,
    );
  }

  /// Trả về text thông báo, giống logic web getNotificationText()
  String getText() {
    const Map<String, String> templates = {
      'station_check_in': 'Xe {vehicle} đã vào {station}',
      'station_check_out': 'Xe {vehicle} đã rời {station}',
      'vehicle_check_in': 'Xe {vehicle} đã vào bãi',
      'vehicle_check_out': 'Xe {vehicle} đã rời bãi',
    };

    if (event != null && templates.containsKey(event)) {
      final vehicle = _firstNonEmpty([vehicleName, vehicleLicensePlate]) ?? '-';
      final station = stationName ?? '-';
      return templates[event]!
          .replaceAll('{vehicle}', vehicle)
          .replaceAll('{station}', station);
    }

    if (message != null && message!.isNotEmpty) return message!;
    if (title != null && title!.isNotEmpty) return title!;
    return 'Bạn có một thông báo mới';
  }

  /// Timestamp string theo thứ tự ưu tiên giống web getNotificationTimestamp()
  String? getTimestamp() {
    return visibleDate ?? emittedAt ?? createdAt;
  }

  DateTime? getParsedTime() {
    final ts = getTimestamp();
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }
}
