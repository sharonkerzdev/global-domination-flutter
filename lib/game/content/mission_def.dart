import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_load_exception.dart';

@immutable
class MissionDef {
  final String id;
  final String name;
  final String conditionType;
  final Map<String, dynamic> conditionParams;
  final Decimal rewardIntel;

  const MissionDef({
    required this.id,
    required this.name,
    required this.conditionType,
    required this.conditionParams,
    required this.rewardIntel,
  });

  factory MissionDef.fromJson(Map<String, dynamic> json) {
    try {
      return MissionDef(
        id: json['id'] as String,
        name: json['name'] as String,
        conditionType: json['conditionType'] as String,
        conditionParams: Map<String, dynamic>.unmodifiable(
          json['conditionParams'] as Map<String, dynamic>,
        ),
        rewardIntel: Decimal.parse(json['rewardIntel'] as String),
      );
    } catch (e) {
      throw ContentLoadException('Failed to parse MissionDef: $e');
    }
  }
}
