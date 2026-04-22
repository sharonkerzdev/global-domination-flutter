import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_load_exception.dart';

@immutable
class AchievementDef {
  final String id;
  final String name;
  final String conditionType;
  final Map<String, dynamic> conditionParams;
  final String rewardType;
  final Decimal rewardValue;

  const AchievementDef({
    required this.id,
    required this.name,
    required this.conditionType,
    required this.conditionParams,
    required this.rewardType,
    required this.rewardValue,
  });

  factory AchievementDef.fromJson(Map<String, dynamic> json) {
    try {
      return AchievementDef(
        id: json['id'] as String,
        name: json['name'] as String,
        conditionType: json['conditionType'] as String,
        conditionParams: Map<String, dynamic>.unmodifiable(
          json['conditionParams'] as Map<String, dynamic>,
        ),
        rewardType: json['rewardType'] as String,
        rewardValue: Decimal.parse(json['rewardValue'] as String),
      );
    } catch (e) {
      throw ContentLoadException('Failed to parse AchievementDef: $e');
    }
  }
}
