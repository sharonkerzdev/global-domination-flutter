import 'package:meta/meta.dart';

enum CrashLogLevel { severe, warning, info }

@immutable
class CrashLogEntry {
  const CrashLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });

  final DateTime timestamp;
  final CrashLogLevel level;
  final String tag;
  final String message;
  final String? stackTrace;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrashLogEntry &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          level == other.level &&
          tag == other.tag &&
          message == other.message &&
          stackTrace == other.stackTrace;

  @override
  int get hashCode => Object.hash(timestamp, level, tag, message, stackTrace);

  @override
  String toString() =>
      'CrashLogEntry(timestamp: $timestamp, level: $level, tag: $tag, '
      'message: $message, stackTrace: $stackTrace)';
}
