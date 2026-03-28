import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/network/api_exception.dart';

void main() {
  group('ApiException.fromDioException', () {
    test('maps 400 responses to a user-friendly validation message', () {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/api/v1/subscriptions/123/tasks'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/api/v1/subscriptions/123/tasks',
          ),
          statusCode: 400,
          data: const {'detail': 'Bad request'},
        ),
        type: DioExceptionType.badResponse,
      );

      final mapped = ApiException.fromDioException(exception);

      expect(mapped.statusCode, 400);
      expect(mapped.toString(), '请求参数无效，请检查输入或稍后重试。');
    });

    test('maps 404 responses to a user-friendly not-found message', () {
      final exception = DioException(
        requestOptions: RequestOptions(
          path: '/api/v1/subscriptions/missing/tasks',
        ),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(
            path: '/api/v1/subscriptions/missing/tasks',
          ),
          statusCode: 404,
          data: const {'detail': 'Subscription not found'},
        ),
        type: DioExceptionType.badResponse,
      );

      final mapped = ApiException.fromDioException(exception);

      expect(mapped.statusCode, 404);
      expect(mapped.toString(), '请求的资源不存在或已被删除。');
    });
  });
}
