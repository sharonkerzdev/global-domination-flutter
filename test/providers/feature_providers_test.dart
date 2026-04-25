import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/providers/game_providers.dart';

import '../helpers/next_unlock_test_fixtures.dart';

class _TestGameWorldNotifier extends GameWorldNotifier {
  _TestGameWorldNotifier({
    required ContentRegistry content,
    required GameState initialState,
  }) : super(
         GameWorld(
           content: content,
           clock: const SystemClock(),
           rng: SeededRng(0),
           initialState: initialState,
         ),
       );

  void setTestState(GameState s) {
    state = s;
  }
}

CountryState _cs(CountryId id, {required bool unlocked}) {
  return CountryState(
    id: id,
    unlocked: unlocked,
    ipLevel: unlocked ? 1 : 0,
    leaderTier: LeaderTier.none,
    bankedInfluence: Influence.zero,
  );
}

void main() {
  group('feature_providers — next unlock', () {
    test('nextUnlockInContinentProvider returns expected teaser', () async {
      final content = multiContinentNextUnlockFixture();
      const egypt = CountryId('egypt');
      const nigeria = CountryId('nigeria');
      final initial = GameState(
        countries: {
          egypt: _cs(egypt, unlocked: true),
          nigeria: _cs(nigeria, unlocked: false),
          const CountryId('kenya'): _cs(
            const CountryId('kenya'),
            unlocked: false,
          ),
        },
      );
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: initial,
      );
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);

      await container.read(contentRegistryProvider.future);
      final teaser = container.read(
        nextUnlockInContinentProvider(const ContinentId('africa')),
      );
      expect(teaser, isNotNull);
      expect(teaser!.countryId, equals(nigeria));
    });

    test('mutating notifier state yields updated teaser', () async {
      final content = multiContinentNextUnlockFixture();
      const egypt = CountryId('egypt');
      const nigeria = CountryId('nigeria');
      const kenya = CountryId('kenya');
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(
          countries: {
            egypt: _cs(egypt, unlocked: true),
            nigeria: _cs(nigeria, unlocked: false),
            kenya: _cs(kenya, unlocked: false),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentRegistryProvider.future);

      expect(
        container
            .read(nextUnlockInContinentProvider(const ContinentId('africa')))!
            .countryId,
        equals(nigeria),
      );

      notifier.setTestState(
        GameState(
          countries: {
            egypt: _cs(egypt, unlocked: true),
            nigeria: _cs(nigeria, unlocked: true),
            kenya: _cs(kenya, unlocked: false),
          },
        ),
      );

      expect(
        container
            .read(nextUnlockInContinentProvider(const ContinentId('africa')))!
            .countryId,
        equals(kenya),
      );
    });

    test(
      'nextUnlockOverallProvider returns africa when only africa unlocked',
      () async {
        final content = multiContinentNextUnlockFixture();
        const egypt = CountryId('egypt');
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameState(
            totalInfluence: Influence(Decimal.parse('100')),
            countries: {egypt: _cs(egypt, unlocked: false)},
          ),
        );
        final container = ProviderContainer(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
        );
        addTearDown(container.dispose);
        await container.read(contentRegistryProvider.future);

        final teaser = container.read(nextUnlockOverallProvider);
        expect(teaser, isNotNull);
        expect(teaser!.continent, equals(const ContinentId('africa')));
      },
    );

    test('mutating notifier state updates overall teaser', () async {
      final content = multiContinentNextUnlockFixture();
      const egypt = CountryId('egypt');
      const nigeria = CountryId('nigeria');
      const kenya = CountryId('kenya');
      const france = CountryId('france');
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(
          totalInfluence: Influence(Decimal.parse('100')),
          countries: {
            egypt: _cs(egypt, unlocked: false),
            nigeria: _cs(nigeria, unlocked: false),
            kenya: _cs(kenya, unlocked: false),
            france: _cs(france, unlocked: false),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentRegistryProvider.future);

      expect(
        container.read(nextUnlockOverallProvider)!.continent,
        equals(const ContinentId('africa')),
      );

      notifier.setTestState(
        GameState(
          totalInfluence: Influence(Decimal.parse('1000000000')),
          countries: {
            egypt: _cs(egypt, unlocked: true),
            nigeria: _cs(nigeria, unlocked: true),
            kenya: _cs(kenya, unlocked: true),
            france: _cs(france, unlocked: false),
          },
        ),
      );

      final teaser = container.read(nextUnlockOverallProvider);
      expect(teaser, isNotNull);
      expect(teaser!.continent, equals(const ContinentId('europe')));
      expect(teaser.countryId, equals(france));
    });

    test('while content is loading both providers return null', () async {
      final content = multiContinentNextUnlockFixture();
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(),
      );
      final never = Completer<ContentRegistry>();
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) => never.future),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(
          nextUnlockInContinentProvider(const ContinentId('africa')),
        ),
        isNull,
      );
      expect(container.read(nextUnlockOverallProvider), isNull);
    });
  });
}
