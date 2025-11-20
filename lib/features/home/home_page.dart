// lib/features/home/home_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'package:kechen_software_flutter/api/ws_service.dart';
import 'package:kechen_software_flutter/utils/device_id.dart'; // 如果是 utils 目录，请改成 ../../utils/device_id.dart
import 'package:kechen_software_flutter/core/log/app_logger.dart';

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

/// 一条状态文案 + 对应状态
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

  /// 状态枚举，比如：空闲、播放中、离线

  /// WebSocket 地址
  static const String _wsUrl = 'ws://192.168.3.22:11020/ws/device';

  /// 所有可选状态短句
  final List<StatusItem> _statusList = const [
    StatusItem(text: '未连接', status: DeviceStatus.notConnected),
    StatusItem(text: '设备空闲中，等待任务下发', status: DeviceStatus.idle),
    StatusItem(text: '正在连接服务器...', status: DeviceStatus.connecting),
    StatusItem(text: '已连接服务器，等待指令', status: DeviceStatus.connected),
    StatusItem(text: '正在播放服务器下发的视频', status: DeviceStatus.playing),
    StatusItem(text: '设备离线，请检查网络与服务端', status: DeviceStatus.offline),
  ];

  String _log = '今天天气怎么样\n';
  String? _androidId;

  /// 当前设备状态（默认：离线 / 未连接）
  DeviceStatus _deviceStatus = DeviceStatus.notConnected;

  /// 根据当前状态返回对应的文案
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
        return '正在播放服务器下发的视频';
    }
  }

  /// 切换状态
  void _setStatus(DeviceStatus status) {
    setState(() {
      _deviceStatus = status;
    });
  }

  /// 视频播放器
  VideoPlayerController? _player;
  List<String> _playList = [];
  int _playIndex = 0;

  /// 日志追加
  void _append(String s) {
    setState(() {
      _log += '$s\n';
    });
  }

  /// 获取 ANDROID_ID（用你封装的 getAndroidId）
  Future<void> _ensureAndroidId() async {
    if (_androidId != null && _androidId!.isNotEmpty) {
      return;
    }

    try {
      final id = await getAndroidId();
      _androidId = id;
      _append('【ANDROID_ID】$id');
      setState(() {});
    } catch (e) {
      _append('【ANDROID_ID 获取失败】$e');
    }
  }

  /// 处理 WebSocket 收到的消息
  void _handleWsMessage(dynamic raw) {
    final text = raw.toString();
    _append('【<=】$text');

    try {
      final msg = jsonDecode(text);
      final action = msg['action'];
      appLogger.d('🛜 收到消息 $raw');

      if (msg['action'] == 'connected') {
        appLogger.i('注册成功');
        _setStatus(DeviceStatus.idle);
      }

      if (action == 'publishVideo') {
        appLogger.i('视频下发成功');

        final rawUrls = msg['data']['videoUrls'] as String;

        final urls =
            rawUrls
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();

        _append('【收到视频列表】$urls');
        _playVideos(urls);
      }
    } catch (e) {
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
      // ⭐ 1. 正在连接
      onConnecting: () {
        _append('🛜 已发起连接');
        appLogger.i('🛜 已发起连接');
        _setStatus(DeviceStatus.connecting);
      },

      // ⭐ 2. 底层 WebSocket 已连上
      onConnected: () async {
        _append('✅ 底层 WebSocket 已连接，准备注册设备');
        appLogger.i('✅ 底层 WebSocket 已连接，准备注册设备');
        _setStatus(DeviceStatus.connected);

        // 立刻发注册消息
        await _register();
      },

      // ⭐ 3. 被断开 / 失败 / 重连期间都会触发
      onDisconnected: () {
        _append('⚠️ 连接已断开');
        appLogger.i('⚠️ 连接已断开');
        _setStatus(DeviceStatus.offline);
      },
    );

    // _append('🛜 已发起连接');
    // await _ensureAndroidId();
    // _register(); // 发送注册
  }

  /// 向服务器注册设备 ID
  Future<void> _register() async {
    if (!_ws.isConnected) {
      _append('【提示】未连接，无法注册');
      return;
    }

    await _ensureAndroidId();

    final payload = {
      'action': 'register',
      'data': {'deviceId': _androidId},
    };

    final msg = jsonEncode(payload);
    _ws.send(msg);

    _append('【=>】register: $msg');
  }

  /// 发送 ping
  void _sendPing() {
    if (!_ws.isConnected) {
      _append('【提示】未连接，无法发送 ping');
      return;
    }
    _ws.send('ping');
    _append('【=>】ping');
  }

  /// 主动断开
  void _disconnect() {
    _ws.close();
    _append('【OK】已断开');
    setState(() {});
  }

  /// 播放一组视频
  Future<void> _playVideos(List<String> urls) async {
    if (urls.isEmpty) {
      _append('【提示】视频列表为空');
      return;
    }

    _playList = urls;
    _playIndex = 0;
    await _startPlay();
  }

  /// 播放当前索引的视频
  Future<void> _startPlay() async {
    if (_playIndex < 0 || _playIndex >= _playList.length) {
      _append('【错误】播放索引越界');
      return;
    }

    final url = _playList[_playIndex];
    _append('【播放视频】$url');

    _player?.dispose();
    _player = VideoPlayerController.networkUrl(Uri.parse(url));

    await _player!.initialize();
    await _player!.play();

    _player!.addListener(() {
      final v = _player!.value;
      if (v.isInitialized && v.position >= v.duration && !v.isPlaying) {
        _playNext();
      }
    });

    setState(() {});
  }

  /// 播放下一个视频
  void _playNext() {
    if (_playIndex + 1 >= _playList.length) {
      _append('【播放完成】无更多视频');
      return;
    }

    _playIndex++;
    _startPlay();
  }

  @override
  void initState() {
    super.initState();

    _ensureAndroidId();

    // 页面加载完自动连一次
    Future.microtask(() {
      _connect();
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    _ws.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _ws.isConnected;
    return Scaffold(
      // appBar: AppBar(title: const Text('测试')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _statusText,
            style: const TextStyle(color: Color(0xFFCC6633), fontSize: 20),
          ),
        ),
      ),
    );
  }
}
