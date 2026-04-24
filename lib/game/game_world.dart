import 'dart:async';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/continents/continents_reducer.dart';
import 'package:global_domination/game/features/continents/unlocks_reducer.dart';
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
    final countriesChanged = !identical(newCountries, _state.countries);
    if (countriesChanged) {
      _state = _state.copyWith(countries: newCountries);
    }

    final unlockRes = evaluateContinentUnlocks(
      _state,
      _content,
      now: _clock.now(),
    );
    if (unlockRes.isFailure) {
      throw AssertionError(unlockRes.errorOrNull);
    }
    final (unlockState, continentEvents) = unlockRes.valueOrNull!;
    if (continentEvents.isNotEmpty) {
      _state = unlockState;
      for (final e in continentEvents) {
        _events.add(e);
      }
    }

    if (countriesChanged || continentEvents.isNotEmpty) {
      _events.add(Tick(_clock.now()));
    }
  }

  Result<void, GameError> applyCommand(GameCommand cmd) {
    if (cmd is Noop) {
      return const Success<void, GameError>(null);
    }

    if (cmd is UnlockCountry) {
      // Reconcile continent unlock state before spending influence so a command
      // cannot unlock a country inside a stale "locked" continent snapshot.
      _evaluateContinentUnlocks(_clock.now());
      return _applyUnlockCountry(cmd);
    }

    final result = switch (cmd) {
      TapCountry() => _applyTapCountry(cmd),
      PurchaseUpgrade() => _applyPurchaseUpgrade(cmd),
      HireLeader() => _applyHireLeader(cmd),
      UpgradeLeader() => _applyUpgradeLeader(cmd),
      Noop() => const Success<void, GameError>(null),
      UnlockCountry() => const Success<void, GameError>(null),
    };
    if (result.isSuccess) {
      _evaluateContinentUnlocks(_clock.now());
    }
    return result;
  }

  void _evaluateContinentUnlocks(DateTime now) {
    final unlockRes = evaluateContinentUnlocks(_state, _content, now: now);
    if (unlockRes.isFailure) {
      throw AssertionError(unlockRes.errorOrNull);
    }
    final (unlockState, continentEvents) = unlockRes.valueOrNull!;
    if (continentEvents.isEmpty) return;
    _state = unlockState;
    for (final e in continentEvents) {
      _events.add(e);
    }
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

  Result<void, GameError> _applyUnlockCountry(UnlockCountry cmd) {
    final result = applyUnlockCountry(
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
