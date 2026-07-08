import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/application_form/data/models/application_model.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';

class ApplicationService {
  final Dio dio;

  ApplicationService(this.dio);

  Future<Map<String, dynamic>> listRequests({
    required int page,
    required int limit,
    required String status, // 'all', 'pending', 'approved', 'rejected', 'canceled'
    String? workDate,
    required bool mine,
  }) async {
    final Map<String, dynamic> query = {
      'page': page,
      'limit': limit,
      'mine': mine,
    };
    if (status != 'all') {
      query['status'] = status;
    }
    if (workDate != null && workDate.isNotEmpty) {
      query['work_date'] = workDate;
    }

    final response = await dio.get(AppEndpoints.lotTagRequests, queryParameters: query);
    final data = response.data;
    
    List<dynamic> items = [];
    int total = 0;
    if (data is Map<String, dynamic>) {
      if (data['data'] is List) {
        items = data['data'];
      } else if (data['items'] is List) {
        items = data['items'];
      }
      total = data['total'] ?? data['count'] ?? 0;
    } else if (data is List) {
      items = data;
      total = data.length;
    }

    final requestsList = items.map((e) => LotTagRequest.fromJson(e)).toList();
    return {
      'requests': requestsList,
      'total': total,
    };
  }

  Future<LotTagRequest> createRequest({
    required String workDate,
    required int vehicleId,
    required int? lotTagId,
    required String lotTagKey,
    String? requestReason,
  }) async {
    final payload = {
      'work_date': workDate,
      'vehicle_id': vehicleId,
      'lot_tag_id': lotTagId,
      'lot_tag_key': lotTagKey,
      'request_reason': requestReason,
    };
    final response = await dio.post(AppEndpoints.lotTagRequests, data: payload);
    final body = response.data;
    final item = (body is Map<String, dynamic> && body['data'] != null) ? body['data'] : body;
    return LotTagRequest.fromJson(item);
  }

  Future<LotTagRequest> approveRequest(int requestId, String? note) async {
    final response = await dio.post(
      '${AppEndpoints.lotTagRequests}/$requestId/approve',
      data: {'note': note ?? ''},
    );
    final body = response.data;
    final item = (body is Map<String, dynamic> && body['data'] != null) ? body['data'] : body;
    return LotTagRequest.fromJson(item);
  }

  Future<LotTagRequest> rejectRequest(int requestId, String reason) async {
    final response = await dio.post(
      '${AppEndpoints.lotTagRequests}/$requestId/reject',
      data: {'reason': reason},
    );
    final body = response.data;
    final item = (body is Map<String, dynamic> && body['data'] != null) ? body['data'] : body;
    return LotTagRequest.fromJson(item);
  }

  Future<LotTagRequest> cancelRequest(int requestId, String reason) async {
    final response = await dio.post(
      '${AppEndpoints.lotTagRequests}/$requestId/cancel',
      data: {'reason': reason},
    );
    final body = response.data;
    final item = (body is Map<String, dynamic> && body['data'] != null) ? body['data'] : body;
    return LotTagRequest.fromJson(item);
  }

  Future<List<LotTagCatalogItem>> listLotTags() async {
    final response = await dio.get(AppEndpoints.lotTags, queryParameters: {'limit': 100});
    final data = response.data;
    List<dynamic> items = [];
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      for (final key in ['data', 'items', 'results', 'rows', 'lot_tags']) {
        if (data[key] is List) {
          items = data[key];
          break;
        }
      }
    }
    return items
        .map((e) => LotTagCatalogItem.fromJson(e))
        .where((tag) => tag.lotTagKey.isNotEmpty)
        .toList();
  }

  Future<List<WorkVehicle>> listVehicles() async {
    final response = await dio.get(AppEndpoints.vehicles, queryParameters: {'limit': 1000});
    final data = response.data;
    List<dynamic> items = [];
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      for (final key in ['data', 'items', 'results', 'rows', 'vehicles']) {
        if (data[key] is List) {
          items = data[key];
          break;
        }
      }
    }
    return items.map((e) => WorkVehicle.fromJson(e)).toList();
  }
}
