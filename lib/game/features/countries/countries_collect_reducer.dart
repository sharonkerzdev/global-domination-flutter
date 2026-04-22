import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/result.dart';

Result<(GameState, GameEvent?), GameError> collectInfluence(
  GameState state,
  TapCountry cmd, {
  required DateTime now,
}) {
  final country = state.countries[cmd.countryId];
  if (country == null) {
    return Result.failure(GameError.internalMissingCountry(id: cmd.countryId));
  }
  if (!country.unlocked) {
    return Result.failure(
      GameError.userLocked(reason: 'Country ${cmd.countryId.value} is locked'),
    );
  }
  if (country.bankedInfluence.isZero) {
    return Result.success((state, null));
  }
  final collected = country.bankedInfluence;
  final newCountry = country.copyWith(
    bankedInfluence: Influence.zero,
    lastCollectedAt: now,
  );
  final newState = state.copyWith(
    countries: {...state.countries, cmd.countryId: newCountry},
    totalInfluence: state.totalInfluence + collected,
  );
  final event = CountryTapped(
    now,
    countryId: cmd.countryId,
    collected: collected,
  );
  return Result.success((newState, event));
}
