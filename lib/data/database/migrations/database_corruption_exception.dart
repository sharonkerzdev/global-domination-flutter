import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

/// Thrown when the SQLite database file is corrupt or not a database (Story 6.6).
@immutable
class DatabaseCorruptionException implements Exception {
  const DatabaseCorruptionException({
    required this.cause,
    this.originalStackTrace,
    this.sqliteResultCode,
    this.sqliteExtendedResultCode,
    this.sqliteOperation,
  });

  final Object cause;
  final StackTrace? originalStackTrace;
  final int? sqliteResultCode;
  final int? sqliteExtendedResultCode;
  final String? sqliteOperation;

  /// Recognizes SQLITE_CORRUPT / SQLITE_NOTADB primary result codes only.
  static DatabaseCorruptionException? tryFrom(Object error, StackTrace stack) {
    Object current = error;
    var relevantStack = stack;

    for (var i = 0; i < 16; i++) {
      if (current is SqliteException) {
        final primary = current.resultCode;
        if (primary != SqlError.SQLITE_CORRUPT &&
            primary != SqlError.SQLITE_NOTADB) {
          return null;
        }
        return DatabaseCorruptionException(
          cause: error,
          originalStackTrace: relevantStack,
          sqliteResultCode: current.resultCode,
          sqliteExtendedResultCode: current.extendedResultCode,
          sqliteOperation: current.operation,
        );
      }

      final next = _unwrapDrift(current);
      if (next == null) break;
      current = next.$1;
      relevantStack = next.$2 ?? relevantStack;
    }
    return null;
  }

  static (Object, StackTrace?)? _unwrapDrift(Object e) {
    if (e is DriftWrappedException && e.cause != null) {
      return (e.cause!, e.trace);
    }
    final remote = _unwrapDriftRemote(e);
    if (remote != null) return remote;
    return null;
  }

  /// Background isolate adapter may surface errors as [DriftRemoteException]
  /// without importing the experimental `drift/remote.dart` library.
  static (Object, StackTrace?)? _unwrapDriftRemote(Object e) {
    if (e.runtimeType.toString() != 'DriftRemoteException') return null;
    try {
      final dynamic d = e;
      final cause = d.remoteCause;
      final StackTrace? trace = d.remoteStackTrace as StackTrace?;
      return (cause as Object, trace);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'DatabaseCorruptionException(sqlite=$sqliteResultCode/'
      '${sqliteExtendedResultCode ?? '?'}, operation=$sqliteOperation, '
      'cause: $cause)';
}
