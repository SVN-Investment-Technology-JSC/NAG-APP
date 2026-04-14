import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_management/features/setup/presentation/selection_page.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final GlobalKey<NavigatorState> navigatorKey;

  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  AuthInterceptor({required this.dio, required this.navigatorKey});

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for refresh endpoint itself
    if (options.path.contains('/auth/refresh')) {
      handler.next(options);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');

    if (token != null && token.isNotEmpty) {
      // Check if token is expired or about to expire (within 30s)
      if (JwtDecoder.isExpired(token)) {
        // Token expired, try to refresh
        if (!_isRefreshing) {
          _isRefreshing = true;
          try {
            final newToken = await _refreshToken(prefs);
            if (newToken != null) {
              token = newToken;
            } else {
              _forceLogout();
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Session expired',
                ),
              );
              return;
            }
          } catch (e) {
            _forceLogout();
            handler.reject(
              DioException(requestOptions: options, error: 'Refresh failed'),
            );
            return;
          } finally {
            _isRefreshing = false;
            // Replay pending requests
            for (final pending in _pendingRequests) {
              pending.options.headers['Authorization'] = 'Bearer $token';
              pending.handler.next(pending.options);
            }
            _pendingRequests.clear();
          }
        } else {
          // Another refresh in progress, queue this request
          _pendingRequests.add(_PendingRequest(options, handler));
          return;
        }
      }

      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/')) {
      // Try refresh on 401
      final prefs = await SharedPreferences.getInstance();
      final newToken = await _refreshToken(prefs);

      if (newToken != null) {
        // Retry the failed request
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $newToken';

        try {
          final response = await dio.fetch(options);
          handler.resolve(response);
          return;
        } catch (e) {
          handler.next(err);
          return;
        }
      } else {
        _forceLogout();
      }
    }

    handler.next(err);
  }

  Future<String?> _refreshToken(SharedPreferences prefs) async {
    try {
      final response = await dio.get('/auth/refresh');

      if (response.statusCode == 200) {
        final data = response.data;
        final newToken = data['accessToken'] as String?;

        if (newToken != null && newToken.isNotEmpty) {
          await prefs.setString('access_token', newToken);

          // Update user info if provided
          if (data['user_id'] != null) {
            await prefs.setInt('user_id', data['user_id']);
          }
          if (data['user_full_name'] != null) {
            await prefs.setString('user_full_name', data['user_full_name']);
          }
          if (data['role'] != null) {
            await prefs.setString('user_role', data['role']);
          }

          return newToken;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AuthInterceptor] Refresh failed: $e');
      return null;
    }
  }

  void _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_id');
    await prefs.remove('user_full_name');
    await prefs.remove('user_role');
    await prefs.setBool('is_logged_in', false);

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SelectionPage()),
      (route) => false,
    );
  }
}

class _PendingRequest {
  final RequestOptions options;
  final RequestInterceptorHandler handler;

  _PendingRequest(this.options, this.handler);
}
