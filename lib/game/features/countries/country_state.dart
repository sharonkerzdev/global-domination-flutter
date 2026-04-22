import 'package:meta/meta.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

@immutable
class CountryState {
  final CountryId id;
  final bool unlocked;
  final int ipLevel;
  final LeaderTier leaderTier;
  final Influence bankedInfluence;
  final DateTime? lastCollectedAt;

  const CountryState({
    required this.id,
    required this.unlocked,
    required this.ipLevel,
    required this.leaderTier,
    required this.bankedInfluence,
    this.lastCollectedAt,
  });

  CountryState copyWith({
    CountryId? id,
    bool? unlocked,
    int? ipLevel,
    LeaderTier? leaderTier,
    Influence? bankedInfluence,
    DateTime? lastCollectedAt,
  }) {
    return CountryState(
      id: id ?? this.id,
      unlocked: unlocked ?? this.unlocked,
      ipLevel: ipLevel ?? this.ipLevel,
      leaderTier: leaderTier ?? this.leaderTier,
      bankedInfluence: bankedInfluence ?? this.bankedInfluence,
      lastCollectedAt: lastCollectedAt ?? this.lastCollectedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountryState &&
          id == other.id &&
          unlocked == other.unlocked &&
          ipLevel == other.ipLevel &&
          leaderTier == other.leaderTier &&
          bankedInfluence == other.bankedInfluence &&
          lastCollectedAt == other.lastCollectedAt);

  @override
  int get hashCode => Object.hash(
    id,
    unlocked,
    ipLevel,
    leaderTier,
    bankedInfluence,
    lastCollectedAt,
  );

  @override
  String toString() =>
      'CountryState(id: $id, unlocked: $unlocked, ipLevel: $ipLevel, '
      'leaderTier: $leaderTier, bankedInfluence: $bankedInfluence, '
      'lastCollectedAt: $lastCollectedAt)';
}
