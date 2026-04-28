import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/providers/game_providers.dart';

import '../helpers/fake_clock.dart';
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

  group('feature_providers — daily reward', () {
    test('dailyRewardAvailableProvider is false while content is loading', () {
      final content = multiContinentNextUnlockFixture();
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(),
      );
      final never = Completer<ContentRegistry>();
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(DateTime(2026, 4, 25))),
          contentRegistryProvider.overrideWith((_) => never.future),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(dailyRewardAvailableProvider), isFalse);
    });

    test(
      'dailyRewardAvailableProvider: empty, claimed today, next day',
      () async {
        final content = multiContinentNextUnlockFixture();
        final now = DateTime(2026, 4, 25, 12, 0);
        final clock = FakeClock(now);
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameState(),
        );
        final container = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(clock),
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
        );
        addTearDown(container.dispose);
        await container.read(contentRegistryProvider.future);
        expect(container.read(dailyRewardAvailableProvider), isTrue);

        notifier.setTestState(
          GameState(dailyStreak: DailyStreak(day: 1, lastClaimDate: now)),
        );
        expect(container.read(dailyRewardAvailableProvider), isFalse);

        clock.advance(const Duration(days: 1));
        container.invalidate(dailyRewardAvailableProvider);
        expect(container.read(dailyRewardAvailableProvider), isTrue);
      },
    );
  });

  group('feature_providers — currency totals', () {
    test(
      'totalInfluenceProvider and totalIntelProvider return typed values',
      () async {
        final content = multiContinentNextUnlockFixture();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameState(
            totalInfluence: Influence(Decimal.parse('1234')),
            totalIntel: Intel(Decimal.parse('56')),
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
          container.read(totalInfluenceProvider),
          equals(Influence(Decimal.parse('1234'))),
        );
        expect(
          container.read(totalIntelProvider),
          equals(Intel(Decimal.parse('56'))),
        );
      },
    );

    testWidgets(
      'ref.listen on totalInfluenceProvider skips intel-only state updates',
      (tester) async {
        var influenceNotifications = 0;
        final content = multiContinentNextUnlockFixture();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameState(
            totalInfluence: Influence(Decimal.one),
            totalIntel: Intel(Decimal.one),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentRegistryProvider.overrideWith((_) async => content),
              gameWorldProvider.overrideWith((_) => notifier),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  ref.watch(gameWorldProvider);
                  ref.listen<Influence>(totalInfluenceProvider, (
                    previous,
                    next,
                  ) {
                    influenceNotifications++;
                  });
                  return Scaffold(
                    body: Column(
                      children: [
                        TextButton(
                          key: const Key('intelOnly'),
                          onPressed: () {
                            notifier.setTestState(
                              GameState(
                                totalInfluence: Influence(Decimal.one),
                                totalIntel: Intel(Decimal.parse('99')),
                              ),
                            );
                          },
                          child: const Text('intelOnly'),
                        ),
                        TextButton(
                          key: const Key('influence'),
                          onPressed: () {
                            notifier.setTestState(
                              GameState(
                                totalInfluence: Influence(Decimal.parse('2')),
                                totalIntel: Intel(Decimal.parse('99')),
                              ),
                            );
                          },
                          child: const Text('influence'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final baseline = influenceNotifications;

        await tester.tap(find.byKey(const Key('intelOnly')));
        await tester.pump();
        expect(influenceNotifications, baseline);

        await tester.tap(find.byKey(const Key('influence')));
        await tester.pump();
        expect(influenceNotifications, baseline + 1);
      },
    );

    testWidgets(
      'ref.listen on totalIntelProvider skips influence-only state updates',
      (tester) async {
        var intelNotifications = 0;
        final content = multiContinentNextUnlockFixture();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameState(
            totalInfluence: Influence(Decimal.one),
            totalIntel: Intel(Decimal.one),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentRegistryProvider.overrideWith((_) async => content),
              gameWorldProvider.overrideWith((_) => notifier),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  ref.watch(gameWorldProvider);
                  ref.listen<Intel>(totalIntelProvider, (previous, next) {
                    intelNotifications++;
                  });
                  return Scaffold(
                    body: Column(
                      children: [
                        TextButton(
                          key: const Key('influenceOnly'),
                          onPressed: () {
                            notifier.setTestState(
                              GameState(
                                totalInfluence: Influence(Decimal.parse('500')),
                                totalIntel: Intel(Decimal.one),
                              ),
                            );
                          },
                          child: const Text('influenceOnly'),
                        ),
                        TextButton(
                          key: const Key('intel'),
                          onPressed: () {
                            notifier.setTestState(
                              GameState(
                                totalInfluence: Influence(Decimal.parse('500')),
                                totalIntel: Intel(Decimal.parse('3')),
                              ),
                            );
                          },
                          child: const Text('intel'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final baseline = intelNotifications;

        await tester.tap(find.byKey(const Key('influenceOnly')));
        await tester.pump();
        expect(intelNotifications, baseline);

        await tester.tap(find.byKey(const Key('intel')));
        await tester.pump();
        expect(intelNotifications, baseline + 1);
      },
    );

    testWidgets('totalInfluenceProvider can be overridden in widget tests', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            totalInfluenceProvider.overrideWithValue(
              Influence(Decimal.parse('777')),
            ),
            totalIntelProvider.overrideWithValue(Intel(Decimal.parse('2'))),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final inf = ref.watch(totalInfluenceProvider);
                return Scaffold(body: Text(inf.format()));
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('777'), findsOneWidget);
    });
  });
}
