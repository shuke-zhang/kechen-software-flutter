import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';

class HomeApi {
  static final Dio _req = Request().dio;

  /// 生成报告（设备端）
  static Future<Map<String, dynamic>> generateReport({
    required String treatId,
  }) async {
    final res = await _req.get(
      '/api/videoTreat/addReport',
      queryParameters: {'treatId': treatId},
    );

    return res.data as Map<String, dynamic>;
  }
}
