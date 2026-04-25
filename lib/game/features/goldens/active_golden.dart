import 'package:meta/meta.dart';

import 'package:global_domination/game/values/country_id.dart';

@immutable
class ActiveGolden {
  const ActiveGolden({
    required this.id,
    required this.countryId,
    required this.multiplier,
    required this.expiresAt,
  });

  final String id;
  final CountryId countryId;
  final int multiplier;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveGolden &&
          id == other.id &&
          countryId == other.countryId &&
          multiplier == other.multiplier &&
          expiresAt == other.expiresAt);

  @override
  int get hashCode => Object.hash(id, countryId, multiplier, expiresAt);

  @override
  String toString() =>
      'ActiveGolden(id: $id, countryId: ${countryId.value}, '
      'multiplier: $multiplier, expiresAt: $expiresAt)';
}
