import 'package:global_domination/game/values/country_id.dart';

sealed class GameCommand {
  const GameCommand();
}

final class Noop extends GameCommand {
  const Noop();

  @override
  bool operator ==(Object other) => identical(this, other) || other is Noop;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Noop()';
}

final class TapCountry extends GameCommand {
  const TapCountry({required this.countryId});

  final CountryId countryId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TapCountry && countryId == other.countryId);

  @override
  int get hashCode => countryId.hashCode;

  @override
  String toString() => 'TapCountry(${countryId.value})';
}

final class PurchaseUpgrade extends GameCommand {
  const PurchaseUpgrade({required this.countryId, this.bulk = 1})
    : assert(bulk >= 1, 'bulk must be at least 1');

  final CountryId countryId;

  /// Number of levels to buy (1, 10, 25, …); capped in reducer by [BalanceConfig.maxIpLevel].
  final int bulk;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseUpgrade &&
          countryId == other.countryId &&
          bulk == other.bulk);

  @override
  int get hashCode => Object.hash(countryId, bulk);

  @override
  String toString() => 'PurchaseUpgrade(${countryId.value}, bulk: $bulk)';
}

final class HireLeader extends GameCommand {
  const HireLeader({required this.countryId});

  final CountryId countryId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HireLeader && countryId == other.countryId);

  @override
  int get hashCode => countryId.hashCode;

  @override
  String toString() => 'HireLeader(${countryId.value})';
}

final class UpgradeLeader extends GameCommand {
  const UpgradeLeader({required this.countryId});

  final CountryId countryId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpgradeLeader && countryId == other.countryId);

  @override
  int get hashCode => countryId.hashCode;

  @override
  String toString() => 'UpgradeLeader(${countryId.value})';
}
