import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/features/missions/mission_state.dart';
import 'package:global_domination/game/features/missions/missions_seed.dart';
import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/features/goldens/active_golden_effect.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

@immutable
class GameState {
  static const Object _activeBoostUnchanged = Object();
  static const Object _activeGoldenEffectUnchanged = Object();

  static final _continentCompletionEq = MapEquality<ContinentId, bool>();
  static final _unlockedContinentsEq = MapEquality<ContinentId, bool>();
  static final _reachedMilestonesEq = MapEquality<ContinentId, Set<int>>(
    values: SetEquality<int>(),
  );
  static final _activeGoldensEq = MapEquality<String, ActiveGolden>();
  static final _stringSetEq = SetEquality<String>();
  static final _activeMissionsEq = ListEquality<MissionState>();

  final Map<CountryId, CountryState> countries;
  final Influence totalInfluence;
  final Intel totalIntel;
  final DailyStreak dailyStreak;
  final List<MissionState> activeMissions;
  final Set<String> completedMissionIds;
  final Map<ContinentId, bool> unlockedContinents;
  final Map<ContinentId, Set<int>> reachedMilestones;
  final Map<ContinentId, bool> continentCompletions;
  final Set<String> earnedAchievementIds;
  final Set<String> activeGlobalUpgradeIds;
  final Decimal goldenOpportunityMultiplier;
  final BoostState? activeBoost;
  final Map<String, ActiveGolden> activeGoldens;
  final ActiveGoldenEffect? activeGoldenEffect;

  GameState({
    Map<CountryId, CountryState>? countries,
    Influence? totalInfluence,
    Intel? totalIntel,
    DailyStreak? dailyStreak,
    Map<ContinentId, bool>? unlockedContinents,
    Map<ContinentId, Set<int>>? reachedMilestones,
    Map<ContinentId, bool>? continentCompletions,
    Set<String>? earnedAchievementIds,
    Set<String>? activeGlobalUpgradeIds,
    Decimal? goldenOpportunityMultiplier,
    this.activeBoost,
    Map<String, ActiveGolden>? activeGoldens,
    this.activeGoldenEffect,
    List<MissionState>? activeMissions,
    Set<String>? completedMissionIds,
  }) : countries = countries ?? const {},
       totalInfluence = totalInfluence ?? Influence.zero,
       totalIntel = totalIntel ?? Intel.zero,
       dailyStreak = dailyStreak ?? DailyStreak.empty,
       activeMissions = List.unmodifiable(activeMissions ?? const []),
       completedMissionIds = Set.unmodifiable(
         completedMissionIds ?? const <String>{},
       ),
       unlockedContinents = Map.unmodifiable(
         unlockedContinents ?? const <ContinentId, bool>{},
       ),
       reachedMilestones = Map.unmodifiable({
         for (final e
             in (reachedMilestones ?? const <ContinentId, Set<int>>{}).entries)
           e.key: Set.unmodifiable({...e.value}),
       }),
       continentCompletions = Map.unmodifiable(
         continentCompletions ?? const <ContinentId, bool>{},
       ),
       earnedAchievementIds = Set.unmodifiable(
         earnedAchievementIds ?? const <String>{},
       ),
       activeGlobalUpgradeIds = Set.unmodifiable(
         activeGlobalUpgradeIds ?? const <String>{},
       ),
       goldenOpportunityMultiplier = goldenOpportunityMultiplier ?? Decimal.one,
       activeGoldens = Map.unmodifiable(
         activeGoldens ?? const <String, ActiveGolden>{},
       );

  GameState copyWith({
    Map<CountryId, CountryState>? countries,
    Influence? totalInfluence,
    Intel? totalIntel,
    DailyStreak? dailyStreak,
    Map<ContinentId, bool>? unlockedContinents,
    Map<ContinentId, Set<int>>? reachedMilestones,
    Map<ContinentId, bool>? continentCompletions,
    Set<String>? earnedAchievementIds,
    Set<String>? activeGlobalUpgradeIds,
    Decimal? goldenOpportunityMultiplier,
    Object? activeBoost = _activeBoostUnchanged,
    Map<String, ActiveGolden>? activeGoldens,
    Object? activeGoldenEffect = _activeGoldenEffectUnchanged,
    List<MissionState>? activeMissions,
    Set<String>? completedMissionIds,
  }) {
    return GameState(
      countries: countries ?? this.countries,
      totalInfluence: totalInfluence ?? this.totalInfluence,
      totalIntel: totalIntel ?? this.totalIntel,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      activeMissions: activeMissions ?? this.activeMissions,
      completedMissionIds: completedMissionIds ?? this.completedMissionIds,
      unlockedContinents: unlockedContinents ?? this.unlockedContinents,
      reachedMilestones: reachedMilestones ?? this.reachedMilestones,
      continentCompletions: continentCompletions ?? this.continentCompletions,
      earnedAchievementIds: earnedAchievementIds ?? this.earnedAchievementIds,
      activeGlobalUpgradeIds:
          activeGlobalUpgradeIds ?? this.activeGlobalUpgradeIds,
      goldenOpportunityMultiplier:
          goldenOpportunityMultiplier ?? this.goldenOpportunityMultiplier,
      activeBoost: identical(activeBoost, _activeBoostUnchanged)
          ? this.activeBoost
          : activeBoost as BoostState?,
      activeGoldens: activeGoldens ?? this.activeGoldens,
      activeGoldenEffect:
          identical(activeGoldenEffect, _activeGoldenEffectUnchanged)
          ? this.activeGoldenEffect
          : activeGoldenEffect as ActiveGoldenEffect?,
    );
  }

