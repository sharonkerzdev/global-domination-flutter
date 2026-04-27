import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/mappers/game_state_companions.dart';
import 'package:global_domination/data/mappers/game_state_rows.dart';
import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/features/goldens/active_golden_effect.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/features/missions/mission_state.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

/// Maps [GameState] ↔ Drift rows; [LeaderTier] stored as enum [LeaderTier.name] text (no converter).
class GameStateMapper {
  const GameStateMapper();

  GameStateCompanions toCompanions(
    GameState state, {
    required DateTime savedAt,
  }) {
    assert(savedAt.isUtc, 'savedAt must be UTC');

    final meta = MetaCompanion.insert(
      singletonId: const Value(0),
      schemaVersion: 3,
      lastSavedAt: savedAt,
      totalInfluence: state.totalInfluence.value,
      totalIntel: state.totalIntel.value,
      goldenOpportunityMultiplier: state.goldenOpportunityMultiplier,
      boostMultiplier: state.activeBoost?.multiplier ?? Decimal.one,
    );

    final activeBoost = state.activeBoost == null
        ? null
        : ActiveBoostCompanion.insert(
            singletonId: const Value(0),
            multiplier: state.activeBoost!.multiplier,
            expiresAt: state.activeBoost!.expiresAt,
          );

    final countryIds = state.countries.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final countries = <CountriesCompanion>[
      for (final id in countryIds)
        CountriesCompanion.insert(
          id: id.value,
          unlocked: state.countries[id]!.unlocked,
          ipLevel: state.countries[id]!.ipLevel,
          leaderTier: state.countries[id]!.leaderTier.name,
          bankedInfluence: state.countries[id]!.bankedInfluence.value,
          lastCollectedAt: Value(state.countries[id]!.lastCollectedAt),
        ),
    ];

    final continentKeys = {
      ...state.unlockedContinents.keys,
      ...state.continentCompletions.keys,
    }.toList()..sort((a, b) => a.value.compareTo(b.value));
    final continents = <ContinentsCompanion>[
      for (final id in continentKeys)
        ContinentsCompanion.insert(
          id: id.value,
          unlocked: state.unlockedContinents[id] ?? false,
          completed: state.continentCompletions[id] ?? false,
        ),
    ];

    final milestoneContinentIds = state.reachedMilestones.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final continentMilestones = <ContinentMilestonesCompanion>[];
    for (final cid in milestoneContinentIds) {
      final set = state.reachedMilestones[cid]!;
      final sorted = set.toList()..sort();
      for (final m in sorted) {
        continentMilestones.add(
          ContinentMilestonesCompanion.insert(
            continentId: cid.value,
            milestone: m,
          ),
        );
      }
    }

    final achIds = state.earnedAchievementIds.toList()..sort();
    final earnedAchievements = <EarnedAchievementsCompanion>[
      for (final id in achIds) EarnedAchievementsCompanion.insert(id: id),
    ];

    final upgradeIds = state.activeGlobalUpgradeIds.toList()..sort();
    final activeGlobalUpgrades = <ActiveGlobalUpgradesCompanion>[
      for (final id in upgradeIds) ActiveGlobalUpgradesCompanion.insert(id: id),
    ];

    final goldenIds = state.activeGoldens.keys.toList()..sort();
    final activeGoldens = <ActiveGoldensCompanion>[
      for (final id in goldenIds)
        ActiveGoldensCompanion.insert(
          id: id,
          countryId: state.activeGoldens[id]!.countryId.value,
          multiplier: state.activeGoldens[id]!.multiplier,
          expiresAt: state.activeGoldens[id]!.expiresAt,
        ),
    ];

    final activeMissions = <ActiveMissionsCompanion>[
      for (var i = 0; i < state.activeMissions.length; i++)
        ActiveMissionsCompanion.insert(
          slot: Value(i),
          id: state.activeMissions[i].id,
          progress: state.activeMissions[i].progress,
          target: state.activeMissions[i].target,
          rewardIntel: state.activeMissions[i].rewardIntel.value,
        ),
    ];

    final completedMissionIds = state.completedMissionIds.toList()..sort();
    final completedMissions = <CompletedMissionsCompanion>[
      for (final id in completedMissionIds)
        CompletedMissionsCompanion.insert(id: id),
    ];

    final dailyStreak = DailyStreaksCompanion.insert(
      singletonId: const Value(0),
      day: state.dailyStreak.day,
      lastClaimDate: Value(state.dailyStreak.lastClaimDate),
    );

    final effect = state.activeGoldenEffect;
    final ActiveGoldenEffectCompanion? activeGoldenEffectCompanion;
    if (effect == null) {
      activeGoldenEffectCompanion = null;
    } else {
      activeGoldenEffectCompanion = ActiveGoldenEffectCompanion.insert(
        goldenId: effect.goldenId,
        multiplier: effect.multiplier,
        expiresAt: effect.expiresAt,
        singletonId: const Value(0),
      );
    }

    return GameStateCompanions(
      meta: meta,
      activeBoost: activeBoost,
      countries: countries,
      continents: continents,
      continentMilestones: continentMilestones,
      earnedAchievements: earnedAchievements,
      activeGlobalUpgrades: activeGlobalUpgrades,
      activeGoldens: activeGoldens,
      activeMissions: activeMissions,
      completedMissions: completedMissions,
      dailyStreak: dailyStreak,
      activeGoldenEffect: activeGoldenEffectCompanion,
    );
  }

