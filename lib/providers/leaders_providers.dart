import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/upgrades_providers.dart'
    show countryDisplayName;

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

enum LeaderRowAction {
  reachIp10First,
  hire,
  upgradeToTier2,
  upgradeToTier3,
  maxTier,
}

enum ApproachingThreshold { none, hire, tier2, tier3 }

@immutable
class CountryLeaderRow {
  final CountryId countryId;
  final String displayName;
  final int ipLevel;
  final LeaderTier currentTier;
  final LeaderRowAction action;
  final Influence? actionCost;
  final bool canAfford;
  final ApproachingThreshold approaching;

  const CountryLeaderRow({
    required this.countryId,
    required this.displayName,
    required this.ipLevel,
    required this.currentTier,
    required this.action,
    required this.actionCost,
    required this.canAfford,
    required this.approaching,
  });
}

@immutable
class ContinentLeadersSection {
  final ContinentId continentId;
  final String continentName;
  final List<CountryLeaderRow> rows;
  final int hiredCount;
  final int totalCount;
  final bool hasAffordableAction;

  const ContinentLeadersSection({
    required this.continentId,
    required this.continentName,
    required this.rows,
    required this.hiredCount,
    required this.totalCount,
    required this.hasAffordableAction,
  });
}

@immutable
class LeadersTabModel {
  final List<ContinentLeadersSection> sections;

  const LeadersTabModel({required this.sections});

  bool get isEmpty => sections.isEmpty;
}

// ---------------------------------------------------------------------------
// Approaching-threshold windows (visual hint only, do NOT gate commands).
// ---------------------------------------------------------------------------
//
// Hire eligibility: IP >= BalanceConfig.leaderHireMinIpLevel (10). Window
// covers the two levels just below the gate: 8 and 9. Tier-2 / tier-3
// breakpoint windows mirror the epic doc's typical IP positions (48 / 98).
const int _kApproachingHireLowestIp = 8;
const int _kApproachingHireHighestIp = 9;
const int _kApproachingTier2LowestIp = 46;
const int _kApproachingTier2HighestIp = 47;
const int _kApproachingTier3LowestIp = 96;
const int _kApproachingTier3HighestIp = 97;

ApproachingThreshold _approachingFor(int ipLevel, LeaderTier tier) {
  switch (tier) {
    case LeaderTier.none:
      if (ipLevel >= _kApproachingHireLowestIp &&
          ipLevel <= _kApproachingHireHighestIp) {
        return ApproachingThreshold.hire;
      }
      return ApproachingThreshold.none;
    case LeaderTier.tier1:
      if (ipLevel >= _kApproachingTier2LowestIp &&
          ipLevel <= _kApproachingTier2HighestIp) {
        return ApproachingThreshold.tier2;
      }
      return ApproachingThreshold.none;
    case LeaderTier.tier2:
      if (ipLevel >= _kApproachingTier3LowestIp &&
          ipLevel <= _kApproachingTier3HighestIp) {
        return ApproachingThreshold.tier3;
      }
      return ApproachingThreshold.none;
    case LeaderTier.tier3:
      return ApproachingThreshold.none;
  }
}

// ---------------------------------------------------------------------------
// Narrow GameState projection — keeps tab rebuilds insensitive to banked
// influence and other unrelated state slots.
// ---------------------------------------------------------------------------

@immutable
class _CountryLeaderState {
  const _CountryLeaderState({
    required this.unlocked,
    required this.ipLevel,
    required this.leaderTier,
  });

  final bool unlocked;
  final int ipLevel;
  final LeaderTier leaderTier;

  static _CountryLeaderState fromCountry(CountryState c) {
    return _CountryLeaderState(
      unlocked: c.unlocked,
      ipLevel: c.ipLevel,
      leaderTier: c.leaderTier,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CountryLeaderState &&
          unlocked == other.unlocked &&
          ipLevel == other.ipLevel &&
          leaderTier == other.leaderTier);

  @override
  int get hashCode => Object.hash(unlocked, ipLevel, leaderTier);
}

@immutable
class _LeadersStateSlice {
  static const _countriesEq = MapEquality<CountryId, _CountryLeaderState>();
  static const _continentEq = MapEquality<ContinentId, bool>();

  const _LeadersStateSlice({
    required this.countries,
    required this.totalInfluence,
    required this.unlockedContinents,
  });