  static GameState initialSeed(ContentRegistry content) {
    const seedCountryId = CountryId('egypt');
    assert(
      content.countries.containsKey(seedCountryId),
      'ContentRegistry must contain egypt to seed initial state',
    );
    final countries = <CountryId, CountryState>{
      for (final entry in content.countries.entries)
        entry.key: CountryState(
          id: entry.key,
          unlocked: entry.key == seedCountryId,
          ipLevel: entry.key == seedCountryId ? 1 : 0,
          leaderTier: LeaderTier.none,
          bankedInfluence: Influence.zero,
          lastCollectedAt: null,
        ),
    };
    final unlockedContinents = <ContinentId, bool>{
      for (final c in content.continents.values)
        if (c.unlockThreshold <= Decimal.zero) c.id: true,
    };
    return GameState(
      countries: Map.unmodifiable(countries),
      totalInfluence: Influence.zero,
      totalIntel: Intel.zero,
      dailyStreak: DailyStreak.empty,
      activeBoost: null,
      unlockedContinents: Map.unmodifiable(unlockedContinents),
      reachedMilestones: const <ContinentId, Set<int>>{},
      activeMissions: seedActiveMissions(content),
      completedMissionIds: const <String>{},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameState &&
          _mapsEqual(countries, other.countries) &&
          totalInfluence == other.totalInfluence &&
          totalIntel == other.totalIntel &&
          dailyStreak == other.dailyStreak &&
          _activeMissionsEq.equals(activeMissions, other.activeMissions) &&
          _stringSetEq.equals(completedMissionIds, other.completedMissionIds) &&
          _unlockedContinentsEq.equals(
            unlockedContinents,
            other.unlockedContinents,
          ) &&
          _reachedMilestonesEq.equals(
            reachedMilestones,
            other.reachedMilestones,
          ) &&
          _continentCompletionEq.equals(
            continentCompletions,
            other.continentCompletions,
          ) &&
          _stringSetEq.equals(
            earnedAchievementIds,
            other.earnedAchievementIds,
          ) &&
          _stringSetEq.equals(
            activeGlobalUpgradeIds,
            other.activeGlobalUpgradeIds,
          ) &&
          goldenOpportunityMultiplier == other.goldenOpportunityMultiplier &&
          activeBoost == other.activeBoost &&
          _activeGoldensEq.equals(activeGoldens, other.activeGoldens) &&
          activeGoldenEffect == other.activeGoldenEffect);

  @override
  int get hashCode => Object.hash(
    _mapHash(countries),
    totalInfluence,
    totalIntel,
    dailyStreak,
    _activeMissionsEq.hash(activeMissions),
    _stringSetEq.hash(completedMissionIds),
    _unlockedContinentsEq.hash(unlockedContinents),
    _reachedMilestonesEq.hash(reachedMilestones),
    _continentCompletionEq.hash(continentCompletions),
    _stringSetEq.hash(earnedAchievementIds),
    _stringSetEq.hash(activeGlobalUpgradeIds),
    goldenOpportunityMultiplier,
    activeBoost,
    _activeGoldensEq.hash(activeGoldens),
    activeGoldenEffect,
  );

  @override
  String toString() =>
      'GameState(countries: ${countries.length} entries, '
      'totalInfluence: $totalInfluence, '
      'totalIntel: $totalIntel, '
      'dailyStreak: $dailyStreak, '
      'activeMissions: ${activeMissions.length}, '
      'completedMissionIds: ${completedMissionIds.length}, '
      'unlockedContinents: ${unlockedContinents.length}, '
      'reachedMilestones: ${reachedMilestones.length}, '
      'continentCompletions: ${continentCompletions.length}, '
      'earnedAchievementIds: ${earnedAchievementIds.length}, '
      'activeGlobalUpgradeIds: ${activeGlobalUpgradeIds.length}, '
      'goldenOpportunityMultiplier: $goldenOpportunityMultiplier, '
      'activeBoost: $activeBoost, '
      'activeGoldens: ${activeGoldens.length}, '
      'activeGoldenEffect: $activeGoldenEffect)';

  static bool _mapsEqual(
    Map<CountryId, CountryState> a,
    Map<CountryId, CountryState> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static int _mapHash(Map<CountryId, CountryState> map) {
    var h = 0;
    for (final entry in map.entries) {
      h ^= Object.hash(entry.key, entry.value);
    }
    return h;
  }
}
