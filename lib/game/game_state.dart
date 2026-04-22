import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

@immutable
class GameState {
  static final _continentCompletionEq = MapEquality<ContinentId, bool>();
  static final _stringSetEq = SetEquality<String>();

  final Map<CountryId, CountryState> countries;
  final Influence totalInfluence;
  final Map<ContinentId, bool> continentCompletions;
  final Set<String> earnedAchievementIds;
  final Set<String> activeGlobalUpgradeIds;
  final Decimal goldenOpportunityMultiplier;
  final Decimal boostMultiplier;

  GameState({
    Map<CountryId, CountryState>? countries,
    Influence? totalInfluence,
    Map<ContinentId, bool>? continentCompletions,
    Set<String>? earnedAchievementIds,
    Set<String>? activeGlobalUpgradeIds,
    Decimal? goldenOpportunityMultiplier,
    Decimal? boostMultiplier,
  }) : countries = countries ?? const {},
       totalInfluence = totalInfluence ?? Influence.zero,
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
       boostMultiplier = boostMultiplier ?? Decimal.one;

  GameState copyWith({
    Map<CountryId, CountryState>? countries,
    Influence? totalInfluence,
    Map<ContinentId, bool>? continentCompletions,
    Set<String>? earnedAchievementIds,
    Set<String>? activeGlobalUpgradeIds,
    Decimal? goldenOpportunityMultiplier,
    Decimal? boostMultiplier,
  }) {
    return GameState(
      countries: countries ?? this.countries,
      totalInfluence: totalInfluence ?? this.totalInfluence,
      continentCompletions: continentCompletions ?? this.continentCompletions,
      earnedAchievementIds: earnedAchievementIds ?? this.earnedAchievementIds,
      activeGlobalUpgradeIds:
          activeGlobalUpgradeIds ?? this.activeGlobalUpgradeIds,
      goldenOpportunityMultiplier:
          goldenOpportunityMultiplier ?? this.goldenOpportunityMultiplier,
      boostMultiplier: boostMultiplier ?? this.boostMultiplier,
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
    return GameState(
      countries: Map.unmodifiable(countries),
      totalInfluence: Influence.zero,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameState &&
          _mapsEqual(countries, other.countries) &&
          totalInfluence == other.totalInfluence &&
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
          boostMultiplier == other.boostMultiplier);

  @override
  int get hashCode => Object.hash(
    _mapHash(countries),
    totalInfluence,
    _continentCompletionEq.hash(continentCompletions),
    _stringSetEq.hash(earnedAchievementIds),
    _stringSetEq.hash(activeGlobalUpgradeIds),
    goldenOpportunityMultiplier,
    boostMultiplier,
  );

  @override
  String toString() =>
      'GameState(countries: ${countries.length} entries, '
      'totalInfluence: $totalInfluence, '
      'continentCompletions: ${continentCompletions.length}, '
      'earnedAchievementIds: ${earnedAchievementIds.length}, '
      'activeGlobalUpgradeIds: ${activeGlobalUpgradeIds.length}, '
      'goldenOpportunityMultiplier: $goldenOpportunityMultiplier, '
      'boostMultiplier: $boostMultiplier)';

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