  final Map<CountryId, _CountryLeaderState> countries;
  final Influence totalInfluence;
  final Map<ContinentId, bool> unlockedContinents;

  static _LeadersStateSlice fromState(GameState state) {
    return _LeadersStateSlice(
      countries: Map<CountryId, _CountryLeaderState>.unmodifiable({
        for (final entry in state.countries.entries)
          entry.key: _CountryLeaderState.fromCountry(entry.value),
      }),
      totalInfluence: state.totalInfluence,
      unlockedContinents: Map<ContinentId, bool>.unmodifiable({
        ...state.unlockedContinents,
      }),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _LeadersStateSlice &&
          _countriesEq.equals(countries, other.countries) &&
          totalInfluence == other.totalInfluence &&
          _continentEq.equals(unlockedContinents, other.unlockedContinents));

  @override
  int get hashCode => Object.hashAll([
    _countriesEq.hash(countries),
    totalInfluence,
    _continentEq.hash(unlockedContinents),
  ]);
}

// ---------------------------------------------------------------------------
// Pure builder
// ---------------------------------------------------------------------------

LeadersTabModel _buildLeadersTabModel(
  _LeadersStateSlice slice,
  ContentRegistry content,
) {
  final sortedContinents = content.continents.values.toList()
    ..sort((a, b) {
      final t = a.unlockThreshold.compareTo(b.unlockThreshold);
      if (t != 0) return t;
      return a.id.value.compareTo(b.id.value);
    });

  final sections = <ContinentLeadersSection>[];

  for (final continent in sortedContinents) {
    if (slice.unlockedContinents[continent.id] != true) continue;

    final rows = <CountryLeaderRow>[];
    var hiredCount = 0;
    var hasAffordable = false;

    for (final def in content.countries.values) {
      if (def.continent != continent.id) continue;
      final cs = slice.countries[def.id];
      if (cs == null || !cs.unlocked) continue;

      final tier = cs.leaderTier;
      final ip = cs.ipLevel;

      LeaderRowAction action;
      Influence? cost;

      if (tier == LeaderTier.none && ip < BalanceConfig.leaderHireMinIpLevel) {
        action = LeaderRowAction.reachIp10First;
        cost = null;
      } else if (tier == LeaderTier.none) {
        action = LeaderRowAction.hire;
        cost = IncomeCalculator.leaderHireCost(def);
      } else if (tier == LeaderTier.tier1) {
        action = LeaderRowAction.upgradeToTier2;
        cost = IncomeCalculator.leaderUpgradeCost(def, LeaderTier.tier1);
      } else if (tier == LeaderTier.tier2) {
        action = LeaderRowAction.upgradeToTier3;
        cost = IncomeCalculator.leaderUpgradeCost(def, LeaderTier.tier2);
      } else {
        action = LeaderRowAction.maxTier;
        cost = null;
      }

      final canAfford = cost != null && slice.totalInfluence >= cost;
      final approaching = _approachingFor(ip, tier);

      if (tier != LeaderTier.none) hiredCount += 1;
      if (canAfford &&
          (action == LeaderRowAction.hire ||
              action == LeaderRowAction.upgradeToTier2 ||
              action == LeaderRowAction.upgradeToTier3)) {
        hasAffordable = true;
      }

      rows.add(
        CountryLeaderRow(
          countryId: def.id,
          displayName: countryDisplayName(def.id),
          ipLevel: ip,
          currentTier: tier,
          action: action,
          actionCost: cost,
          canAfford: canAfford,
          approaching: approaching,
        ),
      );
    }

    sections.add(
      ContinentLeadersSection(
        continentId: continent.id,
        continentName: continent.name,
        rows: List.unmodifiable(rows),
        hiredCount: hiredCount,
        totalCount: rows.length,
        hasAffordableAction: hasAffordable,
      ),
    );
  }

  return LeadersTabModel(sections: List.unmodifiable(sections));
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final leadersTabModelProvider = Provider<AsyncValue<LeadersTabModel>>((ref) {
  final contentAsync = ref.watch(contentRegistryProvider);
  return contentAsync.whenData((content) {
    final slice = ref.watch(
      gameWorldProvider.select(_LeadersStateSlice.fromState),
    );
    return _buildLeadersTabModel(slice, content);
  });
});
