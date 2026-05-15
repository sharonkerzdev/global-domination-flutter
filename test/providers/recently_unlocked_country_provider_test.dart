import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/map_focus_providers.dart';

CountryUnlocked _unlock(String id, String continent) => CountryUnlocked(
  DateTime.utc(2026, 1, 1),
  countryId: CountryId(id),
  continent: ContinentId(continent),
  cost: Influence.zero,
);

ProviderContainer _container(Stream<GameEvent> stream) {
  return ProviderContainer(
    overrides: [gameWorldEventsProvider.overrideWith((ref) => stream)],
  );
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('recentlyUnlockedCountryProvider', () {
    test('initial state is null', () {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final container = _container(bus.stream);
      addTearDown(container.dispose);

      expect(container.read(recentlyUnlockedCountryProvider), isNull);
    });

    test('CountryUnlocked event updates state to that countryId', () async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final container = _container(bus.stream);
      addTearDown(container.dispose);

      // Trigger subscription.
      container.read(recentlyUnlockedCountryProvider);

      bus.add(_unlock('egypt', 'africa'));
      await _pump();

      expect(
        container.read(recentlyUnlockedCountryProvider),
        const CountryId('egypt'),
      );
    });

    test('multiple CountryUnlocked events: last one wins', () async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final container = _container(bus.stream);
      addTearDown(container.dispose);

      container.read(recentlyUnlockedCountryProvider);

      bus.add(_unlock('egypt', 'africa'));
      bus.add(_unlock('germany', 'europe'));
      bus.add(_unlock('china', 'asia'));
      await _pump();

      expect(
        container.read(recentlyUnlockedCountryProvider),
        const CountryId('china'),
      );
    });

    test('non-CountryUnlocked events do not change state', () async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final container = _container(bus.stream);
      addTearDown(container.dispose);

      container.read(recentlyUnlockedCountryProvider);

      final at = DateTime.utc(2026, 1, 1);
      bus.add(Tick(at));
      bus.add(
        CountryTapped(
          at,
          countryId: const CountryId('egypt'),
          collected: Influence.zero,
        ),
      );
      bus.add(
        UpgradePurchased(
          at,
          countryId: const CountryId('egypt'),
          levelsAdded: 1,
          bulkRequested: 1,
          totalCost: Influence.zero,
        ),
      );
      bus.add(
        LeaderHired(
          at,
          countryId: const CountryId('egypt'),
          cost: Influence.zero,
        ),
      );
      bus.add(
        LeaderUpgraded(
          at,
          countryId: const CountryId('egypt'),
          cost: Influence.zero,
          newTier: LeaderTier.tier2,
        ),
      );
      bus.add(ContinentUnlocked(at, continentId: const ContinentId('africa')));
      bus.add(BoostExpired(at));
      bus.add(
        BoostActivated(
          at,
          multiplier: Decimal.fromInt(2),
          expiresAt: at.add(const Duration(seconds: 30)),
          intelSpent: Intel.zero,
        ),
      );

      await _pump();

      expect(container.read(recentlyUnlockedCountryProvider), isNull);
    });

    test('after container.dispose, late events do not throw', () async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final container = _container(bus.stream);

      container.read(recentlyUnlockedCountryProvider);
      bus.add(_unlock('egypt', 'africa'));
      await _pump();

      container.dispose();

      expect(() => bus.add(_unlock('china', 'asia')), returnsNormally);
      await _pump();
    });
  });
}
