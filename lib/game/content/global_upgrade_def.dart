import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/content_load_exception.dart';

@immutable
class GlobalUpgradeDef {
  final String id;
  final String name;
  final Decimal influenceAmplifier;

  const GlobalUpgradeDef({
    required this.id,
    required this.name,
    required this.influenceAmplifier,
  });

  factory GlobalUpgradeDef.fromJson(Map<String, dynamic> json) {
    try {
      return GlobalUpgradeDef(
        id: json['id'] as String,
        name: json['name'] as String,
        influenceAmplifier: Decimal.parse(json['influenceAmplifier'] as String),
      );
    } catch (e) {
      throw ContentLoadException('Failed to parse GlobalUpgradeDef: $e');
    }
  }
}
