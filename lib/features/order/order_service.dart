import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/data/models/tanker_queue_snapshot_item.dart';

class OrderService {
  final Dio dio;

  OrderService(this.dio);

  Future<List<OrderModel>> getOrders({List<String>? statuses}) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}orders';
      final statusParam = (statuses ?? ['pending']).join(',');

      final response = await dio.get(
        fullUrl,
        queryParameters: {
          'order_status': statusParam,
          'limit': 1000,
        },
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => OrderModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('[ORDER SERVICE] API Error: ${e.response?.statusCode}');
      debugPrint('[ORDER SERVICE] Response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[ORDER SERVICE] Error: $e');
      rethrow;
    }
  }

  /// Fetch orders by start date
  Future<List<OrderModel>> getOrdersByDate(String date) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}orders';

      final response = await dio.get(
        fullUrl,
        queryParameters: {
          'order_start_datetime': date,
          'limit': 1000,
        },
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => OrderModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('[ORDER SERVICE] API Error: ${e.response?.statusCode}');
      debugPrint('[ORDER SERVICE] Response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[ORDER SERVICE] Error: $e');
      rethrow;
    }
  }

  /// Fetch all orders for today by order_start date
  Future<List<OrderModel>> getTodayOrders() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return getOrdersByDate(today);
  }

  Future<List<OrderModel>> getPendingOrders() async {
    return getOrders(statuses: ['pending']);
  }

  Future<List<OrderModel>> getPendingAndCollectingOrders() async {
    return getOrders(statuses: ['pending', 'collecting']);
  }

  Future<void> updateOrderStation(int orderId, int stationId) async {
    final String fullUrl = '${AppEndpoints.apiBaseUrl}orders/$orderId';

    await dio.put(
      fullUrl,
      data: {'station_id': stationId},
    );
  }

  Future<void> updateOrderNumber(int orderId, int orderNumber) async {
    final String fullUrl = '${AppEndpoints.apiBaseUrl}orders/$orderId';

    await dio.put(
      fullUrl,
      data: {'order_number': orderNumber},
    );
  }

  Future<void> updateOrder(int orderId, {int? stationId, int? orderNumber}) async {
    final String fullUrl = '${AppEndpoints.apiBaseUrl}orders/$orderId';
    final data = <String, dynamic>{};

    if (stationId != null) data['station_id'] = stationId;
    if (orderNumber != null) data['order_number'] = orderNumber;

    if (data.isNotEmpty) {
      await dio.put(fullUrl, data: data);
    }
  }

  Future<void> moveToTop(int orderId, {int? stationId}) async {
    await updateOrder(orderId, stationId: stationId, orderNumber: 1);
  }

  Future<void> shiftClose(String operationDate) async {
    final String fullUrl = '${AppEndpoints.apiBaseUrl}orders/shift-close';
    await dio.post(fullUrl, data: {'operation_date': operationDate});
  }

  Future<List<TankerQueueSnapshotItem>> getTankerQueueSnapshot(String date) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}${AppEndpoints.tankerQueueSnapshot}';
      final response = await dio.get(
        fullUrl,
        queryParameters: {'date': date},
      );

      if (response.statusCode == 200 && response.data['multi_data'] != null) {
        final multiData = response.data['multi_data'];
        if (multiData['items'] != null) {
          final List<dynamic> items = multiData['items'];
          final parsedItems = items.map((json) => TankerQueueSnapshotItem.fromJson(json)).toList();
          parsedItems.sort((a, b) => a.position.compareTo(b.position));
          return parsedItems;
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ORDER SERVICE] getTankerQueueSnapshot Error: $e');
      rethrow;
    }
  }
}
