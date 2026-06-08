import 'dart:io';
import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';

void main() async {
  final dio = Dio(BaseOptions(
    baseUrl: AppEndpoints.apiBaseUrl,
  ));
  
  // Need to add token interceptor?
  print('Need token to test API');
}
