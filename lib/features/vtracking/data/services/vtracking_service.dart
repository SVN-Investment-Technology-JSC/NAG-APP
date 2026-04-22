import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';

class VtrackingService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  String? _presence;
  DateTime? _presenceAt;
  static const _presenceTtl = Duration(minutes: 30);

  Future<String?> _getPresence() async {
    // Return cached if still valid
    if (_presence != null &&
        _presenceAt != null &&
        DateTime.now().difference(_presenceAt!) < _presenceTtl) {
      return _presence;
    }

    try {
      final res = await _dio.post(
        '${AppEndpoints.vtrackingBaseUrl}/login1',
        data: {
          'username': AppEndpoints.vtrackingUsername,
          'password': AppEndpoints.vtrackingPassword,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': '*/*',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': '${AppEndpoints.vtrackingBaseUrl}/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      // Extract presence from set-cookie header
      final cookies = res.headers['set-cookie'];
      if (cookies != null) {
        for (final cookie in cookies) {
          final match = RegExp(r'presence=([^;]+)').firstMatch(cookie);
          if (match != null) {
            _presence = match.group(1);
            _presenceAt = DateTime.now();
            debugPrint('[VTRACKING] Got presence token');
            return _presence;
          }
        }
      }

      debugPrint('[VTRACKING] No presence cookie in response');
      return null;
    } catch (e) {
      debugPrint('[VTRACKING] Login failed: $e');
      return null;
    }
  }

  Future<List<VtrackingVehicle>> fetchVehicles() async {
    String? presence = await _getPresence();
    if (presence == null) return [];

    List<VtrackingVehicle>? vehicles = await _doFetchVehicles(presence);

    // If failed, try re-login
    if (vehicles == null) {
      _presence = null;
      presence = await _getPresence();
      if (presence == null) return [];
      vehicles = await _doFetchVehicles(presence);
    }

    return vehicles ?? [];
  }

  Future<List<VtrackingVehicle>?> _doFetchVehicles(String presence) async {
    try {
      final res = await _dio.post(
        '${AppEndpoints.vtrackingBaseUrl}/portDataWithParamAndProjectId',
        data: {
          'param':
              '/api/devices/vtracking/vehicle/filter?limit=500&offset=0&expand=true&getAllAttributes=true',
          'body': {
            'org_ids': [AppEndpoints.vtrackingOrgId],
            'vehicle_type': '',
            'status': [],
            'svc_status': ['expired'],
          },
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': '*/*',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': '${AppEndpoints.vtrackingBaseUrl}/monitorMapV2',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Cookie': 'PLAY_LANG=vi;presence=$presence',
          },
        ),
      );

      final data = res.data;
      if (data == null || data['content'] == null) return null;

      final content = data['content'];
      final rawVehicles = content['vehicles'] as List<dynamic>?;
      if (rawVehicles == null) return null;

      return rawVehicles
          .map((v) =>
              VtrackingVehicle.fromRawJson(v as Map<String, dynamic>))
          .where((v) => v.hasPosition)
          .toList();
    } catch (e) {
      debugPrint('[VTRACKING] Fetch vehicles failed: $e');
      return null;
    }
  }
}
