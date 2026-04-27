import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/mappers/game_state_companions.dart';
import 'package:global_domination/data/mappers/game_state_mapper.dart';
import 'package:global_domination/data/mappers/game_state_rows.dart';
import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/features/goldens/active_golden_effect.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/features/missions/mission_state.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

import '../../helpers/game_state_builder.dart';
import '../../helpers/test_content_registry.dart';

Future<void> insertCompanions(AppDatabase db, GameStateCompanions c) async {
  await db.transaction(() async {
    await db.into(db.meta).insert(c.meta);
    if (c.activeBoost != null) {
      await db.into(db.activeBoost).insert(c.activeBoost!);
    }
    for (final row in c.countries) {
      await db.into(db.countries).insert(row);
    }
    for (final row in c.continents) {
      await db.into(db.continents).insert(row);
    }
    for (final row in c.continentMilestones) {
      await db.into(db.continentMilestones).insert(row);
    }
    for (final row in c.earnedAchievements) {
      await db.into(db.earnedAchievements).insert(row);
    }
    for (final row in c.activeGlobalUpgrades) {
      await db.into(db.activeGlobalUpgrades).insert(row);
    }
    for (final row in c.activeGoldens) {
      await db.into(db.activeGoldens).insert(row);
    }
    for (final row in c.activeMissions) {
      await db.into(db.activeMissions).insert(row);
    }
    for (final row in c.completedMissions) {
      await db.into(db.completedMissions).insert(row);
    }
    await db.into(db.dailyStreaks).insert(c.dailyStreak);
    if (c.activeGoldenEffect != null) {
      await db.into(db.activeGoldenEffect).insert(c.activeGoldenEffect!);
    }
  });
}

