import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/migrations/database_corruption_exception.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';
import 'package:global_domination/providers/data_providers.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

class _ThrowingSelectable extends Selectable<QueryRow> {
  _ThrowingSelectable(this.throwable);

  final Object throwable;

  @override
  Future<List<QueryRow>> get() async => throw throwable;

  @override
  Stream<List<QueryRow>> watch() => const Stream.empty();
}

class _ConfigurableBootstrapFailDb extends AppDatabase {
  _ConfigurableBootstrapFailDb(this.throwOnSelect)
    : super(NativeDatabase.memory());

  bool closed = false;

  /// Thrown when customSelect().get() runs.
  final Object throwOnSelect;

  @override
  Selectable<QueryRow> customSelect(
    String query, {
    List<Variable> variables = const [],
    Set<ResultSetImplementation> readsFrom = const {},
  }) {
    return _ThrowingSelectable(throwOnSelect);
  }

  @override
  Future<void> close() async {
    closed = true;
    await super.close();
  }
}

void main() {
  test('bootstrap resolves to AsyncError when migration step throws', () async {
    late _ConfigurableBootstrapFailDb failingDb;
    final container = ProviderContainer(
      overrides: [
        appDatabaseFactoryProvider.overrideWithValue(() {
          failingDb = _ConfigurableBootstrapFailDb(
            const MigrationFailureException(
              fromVersion: 2,
              toVersion: 3,
              cause: 'forced',
            ),
          );
          return failingDb;
        }),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(databaseBootstrapProvider.future),
      throwsA(
        isA<MigrationFailureException>()
            .having((e) => e.fromVersion, 'fromVersion', 2)
            .having((e) => e.toVersion, 'toVersion', 3),
      ),
    );
    expect(failingDb.closed, isTrue);
  });

  test('SQLite SQLITE_CORRUPT wraps as DatabaseCorruptionException', () async {
    late _ConfigurableBootstrapFailDb failingDb;
    final corrupt = SqliteException(
      extendedResultCode: SqlError.SQLITE_CORRUPT,
      message: 'bad',
      operation: 'opening',
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseFactoryProvider.overrideWithValue(() {
          failingDb = _ConfigurableBootstrapFailDb(corrupt);
          return failingDb;
        }),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(databaseBootstrapProvider.future),
      throwsA(
        isA<DatabaseCorruptionException>()
            .having(
              (e) => e.sqliteResultCode,
              'primary',
              SqlError.SQLITE_CORRUPT,
            )
            .having((e) => e.sqliteOperation, 'operation', 'opening'),
      ),
    );
    expect(failingDb.closed, isTrue);
  });

  test('SQLite SQLITE_NOTADB wraps as DatabaseCorruptionException', () async {
    late _ConfigurableBootstrapFailDb failingDb;
    final bad = SqliteException(
      extendedResultCode: SqlError.SQLITE_NOTADB,
      message: 'not a db',
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseFactoryProvider.overrideWithValue(() {
          failingDb = _ConfigurableBootstrapFailDb(bad);
          return failingDb;
        }),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(databaseBootstrapProvider.future),
      throwsA(
        isA<DatabaseCorruptionException>().having(
          (e) => e.sqliteResultCode,
          'primary',
          SqlError.SQLITE_NOTADB,
        ),
      ),
    );
    expect(failingDb.closed, isTrue);
  });

  test('SQLite SQLITE_BUSY passes through unchanged', () async {
    late _ConfigurableBootstrapFailDb failingDb;
    final busy = SqliteException(
      extendedResultCode: SqlError.SQLITE_BUSY,
      message: 'busy',
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseFactoryProvider.overrideWithValue(() {
          failingDb = _ConfigurableBootstrapFailDb(busy);
          return failingDb;
        }),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(databaseBootstrapProvider.future),
      throwsA(isA<SqliteException>()),
    );
    expect(failingDb.closed, isTrue);
  });

  test('DriftWrappedException cause Sqlite corrupt wraps', () async {
    late _ConfigurableBootstrapFailDb failingDb;
    final wrapped = DriftWrappedException(
      message: 'inner',
      cause: SqliteException(
        extendedResultCode: SqlError.SQLITE_CORRUPT,
        message: 'x',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseFactoryProvider.overrideWithValue(() {
          failingDb = _ConfigurableBootstrapFailDb(wrapped);
          return failingDb;
        }),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(databaseBootstrapProvider.future),
      throwsA(isA<DatabaseCorruptionException>()),
    );
    expect(failingDb.closed, isTrue);
  });

  test('bootstrap resolves to AsyncData on healthy open', () async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseFactoryProvider.overrideWithValue(() {
          final db = AppDatabase(NativeDatabase.memory());
          return db;
        }),
      ],
    );
    addTearDown(container.dispose);
    final db = await container.read(databaseBootstrapProvider.future);
    expect(db.schemaVersion, AppDatabase.currentSchemaVersion);
  });
}