  GameState fromRows(GameStateRows rows, ContentRegistry content) {
    if (rows.meta == null) {
      return GameState.initialSeed(content);
    }

    final m = rows.meta!;

    final byCountryId = {for (final r in rows.countries) r.id: r};
    final countryIdsSorted = content.countries.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final countries = <CountryId, CountryState>{};
    for (final id in countryIdsSorted) {
      final row = byCountryId[id.value];
      if (row == null) {
        countries[id] = CountryState(
          id: id,
          unlocked: false,
          ipLevel: 0,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
          lastCollectedAt: null,
        );
      } else {
        countries[id] = CountryState(
          id: id,
          unlocked: row.unlocked,
          ipLevel: row.ipLevel,
          leaderTier: _leaderTierFromDb(row.leaderTier),
          bankedInfluence: Influence(row.bankedInfluence),
          lastCollectedAt: row.lastCollectedAt,
        );
      }
    }

    final unlockedContinents = <ContinentId, bool>{};
    final continentCompletions = <ContinentId, bool>{};
    for (final r in rows.continents) {
      final id = ContinentId(r.id);
      if (!content.continents.containsKey(id)) continue;
      if (r.unlocked) {
        unlockedContinents[id] = true;
      }
      if (r.completed) {
        continentCompletions[id] = true;
      }
    }

    final reachedMilestones = <ContinentId, Set<int>>{};
    for (final r in rows.continentMilestones) {
      final id = ContinentId(r.continentId);
      reachedMilestones.putIfAbsent(id, () => <int>{}).add(r.milestone);
    }

    final earnedAchievementIds = rows.earnedAchievements
        .map((r) => r.id)
        .toSet();
    final activeGlobalUpgradeIds = rows.activeGlobalUpgrades
        .map((r) => r.id)
        .toSet();

    final activeGoldens = <String, ActiveGolden>{
      for (final r in rows.activeGoldens)
        r.id: ActiveGolden(
          id: r.id,
          countryId: CountryId(r.countryId),
          multiplier: r.multiplier,
          expiresAt: r.expiresAt,
        ),
    };

    final rowFx = rows.activeGoldenEffect;
    final ActiveGoldenEffect? activeGoldenEffect;
    if (rowFx == null) {
      activeGoldenEffect = null;
    } else {
      activeGoldenEffect = ActiveGoldenEffect(
        goldenId: rowFx.goldenId,
        multiplier: rowFx.multiplier,
        expiresAt: rowFx.expiresAt,
      );
    }

    final rowBoost = rows.activeBoost;
    final BoostState? activeBoost;
    if (rowBoost == null) {
      activeBoost = null;
    } else {
      activeBoost = BoostState(
        multiplier: rowBoost.multiplier,
        expiresAt: rowBoost.expiresAt,
      );
    }

    final activeMissions = rows.activeMissions.toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    final missions = <MissionState>[
      for (final r in activeMissions)
        MissionState(
          id: r.id,
          progress: r.progress,
          target: r.target,
          rewardIntel: Intel(r.rewardIntel),
        ),
    ];

    final completedMissionIds = rows.completedMissions.map((r) => r.id).toSet();

    final rowDailyStreak = rows.dailyStreak;
    final dailyStreak = rowDailyStreak == null
        ? DailyStreak.empty
        : DailyStreak(
            day: rowDailyStreak.day,
            lastClaimDate: rowDailyStreak.lastClaimDate,
          );

    return GameState(
      countries: countries,
      totalInfluence: Influence(m.totalInfluence),
      totalIntel: Intel(m.totalIntel),
      dailyStreak: dailyStreak,
      activeMissions: missions,
      completedMissionIds: completedMissionIds,
      unlockedContinents: unlockedContinents,
      reachedMilestones: reachedMilestones,
      continentCompletions: continentCompletions,
      earnedAchievementIds: earnedAchievementIds,
      activeGlobalUpgradeIds: activeGlobalUpgradeIds,
      goldenOpportunityMultiplier: m.goldenOpportunityMultiplier,
      activeBoost: activeBoost,
      activeGoldens: activeGoldens,
      activeGoldenEffect: activeGoldenEffect,
    );
  }

  static LeaderTier _leaderTierFromDb(String raw) {
    try {
      return LeaderTier.values.byName(raw);
    } catch (_) {
      throw ContentLoadException('Invalid leaderTier in DB: $raw');
    }
  }
}
