import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_management/core/network/api_client.dart';
import 'package:vehicle_management/features/setup/presentation/selection_page.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final Dio refreshDio;
  final GlobalKey<NavigatorState> navigatorKey;
  VoidCallback? onTokenRefreshed;

  bool _isRefreshing = false;
  bool _isLoggingOut = false;
  Completer<String?>? _refreshCompleter;

  static const _retryKey = '_isRetry';

  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.navigatorKey,
    this.onTokenRefreshed,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.contains('/auth/refresh') ||
        options.path.contains('/auth/login')) {
      handler.next(options);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.contains('/auth/login') ||
        err.requestOptions.path.contains('/auth/refresh')) {
      handler.next(err);
      return;
    }

    if (err.requestOptions.extra[_retryKey] == true) {
      handler.next(err);
      return;
    }

    try {
      final newToken = await _handleTokenRefresh();

      if (newToken != null) {
        final original = err.requestOptions;

        // Clone FormData to avoid "Stream already listened to" on retry
        dynamic newData = original.data;
        if (original.data is FormData) {
          final old = original.data as FormData;
          final cloned = FormData();
          cloned.fields.addAll(old.fields);
          for (final f in old.files) {
            cloned.files.add(MapEntry(f.key, f.value.clone()));
          }
          newData = cloned;
        }

        final response = await dio.request(
          original.path,
          data: newData,
          queryParameters: original.queryParameters,
          options: Options(
            method: original.method,
            headers: {
              ...original.headers,
              'Authorization': 'Bearer $newToken',
            },
            contentType: original.contentType,
            responseType: original.responseType,
            extra: {...original.extra, _retryKey: true},
          ),
        );
        handler.resolve(response);
        return;
      }
    } catch (_) {}

    _forceLogout();
    handler.next(err);
  }

  Future<String?> _handleTokenRefresh() async {
    final inflight = _refreshCompleter;
    if (_isRefreshing && inflight != null) {
      return inflight.future;
    }

    _isRefreshing = true;
    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final newToken = await _refreshToken();
      completer.complete(newToken);
      return newToken;
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
      return null;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  Future<String?> _refreshToken() async {
    try {
      final response = await refreshDio.get('/auth/refresh');

      if (response.statusCode == 200) {
        final data = response.data;
        final newToken = data['accessToken'] as String?;

        if (newToken != null && newToken.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', newToken);

          final userIdValue = data['user_id'];
          if (userIdValue != null) {
            final parsed = userIdValue is int
                ? userIdValue
                : userIdValue is num
                    ? userIdValue.toInt()
                    : int.tryParse(userIdValue.toString());
            if (parsed != null) {
              await prefs.setInt('user_id', parsed);
            }
          }
          if (data['user_full_name'] != null) {
            await prefs.setString('user_full_name', data['user_full_name'].toString());
          }
          if (data['role'] != null) {
            await prefs.setString('user_role', data['role'].toString());
          }
          await prefs.setBool('is_logged_in', true);

          onTokenRefreshed?.call();

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
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('user_id');
      await prefs.remove('user_full_name');
      await prefs.remove('user_role');
      await prefs.setBool('is_logged_in', false);

      ApiClient.cookieJar.deleteAll();

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SelectionPage()),
        (route) => false,
      );
    } finally {
      _isLoggingOut = false;
    }
  }
}