Future<GameState> roundTrip(
  AppDatabase db,
  GameStateMapper mapper,
  GameState state,
  DateTime savedAtUtc,
  ContentRegistry registry,
) async {
  final c = mapper.toCompanions(state, savedAt: savedAtUtc);
  await insertCompanions(db, c);
  final rows = await db.loadAll();
  return mapper.fromRows(rows, registry);
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  const mapper = GameStateMapper();
  final content = testMapperContentRegistry();
  final savedAt = DateTime.utc(2026, 1, 15, 12, 30);

  group('GameStateMapper', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('fromRows on empty rows returns initialSeed', () {
      const rows = GameStateRows(
        meta: null,
        activeBoost: null,
        countries: [],
        continents: [],
        continentMilestones: [],
        earnedAchievements: [],
        activeGlobalUpgrades: [],
        activeGoldens: [],
        activeMissions: [],
        completedMissions: [],
        dailyStreak: null,
        activeGoldenEffect: null,
      );
      expect(
        mapper.fromRows(rows, content),
        equals(GameState.initialSeed(content)),
      );
    });

    test('toCompanions then fromRows is lossless for trivial state', () async {
      final state1 = GameState.initialSeed(content);
      final c = mapper.toCompanions(state1, savedAt: savedAt);
      await insertCompanions(db, c);
      final rows = await db.loadAll();
      final state2 = mapper.fromRows(rows, content);
      expect(state2, equals(state1));
    });

    test(
      'toCompanions then fromRows is lossless for fully-populated state',
      () async {
        final state1 = GameStateBuilder.fullyPopulated(
          content: content,
          savedAtUtc: savedAt,
        );
        final state2 = await roundTrip(db, mapper, state1, savedAt, content);
        expect(state2, equals(state1));
      },
    );

    test('savedAt non-UTC throws in debug', () {
      if (!kDebugMode) return;
      final s = GameState.initialSeed(content);
      expect(
        () => mapper.toCompanions(s, savedAt: DateTime(2026, 1, 1)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('leader_tier enum.name round-trips for every variant', () async {
      const egypt = CountryId('egypt');
      for (final tier in LeaderTier.values) {
        final dbTier = AppDatabase(NativeDatabase.memory());
        final base = GameState.initialSeed(content);
        final countries = Map<CountryId, CountryState>.from(base.countries);
        countries[egypt] = countries[egypt]!.copyWith(leaderTier: tier);
        final state1 = base.copyWith(countries: countries);
        final state2 = await roundTrip(
          dbTier,
          mapper,
          state1,
          savedAt,
          content,
        );
        expect(state2, equals(state1));
        await dbTier.close();
      }
    });

    test('meta single-row CHECK survives mapper write', () async {
      final state1 = GameStateBuilder.fullyPopulated(
        content: content,
        savedAtUtc: savedAt,
      );
      await insertCompanions(db, mapper.toCompanions(state1, savedAt: savedAt));
      final state2 = state1.copyWith(
        totalInfluence: Influence(Decimal.parse('42')),
      );
      await db
          .into(db.meta)
          .insertOnConflictUpdate(
            mapper.toCompanions(state2, savedAt: savedAt).meta,
          );
      final metaRows = await db.select(db.meta).get();
      expect(metaRows, hasLength(1));
      expect(metaRows.single.totalInfluence, equals(Decimal.parse('42')));
    });

    group('per-field round-trip from initialSeed', () {
      test('totalInfluence', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final s = GameState.initialSeed(
          content,
        ).copyWith(totalInfluence: Influence(Decimal.parse('1.234e38')));
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('totalIntel', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final s = GameState.initialSeed(
          content,
        ).copyWith(totalIntel: Intel(Decimal.parse('456.789')));
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('unlockedContinents', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final base = GameState.initialSeed(content);
        final s = base.copyWith(
          unlockedContinents: {
            ...base.unlockedContinents,
            const ContinentId('europe'): true,
          },
        );
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('continentCompletions', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final base = GameState.initialSeed(content);
        final s = base.copyWith(
          continentCompletions: {const ContinentId('africa'): true},
        );
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('reachedMilestones partial', () async {
        final db3 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db3.close());
        final base = GameState.initialSeed(content);
        final s2 = base.copyWith(
          reachedMilestones: {
            const ContinentId('africa'): {25, 50},
            const ContinentId('europe'): {100},
          },
        );
        expect(await roundTrip(db3, mapper, s2, savedAt, content), equals(s2));
      });

      test('earnedAchievementIds', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final s = GameState.initialSeed(
          content,
        ).copyWith(earnedAchievementIds: {'ach_fixture_inert_5'});
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('activeGlobalUpgradeIds', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final s = GameState.initialSeed(
          content,
        ).copyWith(activeGlobalUpgradeIds: {'gu_fixture'});
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('activeGoldens one and three', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final one = {
          'x': ActiveGolden(
            id: 'x',
            countryId: const CountryId('egypt'),
            multiplier: 11,
            expiresAt: savedAt,
          ),
        };
        final s1 = GameState.initialSeed(content).copyWith(activeGoldens: one);
        expect(await roundTrip(db2, mapper, s1, savedAt, content), equals(s1));
        final db3 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db3.close());
        final three = {
          'a': ActiveGolden(
            id: 'a',
            countryId: const CountryId('egypt'),
            multiplier: 10,
            expiresAt: savedAt,
          ),
          'b': ActiveGolden(
            id: 'b',
            countryId: const CountryId('nigeria'),
            multiplier: 20,
            expiresAt: savedAt,
          ),
          'c': ActiveGolden(
            id: 'c',
            countryId: const CountryId('france'),
            multiplier: 30,
            expiresAt: savedAt,
          ),
        };
        final s2 = GameState.initialSeed(
          content,
        ).copyWith(activeGoldens: three);
        expect(await roundTrip(db3, mapper, s2, savedAt, content), equals(s2));
      });

      test('activeGoldenEffect null and non-null', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final s0 = GameState.initialSeed(
          content,
        ).copyWith(activeGoldenEffect: null);
        expect(await roundTrip(db2, mapper, s0, savedAt, content), equals(s0));
        final db3 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db3.close());
        final fx = ActiveGoldenEffect(
          goldenId: 'g',
          multiplier: 99,
          expiresAt: savedAt,
        );
        final s1 = GameState.initialSeed(
          content,
        ).copyWith(activeGoldenEffect: fx);
        expect(await roundTrip(db3, mapper, s1, savedAt, content), equals(s1));
      });

      test('goldenOpportunityMultiplier', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final s = GameState.initialSeed(
          content,
        ).copyWith(goldenOpportunityMultiplier: Decimal.parse('7.5'));
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('activeBoost multiplier snapshot', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final expiresAt = savedAt.add(const Duration(seconds: 30));
        final s = GameState.initialSeed(content).copyWith(
          activeBoost: BoostState(
            multiplier: BalanceConfig.boostMultiplier,
            expiresAt: expiresAt,
          ),
        );
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('dailyStreak', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final s = GameState.initialSeed(content).copyWith(
          dailyStreak: DailyStreak(
            day: 4,
            lastClaimDate: savedAt.subtract(const Duration(days: 1)),
          ),
        );
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('activeMissions', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final missions = [
          MissionState(
            id: 'm_fix_b',
            progress: 1,
            target: 2,
            rewardIntel: Intel(Decimal.parse('2')),
          ),
          MissionState(
            id: 'm_fix_c',
            progress: 3,
            target: 3,
            rewardIntel: Intel(Decimal.parse('3')),
          ),
        ];
        final s = GameState.initialSeed(
          content,
        ).copyWith(activeMissions: missions);
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('completedMissionIds', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        final s = GameState.initialSeed(
          content,
        ).copyWith(completedMissionIds: {'m_fix_a', 'm_prior_done'});
        expect(await roundTrip(db2, mapper, s, savedAt, content), equals(s));
      });

      test('country unlocked ipLevel banked lastCollectedAt', () async {
        final db2 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db2.close());
        const egypt = CountryId('egypt');
        final base = GameState.initialSeed(content);
        final countries = Map<CountryId, CountryState>.from(base.countries);
        countries[egypt] = CountryState(
          id: egypt,
          unlocked: true,
          ipLevel: 7,
          leaderTier: LeaderTier.tier2,
          bankedInfluence: Influence(Decimal.parse('123.45')),
          lastCollectedAt: null,
        );
        final s1 = base.copyWith(countries: countries);
        expect(await roundTrip(db2, mapper, s1, savedAt, content), equals(s1));
        final db3 = AppDatabase(NativeDatabase.memory());
        addTearDown(() async => db3.close());
        countries[egypt] = countries[egypt]!.copyWith(lastCollectedAt: savedAt);
        final s2 = base.copyWith(countries: Map.from(countries));
        expect(await roundTrip(db3, mapper, s2, savedAt, content), equals(s2));
      });
    });
  });
}
