import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_load_exception.dart';

@immutable
class DailyRewardDef {
  final int day;
  final Decimal influenceReward;
  final Decimal intelReward;

  const DailyRewardDef({
    required this.day,
    required this.influenceReward,
    required this.intelReward,
  });

  factory DailyRewardDef.fromJson(Map<String, dynamic> json) {
    try {
      return DailyRewardDef(
        day: json['day'] as int,
        influenceReward: Decimal.parse(json['influenceReward'] as String),
        intelReward: Decimal.parse(json['intelReward'] as String),
      );
    } catch (e) {
      if (e is ContentLoadException) rethrow;
      throw ContentLoadException('Failed to parse DailyRewardDef: $e');
    }
  }
}
