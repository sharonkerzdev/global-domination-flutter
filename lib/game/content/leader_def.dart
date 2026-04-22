import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_load_exception.dart';

@immutable
class LeaderDef {
  final String id;
  final String name;
  final List<Decimal> tierMultipliers;

  const LeaderDef({
    required this.id,
    required this.name,
    required this.tierMultipliers,
  });

  factory LeaderDef.fromJson(Map<String, dynamic> json) {
    try {
      final multipliers = (json['tierMultipliers'] as List<dynamic>)
          .map((e) => Decimal.parse(e as String))
          .toList();
      return LeaderDef(
        id: json['id'] as String,
        name: json['name'] as String,
        tierMultipliers: List.unmodifiable(multipliers),
      );
    } catch (e) {
      throw ContentLoadException('Failed to parse LeaderDef: $e');
    }
  }
}
