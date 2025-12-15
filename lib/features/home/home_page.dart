// lib/features/home/home_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:kechen_software_flutter/env/env.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kechen_software_flutter/api/ws_service.dart';
import 'package:kechen_software_flutter/utils/device_id.dart';
import 'package:kechen_software_flutter/core/log/app_logger.dart';
import 'package:kechen_software_flutter/core/player/system_video_player.dart';
import 'package:kechen_software_flutter/api/home_api.dart';

/// 设备状态
/// - notConnected 初始状态：还没开始连服务器（默认值）
/// - idle 空闲（已连接，等待任务下发）
/// - connecting 正在连接服务器
/// - connected 已连接服务器（注册已发送/成功）
/// - playing 正在播放
/// - offline 离线 / 未连接 / 连接失败
enum DeviceStatus {
  /// 初始状态：还没开始连服务器（默认值）
  notConnected,

  /// 空闲（已连接，等待任务下发）
  idle,

  /// 正在连接服务器
  connecting,

  /// 已连接服务器（注册已发送/成功）
  connected,

  /// 正在播放
  playing,

  /// 离线 / 未连接 / 连接失败
  offline,
}

/// 一条状态文案 + 对应状态（目前没在 UI 用到，先保留）
class StatusItem {
  final String text;
  final DeviceStatus status;

  const StatusItem({required this.text, required this.status});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// WebSocket 服务（单例）
  final WsService _ws = WsService();

  /// WebSocket 地址
  static const String _wsUrl = 'ws://192.168.3.22:11020/ws/device';

  String? _androidId;

  /// 当前生成订单号
  String _treatId = '';

  String _log = '日志开始\n';

  /// 日志追加
  void _appendLog(String s) {
    setState(() {
      _log += '$s\n';
    });
  }

  /// 当前设备状态（默认：未连接）
  DeviceStatus _deviceStatus = DeviceStatus.notConnected;

  /// 简单的任务队列：存视频 URL
  final List<String> _taskQueue = <String>[];

  /// 本次下发任务的总数量（用于显示 1/3 这种）
  int _totalTasks = 0;

  /// 已播放数量 = 总数 - 队列剩余
  int get _playedCount {
    return (_totalTasks - _taskQueue.length).clamp(0, _totalTasks);
  }

  /// 播放按钮的文案
  String get _playButtonText {
    if (_totalTasks <= 0) {
      return '播放';
    }

    if (_totalTasks == 1) {
      // 只有一条，不显示进度
      return '播放';
    }

    if (_taskQueue.isEmpty) {
      // 全部播完了
      return '播放（$_totalTasks/$_totalTasks）';
    }

    final int currentIndex = (_playedCount + 1).clamp(1, _totalTasks);
    return '播放（$currentIndex/$_totalTasks）';
  }

  /// 根据当前状态返回对应的文案（居中显示）
  String get _statusText {
    switch (_deviceStatus) {
      case DeviceStatus.notConnected:
        return '未连接服务器';
      case DeviceStatus.offline:
        return '设备离线，请检查网络与服务端';
      case DeviceStatus.connecting:
        return '正在连接服务器...';
      case DeviceStatus.connected:
        return '连接成功，正在注册设备...';
      case DeviceStatus.idle:
        return '已连接，等待任务下发';
      case DeviceStatus.playing:
        return '正在播放服务器下发的视频（系统播放器）';
    }
  }

  /// 切换状态
  void _setStatus(DeviceStatus status) {
    setState(() {
      _deviceStatus = status;
    });
  }

  /// 日志追加（目前主要打到 logger）
  void _append(String s) {
    appLogger.d(s);
    _appendLog(s);
  }

  /// 获取 ANDROID_ID（用你封装的 getAndroidId）
  Future<void> _ensureAndroidId() async {
    if (_androidId != null && _androidId!.isNotEmpty) {
      return;
    }

    try {
      final String id = await getAndroidId();
      _androidId = id;
      _append('【ANDROID_ID】$id');
      setState(() {});
    } catch (e) {
      _append('【ANDROID_ID 获取失败】$e');
    }
  }

  /// 处理 WebSocket 收到的消息
  void _handleWsMessage(dynamic raw) {
    final String text = raw.toString();
    _append('【<=】$text');

    try {
      final Map<String, dynamic> msg = jsonDecode(text) as Map<String, dynamic>;
      final String? action = msg['action'] as String?;
      appLogger.d('🛜 收到消息 $msg');

      // 注册成功
      if (action == 'connected') {
        appLogger.i('注册成功');
        _setStatus(DeviceStatus.idle);
        _append('✅ 设备注册成功，等待任务下发');
        return;
      }

      // 下发视频任务
      if (action == 'publishVideo') {
        appLogger.i('视频下发成功');

        final Map<String, dynamic>? data = msg['data'] as Map<String, dynamic>?;
        final String? rawUrl = data?['videoUrls'] as String?;

        final String videoUrls =
            rawUrl == null
                ? ''
                : rawUrl.startsWith('http')
                ? rawUrl
                : '${Env.apiBase}/upload/$rawUrl';

        final String rawUrls = data?['videoUrls'] as String? ?? '';
        appLogger.i("获取到单号id ${msg['data']['treatId']}");
        appLogger.i("videoUrls $videoUrls $Env.apiBase");
        appLogger.i(Env.apiBase);
        _treatId = msg['data']?['treatId']?.toString() ?? '';

        final List<String> urls =
            videoUrls
                .split(',')
                .map((String e) => e.trim())
                .where((String e) => e.isNotEmpty)
                .toList();

        if (urls.isEmpty) {
          _append('【视频错误】下发的视频列表为空');
          return;
        }

        setState(() {
          _taskQueue
            ..clear()
            ..addAll(urls);
          _totalTasks = urls.length;
        });

        _append('【任务队列】接收 ${urls.length} 条视频任务');
        appLogger.i('任务队列：$_taskQueue');

        // 自动先播第一条
        _playNextFromQueue();
        return;
      }
    } catch (e, s) {
      appLogger.e('解析消息失败', error: e, stackTrace: s);
      _append('【JSON 解析错误】$e');
    }
  }

