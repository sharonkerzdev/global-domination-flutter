import 'package:meta/meta.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

@immutable
sealed class GameEvent {
  final DateTime at;
  const GameEvent(this.at);
}

final class Tick extends GameEvent {
  const Tick(super.at);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Tick && at == other.at);

  @override
  int get hashCode => at.hashCode;

  @override
  String toString() => 'Tick(at: $at)';
}

final class CountryTapped extends GameEvent {
  final CountryId countryId;
  final Influence collected;

  const CountryTapped(
    super.at, {
    required this.countryId,
    required this.collected,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountryTapped &&
          at == other.at &&
          countryId == other.countryId &&
          collected == other.collected);

  @override
  int get hashCode => Object.hash(at, countryId, collected);

  @override
  String toString() =>
      'CountryTapped(at: $at, countryId: $countryId, collected: $collected)';
}

final class UpgradePurchased extends GameEvent {
  final CountryId countryId;
  final int levelsAdded;
  final int bulkRequested;
  final Influence totalCost;

  UpgradePurchased(
    super.at, {
    required this.countryId,
    required this.levelsAdded,
    required this.bulkRequested,
    required this.totalCost,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpgradePurchased &&
          at == other.at &&
          countryId == other.countryId &&
          levelsAdded == other.levelsAdded &&
          bulkRequested == other.bulkRequested &&
          totalCost == other.totalCost);

  @override
  int get hashCode =>
      Object.hash(at, countryId, levelsAdded, bulkRequested, totalCost);

  @override
  String toString() =>
      'UpgradePurchased(at: $at, countryId: $countryId, levelsAdded: $levelsAdded, '
      'bulkRequested: $bulkRequested, totalCost: $totalCost)';
}

final class LeaderHired extends GameEvent {
  final CountryId countryId;
  final Influence cost;
  final LeaderTier newTier;

  const LeaderHired(
    super.at, {
    required this.countryId,
    required this.cost,
    this.newTier = LeaderTier.tier1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LeaderHired &&
          at == other.at &&
          countryId == other.countryId &&
          cost == other.cost &&
          newTier == other.newTier);

  @override
  int get hashCode => Object.hash(at, countryId, cost, newTier);

  @override
  String toString() =>
      'LeaderHired(at: $at, countryId: $countryId, cost: $cost, newTier: $newTier)';
}

final class LeaderUpgraded extends GameEvent {
  final CountryId countryId;
  final Influence cost;
  final LeaderTier newTier;

  const LeaderUpgraded(
    super.at, {
    required this.countryId,
    required this.cost,
    required this.newTier,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LeaderUpgraded &&
          at == other.at &&
          countryId == other.countryId &&
          cost == other.cost &&
          newTier == other.newTier);

  @override
  int get hashCode => Object.hash(at, countryId, cost, newTier);

  @override
  String toString() =>
      'LeaderUpgraded(at: $at, countryId: $countryId, cost: $cost, newTier: $newTier)';
}

final class ContinentUnlocked extends GameEvent {
  final ContinentId continentId;

  const ContinentUnlocked(super.at, {required this.continentId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContinentUnlocked &&
          at == other.at &&
          continentId == other.continentId);

  @override
  int get hashCode => Object.hash(at, continentId);

  @override
  String toString() =>
      'ContinentUnlocked(at: $at, continentId: $continentId)';
}

final class CountryUnlocked extends GameEvent {
  final CountryId countryId;
  final ContinentId continent;
  final Influence cost;

  const CountryUnlocked(
    super.at, {
    required this.countryId,
    required this.continent,
    required this.cost,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountryUnlocked &&
          at == other.at &&
          countryId == other.countryId &&
          continent == other.continent &&
          cost == other.cost);

  @override
  int get hashCode => Object.hash(at, countryId, continent, cost);

  @override
  String toString() =>
      'CountryUnlocked(at: $at, countryId: $countryId, continent: $continent, '
      'cost: $cost)';
}
