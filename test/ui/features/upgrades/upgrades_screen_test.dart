import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/ui/features/continents/continent_progress_bar.dart';
import 'package:global_domination/ui/features/upgrades/upgrades_screen.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

import '../../../helpers/achievements_fixture.dart';
import '../../../helpers/daily_rewards_test_json.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

ContentRegistry _twoContinent() {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
    {
      'id': 'europe',
      'name': 'Europe',
      'unlockThreshold': '1000',
      'completionBonus': '0.50',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': 'egypt',
      'continent': 'africa',
      'baseInfluence': '1',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'nigeria',
      'continent': 'africa',
      'baseInfluence': '5',
      'unlockCost': '10',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '2',
      'unlockCost': '20',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: '[]',
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

CountryState _unlocked(String id, {int ipLevel = 1}) => CountryState(
  id: CountryId(id),
  unlocked: true,
  ipLevel: ipLevel,
  leaderTier: LeaderTier.none,
  bankedInfluence: Influence.zero,
);

CountryState _locked(String id) => CountryState(
  id: CountryId(id),
  unlocked: false,
  ipLevel: 0,
  leaderTier: LeaderTier.none,
  bankedInfluence: Influence.zero,
);

// ---------------------------------------------------------------------------
// Spy notifier for command dispatch assertions
// ---------------------------------------------------------------------------

class _SpyNotifier extends GameWorldNotifier {
  final List<GameCommand> dispatched = [];

  _SpyNotifier({
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

  @override
  void apply(GameCommand cmd) {
    dispatched.add(cmd);
    super.apply(cmd);
  }
}

Widget _pump({
  required ContentRegistry content,
  required GameState state,
  _SpyNotifier? spy,
}) {
  final notifier = spy ?? _SpyNotifier(content: content, initialState: state);
  return ProviderScope(
    overrides: [
      contentRegistryProvider.overrideWith((_) async => content),
      gameWorldProvider.overrideWith((_) => notifier),
    ],
    child: MaterialApp(
      theme: appTheme(),
      home: const Scaffold(body: UpgradesScreen()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UpgradesScreen rendering', () {
    testWidgets('shows continent header and country card', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('1000')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('Africa'), findsOneWidget);
      expect(find.text('Egypt'), findsOneWidget);
    });

    testWidgets('locked continent section is not shown', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('1000')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('Europe'), findsNothing);
    });

    testWidgets('teaser card shows for next unlockable country', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('1000')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('Nigeria'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
    });

    testWidgets('empty state when no continents unlocked', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _locked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: const {},
        totalInfluence: Influence.zero,
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('No continents unlocked yet.'), findsOneWidget);
    });
  });

  group('Buy button', () {
    testWidgets('Buy dispatches PurchaseUpgrade with selected bulk', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 1),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('99999')),
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      await tester.tap(find.text('Buy'));
      await tester.pump();

      expect(spy.dispatched, hasLength(1));
      final cmd = spy.dispatched.first as PurchaseUpgrade;
      expect(cmd.countryId, const CountryId('egypt'));
      expect(cmd.bulk, 1); // default bulk
    });

    testWidgets('Buy dispatches with bulk 10 after selecting 10', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 1),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('99999')),
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      // Tap segment '10' inside the SegmentedButton
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<int>).first,
          matching: find.text('10'),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Buy'));
      await tester.pump();

      expect(spy.dispatched, hasLength(1));
      final cmd = spy.dispatched.first as PurchaseUpgrade;
      expect(cmd.bulk, 10);
    });

    testWidgets('Buy semantics identifies country and selected bulk', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 1),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('99999')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Buy 1 Egypt upgrade',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<int>).first,
          matching: find.text('10'),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Buy 10 Egypt upgrades',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Buy disabled when cannot afford', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 1),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      await tester.tap(find.text('Buy'));
      await tester.pump();

      expect(spy.dispatched, isEmpty);
    });

    testWidgets('max level card shows MAX badge, no Buy button', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: BalanceConfig.maxIpLevel,
          ),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('99999')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('MAX'), findsOneWidget);
      expect(find.text('Buy'), findsNothing);
    });
  });

  group('Unlock button', () {
    testWidgets('Unlock dispatches UnlockCountry when affordable', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('1000')),
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      await tester.tap(find.text('Unlock'));
      await tester.pump();

      expect(spy.dispatched, hasLength(1));
      expect(spy.dispatched.first, isA<UnlockCountry>());
      final cmd = spy.dispatched.first as UnlockCountry;
      expect(cmd.countryId, const CountryId('nigeria'));
    });

    testWidgets('Unlock disabled when cannot afford', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      await tester.tap(find.text('Unlock'));
      await tester.pump();

      expect(spy.dispatched, isEmpty);
    });
  });

  group('Bulk isolation', () {
    testWidgets('changing bulk on one card does not affect another', (
      tester,
    ) async {
      final content = _twoContinent();
      // Both egypt and nigeria unlocked so we have two cards
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 1),
          CountryId('nigeria'): _unlocked('nigeria', ipLevel: 1),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('99999')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      // There should be two SegmentedButton widgets (one per unlocked country)
      final segmentedButtons = tester
          .widgetList<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .toList();
      expect(segmentedButtons, hasLength(2));

      // Both start with bulk=1 selected
      expect(segmentedButtons[0].selected, {1});
      expect(segmentedButtons[1].selected, {1});

      // Tap '10' on the first card
      final firstTen = find.text('10').first;
      await tester.tap(firstTen);
      await tester.pump();

      // First card is now 10, second still 1
      final afterButtons = tester
          .widgetList<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .toList();
      expect(afterButtons[0].selected, {10});
      expect(afterButtons[1].selected, {1});
    });
  });

  group('Responsive / overflow', () {
    testWidgets('narrow width does not throw overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 1),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('99999')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('large numbers render without overflow', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 100),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('1e38')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Continent progress header', () {
    testWidgets('shows X / Y owned badge in continent header', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('100')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      // Egypt is unlocked (1 owned), Nigeria is locked — total Africa = 2.
      expect(find.text('1 / 2 owned'), findsOneWidget);
    });

    testWidgets('mounts ContinentProgressBar under the Africa header', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('100')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.byType(ContinentProgressBar), findsOneWidget);
    });

    testWidgets('ContinentProgressBar reflects reachedMilestones from state', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        reachedMilestones: {
          const ContinentId('africa'): {25},
        },
        totalInfluence: Influence(Decimal.parse('100')),
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      final bar = tester.widget<ContinentProgressBar>(
        find.byType(ContinentProgressBar),
      );
      expect(bar.reachedMilestoneTiers, contains(25));
    });
  });

  group('World complete state', () {
    testWidgets('world complete teaser shown when all countries unlocked', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _unlocked('nigeria'),
          CountryId('france'): _unlocked('france'),
        },
        unlockedContinents: {
          ContinentId('africa'): true,
          ContinentId('europe'): true,
        },
        totalInfluence: Influence(Decimal.parse('99999')),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('World domination complete!'), findsWidgets);
    });
  });
}
