import 'dart:async';
import 'package:flutter/services.dart';
import 'package:kechen_software_flutter/core/log/app_logger.dart';

class SystemVideoPlayer {
  static final MethodChannel _channel = MethodChannel(
    'kechen_software_flutter/system_video_player',
  )..setMethodCallHandler(_callbackHandler);

  /// 🔥 系统播放器关闭事件流（全局广播）
  static final StreamController<void> _exitController =
      StreamController.broadcast();

  static Stream<void> get onPlayerExit => _exitController.stream;

  /// Flutter 收到原生回调
  static Future<dynamic> _callbackHandler(MethodCall call) async {
    if (call.method == 'onSystemPlayerExit') {
      appLogger.i("🔥 Flutter 收到消息：系统播放器关闭了");

      // 🔥 向所有监听者广播事件
      _exitController.add(null);
    }
  }

  /// 打开系统播放器
  static Future<void> open(String url) async {
    try {
      final result = await _channel.invokeMethod('openSystemPlayer', {
        'url': url,
      });

      appLogger.i('已交由系统播放器播放：$url (Result: $result)');
    } on PlatformException catch (e, s) {
      appLogger.e('调用系统播放器失败', error: e, stackTrace: s);
      rethrow;
    }
  }
}
