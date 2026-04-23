import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nguyenanh/core/network/auth_interceptor.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';

class ApiClient {
  static late Dio dio;
  static late Dio refreshDio;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static late PersistCookieJar cookieJar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    cookieJar = PersistCookieJar(
      storage: FileStorage('${dir.path}/.cookies/'),
    );

    final baseOptions = BaseOptions(
      baseUrl: AppEndpoints.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    );

    refreshDio = Dio(BaseOptions(
      baseUrl: AppEndpoints.apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ));
    refreshDio.interceptors.add(CookieManager(cookieJar));

    dio = Dio(baseOptions);
    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        refreshDio: refreshDio,
        navigatorKey: navigatorKey,
      ),
    );
  }
}
