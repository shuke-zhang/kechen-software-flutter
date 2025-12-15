import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:kechen_software_flutter/core/log/app_logger.dart';
import 'package:kechen_software_flutter/env/env.dart';

/// 使用 --dart-define 覆盖：
/// flutter run -t lib/main_dev.dart --dart-define=API_BASE=http://192.168.3.22:5000
const String _kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: Env.apiBase,
);

class Request {
  Request._();
  static final Request _i = Request._();
  factory Request() => _i;

  late final Dio dio = _create();

  Dio _create() {
    final d = Dio(
      BaseOptions(
        baseUrl: _kApiBase,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );

    /// -------------------------
    /// 请求 & 响应 拦截器
    /// -------------------------
    d.interceptors.add(
      InterceptorsWrapper(
        /// ===== 请求拦截 =====
        onRequest: (opts, handler) {
          print('⬆️ [REQUEST] ${opts.method} ${opts.uri}');
          if (opts.data != null) print('📦 Body: ${opts.data}');
          if (opts.queryParameters.isNotEmpty) {
            print('🔍 Query: ${opts.queryParameters}');
          }
          handler.next(opts);
        },

        /// ===== 响应拦截 =====
        onResponse: (res, handler) {
          appLogger.i('⬇️ [RESPONSE] $res ');

          final data = res.data;

          // 后端业务判断格式：{ code, msg, data }
          if (data is Map && data.containsKey('code')) {
            final int code = data['code'];
            final String msg = data['msg'] ?? '未知错误';

            if (code != 0) {
              // ❌ 业务逻辑失败 → 转成 DioException
              return handler.reject(
                DioException(
                  requestOptions: res.requestOptions,
                  response: res,
                  type: DioExceptionType.badResponse,
                  error: msg,
                ),
              );
            }
            if (code == 401) {
              appLogger.d('⚠️ 401 未授权，跳过请求');
              return handler.next(res);
            }
          }

          handler.next(res);
        },

        /// ===== 错误拦截 =====
        onError: (e, handler) {
          String msg = '网络异常，请稍后重试';

          switch (e.type) {
            case DioExceptionType.connectionTimeout:
              msg = '连接服务器超时，请检查网络';
              break;

            case DioExceptionType.sendTimeout:
              msg = '发送数据超时，请稍后重试';
              break;

            case DioExceptionType.receiveTimeout:
              msg = '服务器响应超时，请稍后再试';
              break;

            case DioExceptionType.badResponse:
              msg = '服务器错误：${e.response?.statusCode ?? ''}';
              break;

            case DioExceptionType.unknown:
              // SocketException / 网络断开
              if (e.error is! String && e.error != null) {
                final err = e.error.toString();
                if (err.contains('SocketException')) {
                  msg = '网络连接失败，请检查您的网络';
                }
                if (err.contains('HandshakeException')) {
                  msg = 'SSL 证书异常，无法连接服务器';
                }
              }
              break;

            default:
              msg = e.message ?? '未知错误';
              break;
          }

          print('❌ [ERROR] ${e.type} => $msg');

          // 你可以这里接入你的 SnackBar，例如：
          // AppSnackBar.showError(msg);

          handler.next(e);
        },
      ),
    );

    /// HTTPS 开发忽略证书（开发环境使用，生产删掉）
    final adapter = d.httpClientAdapter as IOHttpClientAdapter;
    adapter.onHttpClientCreate = (client) {
      client.badCertificateCallback = (_, __, ___) => true;
      return client;
    };

    return d;
  }

  // =================================================
  // 常用方法：GET / POST / PUT / DELETE / PATCH / HEAD
  // =================================================

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    return dio.get<T>(path, queryParameters: query);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
  }) {
    return dio.post<T>(path, data: data, queryParameters: query);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
  }) {
    return dio.put<T>(path, data: data, queryParameters: query);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
  }) {
    return dio.delete<T>(path, data: data, queryParameters: query);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
  }) {
    return dio.patch<T>(path, data: data, queryParameters: query);
  }

  Future<Response<T>> head<T>(String path, {Map<String, dynamic>? query}) {
    return dio.head<T>(path, queryParameters: query);
  }

  Future<Response<T>> options<T>(
    String path, {
    Map<String, dynamic>? query,
    dynamic data,
  }) {
    return dio.request<T>(
      path,
      data: data,
      queryParameters: query,
      options: Options(method: 'OPTIONS'),
    );
  }
}
