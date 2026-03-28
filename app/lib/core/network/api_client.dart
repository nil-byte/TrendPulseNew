import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:trendpulse/core/network/api_base_url_resolver.dart';
import 'package:trendpulse/core/network/api_exception.dart';
import 'api_endpoints.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({String? baseUrl}) {
    final configuredBaseUrl = baseUrl ?? ApiEndpoints.baseUrl;
    final effectiveBaseUrl = ApiBaseUrlResolver.resolve(configuredBaseUrl);
    _dio = Dio(
      BaseOptions(
        baseUrl: effectiveBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[API] $obj'),
      ),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _guard(() => _dio.get<T>(path, queryParameters: queryParameters));

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _guard(() => _dio.post<T>(path, data: data));

  Future<Response<T>> put<T>(String path, {Object? data}) =>
      _guard(() => _dio.put<T>(path, data: data));

  Future<Response<T>> delete<T>(String path) =>
      _guard(() => _dio.delete<T>(path));

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  /// Effective HTTP base URL (from constructor or [BaseOptions]).
  String get baseUrl => _dio.options.baseUrl;
}
