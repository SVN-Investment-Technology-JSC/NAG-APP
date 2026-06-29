import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';

class VehicleMaintenance {
  final int vehicleMaintenanceId;
  final DateTime vehicleMaintenanceFromDatetime;
  final DateTime? vehicleMaintenanceToDatetime;
  final String? vehicleMaintenanceLocation;
  final double? vehicleDistanceCovered;
  final String? vehicleMaintenanceDescription;
  final String? vehicleMaintenanceType;
  final int? vehicleMaintenanceRank;
  final String? vehicleMaintenanceStatus;
  final String? paymentStatus;
  final DateTime? deadlinePay;
  final DateTime? paidAt;
  final String? serviceProviderName;
  final String? serviceProviderAddress;
  final String? invoiceNo;
  final DateTime? invoiceDate;
  final double? totalAmount;
  final String? currency;
  final String? vehicleMaintenanceOcrText;
  final int? reportedBy;
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final int? createdBy;
  final int vehicleId;
  final VehicleModel? vehicle;
  final List<VehicleMaintenanceDocument>? documents;
  final List<String>? workflowAvailableActions;

  VehicleMaintenance({
    required this.vehicleMaintenanceId,
    required this.vehicleMaintenanceFromDatetime,
    this.vehicleMaintenanceToDatetime,
    this.vehicleMaintenanceLocation,
    this.vehicleDistanceCovered,
    this.vehicleMaintenanceDescription,
    this.vehicleMaintenanceType,
    this.vehicleMaintenanceRank,
    this.vehicleMaintenanceStatus,
    this.paymentStatus,
    this.deadlinePay,
    this.paidAt,
    this.serviceProviderName,
    this.serviceProviderAddress,
    this.invoiceNo,
    this.invoiceDate,
    this.totalAmount,
    this.currency,
    this.vehicleMaintenanceOcrText,
    this.reportedBy,
    this.reviewedBy,
    this.reviewedAt,
    this.createdBy,
    required this.vehicleId,
    this.vehicle,
    this.documents,
    this.workflowAvailableActions,
  });

