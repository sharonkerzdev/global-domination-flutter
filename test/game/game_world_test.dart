import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

import '../helpers/achievements_fixture.dart';
import '../helpers/daily_rewards_test_json.dart';
import '../helpers/fake_clock.dart';

/// Manual [GameState] fixtures using African content must mirror
/// [GameState.initialSeed]: threshold-0 continents belong in [unlockedContinents].
final Map<ContinentId, bool> _seedAfricaUnlocked = {
  const ContinentId('africa'): true,
};

ContentRegistry _buildSingleCountryContent() {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
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
  ]);
  final leaders = jsonEncode([
    {
      'id': 'default_leader',
      'name': 'General',
      'tierMultipliers': ['1.0', '1.5', '2.0', '3.0'],
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: leaders,
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

ContentRegistry _buildEuropeUnlockMissionContent() {
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
      'unlockThreshold': '10',
      'completionBonus': '0.25',
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
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '1',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  final leaders = jsonEncode([
    {
      'id': 'default_leader',
      'name': 'General',
      'tierMultipliers': ['1.0', '1.5', '2.0', '3.0'],
    },
  ]);
  final missions = jsonEncode([
    {
      'id': 'unlock_one_continent',
      'name': 'Unlock continent',
      'conditionType': 'unlock_continents_n',
      'conditionParams': {'count': 1},
      'rewardIntel': '5',
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: leaders,
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: missions,
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

/// Europe at influence threshold 1; day-1 daily reward (fixture) is enough to unlock.
ContentRegistry _buildEuropeThresholdOneContent() {
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
      'unlockThreshold': '1',
      'completionBonus': '0.25',
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
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '1',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  final leaders = jsonEncode([
    {
      'id': 'default_leader',
      'name': 'General',
      'tierMultipliers': ['1.0', '1.5', '2.0', '3.0'],
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: leaders,
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

ContentRegistry _buildMissionOneTapContent() {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
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
  ]);
  final leaders = jsonEncode([
    {
      'id': 'default_leader',
      'name': 'General',
      'tierMultipliers': ['1.0', '1.5', '2.0', '3.0'],
    },
  ]);
  final missions = jsonEncode([
    {
      'id': 'one_tap',
      'name': 'One tap',
      'conditionType': 'tap_countries_n',
      'conditionParams': {'count': 1},
      'rewardIntel': '3',
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: leaders,
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: missions,
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

ContentRegistry _buildThreeCountryContent() {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
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
      'unlockCost': '5',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'south_africa',
      'continent': 'africa',
      'baseInfluence': '15',
      'unlockCost': '25',
      'tier': 1,
      'generationSeconds': 2,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: jsonEncode([]),
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

ContentRegistry _buildAfricaEuropeStory42Content() {
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
      'unlockThreshold': '100',
      'completionBonus': '0.25',
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
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '1',
      'unlockCost': '10',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: jsonEncode([]),
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

ContentRegistry _buildThreeContinentStory42Content() {
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
      'unlockThreshold': '10',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
    {
      'id': 'asia',
      'name': 'Asia',
      'unlockThreshold': '20',
      'completionBonus': '0.25',
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
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '1',
      'unlockCost': '10',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'china',
      'continent': 'asia',
      'baseInfluence': '1',
      'unlockCost': '10',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: jsonEncode([]),
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

ContentRegistry _buildEuropeUnlockSpendEdgeContent() {
  final continents = jsonEncode([
    {
      'id': 'europe',
      'name': 'Europe',
      'unlockThreshold': '10',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '1',
      'unlockCost': '10',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: jsonEncode([]),
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

ContentRegistry _buildFourCountryAfricaMilestoneContent() {
  final milestones = [
    {'percent': 25, 'rewardType': 'influence', 'rewardValue': '5'},
    {'percent': 50, 'rewardType': 'influence', 'rewardValue': '6'},
    {'percent': 75, 'rewardType': 'influence', 'rewardValue': '7'},
    {'percent': 100, 'rewardType': 'influence', 'rewardValue': '8'},
  ];
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': milestones,
    },
  ]);
  final countries = jsonEncode([
    for (var i = 0; i < 4; i++)
      {
        'id': 'c$i',
        'continent': 'africa',
        'baseInfluence': '1',
        'unlockCost': '0',
        'tier': 1,
        'generationSeconds': 1,
      },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: jsonEncode([]),
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

ContentRegistry _buildThreeCountryAfricaMilestoneContent() {
  final milestones = [
    {'percent': 25, 'rewardType': 'influence', 'rewardValue': '5'},
    {'percent': 50, 'rewardType': 'influence', 'rewardValue': '6'},
    {'percent': 75, 'rewardType': 'influence', 'rewardValue': '7'},
    {'percent': 100, 'rewardType': 'influence', 'rewardValue': '8'},
  ];
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': milestones,
    },
  ]);
  final countries = jsonEncode([
    for (var i = 0; i < 3; i++)
      {
        'id': 'c$i',
        'continent': 'africa',
        'baseInfluence': '1',
        'unlockCost': '0',
        'tier': 1,
        'generationSeconds': 1,
      },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: jsonEncode([]),
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

ContentRegistry _buildThreeCountryAfricaMilestoneAchievementContent() {
  final milestones = [
    {'percent': 25, 'rewardType': 'influence', 'rewardValue': '5'},
    {'percent': 50, 'rewardType': 'influence', 'rewardValue': '6'},
    {'percent': 75, 'rewardType': 'influence', 'rewardValue': '7'},
    {'percent': 100, 'rewardType': 'influence', 'rewardValue': '8'},
  ];
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': milestones,
    },
  ]);
  final countries = jsonEncode([
    for (var i = 0; i < 3; i++)
      {
        'id': 'c$i',
        'continent': 'africa',
        'baseInfluence': '1',
        'unlockCost': '0',
        'tier': 1,
        'generationSeconds': 1,
      },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: jsonEncode([]),
    achievementsJson: achievementsJson27([
      {
        'id': 'ach_gw_africa_done',
        'name': 'GW Africa',
        'conditionType': 'continentCompleted',
        'conditionParams': {'continentId': 'africa'},
        'rewardType': 'influenceMultiplier',
        'rewardValue': '0.11',
      },
    ]),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

void main() {
  late FakeClock clock;
  late ContentRegistry content;
  late GameWorld world;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 1, 1));
    content = _buildSingleCountryContent();
    world = GameWorld(content: content, clock: clock, rng: SeededRng(0));
  });

  tearDown(() {
    world.dispose();
  });

  GameState stateWithUnlockedEgypt() {
    final egypt = CountryState(
      id: CountryId('egypt'),
      unlocked: true,
      ipLevel: 0,
      leaderTier: LeaderTier.none,
      bankedInfluence: Influence.zero,
    );
    return GameState(
      countries: {CountryId('egypt'): egypt},
      totalInfluence: Influence.zero,
      unlockedContinents: _seedAfricaUnlocked,
    );
  }

  group('GameWorld construction', () {
    test('constructs without error', () {
      expect(world, isNotNull);
    });

    test('state returns a GameState after construction', () {
      expect(world.state, isA<GameState>());
    });

    test('initial state has countries map built from ContentRegistry', () {
      expect(world.state.countries, hasLength(1));
      expect(world.state.countries[CountryId('egypt')], isNotNull);
    });

    test(
      'seed country Egypt is unlocked with ipLevel=1 and zero banked influence',
      () {
        final egypt = world.state.countries[CountryId('egypt')]!;
        expect(egypt.unlocked, isTrue);
        expect(egypt.ipLevel, equals(1));
        expect(egypt.leaderTier, equals(LeaderTier.none));
        expect(egypt.bankedInfluence, equals(Influence.zero));
      },
    );

    test('initial totalInfluence is zero', () {
      expect(world.state.totalInfluence, equals(Influence.zero));
    });

    test('accepts optional initialState overriding defaults', () {
      final seeded = stateWithUnlockedEgypt();
      final w = GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
        initialState: seeded,
      );
      expect(w.state.countries[CountryId('egypt')]!.unlocked, isTrue);
      w.dispose();
    });
  });

  group('GameWorld.tick', () {
    late GameWorld allLockedWorld;

    setUp(() {
      // Build a world with all countries locked (bypasses the seed)
      final allLocked = GameState(
        countries: {
          CountryId('egypt'): CountryState(
            id: CountryId('egypt'),
            unlocked: false,
            ipLevel: 0,
            leaderTier: LeaderTier.none,
            bankedInfluence: Influence.zero,
          ),
        },
        totalInfluence: Influence.zero,
        unlockedContinents: _seedAfricaUnlocked,
      );
      allLockedWorld = GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
        initialState: allLocked,
      );
    });

    tearDown(() {
      allLockedWorld.dispose();
    });

    test('tick(Duration.zero) does not throw and state is unchanged', () {
      final stateBefore = world.state;
      world.tick(Duration.zero);
      expect(world.state, equals(stateBefore));
    });

    test('tick(Duration(milliseconds: 16)) does not throw', () {
      expect(
        () => world.tick(const Duration(milliseconds: 16)),
        returnsNormally,
      );
    });

    test('tick with no unlocked countries emits no event', () async {
      final events = <Object>[];
      final sub = allLockedWorld.events.listen(events.add);
      allLockedWorld.tick(const Duration(milliseconds: 16));
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
    });

    test('tick with no unlocked countries does not change state', () {
      final stateBefore = allLockedWorld.state;
      allLockedWorld.tick(const Duration(milliseconds: 100));
      expect(allLockedWorld.state, equals(stateBefore));
    });

    test('tick asserts on negative Duration in debug mode', () {
      expect(
        () => world.tick(const Duration(milliseconds: -1)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('tick with unlocked country accumulates bankedInfluence', () {
      final w = GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
        initialState: stateWithUnlockedEgypt(),
      );
      // 10 × 100ms = 1 second (each tick within the 100ms clamp)
      for (var i = 0; i < 10; i++) {
        w.tick(const Duration(milliseconds: 100));
      }

      expect(
        w.state.countries[CountryId('egypt')]!.bankedInfluence.value,
        equals(Decimal.one),
      );
      w.dispose();
    });

    test('tick with unlocked country emits Tick event', () async {
      final w = GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
        initialState: stateWithUnlockedEgypt(),
      );
      final events = <Object>[];
      final sub = w.events.listen(events.add);

      w.tick(const Duration(milliseconds: 100));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      await sub.cancel();
      w.dispose();
    });

    test('tick with unlocked country updates state', () {
      final w = GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
        initialState: stateWithUnlockedEgypt(),
      );
      w.tick(const Duration(milliseconds: 100));

      expect(
        w.state.countries[CountryId('egypt')]!.bankedInfluence > Influence.zero,
        isTrue,
      );
      w.dispose();
    });

    test('tick emits no event on second tick if nothing changed', () async {
      // With all-locked countries, no events should fire
      final events = <Object>[];
      final sub = allLockedWorld.events.listen(events.add);
      allLockedWorld.tick(const Duration(milliseconds: 100));
      allLockedWorld.tick(const Duration(milliseconds: 100));
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
    });
  });

  group('GameState equality', () {
    test('two default GameStates are equal', () {
      expect(GameState(), equals(GameState()));
    });

    test('GameState with same countries map is equal', () {
      final cs = CountryState(
        id: CountryId('egypt'),
        unlocked: false,
        ipLevel: 0,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      );
      final s1 = GameState(
        countries: {CountryId('egypt'): cs},
        totalInfluence: Influence.zero,
        unlockedContinents: _seedAfricaUnlocked,
      );
      final s2 = GameState(
        countries: {CountryId('egypt'): cs},
        totalInfluence: Influence.zero,
        unlockedContinents: _seedAfricaUnlocked,
      );
      expect(s1, equals(s2));
    });

    test('GameState differs when bankedInfluence differs', () {
      final cs1 = CountryState(
        id: CountryId('egypt'),
        unlocked: true,
        ipLevel: 0,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      );
      final cs2 = cs1.copyWith(bankedInfluence: Influence(Decimal.one));
      final s1 = GameState(countries: {CountryId('egypt'): cs1});
      final s2 = GameState(countries: {CountryId('egypt'): cs2});
      expect(s1, isNot(equals(s2)));
    });
  });

  group('GameWorld.applyCommand', () {
    test('applyCommand(Noop()) returns Result.success(null)', () {
      final result = world.applyCommand(const Noop());
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.errorOrNull, isNull);
    });

    test('applyCommand(Noop()) emits no event on the events stream', () async {
      final events = <Object>[];
      final sub = world.events.listen(events.add);
      world.applyCommand(const Noop());
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
    });

    test(
      'applyCommand(Noop()) does not backfill stale continent unlock state',
      () {
        final c = _buildAfricaEuropeStory42Content();
        final initial = GameState.initialSeed(c).copyWith(
          totalInfluence: Influence(Decimal.fromInt(1000)),
          unlockedContinents: const <ContinentId, bool>{},
        );
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        final before = w.state;

        final result = w.applyCommand(const Noop());

        expect(result.isSuccess, isTrue);
        expect(w.state, equals(before));
        w.dispose();
      },
    );

    test('applyCommand(TapCountry) on locked country returns failure', () {
      final allLocked = GameState(
        countries: {
          CountryId('egypt'): CountryState(
            id: CountryId('egypt'),
            unlocked: false,
            ipLevel: 0,
            leaderTier: LeaderTier.none,
            bankedInfluence: Influence.zero,
          ),
        },
        totalInfluence: Influence.zero,
        unlockedContinents: _seedAfricaUnlocked,
      );
      final w = GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
        initialState: allLocked,
      );
      final result = w.applyCommand(
        const TapCountry(countryId: CountryId('egypt')),
      );
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<Locked>());
      w.dispose();
    });

    test('applyCommand(TapCountry) on locked country emits no event', () async {
      final allLocked = GameState(
        countries: {
          CountryId('egypt'): CountryState(
            id: CountryId('egypt'),
            unlocked: false,
            ipLevel: 0,
            leaderTier: LeaderTier.none,
            bankedInfluence: Influence.zero,
          ),
        },
        totalInfluence: Influence.zero,
        unlockedContinents: _seedAfricaUnlocked,
      );
      final w = GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
        initialState: allLocked,
      );
      final events = <Object>[];
      final sub = w.events.listen(events.add);
      w.applyCommand(const TapCountry(countryId: CountryId('egypt')));
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
      w.dispose();
    });

    test(
      'applyCommand(PurchaseUpgrade) updates state and emits UpgradePurchased',
      () async {
        final egypt = CountryState(
          id: CountryId('egypt'),
          unlocked: true,
          ipLevel: 1,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
          lastCollectedAt: null,
        );
        final def = content.countries[const CountryId('egypt')]!;
        final cost = IncomeCalculator.upgradeCost(def, 1, 1);
        final s = GameState(
          countries: {CountryId('egypt'): egypt},
          totalInfluence: cost,
          unlockedContinents: _seedAfricaUnlocked,
        );
        final w = GameWorld(
          content: content,
          clock: clock,
          rng: SeededRng(0),
          initialState: s,
        );
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        final r = w.applyCommand(
          const PurchaseUpgrade(countryId: CountryId('egypt'), bulk: 1),
        );
        expect(r.isSuccess, isTrue);
        expect(w.state.countries[CountryId('egypt')]!.ipLevel, equals(2));
        expect(w.state.totalInfluence, equals(Influence.zero));
        await Future<void>.delayed(Duration.zero);
        expect(events, isA<List<GameEvent>>());
        expect(events, hasLength(1));
        expect(events.first, isA<UpgradePurchased>());
        await sub.cancel();
        w.dispose();
      },
    );

    test(
      'applyCommand(HireLeader) updates leader tier and emits LeaderHired',
      () async {
        final cDef = content.countries[const CountryId('egypt')]!;
        final hireCost = IncomeCalculator.leaderHireCost(cDef);
        final egypt = CountryState(
          id: CountryId('egypt'),
          unlocked: true,
          ipLevel: 10,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
          lastCollectedAt: null,
        );
        final s = GameState(
          countries: {CountryId('egypt'): egypt},
          totalInfluence: hireCost,
          unlockedContinents: _seedAfricaUnlocked,
        );
        final w = GameWorld(
          content: content,
          clock: clock,
          rng: SeededRng(0),
          initialState: s,
        );
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        final r = w.applyCommand(
          const HireLeader(countryId: CountryId('egypt')),
        );
        expect(r.isSuccess, isTrue);
        expect(
          w.state.countries[CountryId('egypt')]!.leaderTier,
          LeaderTier.tier1,
        );
        expect(w.state.totalInfluence, Influence.zero);
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events.first, isA<LeaderHired>());
        final h = events.first as LeaderHired;
        expect(h.cost, equals(hireCost));
        await sub.cancel();
        w.dispose();
      },
    );

    test(
      'applyCommand(UpgradeLeader) updates tier and emits LeaderUpgraded',
      () async {
        final cDef = content.countries[const CountryId('egypt')]!;
        final upgradeCost = IncomeCalculator.leaderUpgradeCost(
          cDef,
          LeaderTier.tier1,
        );
        final egypt = CountryState(
          id: CountryId('egypt'),
          unlocked: true,
          ipLevel: 10,
          leaderTier: LeaderTier.tier1,
          bankedInfluence: Influence.zero,
          lastCollectedAt: null,
        );
        final s = GameState(
          countries: {CountryId('egypt'): egypt},
          totalInfluence: upgradeCost,
          unlockedContinents: _seedAfricaUnlocked,
        );
        final w = GameWorld(
          content: content,
          clock: clock,
          rng: SeededRng(0),
          initialState: s,
        );
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        final r = w.applyCommand(
          const UpgradeLeader(countryId: CountryId('egypt')),
        );
        expect(r.isSuccess, isTrue);
        expect(
          w.state.countries[CountryId('egypt')]!.leaderTier,
          LeaderTier.tier2,
        );
        expect(w.state.totalInfluence, Influence.zero);
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events.first, isA<LeaderUpgraded>());
        final ev = events.first as LeaderUpgraded;
        expect(ev.newTier, LeaderTier.tier2);
        expect(ev.cost, equals(upgradeCost));
        await sub.cancel();
        w.dispose();
      },
    );

    test(
      'applyCommand(UnlockCountry) unlocks nigeria and emits CountryUnlocked',
      () async {
        final three = _buildThreeCountryContent();
        final initial = GameState.initialSeed(
          three,
        ).copyWith(totalInfluence: Influence(Decimal.fromInt(5)));
        final w = GameWorld(
          content: three,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        final r = w.applyCommand(
          const UnlockCountry(countryId: CountryId('nigeria')),
        );
        expect(r.isSuccess, isTrue);
        final n = w.state.countries[const CountryId('nigeria')]!;
        expect(n.unlocked, isTrue);
        expect(n.ipLevel, equals(1));
        expect(n.bankedInfluence, equals(Influence.zero));
        expect(w.state.totalInfluence, equals(Influence.zero));
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events.first, isA<CountryUnlocked>());
        final cu = events.first as CountryUnlocked;
        expect(cu.cost, equals(Influence(Decimal.fromInt(5))));
        expect(cu.continent, const ContinentId('africa'));
        await sub.cancel();
        w.dispose();
      },
    );

    test(
      'applyCommand(UnlockCountry) then tick accrues bankedInfluence on nigeria (Story 4.1 AC #8)',
      () {
        final three = _buildThreeCountryContent();
        final initial = GameState.initialSeed(
          three,
        ).copyWith(totalInfluence: Influence(Decimal.fromInt(5)));
        final w = GameWorld(
          content: three,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        w.applyCommand(const UnlockCountry(countryId: CountryId('nigeria')));
        for (var i = 0; i < 10; i++) {
          w.tick(const Duration(milliseconds: 100));
        }
        final banked =
            w.state.countries[const CountryId('nigeria')]!.bankedInfluence;
        expect(banked > Influence.zero, isTrue);
        w.dispose();
      },
    );

    test(
      'applyCommand(UnlockCountry) reconciles stale continent unlock before spending influence',
      () async {
        final c = _buildEuropeUnlockSpendEdgeContent();
        final france = c.countries[const CountryId('france')]!;
        final initial = GameState(
          countries: {
            const CountryId('france'): CountryState(
              id: const CountryId('france'),
              unlocked: false,
              ipLevel: 0,
              leaderTier: LeaderTier.none,
              bankedInfluence: Influence.zero,
            ),
          },
          totalInfluence: Influence(france.unlockCost),
          unlockedContinents: const <ContinentId, bool>{},
        );
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);

        final result = w.applyCommand(
          const UnlockCountry(countryId: CountryId('france')),
        );
        await Future<void>.delayed(Duration.zero);

        expect(result.isSuccess, isTrue);
        expect(w.state.unlockedContinents[const ContinentId('europe')], isTrue);
        expect(w.state.totalInfluence, equals(Influence.zero));
        expect(events, hasLength(2));
        expect(events[0], isA<ContinentUnlocked>());
        expect(events[1], isA<CountryUnlocked>());

        await sub.cancel();
        w.dispose();
      },
    );
  });

  group('GameWorld.applyCommand TapCountry collect flow (Story 2.6)', () {
    GameWorld worldWithUnlockedEgypt({Influence? banked}) {
      final egypt = CountryState(
        id: CountryId('egypt'),
        unlocked: true,
        ipLevel: 0,
        leaderTier: LeaderTier.none,
        bankedInfluence: banked ?? Influence(Decimal.parse('10')),
      );
      final state = GameState(
        countries: {CountryId('egypt'): egypt},
        totalInfluence: Influence.zero,
        unlockedContinents: _seedAfricaUnlocked,
      );
      return GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
        initialState: state,
      );
    }

    test(
      '5.1: tick accumulates → applyCommand(TapCountry) → totalInfluence correct, banked reset',
      () {
        final w = worldWithUnlockedEgypt(banked: Influence(Decimal.parse('5')));
        final result = w.applyCommand(
          const TapCountry(countryId: CountryId('egypt')),
        );
        expect(result.isSuccess, isTrue);
        expect(w.state.totalInfluence, equals(Influence(Decimal.parse('5'))));
        expect(
          w.state.countries[CountryId('egypt')]!.bankedInfluence,
          equals(Influence.zero),
        );
        w.dispose();
      },
    );

    test(
      '5.2: event stream emits CountryTapped with correct collected amount',
      () async {
        final banked = Influence(Decimal.parse('7'));
        final w = worldWithUnlockedEgypt(banked: banked);
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);

        w.applyCommand(const TapCountry(countryId: CountryId('egypt')));
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<CountryTapped>());
        final tap = events.first as CountryTapped;
        expect(tap.countryId, equals(CountryId('egypt')));
        expect(tap.collected, equals(banked));

        await sub.cancel();
        w.dispose();
      },
    );

    test('5.3: zero-banked tap → no event on stream', () async {
      final w = worldWithUnlockedEgypt(banked: Influence.zero);
      final events = <GameEvent>[];
      final sub = w.events.listen(events.add);

      w.applyCommand(const TapCountry(countryId: CountryId('egypt')));
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);

      await sub.cancel();
      w.dispose();
    });

    test(
      '5.4: sequential collects — tick, collect, tick again, collect again — totals accumulate correctly',
      () {
        final w = GameWorld(
          content: content,
          clock: clock,
          rng: SeededRng(0),
          initialState: stateWithUnlockedEgypt(),
        );

        // Tick 10× (1s) → egypt banks ~1.0 influence
        for (var i = 0; i < 10; i++) {
          w.tick(const Duration(milliseconds: 100));
        }
        expect(
          w.state.countries[CountryId('egypt')]!.bankedInfluence.value,
          equals(Decimal.one),
        );

        // First collect
        w.applyCommand(const TapCountry(countryId: CountryId('egypt')));
        expect(w.state.totalInfluence.value, equals(Decimal.one));
        expect(
          w.state.countries[CountryId('egypt')]!.bankedInfluence,
          equals(Influence.zero),
        );

        // Tick another 10× → banks another 1.0
        for (var i = 0; i < 10; i++) {
          w.tick(const Duration(milliseconds: 100));
        }

        // Second collect
        w.applyCommand(const TapCountry(countryId: CountryId('egypt')));
        expect(w.state.totalInfluence.value, equals(Decimal.parse('2')));
        expect(
          w.state.countries[CountryId('egypt')]!.bankedInfluence,
          equals(Influence.zero),
        );

        w.dispose();
      },
    );
  });

  group('GameWorld seed integration (Story 2.7)', () {
    late ContentRegistry threeCountryContent;

    setUp(() {
      threeCountryContent = _buildThreeCountryContent();
    });

    test('5.1: fresh GameWorld has Egypt unlocked from seed', () {
      final w = GameWorld(
        content: threeCountryContent,
        clock: clock,
        rng: SeededRng(0),
      );
      expect(w.state.countries[const CountryId('egypt')]!.unlocked, isTrue);
      w.dispose();
    });

    test(
      '5.2: tick for 1 second → Egypt bankedInfluence matches IP multiplier (seed ipLevel=1)',
      () {
        final w = GameWorld(
          content: threeCountryContent,
          clock: clock,
          rng: SeededRng(0),
        );
        // 10 × 100ms = 1 second; base 1 × (1 + 1×0.1) = 1.1 / s
        for (var i = 0; i < 10; i++) {
          w.tick(const Duration(milliseconds: 100));
        }
        expect(
          w.state.countries[const CountryId('egypt')]!.bankedInfluence.value,
          equals(Decimal.parse('1.1')),
        );
        w.dispose();
      },
    );

    test(
      'Story 3.1: tick 1s with ipLevel=10 → banked = base × (1 + 10×0.1)',
      () {
        final egypt = CountryState(
          id: const CountryId('egypt'),
          unlocked: true,
          ipLevel: 10,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
        );
        final w = GameWorld(
          content: content,
          clock: clock,
          rng: SeededRng(0),
          initialState: GameState(
            countries: {const CountryId('egypt'): egypt},
            totalInfluence: Influence.zero,
            unlockedContinents: _seedAfricaUnlocked,
          ),
        );
        for (var i = 0; i < 10; i++) {
          w.tick(const Duration(milliseconds: 100));
        }
        expect(
          w.state.countries[const CountryId('egypt')]!.bankedInfluence.value,
          equals(Decimal.parse('2')),
        );
        w.dispose();
      },
    );

    test(
      'Story 3.1: tick 1s tier2 + continent complete → full stack on base rate',
      () {
        final egypt = CountryState(
          id: const CountryId('egypt'),
          unlocked: true,
          ipLevel: 0,
          leaderTier: LeaderTier.tier2,
          bankedInfluence: Influence.zero,
        );
        final w = GameWorld(
          content: content,
          clock: clock,
          rng: SeededRng(0),
          initialState: GameState(
            countries: {const CountryId('egypt'): egypt},
            totalInfluence: Influence.zero,
            unlockedContinents: _seedAfricaUnlocked,
            continentCompletions: {const ContinentId('africa'): true},
          ),
        );
        for (var i = 0; i < 10; i++) {
          w.tick(const Duration(milliseconds: 100));
        }
        expect(
          w.state.countries[const CountryId('egypt')]!.bankedInfluence.value,
          equals(Decimal.parse('2.5')),
        );
        w.dispose();
      },
    );

    test(
      '5.3: tick for 1 second → Nigeria bankedInfluence == zero (Nigeria is locked)',
      () {
        final w = GameWorld(
          content: threeCountryContent,
          clock: clock,
          rng: SeededRng(0),
        );
        for (var i = 0; i < 10; i++) {
          w.tick(const Duration(milliseconds: 100));
        }
        expect(
          w.state.countries[const CountryId('nigeria')]!.bankedInfluence,
          equals(Influence.zero),
        );
        w.dispose();
      },
    );

    test(
      '5.4: countries map has all 3 countries from three-country content',
      () {
        final w = GameWorld(
          content: threeCountryContent,
          clock: clock,
          rng: SeededRng(0),
        );
        expect(w.state.countries, hasLength(3));
        expect(w.state.countries[const CountryId('egypt')], isNotNull);
        expect(w.state.countries[const CountryId('nigeria')], isNotNull);
        expect(w.state.countries[const CountryId('south_africa')], isNotNull);
        w.dispose();
      },
    );
  });

  group('Story 4.2: continent unlock at influence threshold', () {
    test('tick with bank accrual emits ContinentUnlocked before Tick when '
        'totalInfluence already meets a higher continent threshold', () async {
      final c = _buildAfricaEuropeStory42Content();
      final initial = GameState.initialSeed(c).copyWith(
        totalInfluence: Influence(Decimal.fromInt(1000)),
        unlockedContinents: Map.unmodifiable({
          const ContinentId('africa'): true,
        }),
      );
      final w = GameWorld(
        content: c,
        clock: clock,
        rng: SeededRng(0),
        initialState: initial,
      );
      final events = <GameEvent>[];
      final sub = w.events.listen(events.add);
      w.tick(const Duration(milliseconds: 100));
      await Future<void>.delayed(Duration.zero);
      expect(events, isNotEmpty);
      final unlockIdx = events.indexWhere((e) => e is ContinentUnlocked);
      final tickIdx = events.indexWhere((e) => e is Tick);
      expect(unlockIdx, greaterThanOrEqualTo(0));
      expect(tickIdx, greaterThanOrEqualTo(0));
      expect(unlockIdx, lessThan(tickIdx));
      expect(
        (events[unlockIdx] as ContinentUnlocked).continentId,
        const ContinentId('europe'),
      );
      await sub.cancel();
      w.dispose();
    });

    test(
      'first tick with total past all thresholds and empty unlockedContinents '
      'emits continent unlocks in threshold order then Tick',
      () async {
        final c = _buildThreeContinentStory42Content();
        final initial = GameState.initialSeed(c).copyWith(
          totalInfluence: Influence(Decimal.fromInt(100)),
          unlockedContinents: Map.unmodifiable(<ContinentId, bool>{}),
        );
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        w.tick(const Duration(milliseconds: 1));
        await Future<void>.delayed(Duration.zero);
        expect(events.length, greaterThanOrEqualTo(4));
        expect(events[0], isA<ContinentUnlocked>());
        expect(
          (events[0] as ContinentUnlocked).continentId,
          const ContinentId('africa'),
        );
        expect(events[1], isA<ContinentUnlocked>());
        expect(
          (events[1] as ContinentUnlocked).continentId,
          const ContinentId('europe'),
        );
        expect(events[2], isA<ContinentUnlocked>());
        expect(
          (events[2] as ContinentUnlocked).continentId,
          const ContinentId('asia'),
        );
        expect(events[3], isA<Tick>());
        await sub.cancel();
        w.dispose();
      },
    );

    test('applyCommand(TapCountry) emits CountryTapped then ContinentUnlocked '
        'when collect crosses a continent threshold', () async {
      final c = _buildAfricaEuropeStory42Content();
      final seed = GameState.initialSeed(c);
      final egypt = seed.countries[const CountryId('egypt')]!;
      final initial = seed.copyWith(
        totalInfluence: Influence(Decimal.fromInt(99)),
        unlockedContinents: Map.unmodifiable({
          const ContinentId('africa'): true,
        }),
        countries: Map.unmodifiable({
          ...seed.countries,
          const CountryId('egypt'): egypt.copyWith(
            bankedInfluence: Influence(Decimal.fromInt(10)),
          ),
        }),
      );
      final w = GameWorld(
        content: c,
        clock: clock,
        rng: SeededRng(0),
        initialState: initial,
      );
      final events = <GameEvent>[];
      final sub = w.events.listen(events.add);
      w.applyCommand(const TapCountry(countryId: CountryId('egypt')));
      await Future<void>.delayed(Duration.zero);
      expect(events.take(2).toList(), hasLength(2));
      expect(events[0], isA<CountryTapped>());
      expect(events[1], isA<ContinentUnlocked>());
      expect(
        (events[1] as ContinentUnlocked).continentId,
        const ContinentId('europe'),
      );
      await sub.cancel();
      w.dispose();
    });

    test(
      'seeded africa in unlockedContinents: tick emits no ContinentUnlocked',
      () async {
        final w = GameWorld(content: content, clock: clock, rng: SeededRng(0));
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        w.tick(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(events.whereType<ContinentUnlocked>(), isEmpty);
        await sub.cancel();
        w.dispose();
      },
    );
  });

  group('GameWorld milestone wiring (Story 4.3)', () {
    test(
      'TapCountry emits CountryTapped then MilestoneReached(25) when pending',
      () async {
        final c = _buildFourCountryAfricaMilestoneContent();
        final initial = GameState(
          countries: {
            for (var i = 0; i < 4; i++)
              CountryId('c$i'): CountryState(
                id: CountryId('c$i'),
                unlocked: i == 0,
                ipLevel: i == 0 ? 1 : 0,
                leaderTier: LeaderTier.none,
                bankedInfluence: i == 0
                    ? Influence(Decimal.one)
                    : Influence.zero,
                lastCollectedAt: null,
              ),
          },
          totalInfluence: Influence.zero,
          unlockedContinents: _seedAfricaUnlocked,
        );
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        w.applyCommand(const TapCountry(countryId: CountryId('c0')));
        await Future<void>.delayed(Duration.zero);
        expect(events.length, greaterThanOrEqualTo(2));
        expect(events[0], isA<CountryTapped>());
        expect(events[1], isA<MilestoneReached>());
        expect((events[1] as MilestoneReached).percent, 25);
        await sub.cancel();
        w.dispose();
      },
    );

    test('tick does not emit MilestoneReached', () async {
      final w = GameWorld(content: content, clock: clock, rng: SeededRng(0));
      final events = <GameEvent>[];
      final sub = w.events.listen(events.add);
      w.tick(const Duration(milliseconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<MilestoneReached>(), isEmpty);
      await sub.cancel();
      w.dispose();
    });

    test(
      'successful no-op TapCountry does not trigger milestone evaluation',
      () async {
        final c = _buildFourCountryAfricaMilestoneContent();
        final initial = GameState(
          countries: {
            for (var i = 0; i < 4; i++)
              CountryId('c$i'): CountryState(
                id: CountryId('c$i'),
                unlocked: i == 0,
                ipLevel: i == 0 ? 1 : 0,
                leaderTier: LeaderTier.none,
                bankedInfluence: Influence.zero,
                lastCollectedAt: null,
              ),
          },
          totalInfluence: Influence.zero,
          unlockedContinents: _seedAfricaUnlocked,
        );
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        final result = w.applyCommand(
          const TapCountry(countryId: CountryId('c0')),
        );
        await Future<void>.delayed(Duration.zero);
        expect(result.isSuccess, isTrue);
        expect(events, isEmpty);
        expect(w.state.reachedMilestones, isEmpty);
        await sub.cancel();
        w.dispose();
      },
    );

    test(
      'complete-africa via UnlockCountry emits ContinentCompleted and flips flag',
      () async {
        final c = _buildThreeCountryAfricaMilestoneContent();
        final initial = GameState(
          countries: {
            for (var i = 0; i < 3; i++)
              CountryId('c$i'): CountryState(
                id: CountryId('c$i'),
                unlocked: i < 2,
                ipLevel: i < 2 ? 1 : 0,
                leaderTier: LeaderTier.none,
                bankedInfluence: Influence.zero,
                lastCollectedAt: null,
              ),
          },
          totalInfluence: Influence.zero,
          unlockedContinents: _seedAfricaUnlocked,
        );
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        final r = w.applyCommand(
          const UnlockCountry(countryId: CountryId('c2')),
        );
        await Future<void>.delayed(Duration.zero);
        expect(r.isSuccess, isTrue);
        expect(
          w.state.continentCompletions[const ContinentId('africa')],
          isTrue,
        );

        final idx100 = events.indexWhere(
          (e) => e is MilestoneReached && e.percent == 100,
        );
        expect(idx100, greaterThanOrEqualTo(0));
        expect(events[idx100 + 1], isA<ContinentCompleted>());
        expect(
          (events[idx100 + 1] as ContinentCompleted).continentId,
          const ContinentId('africa'),
        );
        await sub.cancel();
        w.dispose();
      },
    );

    test('loaded-state with continentCompletions[africa]=true does NOT re-fire '
        'ContinentCompleted on TapCountry', () async {
      final c = _buildThreeCountryAfricaMilestoneContent();
      final loaded = GameState(
        countries: {
          for (var i = 0; i < 3; i++)
            CountryId('c$i'): CountryState(
              id: CountryId('c$i'),
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none,
              bankedInfluence: i == 0 ? Influence(Decimal.one) : Influence.zero,
              lastCollectedAt: null,
            ),
        },
        totalInfluence: Influence.zero,
        unlockedContinents: _seedAfricaUnlocked,
        reachedMilestones: {
          const ContinentId('africa'): {25, 50, 75, 100},
        },
        continentCompletions: {const ContinentId('africa'): true},
      );
      final w = GameWorld(
        content: c,
        clock: clock,
        rng: SeededRng(0),
        initialState: loaded,
      );
      final events = <GameEvent>[];
      final sub = w.events.listen(events.add);
      w.applyCommand(const TapCountry(countryId: CountryId('c0')));
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<ContinentCompleted>(), isEmpty);
      await sub.cancel();
      w.dispose();
    });
  });

  group('GameWorld.events stream', () {
    test('supports multiple subscribers simultaneously (broadcast)', () {
      final events1 = <Object>[];
      final events2 = <Object>[];
      final sub1 = world.events.listen(events1.add);
      final sub2 = world.events.listen(events2.add);
      expect(sub1, isNotNull);
      expect(sub2, isNotNull);
      sub1.cancel();
      sub2.cancel();
    });

    test('is usable before any events are emitted (no error on listen)', () {
      expect(() => world.events.listen((_) {}), returnsNormally);
    });
  });

  group('Story 5-1 goldens', () {
    test('e2e spawn, claim, effect GoldenExpired(claimed: true)', () async {
      final pTick =
          BalanceConfig.goldenSpawnProbabilityPerSecond.toDouble() * 0.1;
      int? spawnSeed;
      for (var s = 0; s < 100000; s++) {
        if (SeededRng(s).nextDouble() < pTick) {
          spawnSeed = s;
          break;
        }
      }
      expect(spawnSeed, isNotNull);
      final fc = FakeClock(DateTime.utc(2026, 1, 1, 12));
      final c = _buildSingleCountryContent();
      final w = GameWorld(content: c, clock: fc, rng: SeededRng(spawnSeed!));
      addTearDown(w.dispose);
      final log = <GameEvent>[];
      final sub = w.events.listen(log.add);
      w.tick(const Duration(milliseconds: 100));
      await Future<void>.delayed(Duration.zero);
      expect(w.state.activeGoldens, hasLength(1));
      expect(log.whereType<GoldenSpawned>(), hasLength(1));
      final gid = w.state.activeGoldens.keys.first;
      w.applyCommand(ClaimGolden(goldenId: gid));
      await Future<void>.delayed(Duration.zero);
      expect(w.state.activeGoldenEffect, isNotNull);
      expect(w.state.goldenOpportunityMultiplier == Decimal.one, isFalse);
      expect(log.whereType<GoldenClaimed>(), hasLength(1));
      fc.advance(
        const Duration(seconds: BalanceConfig.goldenEffectDurationSeconds + 1),
      );
      w.tick(const Duration(milliseconds: 100));
      await Future<void>.delayed(Duration.zero);
      expect(w.state.activeGoldenEffect, isNull);
      expect(w.state.goldenOpportunityMultiplier, equals(Decimal.one));
      expect(
        log.whereType<GoldenExpired>().where((e) => e.claimed),
        hasLength(1),
      );
      await sub.cancel();
    });

    test('tick with only golden map-expiry still emits Tick', () async {
      const gid = 'eg@100';
      final tClock = DateTime.utc(2026, 1, 1, 12);
      final started = tClock.subtract(const Duration(hours: 1));
      final g = ActiveGolden(
        id: gid,
        countryId: const CountryId('egypt'),
        multiplier: 20,
        expiresAt: started,
      );
      final c = _buildSingleCountryContent();
      final s0 = GameState.initialSeed(c);
      final initial = s0.copyWith(activeGoldens: {gid: g});
      final w = GameWorld(
        content: c,
        clock: FakeClock(tClock),
        rng: SeededRng(0),
        initialState: initial,
      );
      addTearDown(w.dispose);
      final log = <GameEvent>[];
      final sub = w.events.listen(log.add);
      w.tick(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        log.whereType<GoldenExpired>().where((e) => e.claimed).isEmpty,
        isTrue,
      );
      expect(
        log.whereType<GoldenExpired>().where((e) => !e.claimed),
        hasLength(1),
      );
      expect(log.whereType<Tick>(), hasLength(1));
      expect(log.first, isA<GoldenExpired>());
      expect(log.last, isA<Tick>());
      expect(w.state.activeGoldens, isEmpty);
      await sub.cancel();
    });
  });

  group('Story 5-2 boost (ActivateBoost, tick expiry)', () {
    test(
      'applyCommand(ActivateBoost) succeeds when intel sufficient and no active boost',
      () async {
        final initial = stateWithUnlockedEgypt().copyWith(
          totalIntel: Intel(Decimal.fromInt(500)),
        );
        final w = GameWorld(
          content: content,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        final events = <GameEvent>[];
        final sub = w.events.listen(events.add);
        final r = w.applyCommand(const ActivateBoost());
        expect(r.isSuccess, isTrue);
        expect(w.state.totalIntel, Intel(Decimal.fromInt(400)));
        expect(w.state.activeBoost, isNotNull);
        expect(
          w.state.activeBoost!.expiresAt,
          DateTime.utc(2026, 1, 1).add(const Duration(seconds: 30)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(events, hasLength(1));
        expect(events.single, isA<BoostActivated>());
        await sub.cancel();
      },
    );

    test(
      'applyCommand(ActivateBoost) returns failure (locked) when boost already active',
      () {
        final initial = stateWithUnlockedEgypt().copyWith(
          totalIntel: Intel.zero,
          activeBoost: BoostState(
            multiplier: Decimal.parse('2'),
            expiresAt: DateTime.utc(2026, 1, 1, 0, 1, 0),
          ),
        );
        final w = GameWorld(
          content: content,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        final r = w.applyCommand(const ActivateBoost());
        expect(r.isFailure, isTrue);
        expect(r.errorOrNull, isA<Locked>());
        expect((r.errorOrNull! as Locked).reason, 'boost_already_active');
      },
    );

    test(
      'applyCommand(ActivateBoost) returns failure (insufficientIntel) when intel below boostCost',
      () {
        final initial = stateWithUnlockedEgypt().copyWith(
          totalIntel: Intel(Decimal.fromInt(50)),
        );
        final w = GameWorld(
          content: content,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        final r = w.applyCommand(const ActivateBoost());
        expect(r.isFailure, isTrue);
        expect(r.errorOrNull, isA<InsufficientIntel>());
      },
    );

    test(
      'applyCommand(ActivateBoost) on success makes activeBoost.expiresAt = clock.now() + 30s',
      () {
        final t = DateTime.utc(2026, 3, 15, 8);
        final fc = FakeClock(t);
        final initial = stateWithUnlockedEgypt().copyWith(
          totalIntel: Intel(Decimal.fromInt(500)),
        );
        final w = GameWorld(
          content: content,
          clock: fc,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        w.applyCommand(const ActivateBoost());
        expect(
          w.state.activeBoost!.expiresAt,
          t.add(const Duration(seconds: BalanceConfig.boostDurationSeconds)),
        );
      },
    );
  });

  group('GameWorld.tick boost expiry', () {
    test(
      'tick clears active boost when expiresAt has passed and emits BoostExpired and Tick',
      () async {
        final t0 = DateTime.utc(2026, 6, 1);
        final fc = FakeClock(t0);
        final initial = stateWithUnlockedEgypt().copyWith(
          activeBoost: BoostState(
            multiplier: Decimal.parse('2'),
            expiresAt: t0,
          ),
        );
        final w = GameWorld(
          content: content,
          clock: fc,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        final log = <GameEvent>[];
        final sub = w.events.listen(log.add);
        fc.advance(const Duration(milliseconds: 100));
        w.tick(const Duration(milliseconds: 100));
        await Future<void>.delayed(Duration.zero);
        expect(w.state.activeBoost, isNull);
        expect(log.whereType<BoostExpired>(), hasLength(1));
        expect(log.whereType<Tick>(), hasLength(1));
        await sub.cancel();
      },
    );

    test('tick does NOT clear an unexpired boost', () {
      final t0 = DateTime.utc(2026, 6, 1);
      final fc = FakeClock(t0);
      final boost = BoostState(
        multiplier: Decimal.parse('2'),
        expiresAt: t0.add(const Duration(seconds: 60)),
      );
      final initial = stateWithUnlockedEgypt().copyWith(activeBoost: boost);
      final w = GameWorld(
        content: content,
        clock: fc,
        rng: SeededRng(0),
        initialState: initial,
      );
      addTearDown(w.dispose);
      fc.advance(const Duration(milliseconds: 100));
      w.tick(const Duration(milliseconds: 100));
      expect(w.state.activeBoost, equals(boost));
    });

    test(
      'tick income generated AFTER boost expiry uses 1.0 multiplier (strict order)',
      () {
        final t0 = DateTime.utc(2026, 6, 1, 10);
        final fc = FakeClock(t0);
        final egypt = CountryState(
          id: CountryId('egypt'),
          unlocked: true,
          ipLevel: 0,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
        );
        final initial = GameState(
          countries: {CountryId('egypt'): egypt},
          totalInfluence: Influence.zero,
          totalIntel: Intel.zero,
          unlockedContinents: _seedAfricaUnlocked,
          activeBoost: BoostState(
            multiplier: Decimal.parse('2'),
            expiresAt: t0,
          ),
        );
        final w = GameWorld(
          content: _buildSingleCountryContent(),
          clock: fc,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        for (var i = 0; i < 10; i++) {
          fc.advance(const Duration(milliseconds: 100));
          w.tick(const Duration(milliseconds: 100));
        }
        expect(
          w.state.countries[CountryId('egypt')]!.bankedInfluence,
          equals(Influence(Decimal.fromInt(1))),
        );
      },
    );
  });

  group('GameWorld missions (story 5-3)', () {
    test('mission events follow CountryTapped on the stream', () async {
      final c = _buildMissionOneTapContent();
      final seed = GameState.initialSeed(c);
      final eg = seed.countries[const CountryId('egypt')]!;
      final initial = seed.copyWith(
        countries: {
          const CountryId('egypt'): eg.copyWith(
            bankedInfluence: Influence(Decimal.fromInt(4)),
          ),
        },
      );
      final w = GameWorld(
        content: c,
        clock: clock,
        rng: SeededRng(0),
        initialState: initial,
      );
      addTearDown(w.dispose);
      final log = <GameEvent>[];
      final sub = w.events.listen(log.add);
      final r = w.applyCommand(TapCountry(countryId: const CountryId('egypt')));
      expect(r.isSuccess, isTrue);
      await Future<void>.delayed(Duration.zero);
      final ct = log.indexWhere((e) => e is CountryTapped);
      final mc = log.indexWhere((e) => e is MissionCompleted);
      expect(ct, greaterThanOrEqualTo(0));
      expect(mc, greaterThan(ct));
      await sub.cancel();
    });

    test('tick with Tick only leaves activeMissions unchanged in value', () {
      final w2 = GameWorld(content: content, clock: clock, rng: SeededRng(0));
      addTearDown(w2.dispose);
      final before = w2.state.activeMissions;
      w2.tick(const Duration(milliseconds: 16));
      expect(w2.state.activeMissions, equals(before));
    });

    test(
      'tick emits ContinentUnlocked then mission completion for unlock_continents_n',
      () async {
        final c = _buildEuropeUnlockMissionContent();
        final seed = GameState.initialSeed(c);
        final initial = seed.copyWith(
          totalInfluence: Influence(Decimal.fromInt(50)),
          unlockedContinents: _seedAfricaUnlocked,
        );
        expect(initial.activeMissions.single.id, 'unlock_one_continent');
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        final log = <GameEvent>[];
        final sub = w.events.listen(log.add);
        w.tick(const Duration(milliseconds: 16));
        await Future<void>.delayed(Duration.zero);
        final cu = log.indexWhere((e) => e is ContinentUnlocked);
        final mc = log.indexWhere((e) => e is MissionCompleted);
        expect(cu, greaterThanOrEqualTo(0));
        expect(mc, greaterThan(cu));
        expect(log.whereType<MissionCompleted>(), hasLength(1));
        expect(w.state.completedMissionIds, contains('unlock_one_continent'));
        await sub.cancel();
      },
    );

    test(
      'single tap emits one MissionCompleted and one MissionRotated',
      () async {
        final c = _buildMissionOneTapContent();
        final seed = GameState.initialSeed(c);
        final eg = seed.countries[const CountryId('egypt')]!;
        final initial = seed.copyWith(
          countries: {
            const CountryId('egypt'): eg.copyWith(
              bankedInfluence: Influence(Decimal.fromInt(2)),
            ),
          },
        );
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        final log = <GameEvent>[];
        final sub = w.events.listen(log.add);
        w.applyCommand(TapCountry(countryId: const CountryId('egypt')));
        await Future<void>.delayed(Duration.zero);
        expect(log.whereType<MissionCompleted>(), hasLength(1));
        expect(log.whereType<MissionRotated>(), hasLength(1));
        await sub.cancel();
      },
    );
  });

  group('ClaimDailyReward (Story 5-4)', () {
    test(
      'first claim emits DailyRewardClaimed and updates streak and totals',
      () async {
        final c = _buildSingleCountryContent();
        final t = DateTime(2026, 4, 25, 10, 0);
        final w = GameWorld(
          content: c,
          clock: FakeClock(t),
          rng: SeededRng(0),
          initialState: GameState.initialSeed(c),
        );
        addTearDown(w.dispose);
        final log = <GameEvent>[];
        final sub = w.events.listen(log.add);
        expect(w.applyCommand(const ClaimDailyReward()).isSuccess, isTrue);
        expect(w.state.dailyStreak.day, 1);
        expect(w.state.dailyStreak.lastClaimDate, equals(t));
        expect(w.state.totalInfluence, equals(Influence(Decimal.one)));
        await Future<void>.delayed(Duration.zero);
        expect(log, contains(isA<DailyRewardClaimed>()));
        await sub.cancel();
      },
    );

    test('same-day second claim fails; state is unchanged', () {
      final c = _buildSingleCountryContent();
      final t = DateTime(2026, 4, 25, 10, 0);
      final s = GameState.initialSeed(c).copyWith(
        dailyStreak: DailyStreak(day: 1, lastClaimDate: t),
        totalInfluence: Influence(Decimal.one),
        totalIntel: Intel(Decimal.parse('10')),
      );
      final w = GameWorld(
        content: c,
        clock: FakeClock(t),
        rng: SeededRng(0),
        initialState: s,
      );
      addTearDown(w.dispose);
      final before = w.state;
      expect(w.applyCommand(const ClaimDailyReward()).isFailure, isTrue);
      expect(identical(before, w.state), isTrue);
    });

    test(
      'claim that crosses Europe threshold: DailyRewardClaimed then ContinentUnlocked',
      () async {
        final c = _buildEuropeThresholdOneContent();
        final t = DateTime(2026, 5, 1, 9, 0);
        final w = GameWorld(
          content: c,
          clock: FakeClock(t),
          rng: SeededRng(0),
          initialState: GameState.initialSeed(c),
        );
        addTearDown(w.dispose);
        final log = <GameEvent>[];
        final sub = w.events.listen(log.add);
        expect(w.applyCommand(const ClaimDailyReward()).isSuccess, isTrue);
        await Future<void>.delayed(Duration.zero);
        final d = log.indexWhere((e) => e is DailyRewardClaimed);
        final u = log.indexWhere(
          (e) =>
              e is ContinentUnlocked &&
              e.continentId == const ContinentId('europe'),
        );
        expect(d, greaterThanOrEqualTo(0));
        expect(u, greaterThan(d));
        expect(w.state.unlockedContinents[const ContinentId('europe')], isTrue);
        await sub.cancel();
      },
    );
  });

  group('Story 5-5-27 achievements', () {
    test('UnlockCountry 0→1 emits AchievementEarned on stream', () async {
      final continents = jsonEncode([
        {
          'id': 'africa',
          'name': 'Africa',
          'unlockThreshold': '0',
          'completionBonus': '0.25',
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
      ]);
      final c = ContentRegistry.fromJsonStrings(
        countriesJson: countries,
        continentsJson: continents,
        leadersJson: '[]',
        achievementsJson: achievementsJson27([
          {
            'id': 'ach_gw_first_unlock',
            'name': 'First',
            'conditionType': 'countriesUnlockedAtLeast',
            'conditionParams': {'count': 1},
            'rewardType': 'influenceMultiplier',
            'rewardValue': '0.05',
          },
        ]),
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      final initial = GameState(
        countries: {
          const CountryId('egypt'): CountryState(
            id: const CountryId('egypt'),
            unlocked: false,
            ipLevel: 0,
            leaderTier: LeaderTier.none,
            bankedInfluence: Influence.zero,
            lastCollectedAt: null,
          ),
        },
        totalInfluence: Influence.zero,
        unlockedContinents: _seedAfricaUnlocked,
      );
      final w = GameWorld(
        content: c,
        clock: clock,
        rng: SeededRng(0),
        initialState: initial,
      );
      addTearDown(w.dispose);
      final log = <GameEvent>[];
      final sub = w.events.listen(log.add);
      expect(
        w
            .applyCommand(const UnlockCountry(countryId: CountryId('egypt')))
            .isSuccess,
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(w.state.earnedAchievementIds, contains('ach_gw_first_unlock'));
      expect(log.whereType<AchievementEarned>(), hasLength(1));
      await sub.cancel();
    });

    test(
      'continent completion emits AchievementEarned after ContinentCompleted',
      () async {
        final c = _buildThreeCountryAfricaMilestoneAchievementContent();
        final initial = GameState(
          countries: {
            for (var i = 0; i < 3; i++)
              CountryId('c$i'): CountryState(
                id: CountryId('c$i'),
                unlocked: i < 2,
                ipLevel: i < 2 ? 1 : 0,
                leaderTier: LeaderTier.none,
                bankedInfluence: Influence.zero,
                lastCollectedAt: null,
              ),
          },
          totalInfluence: Influence.zero,
          unlockedContinents: _seedAfricaUnlocked,
        );
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        final log = <GameEvent>[];
        final sub = w.events.listen(log.add);
        expect(
          w
              .applyCommand(const UnlockCountry(countryId: CountryId('c2')))
              .isSuccess,
          isTrue,
        );
        await Future<void>.delayed(Duration.zero);
        final idx100 = log.indexWhere(
          (e) => e is MilestoneReached && e.percent == 100,
        );
        expect(idx100, greaterThanOrEqualTo(0));
        expect(log[idx100 + 1], isA<ContinentCompleted>());
        expect(log[idx100 + 2], isA<AchievementEarned>());
        expect(
          (log[idx100 + 2] as AchievementEarned).achievementId,
          'ach_gw_africa_done',
        );
        await sub.cancel();
      },
    );

    test('failed UnlockCountry does not emit AchievementEarned', () async {
      final three = _buildThreeCountryContent();
      final initial = GameState.initialSeed(three);
      final w = GameWorld(
        content: three,
        clock: clock,
        rng: SeededRng(0),
        initialState: initial,
      );
      addTearDown(w.dispose);
      final log = <GameEvent>[];
      final sub = w.events.listen(log.add);
      expect(
        w
            .applyCommand(
              const UnlockCountry(countryId: CountryId('south_africa')),
            )
            .isFailure,
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(log.whereType<AchievementEarned>(), isEmpty);
      await sub.cancel();
    });

    test(
      'earnedAchievementIds ledger prevents duplicate AchievementEarned',
      () async {
        final continents = jsonEncode([
          {
            'id': 'africa',
            'name': 'Africa',
            'unlockThreshold': '0',
            'completionBonus': '0.25',
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
        ]);
        final c = ContentRegistry.fromJsonStrings(
          countriesJson: countries,
          continentsJson: continents,
          leadersJson: '[]',
          achievementsJson: achievementsJson27([
            {
              'id': 'ach_gw_idem',
              'name': 'Idem',
              'conditionType': 'countriesUnlockedAtLeast',
              'conditionParams': {'count': 1},
              'rewardType': 'influenceMultiplier',
              'rewardValue': '0.05',
            },
          ]),
          missionsJson: '[]',
          globalUpgradesJson: '[]',
          dailyRewardsJson: testDailyRewardsJson(),
        );
        final initial = GameState(
          countries: {
            const CountryId('egypt'): CountryState(
              id: const CountryId('egypt'),
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none,
              bankedInfluence: Influence(Decimal.one),
              lastCollectedAt: null,
            ),
          },
          unlockedContinents: _seedAfricaUnlocked,
          earnedAchievementIds: {'ach_gw_idem'},
        );
        final w = GameWorld(
          content: c,
          clock: clock,
          rng: SeededRng(0),
          initialState: initial,
        );
        addTearDown(w.dispose);
        final log = <GameEvent>[];
        final sub = w.events.listen(log.add);
        expect(
          w
              .applyCommand(const TapCountry(countryId: CountryId('egypt')))
              .isSuccess,
          isTrue,
        );
        await Future<void>.delayed(Duration.zero);
        expect(log.whereType<AchievementEarned>(), isEmpty);
        await sub.cancel();
      },
    );
  });

  group('GameWorld.dispose', () {
    test('closes the stream', () async {
      final world2 = GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
      );
      var isDone = false;
      world2.events.listen((_) {}, onDone: () => isDone = true);
      world2.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(isDone, isTrue);
    });

    test('is idempotent — second dispose() does not throw', () {
      final world2 = GameWorld(
        content: content,
        clock: clock,
        rng: SeededRng(0),
      );
      world2.dispose();
      expect(world2.dispose, returnsNormally);
    });
  });
}
