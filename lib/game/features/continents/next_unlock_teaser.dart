import 'package:meta/meta.dart';

import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

@immutable
class NextUnlockTeaser {
  final CountryId countryId;
  final Influence unlockCost;
  final ContinentId continent;

  const NextUnlockTeaser({
    required this.countryId,
    required this.unlockCost,
    required this.continent,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NextUnlockTeaser &&
          countryId == other.countryId &&
          unlockCost == other.unlockCost &&
          continent == other.continent);

  @override
  int get hashCode => Object.hash(countryId, unlockCost, continent);

  @override
  String toString() =>
      'NextUnlockTeaser(countryId: $countryId, unlockCost: $unlockCost, '
      'continent: $continent)';
}
