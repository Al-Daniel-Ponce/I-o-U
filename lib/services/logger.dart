import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class Logger {
  final String tag;

  const Logger(this.tag);

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message) => _log(LogLevel.warning, message);
  void error(String message, [Object? exception, StackTrace? stack]) {
    _log(LogLevel.error, message);
    if (exception != null) {
      debugPrint('  Exception: $exception');
    }
    if (stack != null) {
      debugPrint('  StackTrace: ${stack.toString().split('\n').take(4).join('\n')}');
    }
  }

  void _log(LogLevel level, String message) {
    debugPrint('[${level.name.toUpperCase()}] [$tag] $message');
  }
}
