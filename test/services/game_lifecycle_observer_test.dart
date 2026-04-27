import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/services/game_lifecycle_observer.dart';

import '../helpers/save_repository_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('GameLifecycleObserver', () {
    test('paused schedules SaveRepository.flush (meta row appears)', () async {
      final h = SaveRepositoryTestHarness()
        ..start(
          initial: egyptOnlyGameState(ip: 2),
          debounce: const Duration(hours: 1),
        );
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'egypt',
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      h.events.add(
        UpgradePurchased(
          testRepoTimeUtc,
          countryId: const CountryId('egypt'),
          levelsAdded: 1,
          bulkRequested: 0,
          totalCost: Influence.zero,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await h.db.select(h.db.meta).get(), isEmpty);
      final o = GameLifecycleObserver(h.repo);
      await o.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(await h.db.select(h.db.meta).get(), isNotEmpty);
      await h.shutdown();
    });

    test('inactive, detached, hidden each flush', () async {
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.detached,
        AppLifecycleState.hidden,
      ]) {
        final h = SaveRepositoryTestHarness()
          ..start(
            initial: egyptOnlyGameState(),
            debounce: const Duration(hours: 1),
          );
        await h.db
            .into(h.db.countries)
            .insert(
              CountriesCompanion.insert(
                id: 'egypt',
                unlocked: true,
                ipLevel: 1,
                leaderTier: LeaderTier.none.name,
                bankedInfluence: Decimal.zero,
                lastCollectedAt: const Value(null),
              ),
            );
        h.events.add(
          UpgradePurchased(
            testRepoTimeUtc,
            countryId: const CountryId('egypt'),
            levelsAdded: 0,
            bulkRequested: 0,
            totalCost: Influence.zero,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await GameLifecycleObserver(h.repo).didChangeAppLifecycleState(s);
        expect(await h.db.select(h.db.meta).get(), isNotEmpty);
        await h.shutdown();
      }
    });

    test(
      'resumed does not flush (meta stays empty without pending save)',
      () async {
        final h = SaveRepositoryTestHarness()..start();
        await Future<void>.delayed(Duration.zero);
        await GameLifecycleObserver(
          h.repo,
        ).didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(await h.db.select(h.db.meta).get(), isEmpty);
        await h.shutdown();
      },
    );

    test('onResume runs on resumed and swallows errors', () async {
      final h = SaveRepositoryTestHarness()..start();
      await Future<void>.delayed(Duration.zero);
      var calls = 0;
      await GameLifecycleObserver(
        h.repo,
        onResume: () async {
          calls++;
          throw StateError('forced');
        },
      ).didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(calls, 1);
      await h.shutdown();
    });

    test(
      'detach means binding lifecycle change does not flush this repo',
      () async {
        final h = SaveRepositoryTestHarness()
          ..start(
            initial: egyptOnlyGameState(),
            debounce: const Duration(hours: 1),
          );
        await h.db
            .into(h.db.countries)
            .insert(
              CountriesCompanion.insert(
                id: 'egypt',
                unlocked: true,
                ipLevel: 1,
                leaderTier: LeaderTier.none.name,
                bankedInfluence: Decimal.zero,
                lastCollectedAt: const Value(null),
              ),
            );
        h.events.add(
          UpgradePurchased(
            testRepoTimeUtc,
            countryId: const CountryId('egypt'),
            levelsAdded: 0,
            bulkRequested: 0,
            totalCost: Influence.zero,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        GameLifecycleObserver(h.repo)
          ..attach()
          ..detach();
        WidgetsBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(await h.db.select(h.db.meta).get(), isEmpty);
        await h.shutdown();
      },
    );
  });
}
