import 'dart:async';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/countries_collect_reducer.dart';
import 'package:global_domination/game/features/countries/countries_reducer.dart';
import 'package:global_domination/game/features/leaders/leaders_reducer.dart';
import 'package:global_domination/game/features/upgrades/upgrades_reducer.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/values/result.dart';

class GameWorld {
  final Clock _clock;
  final ContentRegistry _content;
  GameState _state;
  final StreamController<GameEvent> _events =
      StreamController<GameEvent>.broadcast(sync: true);

  GameWorld({
    required ContentRegistry content,
    required Clock clock,
    GameState? initialState,
  }) : _clock = clock,
       _content = content,
       _state = initialState ?? GameState.initialSeed(content);

  GameState get state => _state;
  Stream<GameEvent> get events => _events.stream;

  void tick(Duration dt) {
    assert(!dt.isNegative, 'tick dt must be non-negative, got $dt');
    assert(dt.inMilliseconds <= 100, 'tick dt should be clamped to 100ms');

    final newCountries = tickCountries(_state, dt, _content);
    if (identical(newCountries, _state.countries)) return;

    _state = _state.copyWith(countries: newCountries);
    _events.add(Tick(_clock.now()));
  }

  Result<void, GameError> applyCommand(GameCommand cmd) {
    return switch (cmd) {
      Noop() => const Result.success(null),
      TapCountry() => _applyTapCountry(cmd),
      PurchaseUpgrade() => _applyPurchaseUpgrade(cmd),
      HireLeader() => _applyHireLeader(cmd),
      UpgradeLeader() => _applyUpgradeLeader(cmd),
    };
  }

  Result<void, GameError> _applyTapCountry(TapCountry cmd) {
    final result = collectInfluence(_state, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) _events.add(event);
    });
  }

  Result<void, GameError> _applyPurchaseUpgrade(PurchaseUpgrade cmd) {
    final result = applyPurchaseUpgrade(
      _state,
      _content,
      cmd,
      now: _clock.now(),
    );
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) _events.add(event);
    });
  }

  Result<void, GameError> _applyHireLeader(HireLeader cmd) {
    final result = applyHireLeader(
      _state,
      _content,
      cmd,
      now: _clock.now(),
    );
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) _events.add(event);
    });
  }

  Result<void, GameError> _applyUpgradeLeader(UpgradeLeader cmd) {
    final result = applyUpgradeLeader(
      _state,
      _content,
      cmd,
      now: _clock.now(),
    );
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) _events.add(event);
    });
  }

  void dispose() {
    if (_events.isClosed) return;
    _events.close();
  }
}
