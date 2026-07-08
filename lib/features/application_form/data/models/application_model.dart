class LotTagRequest {
  final int lotTagRequestId;
  final String workDate;
  final int? vehicleId;
  final int? lotTagId;
  final String lotTagKey;
  final String? requestReason;
  final String? reviewNote;
  final String? rejectReason;
  final String requestStatus; // 'pending' (Chờ duyệt), 'approved' (Đã duyệt), 'rejected' (Từ chối), 'canceled' (Đã hủy)
  final int? requestedBy;
  final int? reviewedBy;
  final String? requestedAt;
  final String? reviewedAt;
  final String? createdAt;
  final String? updatedAt;
  final LotTagRequestVehicle? vehicle;
  final LotTagRequestTag? lotTag;
  final LotTagRequestUser? requestedByUser;
  final LotTagRequestUser? reviewedByUser;

  LotTagRequest({
    required this.lotTagRequestId,
    required this.workDate,
    this.vehicleId,
    this.lotTagId,
    required this.lotTagKey,
    this.requestReason,
    this.reviewNote,
    this.rejectReason,
    required this.requestStatus,
    this.requestedBy,
    this.reviewedBy,
    this.requestedAt,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
    this.vehicle,
    this.lotTag,
    this.requestedByUser,
    this.reviewedByUser,
  });

  factory LotTagRequest.fromJson(Map<String, dynamic> json) {
    return LotTagRequest(
      lotTagRequestId: json['lot_tag_request_id'] ?? 0,
      workDate: json['work_date'] ?? '',
      vehicleId: json['vehicle_id'],
      lotTagId: json['lot_tag_id'],
      lotTagKey: json['lot_tag_key'] ?? '',
      requestReason: json['request_reason'] ?? json['reason'],
      reviewNote: json['review_note'] ?? json['note'],
      rejectReason: json['reject_reason'],
      requestStatus: json['request_status'] ?? 'pending',
      requestedBy: json['requested_by'],
      reviewedBy: json['reviewed_by'],
      requestedAt: json['requested_at'],
      reviewedAt: json['reviewed_at'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      vehicle: json['vehicle'] != null ? LotTagRequestVehicle.fromJson(json['vehicle']) : null,
      lotTag: json['lot_tag'] != null ? LotTagRequestTag.fromJson(json['lot_tag']) : null,
      requestedByUser: json['requested_by_user'] != null ? LotTagRequestUser.fromJson(json['requested_by_user']) : null,
      reviewedByUser: json['reviewed_by_user'] != null ? LotTagRequestUser.fromJson(json['reviewed_by_user']) : null,
    );
  }
}

class LotTagRequestVehicle {
  final int vehicleId;
  final String? vehicleName;
  final String? vehicleLicensePlate;

  LotTagRequestVehicle({
    required this.vehicleId,
    this.vehicleName,
    this.vehicleLicensePlate,
  });

  factory LotTagRequestVehicle.fromJson(Map<String, dynamic> json) {
    return LotTagRequestVehicle(
      vehicleId: json['vehicle_id'] ?? json['id'] ?? 0,
      vehicleName: json['vehicle_name'],
      vehicleLicensePlate: json['vehicle_license_plate'],
    );
  }
}

class LotTagRequestTag {
  final int? lotTagId;
  final String lotTagKey;
  final String lotTagName;

  LotTagRequestTag({
    this.lotTagId,
    required this.lotTagKey,
    required this.lotTagName,
  });

  factory LotTagRequestTag.fromJson(Map<String, dynamic> json) {
    return LotTagRequestTag(
      lotTagId: json['lot_tag_id'] ?? json['id'],
      lotTagKey: json['lot_tag_key'] ?? '',
      lotTagName: json['lot_tag_name'] ?? json['lot_tag_key'] ?? '',
    );
  }
}

class LotTagRequestUser {
  final int userId;
  final String? userFullName;
  final String? userShortName;

  LotTagRequestUser({
    required this.userId,
    this.userFullName,
    this.userShortName,
  });

  factory LotTagRequestUser.fromJson(Map<String, dynamic> json) {
    return LotTagRequestUser(
      userId: json['user_id'] ?? json['id'] ?? 0,
      userFullName: json['user_full_name'],
      userShortName: json['user_short_name'],
    );
  }
}

class LotTagCatalogItem {
  final int lotTagId;
  final String lotTagKey;
  final String lotTagName;

  LotTagCatalogItem({
    required this.lotTagId,
    required this.lotTagKey,
    required this.lotTagName,
  });

  factory LotTagCatalogItem.fromJson(Map<String, dynamic> json) {
    return LotTagCatalogItem(
      lotTagId: json['lot_tag_id'] ?? 0,
      lotTagKey: json['lot_tag_key'] ?? '',
      lotTagName: json['lot_tag_name'] ?? '',
    );
  }
}
