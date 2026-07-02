import 'dart:developer';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class Logger {
  static LogLevel _level = LogLevel.debug;

  static void setLevel(LogLevel level) {
    _level = level;
  }

  static void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    if (_level.index <= LogLevel.debug.index) {
      log(message, name: 'DEBUG', error: error, stackTrace: stackTrace);
    }
  }

  static void info(String message, {dynamic error, StackTrace? stackTrace}) {
    if (_level.index <= LogLevel.info.index) {
      log(message, name: 'INFO', error: error, stackTrace: stackTrace);
    }
  }

  static void warning(String message, {dynamic error, StackTrace? stackTrace}) {
    if (_level.index <= LogLevel.warning.index) {
      log(message, name: 'WARN', error: error, stackTrace: stackTrace);
    }
  }

  static void error(String message, {dynamic error, StackTrace? stackTrace}) {
    if (_level.index <= LogLevel.error.index) {
      log(message, name: 'ERROR', error: error, stackTrace: stackTrace);
    }
  }
}