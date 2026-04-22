import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';

@immutable
class CountryDef {
  final CountryId id;
  final ContinentId continent;
  final Decimal baseInfluence;
  final Decimal unlockCost;
  final int tier;
  final int generationSeconds;

  const CountryDef({
    required this.id,
    required this.continent,
    required this.baseInfluence,
    required this.unlockCost,
    required this.tier,
    required this.generationSeconds,
  });

  factory CountryDef.fromJson(Map<String, dynamic> json) {
    try {
      return CountryDef(
        id: CountryId(json['id'] as String),
        continent: ContinentId(json['continent'] as String),
        baseInfluence: Decimal.parse(json['baseInfluence'] as String),
        unlockCost: Decimal.parse(json['unlockCost'] as String),
        tier: json['tier'] as int,
        generationSeconds: json['generationSeconds'] as int,
      );
    } catch (e) {
      throw ContentLoadException('Failed to parse CountryDef: $e');
    }
  }
}
