// lib/core/log/app_logger.dart
import 'package:logger/logger.dart';

/// 全局通用 Logger
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);
