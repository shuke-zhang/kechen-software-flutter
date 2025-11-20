import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:kechen_software_flutter/core/log/app_logger.dart';

class WsService {
  WsService._();
  static final WsService _instance = WsService._();
  factory WsService() => _instance;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  bool isConnected = false;

  int retryCount = 0;
  final int maxRetry = 10;

  /// 连接（带状态回调）
  Future<void> connect({
    required String url,
    void Function(dynamic)? onMessage,

    /// 正在发起连接时（UI 可以切换为“正在连接服务器...”）
    void Function()? onConnecting,

    /// 底层 WebSocket 创建成功（UI 可以切换为“已连接服务器”）
    void Function()? onConnected,

    /// 连接关闭/出错（UI 可以切换为“离线/未连接”）
    void Function()? onDisconnected,
  }) async {
    // 已经连上就不重复连
    if (isConnected && _channel != null) {
      // appLogger.i('【WS】已经处于连接状态，跳过 connect');
      return;
    }

    // 通知外面：开始连了
    onConnecting?.call();
    // appLogger.i('【WS】开始连接 → $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // ⭐ 关键：创建 channel 成功就认为“已连接”，先允许发送 register
      isConnected = true;
      retryCount = 0;
      // appLogger.i('【WS】底层 WebSocket 已创建，等待服务器消息');

      // 通知外面：已连接
      onConnected?.call();

      _subscription = _channel!.stream.listen(
        (event) {
          appLogger.i('【WS】收到消息：$event');
          onMessage?.call(event);
        },
        onDone: () {
          isConnected = false;
          // appLogger.i('【WS】连接关闭 (onDone)');
          onDisconnected?.call();
          _tryReconnect(
            url: url,
            onMessage: onMessage,
            onConnecting: onConnecting,
            onConnected: onConnected,
            onDisconnected: onDisconnected,
          );
        },
        onError: (e) {
          isConnected = false;
          // appLogger.i('【WS】错误: $e');
          onDisconnected?.call();
          _tryReconnect(
            url: url,
            onMessage: onMessage,
            onConnecting: onConnecting,
            onConnected: onConnected,
            onDisconnected: onDisconnected,
          );
        },
        cancelOnError: true,
      );
    } catch (e) {
      isConnected = false;
      // appLogger.i('【WS】连接异常: $e');
      onDisconnected?.call();
      _tryReconnect(
        url: url,
        onMessage: onMessage,
        onConnecting: onConnecting,
        onConnected: onConnected,
        onDisconnected: onDisconnected,
      );
    }
  }

  /// 自动重连（不会影响已有连接）
  void _tryReconnect({
    required String url,
    void Function(dynamic)? onMessage,
    void Function()? onConnecting,
    void Function()? onConnected,
    void Function()? onDisconnected,
  }) {
    if (retryCount >= maxRetry) {
      // appLogger.i('【WS】已达到最大重连次数，停止重连');
      return;
    }

    retryCount++;
    final delay = (retryCount * 2).clamp(2, 20);

    // appLogger.i('【WS】$delay 秒后重连（第 $retryCount 次）');

    Future.delayed(Duration(seconds: delay), () {
      connect(
        url: url,
        onMessage: onMessage,
        onConnecting: onConnecting,
        onConnected: onConnected,
        onDisconnected: onDisconnected,
      );
    });
  }

  /// 发送消息
  void send(String msg) {
    if (!isConnected || _channel == null) {
      // appLogger.i('【WS】当前未连接，发送失败：$msg');
      return;
    }

    // appLogger.i('【WS】发送消息：$msg');
    _channel!.sink.add(msg);
  }

  /// 手动关闭
  void close() {
    isConnected = false;
    _subscription?.cancel();
    _channel?.sink.close(status.normalClosure);
    // appLogger.i('【WS】已手动关闭');
  }
}
