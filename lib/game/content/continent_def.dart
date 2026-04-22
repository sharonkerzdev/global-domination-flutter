import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/values/continent_id.dart';

@immutable
class MilestoneReward {
  final int percent;
  final String rewardType;
  final Decimal rewardValue;

  const MilestoneReward({
    required this.percent,
    required this.rewardType,
    required this.rewardValue,
  });

  factory MilestoneReward.fromJson(Map<String, dynamic> json) {
    try {
      return MilestoneReward(
        percent: json['percent'] as int,
        rewardType: json['rewardType'] as String,
        rewardValue: Decimal.parse(json['rewardValue'] as String),
      );
    } catch (e) {
      throw ContentLoadException('Failed to parse MilestoneReward: $e');
    }
  }
}

@immutable
class ContinentDef {
  final ContinentId id;
  final String name;
  final Decimal unlockThreshold;
  final Decimal completionBonus;
  final List<MilestoneReward> milestoneRewards;

  const ContinentDef({
    required this.id,
    required this.name,
    required this.unlockThreshold,
    required this.completionBonus,
    required this.milestoneRewards,
  });

  factory ContinentDef.fromJson(Map<String, dynamic> json) {
    try {
      final rewards =
          (json['milestoneRewards'] as List<dynamic>?)
              ?.map((e) => MilestoneReward.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <MilestoneReward>[];
      return ContinentDef(
        id: ContinentId(json['id'] as String),
        name: json['name'] as String,
        unlockThreshold: Decimal.parse(json['unlockThreshold'] as String),
        completionBonus: Decimal.parse(json['completionBonus'] as String),
        milestoneRewards: List.unmodifiable(rewards),
      );
    } catch (e) {
      if (e is ContentLoadException) rethrow;
      throw ContentLoadException('Failed to parse ContinentDef: $e');
    }
  }
}
