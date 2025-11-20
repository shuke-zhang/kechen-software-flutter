// lib/features/home/home_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../api/ws_service.dart';
import '../../utils/device_id.dart'; // 如果是 utils 目录，请改成 ../../utils/device_id.dart

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

  String _log = '今天天气怎么样\n';
  String? _androidId;
  bool _busy = false;

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

      if (action == 'publishVideo') {
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
      return;
    }

    setState(() {
      _busy = true;
    });

    await _ws.connect(url: _wsUrl, onMessage: _handleWsMessage);

    _append('【OK】已发起连接');
    await _ensureAndroidId();
    _register();

    setState(() {
      _busy = false;
    });
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
      appBar: AppBar(title: const Text('Home: WebSocket')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 按钮区
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: connected || _busy ? null : _connect,
                  child: Text(_busy ? '连接中...' : '连接'),
                ),
                OutlinedButton(
                  onPressed: connected ? _sendPing : null,
                  child: const Text('发送'),
                ),
                TextButton(
                  onPressed: connected ? _disconnect : null,
                  child: const Text('断开'),
                ),
                Chip(
                  label: Text(connected ? '已连接' : '未连接'),
                  backgroundColor:
                      connected ? Colors.green.shade100 : Colors.grey.shade300,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ANDROID_ID 区域
            Row(
              children: [
                const Text(
                  'ANDROID_ID：',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: SelectableText(
                    _androidId ?? '（未获取）',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed:
                      _androidId == null
                          ? null
                          : () async {
                            await Clipboard.setData(
                              ClipboardData(text: _androidId!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制 ANDROID_ID')),
                            );
                          },
                ),
              ],
            ),

            const Divider(),

            // 视频播放器
            if (_player != null && _player!.value.isInitialized)
              AspectRatio(
                aspectRatio: _player!.value.aspectRatio,
                child: VideoPlayer(_player!),
              )
            else
              const Text('等待视频播放...'),

            const SizedBox(height: 8),

            // 日志区
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _log,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
