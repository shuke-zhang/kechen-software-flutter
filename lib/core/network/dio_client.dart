import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// 使用 --dart-define 覆盖：
/// flutter run -t lib/main_dev.dart --dart-define=API_BASE=http://192.168.3.22:5000
const String _kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.3.22:11020',
);

class DioClient {
  DioClient._();
  static final DioClient _i = DioClient._();
  factory DioClient() => _i;

  late final Dio dio = _create();

  Dio _create() {
    final d = Dio(
      BaseOptions(
        baseUrl: _kApiBase,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: <String, dynamic>{'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );

    // 简单日志（避免引入 logger 依赖）
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) {
          // ignore: avoid_print
          print('➡️ ${opts.method} ${opts.uri}');
          handler.next(opts);
        },
        onResponse: (res, handler) {
          // ignore: avoid_print
          print('✅ ${res.statusCode} ${res.requestOptions.uri}');
          handler.next(res);
        },
        onError: (e, handler) {
          // ignore: avoid_print
          print('❌ ${e.type} ${e.message}');
          handler.next(e);
        },
      ),
    );

    // 如需在开发环境信任自签证书（仅调试！）
    final adapter = d.httpClientAdapter as IOHttpClientAdapter;
    adapter.onHttpClientCreate = (client) {
      // 仅在 http 非生产环境使用，生产请删除！
      client.badCertificateCallback = (_, __, ___) => true;
      return client;
    };

    return d;
  }

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
}
