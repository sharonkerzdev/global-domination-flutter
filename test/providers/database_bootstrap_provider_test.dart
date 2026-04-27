import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';
import 'package:global_domination/providers/data_providers.dart';

class _FailingAppDatabase extends AppDatabase {
  _FailingAppDatabase() : super(NativeDatabase.memory());

  bool closed = false;

  @override
  Selectable<QueryRow> customSelect(
    String query, {
    List<Variable> variables = const [],
    Set<ResultSetImplementation> readsFrom = const {},
  }) {
    return _FailingSelectable();
  }

  @override
  Future<void> close() async {
    closed = true;
    await super.close();
  }
}

class _FailingSelectable extends Selectable<QueryRow> {
  @override
  Future<List<QueryRow>> get() async {
    throw const MigrationFailureException(
      fromVersion: 2,
      toVersion: 3,
      cause: 'forced',
    );
  }

  @override
  Stream<List<QueryRow>> watch() => const Stream.empty();
}

void main() {
  test('bootstrap resolves to AsyncError when migration step throws', () async {
    late _FailingAppDatabase failingDb;
    final container = ProviderContainer(
      overrides: [
        appDatabaseFactoryProvider.overrideWithValue(() {
          failingDb = _FailingAppDatabase();
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
    expect(db.schemaVersion, 3);
  });
}