  factory VehicleMaintenance.fromJson(Map<String, dynamic> json) {
    int _parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    int? _parseIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    double? _parseDoubleOrNull(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return VehicleMaintenance(
      vehicleMaintenanceId: _parseInt(json['vehicle_maintenance_id']),
      vehicleMaintenanceFromDatetime: _parseDate(json['vehicle_maintenance_from_datetime']) ?? DateTime.now(),
      vehicleMaintenanceToDatetime: _parseDate(json['vehicle_maintenance_to_datetime']),
      vehicleMaintenanceLocation: json['vehicle_maintenance_location']?.toString(),
      vehicleDistanceCovered: _parseDoubleOrNull(json['vehicle_distance_covered']),
      vehicleMaintenanceDescription: json['vehicle_maintenance_description']?.toString(),
      vehicleMaintenanceType: json['vehicle_maintenance_type']?.toString(),
      vehicleMaintenanceRank: _parseIntOrNull(json['vehicle_maintenance_rank']),
      vehicleMaintenanceStatus: json['vehicle_maintenance_status']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      deadlinePay: _parseDate(json['deadline_pay']),
      paidAt: _parseDate(json['paid_at']),
      serviceProviderName: json['service_provider_name']?.toString(),
      serviceProviderAddress: json['service_provider_address']?.toString(),
      invoiceNo: json['invoice_no']?.toString(),
      invoiceDate: _parseDate(json['invoice_date']),
      totalAmount: _parseDoubleOrNull(json['total_amount']),
      currency: json['currency']?.toString(),
      vehicleMaintenanceOcrText: json['vehicle_maintenance_ocr_text']?.toString(),
      reportedBy: _parseIntOrNull(json['reported_by']),
      reviewedBy: _parseIntOrNull(json['reviewed_by']),
      reviewedAt: _parseDate(json['reviewed_at']),
      createdBy: _parseIntOrNull(json['created_by']),
      vehicleId: _parseInt(json['vehicle_id']),
      vehicle: json['vehicle'] != null && json['vehicle'] is Map ? VehicleModel.fromJson(json['vehicle']) : null,
      documents: (json['documents'] as List<dynamic>?)
          ?.map((e) => VehicleMaintenanceDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
      workflowAvailableActions: (json['workflow_available_actions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_maintenance_id': vehicleMaintenanceId,
    'vehicle_maintenance_from_datetime': vehicleMaintenanceFromDatetime.toIso8601String(),
    'vehicle_maintenance_to_datetime': vehicleMaintenanceToDatetime?.toIso8601String(),
    'vehicle_maintenance_location': vehicleMaintenanceLocation,
    'vehicle_distance_covered': vehicleDistanceCovered,
    'vehicle_maintenance_description': vehicleMaintenanceDescription,
    'vehicle_maintenance_type': vehicleMaintenanceType,
    'vehicle_maintenance_rank': vehicleMaintenanceRank,
    'vehicle_maintenance_status': vehicleMaintenanceStatus,
    'payment_status': paymentStatus,
    'deadline_pay': deadlinePay?.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
    'service_provider_name': serviceProviderName,
    'service_provider_address': serviceProviderAddress,
    'invoiceNo': invoiceNo,
    'invoice_date': invoiceDate?.toIso8601String(),
    'total_amount': totalAmount,
    'currency': currency,
    'vehicle_maintenance_ocr_text': vehicleMaintenanceOcrText,
    'reported_by': reportedBy,
    'reviewed_by': reviewedBy,
    'reviewed_at': reviewedAt?.toIso8601String(),
    'created_by': createdBy,
    'vehicle_id': vehicleId,
    'workflow_available_actions': workflowAvailableActions,
  };
}

class VehicleMaintenanceDocument {
  final int vehicleMaintenanceDocumentId;
  final int vehicleMaintenanceId;
  final int mediaId;
  final String documentType;
  final String ocrStatus;
  final String? ocrRawText;
  final String? ocrText;
  final double? ocrConfidence;
  final String? ocrProvider;
  final String? ocrError;
  final int? sortOrder;
  final dynamic media;

  VehicleMaintenanceDocument({
    required this.vehicleMaintenanceDocumentId,
    required this.vehicleMaintenanceId,
    required this.mediaId,
    required this.documentType,
    required this.ocrStatus,
    this.ocrRawText,
    this.ocrText,
    this.ocrConfidence,
    this.ocrProvider,
    this.ocrError,
    this.sortOrder,
    this.media,
  });

  factory VehicleMaintenanceDocument.fromJson(Map<String, dynamic> json) {
    int _parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    int? _parseIntOrNull(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    double? _parseDoubleOrNull(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return VehicleMaintenanceDocument(
      vehicleMaintenanceDocumentId: _parseInt(json['vehicle_maintenance_document_id']),
      vehicleMaintenanceId: _parseInt(json['vehicle_maintenance_id']),
      mediaId: _parseInt(json['media_id']),
      documentType: json['document_type']?.toString() ?? '',
      ocrStatus: json['ocr_status']?.toString() ?? '',
      ocrRawText: json['ocr_raw_text']?.toString(),
      ocrText: json['ocr_text']?.toString(),
      ocrConfidence: _parseDoubleOrNull(json['ocr_confidence']),
      ocrProvider: json['ocr_provider']?.toString(),
      ocrError: json['ocr_error']?.toString(),
      sortOrder: _parseIntOrNull(json['sort_order']),
      media: json['media'],
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_maintenance_document_id': vehicleMaintenanceDocumentId,
    'vehicle_maintenance_id': vehicleMaintenanceId,
    'media_id': mediaId,
    'document_type': documentType,
    'ocr_status': ocrStatus,
    'ocr_raw_text': ocrRawText,
    'ocr_text': ocrText,
    'ocr_confidence': ocrConfidence,
    'ocr_provider': ocrProvider,
    'ocr_error': ocrError,
    'sort_order': sortOrder,
  };
}
