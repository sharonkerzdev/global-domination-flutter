import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/database_providers.dart';
import 'package:global_domination/providers/game_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test(
    'persisted snapshot has null lastSavedAt when meta row absent',
    () async {
      late AppDatabase db;
      final container = ProviderContainer(
        overrides: [
          appDatabaseFactoryProvider.overrideWithValue(() {
            db = AppDatabase(NativeDatabase.memory());
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() async => db.close());

      await container.read(databaseBootstrapProvider.future);
      final snapshot = await container.read(
        persistedGameSnapshotProvider.future,
      );
      final registry = await container.read(contentRegistryProvider.future);

      expect(snapshot.lastSavedAt, equals(null));
      expect(snapshot.state, equals(GameState.initialSeed(registry)));
    },
  );

  test('persisted snapshot exposes meta lastSavedAt when row exists', () async {
    late AppDatabase db;
    final savedAt = DateTime.utc(2026, 4, 27, 10, 30);
    final container = ProviderContainer(
      overrides: [
        appDatabaseFactoryProvider.overrideWithValue(() {
          db = AppDatabase(NativeDatabase.memory());
          return db;
        }),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async => db.close());

    await container.read(databaseBootstrapProvider.future);
    await db
        .into(db.meta)
        .insert(
          MetaCompanion.insert(
            singletonId: const Value(0),
            schemaVersion: 3,
            lastSavedAt: savedAt,
            totalInfluence: Decimal.zero,
            totalIntel: Decimal.zero,
            goldenOpportunityMultiplier: Decimal.one,
            boostMultiplier: Decimal.one,
          ),
        );

    final snapshot = await container.read(persistedGameSnapshotProvider.future);
    expect(snapshot.lastSavedAt, equals(savedAt.toUtc()));
  });
}
