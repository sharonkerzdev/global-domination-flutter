import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
import 'package:global_domination/ui/features/leaders/leaders_screen.dart';
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

CountryState _unlocked(
  String id, {
  int ipLevel = 1,
  LeaderTier tier = LeaderTier.none,
}) => CountryState(
  id: CountryId(id),
  unlocked: true,
  ipLevel: ipLevel,
  leaderTier: tier,
  bankedInfluence: Influence.zero,
);

CountryState _locked(String id) => CountryState(
  id: CountryId(id),
  unlocked: false,
  ipLevel: 0,
  leaderTier: LeaderTier.none,
  bankedInfluence: Influence.zero,
);

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
      home: const Scaffold(body: LeadersScreen()),
    ),
  );
}

Influence _inf(String v) => Influence(Decimal.parse(v));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Rendering', () {
    testWidgets('shows continent header + hired counter', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('Africa'), findsOneWidget);
      expect(find.text('0 / 1 Leaders hired'), findsOneWidget);
    });

    testWidgets('locked continent not shown', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('100'),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('Europe'), findsNothing);
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

    testWidgets('empty section shows informational text', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _locked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('0 / 0 Leaders hired'), findsOneWidget);
      expect(find.text('No countries unlocked here yet.'), findsOneWidget);
    });
  });

  group('Expansion', () {
    testWidgets('initiallyExpanded: rows visible; tap header collapses', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      // Initially expanded: Egypt row visible
      expect(find.text('Egypt'), findsOneWidget);

      await tester.tap(find.text('Africa'));
      await tester.pumpAndSettle();
      expect(find.text('Egypt'), findsNothing);

      await tester.tap(find.text('Africa'));
      await tester.pumpAndSettle();
      expect(find.text('Egypt'), findsOneWidget);
    });
  });

  group('Hire action', () {
    testWidgets('Hire dispatches HireLeader when affordable', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      final btn = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label ?? '').startsWith('Hire leader for Egypt'),
      );
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump();

      expect(spy.dispatched, hasLength(1));
      expect(spy.dispatched.first, isA<HireLeader>());
      expect(
        (spy.dispatched.first as HireLeader).countryId,
        const CountryId('egypt'),
      );
    });

    testWidgets('Hire disabled when unaffordable: tap is a no-op', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      final btn = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label ?? '').startsWith('Hire leader for Egypt'),
      );
      await tester.tap(btn, warnIfMissed: false);
      await tester.pump();

      expect(spy.dispatched, isEmpty);
    });

    testWidgets('Reach IP 10 first: button disabled, no dispatch', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 5),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      expect(find.text('Reach IP 10 first'), findsOneWidget);
      await tester.tap(find.text('Reach IP 10 first'), warnIfMissed: false);
      await tester.pump();
      expect(spy.dispatched, isEmpty);
    });
  });

  group('Upgrade action', () {
    testWidgets('Upgrade to Tier 2 dispatches UpgradeLeader', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: 20,
            tier: LeaderTier.tier1,
          ),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      final btn = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Upgrade Egypt leader to tier 2',
      );
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump();

      expect(spy.dispatched, hasLength(1));
      expect(spy.dispatched.first, isA<UpgradeLeader>());
      expect(
        (spy.dispatched.first as UpgradeLeader).countryId,
        const CountryId('egypt'),
      );
    });

    testWidgets('Upgrade to Tier 3 dispatches UpgradeLeader', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: 20,
            tier: LeaderTier.tier2,
          ),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      final btn = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Upgrade Egypt leader to tier 3',
      );
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump();

      expect(spy.dispatched, hasLength(1));
      expect(spy.dispatched.first, isA<UpgradeLeader>());
    });

    testWidgets('Max tier reached: disabled, no dispatch', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: 20,
            tier: LeaderTier.tier3,
          ),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final spy = _SpyNotifier(content: content, initialState: state);
      await tester.pumpWidget(_pump(content: content, state: state, spy: spy));
      await tester.pump();

      expect(find.text('Max tier reached'), findsOneWidget);
      await tester.tap(find.text('Max tier reached'), warnIfMissed: false);
      await tester.pump();
      expect(spy.dispatched, isEmpty);
    });
  });

  group('Approaching threshold visual hint', () {
    testWidgets('approaching at IP 9 + none: row has approaching key', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 9),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(
        find.byKey(const Key('leaders.row.egypt.approaching')),
        findsOneWidget,
      );
    });

    testWidgets('not approaching at IP 10 + none', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(
        find.byKey(const Key('leaders.row.egypt.approaching')),
        findsNothing,
      );
      expect(find.byKey(const Key('leaders.row.egypt')), findsOneWidget);
    });
  });

  group('Affordable highlight', () {
    testWidgets('affordable hire shows affordable dot on header', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.byKey(const Key('leaders.affordable_dot')), findsOneWidget);
    });

    testWidgets('no affordable highlight when nothing affordable', (
      tester,
    ) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.byKey(const Key('leaders.affordable_dot')), findsNothing);
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
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('very large costs do not overflow', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('1e38'),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('larger text scale does not overflow', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith(
              (_) => _SpyNotifier(content: content, initialState: state),
            ),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: const Scaffold(body: LeadersScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('All tier3', () {
    testWidgets('every row shows Max tier reached', (tester) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: 20,
            tier: LeaderTier.tier3,
          ),
          CountryId('nigeria'): _unlocked(
            'nigeria',
            ipLevel: 20,
            tier: LeaderTier.tier3,
          ),
          CountryId('france'): _unlocked(
            'france',
            ipLevel: 20,
            tier: LeaderTier.tier3,
          ),
        },
        unlockedContinents: {
          ContinentId('africa'): true,
          ContinentId('europe'): true,
        },
        totalInfluence: _inf('1e30'),
      );
      await tester.pumpWidget(_pump(content: content, state: state));
      await tester.pump();

      expect(find.text('Max tier reached'), findsNWidgets(3));
      expect(find.text('2 / 2 Leaders hired'), findsOneWidget); // Africa
      expect(find.text('1 / 1 Leaders hired'), findsOneWidget); // Europe
      expect(find.byKey(const Key('leaders.affordable_dot')), findsNothing);
    });
  });
}