  /// 连接 WebSocket
  Future<void> _connect() async {
    if (_ws.isConnected) {
      _append('【提示】已经连接，无需重复连接');
      _setStatus(DeviceStatus.connected);
      return;
    }

    await _ws.connect(
      url: _wsUrl,
      onMessage: _handleWsMessage,
      onConnecting: () {
        _append('🛜 已发起连接');
        appLogger.i('🛜 已发起连接');

        _setStatus(DeviceStatus.connecting);
      },
      onConnected: () async {
        _append('✅ 底层 WebSocket 已连接，准备注册设备');
        appLogger.i('✅ 底层 WebSocket 已连接，准备注册设备');
        _setStatus(DeviceStatus.connected);
        await _register();
      },
      onDisconnected: () {
        _append('⚠️ 连接已断开');
        appLogger.i('⚠️ 连接已断开');
        _setStatus(DeviceStatus.offline);
      },
    );
  }

  /// 向服务器注册设备 ID
  Future<void> _register() async {
    if (!_ws.isConnected) {
      _append('【提示】未连接，无法注册');
      return;
    }

    await _ensureAndroidId();

    final Map<String, dynamic> payload = <String, dynamic>{
      'action': 'register',
      'data': <String, dynamic>{'deviceId': _androidId},
    };

    final String msg = jsonEncode(payload);
    _ws.send(msg);

    _append('发送注册设备信息... $msg');
  }

  /// 主动断开
  void _disconnect() {
    _ws.close();
    _append('【OK】已断开');
    _setStatus(DeviceStatus.offline);
  }

  /// 从任务队列里取下一条，用系统播放器播放
  Future<void> _playNextFromQueue() async {
    if (_taskQueue.isEmpty) {
      _append('【任务队列】当前无任务');
      _setStatus(DeviceStatus.idle);
      return;
    }

    final String url = _taskQueue.removeAt(0);

    _setStatus(DeviceStatus.playing);

    _append('【系统播放视频】$url');
    appLogger.i('使用系统播放器播放：$url');

    try {
      await SystemVideoPlayer.open(url);
    } catch (e, s) {
      appLogger.e('打开系统播放器失败', error: e, stackTrace: s);
      _append('【视频错误】打开系统播放器失败：$e');
      _setStatus(DeviceStatus.idle);
    }
  }

  /// 生成报告
  Future<void> _generateReport() async {
    if (_treatId.isEmpty) {
      appLogger.d('_treatId为空你个憨包');
      return;
    }
    try {
      appLogger.i('开始请求生成报告接口');

      final result = await HomeApi.generateReport(treatId: _treatId);

      appLogger.i('报告生成接口返回: $result');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已请求生成报告')));
    } catch (e, s) {
      appLogger.e('生成报告失败', error: e, stackTrace: s);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('报告生成失败：$e')));
    }
  }

  void _test() async {
    try {
      final res = await HomeApi.generateReport(treatId: '1');
      _append('generateReport请求成功 $res');
    } catch (e) {
      _append('generateReport请求失败');
    }
  }

  StreamSubscription? _playerExitSub;
  @override
  void initState() {
    super.initState();
    _ensureAndroidId();
    _appendLog('initState触发');

    Future.microtask(_connect);

    // 🔥 监听系统播放器关闭事件（全局可接收）
    _playerExitSub = SystemVideoPlayer.onPlayerExit.listen((_) {
      appLogger.i("🔥 HomePage 收到系统播放器关闭事件");

      // 这里就是系统播放器关闭后的处理逻辑
      // 例如继续播放下一条任务
      _setStatus(DeviceStatus.idle);

      if (_taskQueue.isNotEmpty) {
        appLogger.i('自动播放下一条');
        _playNextFromQueue(); // 自动播放下一条
      } else {
        _append('【播放完成】任务队列全部完成');
        // 在这儿调取报告接口
        // _generateReport();
      }
    });
  }

  @override
  void dispose() {
    _playerExitSub?.cancel();
    _ws.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool connected = _ws.isConnected;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 8),

              // 头部：显示 设备编号 + 复制按钮
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const Text(
                    '设备编号：',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      _androidId ?? '（未获取）',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed:
                        _androidId == null || _androidId!.isEmpty
                            ? null
                            : () async {
                              await Clipboard.setData(
                                ClipboardData(text: _androidId!),
                              );

                              if (!mounted) {
                                return;
                              }

                              // 先关掉上一个，避免叠加
                              ScaffoldMessenger.of(
                                context,
                              ).hideCurrentSnackBar();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  content: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.inverseSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                          color: Colors.black.withOpacity(0.15),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onInverseSurface,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '已复制设备编号',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onInverseSurface,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 中部：状态文案，垂直水平居中
              Expanded(
                child: Center(
                  child: Row(
                    children: [
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFCC6633),
                          fontSize: 20,
                        ),
                      ),
                      // TextButton(onPressed: _test, child: const Text('测试按钮')),
                      // ButtonBarTheme(data: data, child: child)
                    ],
                  ),
                ),
              ),

              // Expanded(
              //   child: SingleChildScrollView(
              //     child: SelectableText(
              //       _log,
              //       style: const TextStyle(fontSize: 13),
              //     ),
              //   ),
              // ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
