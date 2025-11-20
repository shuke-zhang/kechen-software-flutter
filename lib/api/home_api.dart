import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';

/// 像 Vue 的 /api 模块一样，集中管理接口
class HomeApi {
  HomeApi._();
  static final HomeApi _i = HomeApi._();
  factory HomeApi() => _i;

  final Dio _dio = DioClient().dio;

  /// 示例：获取“今天的天气”或任意测试接口
  /// 把 '/api/hello' 换成你的真实后端路径，比如：'/weather/today'
  Future<String> fetchTodayWeather({Map<String, dynamic>? query}) async {
    final Response res = await _dio.get(
      '/api/user/login',
      queryParameters: query,
    );
    // 格式化成漂亮的 JSON 字符串
    return const JsonEncoder.withIndent('  ').convert(res.data);
  }
}
