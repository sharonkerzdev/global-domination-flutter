import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/content/continent_def.dart';
import 'package:global_domination/game/features/boosts/boost_state.dart';
import 'package:global_domination/game/features/continents/next_unlock_selector.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';

// ---------------------------------------------------------------------------
// Display-name helper
// ---------------------------------------------------------------------------

/// Derives a player-visible country name from a raw id like `united_states`
/// or `ivory-coast` → `United States` / `Ivory Coast`.
String countryDisplayName(CountryId id) {
  return id.value
      .split(RegExp(r'[_\-]'))
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

enum TeaserKind {
  nextUnlock,
  continentComplete,
  futureContinent,
  worldComplete,
}

@immutable
class NextUnlockTeaserRow {
  final CountryId? countryId;
  final String? countryName;
  final Influence? unlockCost;
  final bool canAfford;
  final TeaserKind kind;

  const NextUnlockTeaserRow({
    required this.kind,
    this.countryId,
    this.countryName,
    this.unlockCost,
    required this.canAfford,
  });
}

@immutable
class CountryUpgradeRow {
  final CountryId countryId;
  final String displayName;
  final int ipLevel;
  final bool isMaxLevel;
  final Influence currentRate;

  const CountryUpgradeRow({
    required this.countryId,
    required this.displayName,
    required this.ipLevel,
    required this.isMaxLevel,
    required this.currentRate,
  });
}

@immutable
class ContinentUpgradeSection {
  final ContinentId continentId;
  final String continentName;
  final int ownedCount;
  final int totalCount;
  final Set<int> reachedMilestoneTiers;
  final List<CountryUpgradeRow> countries;
  final NextUnlockTeaserRow teaser;

  const ContinentUpgradeSection({
    required this.continentId,
    required this.continentName,
    required this.ownedCount,
    required this.totalCount,
    required this.reachedMilestoneTiers,
    required this.countries,
    required this.teaser,
  });
}

@immutable
class UpgradesTabModel {
  final List<ContinentUpgradeSection> sections;

  const UpgradesTabModel({required this.sections});

  bool get isEmpty => sections.isEmpty;
}

// ---------------------------------------------------------------------------
// Purchase preview helper
// ---------------------------------------------------------------------------

@immutable
class UpgradePurchasePreview {
  final int actualLevels;
  final Influence? cost;
  final bool canAfford;

  const UpgradePurchasePreview({
    required this.actualLevels,
    required this.cost,
    required this.canAfford,
  });

  bool get isDisabled => actualLevels < 1 || cost == null || !canAfford;
}

// ---------------------------------------------------------------------------
// Narrow GameState projection
// ---------------------------------------------------------------------------

@immutable
class _CountryUpgradeState {
  const _CountryUpgradeState({
    required this.unlocked,
    required this.ipLevel,
    required this.leaderTier,
  });

  final bool unlocked;
  final int ipLevel;
  final LeaderTier leaderTier;

  static _CountryUpgradeState fromCountry(CountryState country) {
    return _CountryUpgradeState(
      unlocked: country.unlocked,
      ipLevel: country.ipLevel,
      leaderTier: country.leaderTier,
    );
  }

  CountryState toCountryState(CountryId id) {
    return CountryState(
      id: id,
      unlocked: unlocked,
      ipLevel: ipLevel,
      leaderTier: leaderTier,
      bankedInfluence: Influence.zero,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CountryUpgradeState &&
          unlocked == other.unlocked &&
          ipLevel == other.ipLevel &&
          leaderTier == other.leaderTier);

  @override
  int get hashCode => Object.hash(unlocked, ipLevel, leaderTier);
}

@immutable
class _UpgradesStateSlice {
  static const _countriesEq = MapEquality<CountryId, _CountryUpgradeState>();
  static const _continentEq = MapEquality<ContinentId, bool>();
  static const _stringSetEq = SetEquality<String>();
  static final _reachedMilestonesEq = MapEquality<ContinentId, Set<int>>(
    values: const SetEquality<int>(),
  );
  static final DateTime _syntheticBoostExpiry =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  const _UpgradesStateSlice({
    required this.countries,
    required this.totalInfluence,
    required this.unlockedContinents,
    required this.continentCompletions,
    required this.earnedAchievementIds,
    required this.activeGlobalUpgradeIds,
    required this.goldenOpportunityMultiplier,
    required this.boostMultiplier,
    required this.reachedMilestones,
  });

  final Map<CountryId, _CountryUpgradeState> countries;
  final Influence totalInfluence;
  final Map<ContinentId, bool> unlockedContinents;
  final Map<ContinentId, bool> continentCompletions;
  final Set<String> earnedAchievementIds;
  final Set<String> activeGlobalUpgradeIds;
  final Decimal goldenOpportunityMultiplier;
  final Decimal? boostMultiplier;
  final Map<ContinentId, Set<int>> reachedMilestones;

  static _UpgradesStateSlice fromState(GameState state) {
    return _UpgradesStateSlice(
      countries: Map<CountryId, _CountryUpgradeState>.unmodifiable({
        for (final entry in state.countries.entries)
          entry.key: _CountryUpgradeState.fromCountry(entry.value),
      }),
      totalInfluence: state.totalInfluence,
      unlockedContinents: Map<ContinentId, bool>.unmodifiable({
        ...state.unlockedContinents,
      }),
      continentCompletions: Map<ContinentId, bool>.unmodifiable({
        ...state.continentCompletions,
      }),
      earnedAchievementIds: Set<String>.unmodifiable({
        ...state.earnedAchievementIds,
      }),
      activeGlobalUpgradeIds: Set<String>.unmodifiable({
        ...state.activeGlobalUpgradeIds,
      }),
      goldenOpportunityMultiplier: state.goldenOpportunityMultiplier,
      boostMultiplier: state.activeBoost?.multiplier,
      reachedMilestones: Map<ContinentId, Set<int>>.unmodifiable({
        for (final entry in state.reachedMilestones.entries)
          entry.key: Set<int>.unmodifiable(entry.value),
      }),
    );
  }

  GameState toGameState() {
    return GameState(
      countries: Map<CountryId, CountryState>.unmodifiable({
        for (final entry in countries.entries)
          entry.key: entry.value.toCountryState(entry.key),
      }),
      totalInfluence: totalInfluence,
      unlockedContinents: unlockedContinents,
      continentCompletions: continentCompletions,
      earnedAchievementIds: earnedAchievementIds,
      activeGlobalUpgradeIds: activeGlobalUpgradeIds,
      goldenOpportunityMultiplier: goldenOpportunityMultiplier,
      activeBoost: boostMultiplier == null
          ? null
          : BoostState(
              multiplier: boostMultiplier!,
              expiresAt: _syntheticBoostExpiry,
            ),
      reachedMilestones: reachedMilestones,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _UpgradesStateSlice &&
          _countriesEq.equals(countries, other.countries) &&
          totalInfluence == other.totalInfluence &&
          _continentEq.equals(unlockedContinents, other.unlockedContinents) &&
          _continentEq.equals(
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
          boostMultiplier == other.boostMultiplier &&
          _reachedMilestonesEq.equals(
            reachedMilestones,
            other.reachedMilestones,
          ));

  @override
  int get hashCode => Object.hashAll([
    _countriesEq.hash(countries),
    totalInfluence,
    _continentEq.hash(unlockedContinents),
    _continentEq.hash(continentCompletions),
    _stringSetEq.hash(earnedAchievementIds),
    _stringSetEq.hash(activeGlobalUpgradeIds),
    goldenOpportunityMultiplier,
    boostMultiplier,
    _reachedMilestonesEq.hash(reachedMilestones),
  ]);
}

UpgradePurchasePreview upgradePurchasePreview(
  CountryUpgradeRow row,
  int selectedBulk,
  Influence totalInfluence,
  ContentRegistry content,
) {
  if (row.isMaxLevel) {
    return const UpgradePurchasePreview(
      actualLevels: 0,
      cost: null,
      canAfford: false,
    );
  }
  final actualLevels = (selectedBulk).clamp(
    0,
    BalanceConfig.maxIpLevel - row.ipLevel,
  );
  if (actualLevels < 1) {
    return const UpgradePurchasePreview(
      actualLevels: 0,
      cost: null,
      canAfford: false,
    );
  }
  final def = content.countries[row.countryId];
  if (def == null) {
    return UpgradePurchasePreview(
      actualLevels: actualLevels,
      cost: null,
      canAfford: false,
    );
  }
  final cost = IncomeCalculator.upgradeCost(def, row.ipLevel, actualLevels);
  return UpgradePurchasePreview(
    actualLevels: actualLevels,
    cost: cost,
    canAfford: totalInfluence >= cost,
  );
}

// ---------------------------------------------------------------------------
// Main provider
// ---------------------------------------------------------------------------

UpgradesTabModel _buildUpgradesTabModel(
  GameState state,
  ContentRegistry content,
) {
  // Sort continents by unlockThreshold asc, then id for determinism
  final sortedContinents = content.continents.values.toList()
    ..sort((a, b) {
      final t = a.unlockThreshold.compareTo(b.unlockThreshold);
      if (t != 0) return t;
      return a.id.value.compareTo(b.id.value);
    });

  final sections = <ContinentUpgradeSection>[];

  for (final continent in sortedContinents) {
    if (state.unlockedContinents[continent.id] != true) continue;

    final totalCount = content.countries.values
        .where((d) => d.continent == continent.id)
        .length;
    if (totalCount == 0) continue;

    // Collect unlocked country rows in content order
    final rows = <CountryUpgradeRow>[];
    for (final def in content.countries.values) {
      if (def.continent != continent.id) continue;
      final cs = state.countries[def.id];
      if (cs == null || !cs.unlocked) continue;

      final isMax = cs.ipLevel >= BalanceConfig.maxIpLevel;
      final rate = IncomeCalculator.compute(cs, state, content);

      rows.add(
        CountryUpgradeRow(
          countryId: def.id,
          displayName: countryDisplayName(def.id),
          ipLevel: cs.ipLevel,
          isMaxLevel: isMax,
          currentRate: rate,
        ),
      );
    }

    // Build teaser
    final teaser = _buildTeaser(state, content, continent);

    // Compute owned count from unlocked rows.
    final ownedCount = rows.length;
    final reachedTiers = state.reachedMilestones[continent.id] ?? const <int>{};

    sections.add(
      ContinentUpgradeSection(
        continentId: continent.id,
        continentName: continent.name,
        ownedCount: ownedCount,
        totalCount: totalCount,
        reachedMilestoneTiers: reachedTiers,
        countries: List.unmodifiable(rows),
        teaser: teaser,
      ),
    );
  }

  return UpgradesTabModel(sections: List.unmodifiable(sections));
}

NextUnlockTeaserRow _buildTeaser(
  GameState state,
  ContentRegistry content,
  ContinentDef continent,
) {
  final sameContinentTeaser = nextUnlockInContinent(
    state,
    content,
    continent.id,
  );

  if (sameContinentTeaser != null) {
    final canAfford = state.totalInfluence >= sameContinentTeaser.unlockCost;
    return NextUnlockTeaserRow(
      kind: TeaserKind.nextUnlock,
      countryId: sameContinentTeaser.countryId,
      countryName: countryDisplayName(sameContinentTeaser.countryId),
      unlockCost: sameContinentTeaser.unlockCost,
      canAfford: canAfford,
    );
  }

  // No more locked countries in this continent — check if world is complete
  final anyLockedGlobally = content.countries.values.any((def) {
    final cs = state.countries[def.id];
    return cs == null || !cs.unlocked;
  });

  if (!anyLockedGlobally) {
    return const NextUnlockTeaserRow(
      kind: TeaserKind.worldComplete,
      canAfford: false,
    );
  }

  // There are locked countries but in other continents
  // Optionally hint at the future continent via nextUnlockOverall
  final overall = nextUnlockOverall(state, content);
  if (overall != null && overall.continent != continent.id) {
    final futureContinentDef = content.continents[overall.continent];
    return NextUnlockTeaserRow(
      kind: TeaserKind.futureContinent,
      countryName: futureContinentDef?.name,
      canAfford: false,
    );
  }

  return const NextUnlockTeaserRow(
    kind: TeaserKind.continentComplete,
    canAfford: false,
  );
}

final upgradesTabModelProvider = Provider<AsyncValue<UpgradesTabModel>>((ref) {
  final contentAsync = ref.watch(contentRegistryProvider);
  return contentAsync.whenData((content) {
    final slice = ref.watch(
      gameWorldProvider.select(_UpgradesStateSlice.fromState),
    );
    return _buildUpgradesTabModel(slice.toGameState(), content);
  });
});
