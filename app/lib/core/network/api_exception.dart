import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? path;
  final String? debugMessage;

  const ApiException({
    required this.message,
    this.statusCode,
    this.path,
    this.debugMessage,
  });

  factory ApiException.fromDioException(DioException exception) {
    final statusCode = exception.response?.statusCode;
    return ApiException(
      message: _resolveMessage(exception),
      statusCode: statusCode,
      path: exception.requestOptions.path,
      debugMessage: _extractDebugMessage(exception),
    );
  }

  static String _resolveMessage(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络请求超时，请稍后重试。';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络后重试。';
      case DioExceptionType.badCertificate:
        return '无法建立安全连接，请稍后重试。';
      case DioExceptionType.cancel:
        return '请求已取消。';
      case DioExceptionType.badResponse:
        return _resolveStatusMessage(exception.response?.statusCode);
      case DioExceptionType.unknown:
        return '请求失败，请稍后重试。';
    }
  }

  static String _resolveStatusMessage(int? statusCode) {
    return switch (statusCode) {
      400 || 422 => '请求参数无效，请检查输入或稍后重试。',
      401 || 403 => '当前操作未被授权，请重新登录后重试。',
      404 => '请求的资源不存在或已被删除。',
      409 => '数据状态已变化，请刷新后重试。',
      int code when code >= 500 => '服务暂时不可用，请稍后重试。',
      _ => '请求失败，请稍后重试。',
    };
  }

  static String? _extractDebugMessage(DioException exception) {
    final responseData = exception.response?.data;
    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
    }
    if (exception.message case final String message
        when message.trim().isNotEmpty) {
      return message.trim();
    }
    return null;
  }

  @override
  String toString() => message;
}
