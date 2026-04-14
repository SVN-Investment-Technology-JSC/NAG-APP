import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'auth_interceptor.dart';
import 'app_endpoints.dart';

class ApiClient {
  static late Dio dio;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void init() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppEndpoints.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(dio: dio, navigatorKey: navigatorKey),
    );
  }
}
