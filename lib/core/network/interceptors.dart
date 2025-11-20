import 'package:dio/dio.dart';
import '../error/app_exception.dart';
import '../logging/app_logger.dart';

class AuthInterceptor extends Interceptor {
  final String Function()? tokenProvider;
  AuthInterceptor({this.tokenProvider});
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.d('➡️ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.e('❌ DioError: ${err.type} ${err.message}', error: err);
    handler.next(err);
  }
}

class ErrorMappingInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 约定：后端非0即错
    if (response.data is Map && response.data['code'] != null) {
      final code = response.data['code'] as int;
      if (code != 0) {
        final msg = (response.data['message'] ?? '请求失败') as String;
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            error: AppException(msg, code: code),
          ),
        );
        return;
      }
    }
    handler.next(response);
  }
}
