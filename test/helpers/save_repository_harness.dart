import 'dart:async';

import 'package:drift/native.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/mappers/game_state_mapper.dart';
import 'package:global_domination/data/repositories/save_repository.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:decimal/decimal.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';

import 'fake_clock.dart';

/// Shared UTC anchor for in-memory [SaveRepository] tests.
final testRepoTimeUtc = DateTime.utc(2026, 1, 1, 12);

/// Counts [Clock.now] calls (used to assert a single debounced meta snapshot).
class CountingTestClock implements Clock {
  CountingTestClock(this._inner);

  final FakeClock _inner;
  int nowCalls = 0;

  @override
  DateTime now() {
    nowCalls++;
    return _inner.now();
  }

  void advance(Duration d) => _inner.advance(d);
}

/// Minimal wiring for [SaveRepository] in tests: memory DB, broadcast event stream, injectable [GameState].
class SaveRepositoryTestHarness {
  SaveRepositoryTestHarness()
    : db = AppDatabase(NativeDatabase.memory()),
      events = StreamController<GameEvent>.broadcast(),
      clock = CountingTestClock(FakeClock(testRepoTimeUtc));

  final AppDatabase db;
  final StreamController<GameEvent> events;
  final CountingTestClock clock;
  GameState state = GameState();
  late SaveRepository repo;

  void start({
    GameState? initial,
    Duration debounce = const Duration(milliseconds: 50),
  }) {
    if (initial != null) {
      state = initial;
    }
    repo = SaveRepository(
      db: db,
      mapper: const GameStateMapper(),
      events: events.stream,
      readState: () => state,
      clock: clock,
      debounceDuration: debounce,
    );
  }

  Future<void> shutdown() async {
    await repo.dispose();
    await db.close();
  }
}

/// One unlocked Egypt country; optional [ip] and [total] for meta/tick tests.
GameState egyptOnlyGameState({
  int ip = 1,
  LeaderTier tier = LeaderTier.none,
  Influence? total,
}) {
  return GameState(
    totalInfluence: total ?? Influence(Decimal.fromInt(1_000)),
    countries: {
      const CountryId('egypt'): CountryState(
        id: const CountryId('egypt'),
        unlocked: true,
        ipLevel: ip,
        leaderTier: tier,
        bankedInfluence: Influence.zero,
        lastCollectedAt: null,
      ),
    },
  );
}
