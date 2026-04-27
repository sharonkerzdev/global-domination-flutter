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
import 'package:global_domination/game/features/achievements/achievements_reducer.dart';
import 'package:global_domination/game/features/daily_rewards/daily_rewards_reducer.dart';
import 'package:global_domination/game/features/missions/missions_reducer.dart';
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
    final batch = <GameEvent>[];

    final (boostExpiredState, boostEvents) = evaluateBoostExpiry(
      _state,
      now: now,
    );
    final boostExpired = boostEvents.isNotEmpty;
    if (boostExpired) {
      _state = boostExpiredState;
      batch.addAll(boostEvents);
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
      batch.addAll(continentEvents);
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
      batch.addAll(goldenEvents);
    }

    if (countriesChanged ||
        continentEvents.isNotEmpty ||
        goldenEvents.isNotEmpty ||
        boostExpired) {
      batch.add(Tick(now));
    }

    _emitBatchWithMissions(batch, now);
  }

  void _appendContinentUnlocksToBatch(List<GameEvent> batch, DateTime now) {
    final unlockRes = evaluateContinentUnlocks(_state, _content, now: now);
    if (unlockRes.isFailure) {
      throw AssertionError(unlockRes.errorOrNull);
    }
    final (unlockState, continentEvents) = unlockRes.valueOrNull!;
    if (continentEvents.isEmpty) return;
    _state = unlockState;
    batch.addAll(continentEvents);
  }

  void _appendMilestonesToBatch(List<GameEvent> batch, DateTime now) {
    final (next, events) = evaluateMilestones(_state, _content, now);
    if (events.isEmpty) return;
    _state = next;
    batch.addAll(events);
  }

  void _appendAchievementsToBatch(List<GameEvent> batch, DateTime now) {
    final (next, events) = evaluateAchievements(_state, _content, now);
    if (events.isEmpty) return;
    _state = next;
    batch.addAll(events);
  }

  /// Emits [batch] (command / continent / milestone / tick / …) then mission
  /// events derived from them, preserving causal ordering (AC 5-3 #9).
  void _emitBatchWithMissions(List<GameEvent> batch, DateTime now) {
    if (batch.isEmpty) return;
    final missionTail = <GameEvent>[];
    var s = _state;
    for (final e in batch) {
      if (e is MissionCompleted || e is MissionRotated) {
        continue;
      }
      final (next, mEv) = evaluateMissions(s, _content, e, now);
      if (identical(next, s) && mEv.isEmpty) continue;
      s = next;
      missionTail.addAll(mEv);
    }
    if (!identical(s, _state)) {
      _state = s;
    }
    for (final e in batch) {
      _events.add(e);
    }
    for (final e in missionTail) {
      _events.add(e);
    }
  }

  Result<void, GameError> applyCommand(GameCommand cmd) {
    if (cmd is Noop) {
      return const Success<void, GameError>(null);
    }

    final now = _clock.now();

    if (cmd is UnlockCountry) {
      final batch = <GameEvent>[];
      _appendContinentUnlocksToBatch(batch, now);
      final stateBeforeCommand = _state;
      final unlockResult = _applyUnlockCountry(cmd, batch);
      if (unlockResult.isSuccess && _state != stateBeforeCommand) {
        _appendContinentUnlocksToBatch(batch, now);
        _appendMilestonesToBatch(batch, now);
        _appendAchievementsToBatch(batch, now);
      }
      _emitBatchWithMissions(batch, now);
      return unlockResult;
    }

    if (cmd is ClaimGolden) {
      final batch = <GameEvent>[];
      final claimResult = _applyClaimGolden(cmd, batch);
      _emitBatchWithMissions(batch, now);
      return claimResult;
    }

    final stateBeforeCommand = _state;
    final batch = <GameEvent>[];
    final result = switch (cmd) {
      TapCountry() => _applyTapCountry(cmd, batch),
      PurchaseUpgrade() => _applyPurchaseUpgrade(cmd, batch),
      HireLeader() => _applyHireLeader(cmd, batch),
      UpgradeLeader() => _applyUpgradeLeader(cmd, batch),
      ActivateBoost() => _applyActivateBoost(cmd, batch),
      ClaimDailyReward() => _applyClaimDailyReward(cmd, batch),
      Noop() => const Success<void, GameError>(null),
      UnlockCountry() => const Success<void, GameError>(null),
      ClaimGolden() => throw AssertionError('unreachable ClaimGolden: $cmd'),
    };
    if (result.isSuccess && _state != stateBeforeCommand) {
      _appendContinentUnlocksToBatch(batch, now);
      _appendMilestonesToBatch(batch, now);
      _appendAchievementsToBatch(batch, now);
    }
    _emitBatchWithMissions(batch, now);
    return result;
  }

  Result<void, GameError> _applyTapCountry(
    TapCountry cmd,
    List<GameEvent> batch,
  ) {
    final result = collectInfluence(_state, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) batch.add(event);
    });
  }

  Result<void, GameError> _applyPurchaseUpgrade(
    PurchaseUpgrade cmd,
    List<GameEvent> batch,
  ) {
    final result = applyPurchaseUpgrade(
      _state,
      _content,
      cmd,
      now: _clock.now(),
    );
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) batch.add(event);
    });
  }

  Result<void, GameError> _applyHireLeader(
    HireLeader cmd,
    List<GameEvent> batch,
  ) {
    final result = applyHireLeader(_state, _content, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) batch.add(event);
    });
  }

  Result<void, GameError> _applyUpgradeLeader(
    UpgradeLeader cmd,
    List<GameEvent> batch,
  ) {
    final result = applyUpgradeLeader(_state, _content, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) batch.add(event);
    });
  }

  Result<void, GameError> _applyUnlockCountry(
    UnlockCountry cmd,
    List<GameEvent> batch,
  ) {
    final result = applyUnlockCountry(_state, _content, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) batch.add(event);
    });
  }

  Result<void, GameError> _applyClaimGolden(
    ClaimGolden cmd,
    List<GameEvent> batch,
  ) {
    final result = applyClaimGolden(_state, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) batch.add(event);
    });
  }

  Result<void, GameError> _applyActivateBoost(
    ActivateBoost cmd,
    List<GameEvent> batch,
  ) {
    final result = applyActivateBoost(_state, cmd, now: _clock.now());
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) batch.add(event);
    });
  }

  Result<void, GameError> _applyClaimDailyReward(
    ClaimDailyReward cmd,
    List<GameEvent> batch,
  ) {
    final result = applyClaimDailyReward(
      _state,
      _content,
      cmd,
      now: _clock.now(),
    );
    return result.map((tuple) {
      final (newState, event) = tuple;
      _state = newState;
      if (event != null) batch.add(event);
    });
  }

  void dispose() {
    if (_events.isClosed) return;
    _events.close();
  }
}
