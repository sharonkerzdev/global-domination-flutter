import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../data/repositories/crash_log_entry.dart';
import '../data/repositories/crash_log_repository.dart';

class CrashReporter {
  CrashReporter._();

  static final CrashReporter instance = CrashReporter._();

  final Logger _logger = Logger('CrashReporter');
  CrashLogRepository? _repo;

  void attach(CrashLogRepository repo) {
    _repo = repo;
  }

  @visibleForTesting
  void reset() {
    _repo = null;
  }

  void reportFlutterError(FlutterErrorDetails details) {
    _logger.severe('Flutter error', details.exception, details.stack);
    final entry = _buildEntry(
      CrashLogLevel.severe,
      'FlutterError',
      details.exceptionAsString(),
      details.stack?.toString(),
    );
    unawaited(_persist(entry));
  }

  void reportPlatformError(Object error, StackTrace stack) {
    _logger.severe('Platform error', error, stack);
    final entry = _buildEntry(
      CrashLogLevel.severe,
      'PlatformError',
      error.toString(),
      stack.toString(),
    );
    unawaited(_persist(entry));
  }

  void reportZonedError(Object error, StackTrace stack) {
    _logger.severe('Zoned error', error, stack);
    final entry = _buildEntry(
      CrashLogLevel.severe,
      'ZonedError',
      error.toString(),
      stack.toString(),
    );
    unawaited(_persist(entry));
  }

  CrashLogEntry _buildEntry(
    CrashLogLevel level,
    String tag,
    String message,
    String? stackTrace,
  ) {
    return CrashLogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      stackTrace: stackTrace,
    );
  }

  Future<void> _persist(CrashLogEntry entry) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.append(entry);
    } catch (e, s) {
      _logger.severe('crash log persistence failed', e, s);
      // Deliberately do NOT rethrow — throwing from an error handler causes infinite loops
    }
  }
}
