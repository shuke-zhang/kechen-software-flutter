// lib/api/ws_service.dart
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WsService {
  WsService._();
  static final WsService _instance = WsService._();
  factory WsService() => _instance;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  bool isConnected = false;

  int retryCount = 0;
  final int maxRetry = 10;

  Future<void> connect({
    required String url,
    void Function(dynamic)? onMessage,
  }) async {
    // 已经连上就不重复连
    if (isConnected && _channel != null) {
      print('【WS】已经处于连接状态，跳过 connect');
      return;
    }

    print('【WS】开始连接 → $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // ⭐ 关键：创建 channel 成功就认为“已连接”，先允许发送 register
      isConnected = true;
      retryCount = 0;
      print('【WS】底层 WebSocket 已创建，等待服务器消息');

      _subscription = _channel!.stream.listen(
        (event) {
          print('【WS】收到消息：$event');
          onMessage?.call(event);
        },
        onDone: () {
          isConnected = false;
          print('【WS】连接关闭 (onDone)');
          _tryReconnect(url, onMessage);
        },
        onError: (e) {
          isConnected = false;
          print('【WS】错误: $e');
          _tryReconnect(url, onMessage);
        },
        cancelOnError: true,
      );
    } catch (e) {
      isConnected = false;
      print('【WS】连接异常: $e');
      _tryReconnect(url, onMessage);
    }
  }

  /// 自动重连（不会影响已有连接）
  void _tryReconnect(String url, Function(dynamic)? onMessage) {
    if (retryCount >= maxRetry) {
      print('【WS】已达到最大重连次数($maxRetry)，停止重连');
      return;
    }

    retryCount++;
    final delay = (retryCount * 2).clamp(2, 20);

    print('【WS】$delay 秒后重连（第 $retryCount 次）');

    Future.delayed(Duration(seconds: delay), () {
      connect(url: url, onMessage: onMessage);
    });
  }

  /// 发送消息
  void send(String msg) {
    if (!isConnected || _channel == null) {
      print('【WS】send 失败：未连接，丢弃消息：$msg');
      return;
    }

    print('【WS】发送消息：$msg');
    _channel!.sink.add(msg);
  }

  /// 手动关闭
  void close() {
    isConnected = false;
    _subscription?.cancel();
    _channel?.sink.close(status.normalClosure);
    print('【WS】已手动关闭');
  }
}
