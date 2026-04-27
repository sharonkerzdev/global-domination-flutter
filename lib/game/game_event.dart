import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

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

  const UpgradePurchased(
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
  String toString() => 'ContinentUnlocked(at: $at, continentId: $continentId)';
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

final class MilestoneReached extends GameEvent {
  final ContinentId continentId;
  final int percent;
  final String rewardType;
  final Decimal rewardValue;

  const MilestoneReached(
    super.at, {
    required this.continentId,
    required this.percent,
    required this.rewardType,
    required this.rewardValue,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MilestoneReached &&
          at == other.at &&
          continentId == other.continentId &&
          percent == other.percent &&
          rewardType == other.rewardType &&
          rewardValue == other.rewardValue);

  @override
  int get hashCode =>
      Object.hash(at, continentId, percent, rewardType, rewardValue);

  @override
  String toString() =>
      'MilestoneReached(at: $at, continentId: $continentId, percent: $percent, '
      'rewardType: $rewardType, rewardValue: $rewardValue)';
}

final class ContinentCompleted extends GameEvent {
  final ContinentId continentId;

  const ContinentCompleted(super.at, {required this.continentId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContinentCompleted &&
          at == other.at &&
          continentId == other.continentId);

  @override
  int get hashCode => Object.hash(at, continentId);

  @override
  String toString() => 'ContinentCompleted(at: $at, continentId: $continentId)';
}

final class GoldenSpawned extends GameEvent {
  const GoldenSpawned(
    super.at, {
    required this.goldenId,
    required this.countryId,
    required this.multiplier,
    required this.expiresAt,
  });

  final String goldenId;
  final CountryId countryId;
  final int multiplier;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoldenSpawned &&
          at == other.at &&
          goldenId == other.goldenId &&
          countryId == other.countryId &&
          multiplier == other.multiplier &&
          expiresAt == other.expiresAt);

  @override
  int get hashCode =>
      Object.hash(at, goldenId, countryId, multiplier, expiresAt);

  @override
  String toString() =>
      'GoldenSpawned(at: $at, goldenId: $goldenId, countryId: $countryId, '
      'multiplier: $multiplier, expiresAt: $expiresAt)';
}

final class GoldenClaimed extends GameEvent {
  const GoldenClaimed(
    super.at, {
    required this.goldenId,
    required this.countryId,
    required this.multiplier,
    required this.durationSeconds,
  });

  final String goldenId;
  final CountryId countryId;
  final int multiplier;
  final int durationSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoldenClaimed &&
          at == other.at &&
          goldenId == other.goldenId &&
          countryId == other.countryId &&
          multiplier == other.multiplier &&
          durationSeconds == other.durationSeconds);

  @override
  int get hashCode =>
      Object.hash(at, goldenId, countryId, multiplier, durationSeconds);

  @override
  String toString() =>
      'GoldenClaimed(at: $at, goldenId: $goldenId, countryId: $countryId, '
      'multiplier: $multiplier, durationSeconds: $durationSeconds)';
}

final class GoldenExpired extends GameEvent {
  const GoldenExpired(
    super.at, {
    required this.goldenId,
    required this.claimed,
  });

  final String goldenId;
  final bool claimed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoldenExpired &&
          at == other.at &&
          goldenId == other.goldenId &&
          claimed == other.claimed);

  @override
  int get hashCode => Object.hash(at, goldenId, claimed);

  @override
  String toString() =>
      'GoldenExpired(at: $at, goldenId: $goldenId, claimed: $claimed)';
}

final class BoostActivated extends GameEvent {
  const BoostActivated(
    super.at, {
    required this.multiplier,
    required this.expiresAt,
    required this.intelSpent,
  });

  final Decimal multiplier;
  final DateTime expiresAt;
  final Intel intelSpent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoostActivated &&
          at == other.at &&
          multiplier == other.multiplier &&
          expiresAt == other.expiresAt &&
          intelSpent == other.intelSpent);

  @override
  int get hashCode => Object.hash(at, multiplier, expiresAt, intelSpent);

  @override
  String toString() =>
      'BoostActivated(at: $at, multiplier: $multiplier, expiresAt: $expiresAt, '
      'intelSpent: $intelSpent)';
}

final class BoostExpired extends GameEvent {
  const BoostExpired(super.at);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BoostExpired && at == other.at);

  @override
  int get hashCode => at.hashCode;

  @override
  String toString() => 'BoostExpired(at: $at)';
}

final class MissionCompleted extends GameEvent {
  const MissionCompleted(
    super.at, {
    required this.missionId,
    required this.rewardIntel,
  });

  final String missionId;
  final Intel rewardIntel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissionCompleted &&
          at == other.at &&
          missionId == other.missionId &&
          rewardIntel == other.rewardIntel);

  @override
  int get hashCode => Object.hash(at, missionId, rewardIntel);

  @override
  String toString() =>
      'MissionCompleted(at: $at, missionId: $missionId, rewardIntel: $rewardIntel)';
}

final class MissionRotated extends GameEvent {
  const MissionRotated(
    super.at, {
    required this.oldMissionId,
    this.newMissionId,
  });

  final String oldMissionId;
  final String? newMissionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissionRotated &&
          at == other.at &&
          oldMissionId == other.oldMissionId &&
          newMissionId == other.newMissionId);

  @override
  int get hashCode => Object.hash(at, oldMissionId, newMissionId);

  @override
  String toString() =>
      'MissionRotated(at: $at, oldMissionId: $oldMissionId, '
      'newMissionId: $newMissionId)';
}

final class DailyRewardClaimed extends GameEvent {
  const DailyRewardClaimed(
    super.at, {
    required this.day,
    required this.influenceReward,
    required this.intelReward,
  });

  final int day;
  final Influence influenceReward;
  final Intel intelReward;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyRewardClaimed &&
          at == other.at &&
          day == other.day &&
          influenceReward == other.influenceReward &&
          intelReward == other.intelReward);

  @override
  int get hashCode => Object.hash(at, day, influenceReward, intelReward);

  @override
  String toString() =>
      'DailyRewardClaimed(at: $at, day: $day, influenceReward: '
      '$influenceReward, intelReward: $intelReward)';
}
