import 'dart:async';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/continents/continents_reducer.dart';
import 'package:global_domination/game/features/continents/milestones_reducer.dart';
import 'package:global_domination/game/features/continents/unlocks_reducer.dart';
import 'package:global_domination/game/features/countries/countries_collect_reducer.dart';
import 'package:global_domination/game/features/countries/countries_reducer.dart';
import 'package:global_domination/game/features/leaders/leaders_reducer.dart';
import 'package:global_domination/game/features/boosts/boosts_reducer.dart';
import 'package:global_domination/game/features/goldens/goldens_reducer.dart';
import 'package:global_domination/game/features/goldens/goldens_scheduler.dart';
import 'package:global_domination/game/features/upgrades/upgrades_reducer.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_error.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/result.dart';

class GameWorld {
  final Clock _clock;
  final ContentRegistry _content;
  final Rng _rng;
  GameState _state;
  final StreamController<GameEvent> _events =
      StreamController<GameEvent>.broadcast(sync: true);

  GameWorld({
    required ContentRegistry content,
    required Clock clock,
    required Rng rng,
    GameState? initialState,
  }) : _clock = clock,
       _content = content,
       _rng = rng,
       _state = initialState ?? GameState.initialSeed(content);

  GameState get state => _state;
  Stream<GameEvent> get events => _events.stream;

  void tick(Duration dt) {
    assert(!dt.isNegative, 'tick dt must be non-negative, got $dt');
    assert(dt.inMilliseconds <= 100, 'tick dt should be clamped to 100ms');

    final now = _clock.now();
    final (boostExpiredState, boostEvents) = evaluateBoostExpiry(
      _state,
      now: now,
    );
    final boostExpired = boostEvents.isNotEmpty;
    if (boostExpired) {
      _state = boostExpiredState;
      for (final e in boostEvents) {
        _events.add(e);
      }
    }

    final newCountries = tickCountries(_state, dt, _content);
    final countriesChanged = !identical(newCountries, _state.countries);
    if (countriesChanged) {
      _state = _state.copyWith(countries: newCountries);
    }

    final unlockRes = evaluateContinentUnlocks(_state, _content, now: now);
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

    final (goldensState, goldenEvents) = evaluateGoldens(
      _state,
      _content,
      dt,
      now: now,
      rng: _rng,
    );
    if (goldenEvents.isNotEmpty) {
      _state = goldensState;
      for (final e in goldenEvents) {
        _events.add(e);
      }
    }

    if (countriesChanged ||
        continentEvents.isNotEmpty ||
        goldenEvents.isNotEmpty ||
        boostExpired) {
      _events.add(Tick(now));
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
      final stateBeforeCommand = _state;
      final unlockResult = _applyUnlockCountry(cmd);
      if (unlockResult.isSuccess && _state != stateBeforeCommand) {
        _evaluateContinentUnlocks(_clock.now());
        _evaluateMilestones(_clock.now());
      }
      return unlockResult;
    }

    if (cmd is ClaimGolden) {
      return _applyClaimGolden(cmd);
    }

    final stateBeforeCommand = _state;
    final result = switch (cmd) {
      TapCountry() => _applyTapCountry(cmd),
      PurchaseUpgrade() => _applyPurchaseUpgrade(cmd),
      HireLeader() => _applyHireLeader(cmd),
      UpgradeLeader() => _applyUpgradeLeader(cmd),
      ActivateBoost() => _applyActivateBoost(cmd),
      Noop() => const Success<void, GameError>(null),
      UnlockCountry() => const Success<void, GameError>(null),
      ClaimGolden() => throw AssertionError('unreachable ClaimGolden: $cmd'),
    };
    if (result.isSuccess && _state != stateBeforeCommand) {
      _evaluateContinentUnlocks(_clock.now());
      _evaluateMilestones(_clock.now());
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

  void _evaluateMilestones(DateTime now) {
    final (next, events) = evaluateMilestones(_state, _content, now);
    if (events.isEmpty) return;
    _state = next;
    for (final e in events) {
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
    final result = applyHireLeader(_state, _content, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) _events.add(event);
    });
  }

  Result<void, GameError> _applyUpgradeLeader(UpgradeLeader cmd) {
    final result = applyUpgradeLeader(_state, _content, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) _events.add(event);
    });
  }

  Result<void, GameError> _applyUnlockCountry(UnlockCountry cmd) {
    final result = applyUnlockCountry(_state, _content, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) _events.add(event);
    });
  }

  Result<void, GameError> _applyClaimGolden(ClaimGolden cmd) {
    final result = applyClaimGolden(_state, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) _events.add(event);
    });
  }

  Result<void, GameError> _applyActivateBoost(ActivateBoost cmd) {
    final result = applyActivateBoost(_state, cmd, now: _clock.now());
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
