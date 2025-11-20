// lib/core/device/device_id.dart
import 'dart:io';
import 'package:android_id/android_id.dart';

/// 获取 Android 的 ANDROID_ID（Android 8.0+ 基本稳定）
/// - 仅在 Android 生效；iOS 会抛异常（可按需改成返回空字符串）
/// - 无需权限
Future<String> getAndroidId() async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('Only available on Android');
  }
  // android_id 插件内部已处理部分兼容性，这里简单拿即可
  final androidId = await const AndroidId().getId();
  return androidId ?? ''; // 理论上不为 null，保险起见给空串
}
