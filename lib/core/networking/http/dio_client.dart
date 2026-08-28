import 'package:beebase/core/error/error_text.dart';
import 'package:beebase/core/networking/exceptions/cancellation_exception.dart';
import 'package:beebase/core/networking/exceptions/internal_exception.dart';
import 'package:beebase/core/networking/exceptions/server_exception.dart';
import 'package:beebase/core/networking/models/api_error_response.dart';
import 'package:dio/dio.dart';

/// Thin wrapper around [Dio]: the single source of HTTP requests. Data
/// sources compose only the interceptors they need via [copyWith], rather
/// than relying on a globally configured client.
class DioClient {
  DioClient({required String baseUrl, List<Interceptor> interceptors = const []})
    : _options = BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ) {
    _dio = Dio(_options)..interceptors.addAll(interceptors);
  }

  DioClient._fromOptions(this._options, List<Interceptor> interceptors) {
    _dio = Dio(_options)..interceptors.addAll(interceptors);
  }

  final BaseOptions _options;
  late final Dio _dio;

  DioClient copyWith({List<Interceptor> interceptors = const []}) {
    return DioClient._fromOptions(_options, interceptors);
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return _run(() => _dio.get<T>(path, queryParameters: queryParameters));
  }

  Future<Response<T>> post<T>(String path, {Object? data, Map<String, dynamic>? headers}) {
    final options = headers == null ? null : Options(headers: headers);
    return _run(() => _dio.post<T>(path, data: data, options: options));
  }

  Future<Response<T>> put<T>(String path, {Object? data}) {
    return _run(() => _dio.put<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(String path) {
    return _run(() => _dio.delete<T>(path));
  }

  Future<Response<T>> fetch<T>(RequestOptions requestOptions) {
    return _run(() => _dio.fetch<T>(requestOptions));
  }

  Future<Response<T>> _run<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Exception _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return const CancellationException(ErrorTextKey('core.errors.requestCancelled'));
      case DioExceptionType.badResponse:
        return _handleBadResponse(e);
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const InternalException(ErrorTextKey('core.errors.unexpectedNetworkError'));
    }
  }

  Exception _handleBadResponse(DioException e) {
    final response = e.response;
    final data = response?.data;
    final statusCode = response?.statusCode;
    if (statusCode != null && statusCode >= 400 && statusCode < 500 && data is Map<String, dynamic>) {
      try {
        final error = ApiErrorResponse.fromJson(data).error;
        return ServerException(statusCode: statusCode, code: error.code, message: error.message, fields: error.fields);
      } catch (_) {
        // Falls through: the body didn't match the API's error contract.
      }
    }
    return const InternalException(ErrorTextKey('core.errors.requestFailed'));
  }
}
