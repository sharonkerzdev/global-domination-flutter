import 'package:meta/meta.dart';

@immutable
class MigrationFailureException implements Exception {
  const MigrationFailureException({
    required this.fromVersion,
    required this.toVersion,
    required this.cause,
    this.originalStackTrace,
  });

  final int fromVersion;
  final int toVersion;
  final String cause;
  final StackTrace? originalStackTrace;

  @override
  String toString() =>
      'MigrationFailureException(from: v$fromVersion → to: v$toVersion, '
      'cause: $cause)';
}
