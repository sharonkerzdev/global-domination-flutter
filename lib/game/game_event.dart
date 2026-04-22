import 'package:meta/meta.dart';

import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

@immutable
sealed class GameEvent {
  final DateTime at;
  const GameEvent(this.at);
}

final class Tick extends GameEvent {
  const Tick(super.at);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Tick && at == other.at);

  @override
  int get hashCode => at.hashCode;

  @override
  String toString() => 'Tick(at: $at)';
}

final class CountryTapped extends GameEvent {
  final CountryId countryId;
  final Influence collected;

  const CountryTapped(
    super.at, {
    required this.countryId,
    required this.collected,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountryTapped &&
          at == other.at &&
          countryId == other.countryId &&
          collected == other.collected);

  @override
  int get hashCode => Object.hash(at, countryId, collected);

  @override
  String toString() =>
      'CountryTapped(at: $at, countryId: $countryId, collected: $collected)';
}
