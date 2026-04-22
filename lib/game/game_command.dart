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
