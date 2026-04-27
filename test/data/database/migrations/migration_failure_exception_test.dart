import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';

void main() {
  test('toString includes from/to versions and cause', () {
    const e = MigrationFailureException(
      fromVersion: 2,
      toVersion: 3,
      cause: 'boom',
    );
    expect(
      e.toString(),
      'MigrationFailureException(from: v2 → to: v3, cause: boom)',
    );
  });

  test('preserves stackTrace field', () {
    final st = StackTrace.current;
    final e = MigrationFailureException(
      fromVersion: 1,
      toVersion: 2,
      cause: 'x',
      originalStackTrace: st,
    );
    expect(e.originalStackTrace, same(st));
  });
}
