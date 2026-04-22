# Story 1.9: Skeleton `GameWorld` With `tick` and `applyCommand` (No-Op)

Status: done

## Story

As a developer,
I want a `GameWorld` class in `lib/game/game_world.dart` with `tick(Duration dt)`, `applyCommand(GameCommand)`, `GameState get state`, and `Stream<GameEvent> get events`, initially returning no-ops or empty state,
So that subsequent epics have a stable aggregator to attach reducers and events to.

## Acceptance Criteria

1. **Given** `GameWorld` is instantiated with an injected `Clock` and a `ContentRegistry` **When** `tick(Duration.zero)` is called **Then** it returns without error and `state` is unchanged.

2. **Given** `GameWorld` **When** `applyCommand(cmd)` is called for any `GameCommand` variant defined so far (initially an empty sealed hierarchy or a single `Noop`) **Then** it returns `Result.success(null)` and emits no event — a placeholder ready to be extended.

3. **Given** the `events` stream **When** a subscriber attaches before any event emission **Then** the stream is a broadcast stream that survives multiple subscribers.

4. **Given** `GameWorld` **When** imported **Then** it has zero `package:flutter/*` imports (enforced by Story 1.3's architecture boundary test).

## Tasks / Subtasks

- [x] Task 1: Create `Clock` abstraction in `lib/game/support/clock.dart` (AC: #1)
  - [x] 1.1 Create `lib/game/support/clock.dart` — abstract interface for time injection
  - [x] 1.2 Define `Clock` as a simple abstract class or typedef with a `DateTime now()` method
  - [x] 1.3 Create `SystemClock` implementation that delegates to `DateTime.now()`
  - [x] 1.4 Verify zero Flutter imports — pure Dart only

- [x] Task 2: Create `GameState` in `lib/game/game_state.dart` (AC: #1)
  - [x] 2.1 Create `lib/game/game_state.dart` — `@immutable` class holding the immutable game snapshot
  - [x] 2.2 For this skeleton, `GameState` is minimal: `final ContentRegistry content` (or an empty data holder) — just enough to compile and pass through `GameWorld`. Future epics expand it with `countries`, `leaders`, `totalInfluence`, etc.
  - [x] 2.3 Add `const` constructor, `==`, `hashCode`, `toString`
  - [x] 2.4 Add `copyWith` (even though it's trivial now — establishes the pattern)

- [x] Task 3: Create `GameCommand` sealed hierarchy in `lib/game/game_command.dart` (AC: #2)
  - [x] 3.1 Create `lib/game/game_command.dart` — `sealed class GameCommand` with a single `Noop` variant for now
  - [x] 3.2 `Noop` is `final class Noop extends GameCommand { const Noop(); }` — placeholder so the exhaustive switch in `applyCommand` compiles
  - [x] 3.3 Future stories replace `Noop` with real commands (`TapCountry`, `PurchaseUpgrade`, etc.) — the sealed hierarchy forces compiler errors at every unhandled consumer

- [x] Task 4: Create `GameEvent` sealed hierarchy in `lib/game/game_event.dart` (AC: #3)
  - [x] 4.1 Create `lib/game/game_event.dart` — `sealed class GameEvent` with a `DateTime at` field per architecture
  - [x] 4.2 Add a single `Tick` event variant: `final class Tick extends GameEvent { const Tick(super.at); }` — placeholder emitted (or not emitted) by `tick()`. This gives the event stream a concrete type to test against. Alternative: leave the hierarchy with no variants if the architecture intent is that `tick()` emits nothing initially — decide based on AC #2 ("emits no event" for `applyCommand`; `tick` AC says "returns without error" not "emits no event", so a `Tick` event is acceptable)
  - [x] 4.3 Architecture reference: events use past-tense naming. `Tick` is an exception as a system heartbeat — future real events are `CountryTapped`, `UpgradePurchased`, etc.

- [x] Task 5: Create `GameWorld` in `lib/game/game_world.dart` (AC: #1, #2, #3, #4)
  - [x] 5.1 Create `lib/game/game_world.dart` — the root aggregator class
  - [x] 5.2 Constructor: `GameWorld({required ContentRegistry content, required Clock clock})` — stores both as private fields
  - [x] 5.3 `GameState get state` — returns current `_state` (initialized from `content` in constructor)
  - [x] 5.4 `Stream<GameEvent> get events` — backed by `StreamController<GameEvent>.broadcast(sync: true)` per architecture mandate. **MUST be `sync: true`** — subscribers observe state + event in the same microtask [Source: game-architecture.md, line 842]
  - [x] 5.5 `void tick(Duration dt)` — no-op for now: returns immediately without modifying state. Future epics add income accumulation, timer-based generation, Golden spawning, Boost expiry, etc.
  - [x] 5.6 `Result<void, GameError> applyCommand(GameCommand cmd)` — exhaustive switch on `cmd`. For `Noop`, return `const Result.success(null)`. Emits no event. As architecture shows [Source: game-architecture.md, lines 818-836], future commands dispatch to feature reducers and emit events.
  - [x] 5.7 Add `void dispose()` — closes the `StreamController`

- [x] Task 6: Create `FakeClock` test helper in `test/helpers/fake_clock.dart` (AC: #1)
  - [x] 6.1 Create `test/helpers/fake_clock.dart` — implements `Clock` with a controllable `DateTime`
  - [x] 6.2 `FakeClock(DateTime initial)` with `DateTime now()` returning the stored time
  - [x] 6.3 Add `void advance(Duration d)` to move time forward deterministically

- [x] Task 7: Write tests for `GameWorld` (AC: #1, #2, #3, #4)
  - [x] 7.1 Create `test/game/game_world_test.dart` using `package:test/test.dart` (NOT `flutter_test`)
  - [x] 7.2 Test: `GameWorld` constructs without error given a `ContentRegistry` and `FakeClock`
  - [x] 7.3 Test: `state` returns a `GameState` after construction
  - [x] 7.4 Test: `tick(Duration.zero)` does not throw and `state` is unchanged after call
  - [x] 7.5 Test: `tick(Duration(milliseconds: 16))` does not throw (simulates one frame)
  - [x] 7.6 Test: `applyCommand(Noop())` returns `Result.success(null)` — `isSuccess == true`
  - [x] 7.7 Test: `applyCommand(Noop())` emits no event on the `events` stream
  - [x] 7.8 Test: `events` stream supports multiple subscribers simultaneously (broadcast)
  - [x] 7.9 Test: `events` stream is usable before any events are emitted (no error on listen)
  - [x] 7.10 Test: `dispose()` closes the stream (subsequent `listen` throws or stream is done)

- [x] Task 8: Write tests for `GameCommand` and `GameEvent` (AC: #2, #3)
  - [x] 8.1 Create `test/game/game_command_test.dart` — test `Noop` construction, `==`, `hashCode`
  - [x] 8.2 Create `test/game/game_event_test.dart` — test `Tick` (or whichever placeholder variant) construction, `at` field, `==`, `hashCode`
  - [x] 8.3 Test exhaustive switch compiles on both sealed hierarchies

- [x] Task 9: Write tests for `GameState` (AC: #1)
  - [x] 9.1 Create `test/game/game_state_test.dart` — test construction, `==`, `hashCode`, `copyWith`

- [x] Task 10: Write tests for `Clock` and `FakeClock` (AC: #1)
  - [x] 10.1 Create `test/game/support/clock_test.dart` — test `SystemClock` returns a `DateTime` (basic sanity)
  - [x] 10.2 Test `FakeClock` returns controlled time, `advance` moves forward correctly

- [x] Task 11: Run analyzer and full test suite (AC: all)
  - [x] 11.1 Run `flutter analyze --fatal-infos` — zero issues
  - [x] 11.2 Run `dart test test/game/` — all pure-Dart tests pass (208 tests, including 30 new for this story)
  - [x] 11.3 Verify ALL new files under `lib/game/` have ZERO Flutter imports
  - [x] 11.4 Verify architecture boundary test (`test/architecture/game_boundary_test.dart`) still passes — full suite 235/235

## Dev Notes

### Architecture Compliance

**All new files live in `lib/game/` — ZERO Flutter imports. Pure Dart only.**

This story creates the central aggregator (`GameWorld`) that the entire game architecture revolves around. Per architecture [Source: game-architecture.md, lines 203-209]:
- `GameWorld` is a plain Dart class with zero Flutter imports
- Exposes: `tick(Duration dt)`, `applyCommand(GameCommand)`, `GameState get state`, `Stream<GameEvent> get events`
- Consumes an injected `Clock` for all time-based logic

The architecture shows `applyEvent(GameEvent)` in the description (line 206) but the code example (line 819) shows `applyCommand(GameCommand cmd)`. **Use `applyCommand(GameCommand)`** — commands are input to the sim, events are output. The epics file AC confirms: "`applyCommand(GameCommand)`".

### Implementation Approach

**`Clock` — injectable time source:**

```dart
// lib/game/support/clock.dart
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}
```

Architecture mandates `DateTime.now()` is NEVER called directly in `lib/game/` — always through injected `Clock` [Source: project-context.md#Anti-patterns]. `SystemClock` is the production implementation; `FakeClock` is the test double.

**`GameState` — minimal skeleton:**

```dart
// lib/game/game_state.dart
@immutable
class GameState {
  // Minimal for Story 1.9. Future stories add:
  // - Map<CountryId, CountryState> countries
  // - Influence totalInfluence
  // - Intel totalIntel
  // - ... per-feature state slices

  const GameState();

  GameState copyWith() => const GameState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GameState;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'GameState()';
}
```

Keep it truly minimal — the point is to have a compilable type for `GameWorld` to hold. Future stories (Epic 2+) expand fields. Do NOT preemptively add country maps, influence totals, etc.

**`GameCommand` — sealed with Noop:**

```dart
// lib/game/game_command.dart
sealed class GameCommand {
  const GameCommand();
}

final class Noop extends GameCommand {
  const Noop();
}
```

Naming convention: commands are imperative [Source: game-architecture.md, line 734]. `Noop` is a deliberate placeholder — Epic 2 introduces `TapCountry`, Epic 3 introduces `PurchaseUpgrade`, `HireLeader`, etc.

**`GameEvent` — sealed with timestamp:**

```dart
// lib/game/game_event.dart
sealed class GameEvent {
  final DateTime at;
  const GameEvent(this.at);
}

final class Tick extends GameEvent {
  const Tick(super.at);
}
```

Architecture specifies `GameEvent` has a `DateTime at` field [Source: game-architecture.md, line 468]. Events are past-tense named. `Tick` is a minimal placeholder; real events (`CountryTapped`, `UpgradePurchased`, etc.) arrive in Epic 2+.

**`GameWorld` — the aggregator:**

```dart
// lib/game/game_world.dart
class GameWorld {
  final Clock _clock;
  final ContentRegistry _content;
  GameState _state;
  final StreamController<GameEvent> _events =
      StreamController<GameEvent>.broadcast(sync: true);

  GameWorld({required ContentRegistry content, required Clock clock})
      : _clock = clock,
        _content = content,
        _state = const GameState();

  GameState get state => _state;
  Stream<GameEvent> get events => _events.stream;

  void tick(Duration dt) {
    // No-op for now. Future epics add:
    // - Income accumulation per country
    // - Timer-based generation checks
    // - Golden Opportunity spawning
    // - Boost expiry
  }

  Result<void, GameError> applyCommand(GameCommand cmd) {
    return switch (cmd) {
      Noop() => const Result.success(null),
    };
  }

  void dispose() {
    _events.close();
  }
}
```

Key decisions:
- `StreamController.broadcast(sync: true)` — **mandatory** per architecture. Subscribers observe state + event in the same microtask [Source: game-architecture.md, line 842].
- `applyCommand` uses exhaustive `switch` — adding a new `GameCommand` variant forces compiler errors here, ensuring every command is handled.
- `tick` takes `Duration dt` (variable timestep, wall-clock delta) — clamped to ≤ 0.1s by `GameLoop` (Flutter layer, not `GameWorld`'s concern).
- `_content` stored for future reducer access — reducers receive `ContentRegistry` via `GameWorld`.
- Returns `Result<void, GameError>` from `applyCommand` per architecture pattern [Source: game-architecture.md, lines 818-836].

### Relationship to Future Code

**Story 1.10 (Crash Log):** Independent — no interaction with GameWorld.

**Epic 2 (Playable Map):** Story 2.5 (`GameWorld.tick` drives income generation) and Story 2.6 (tap-to-collect via `applyCommand(TapCountry(...))`) are the first real consumers. They will:
- Add `CountryState` map to `GameState`
- Add `TapCountry` command to `GameCommand`
- Add `CountryTapped` event to `GameEvent`
- Add the country reducer wired into `applyCommand`'s switch

**Epic 3 (Upgrades/Leaders):** Adds `PurchaseUpgrade`, `HireLeader` commands and corresponding reducers. The exhaustive switch forces all to be wired.

This skeleton establishes the pattern; every future feature plugs into it without restructuring.

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/game/support/clock.dart` | Injectable `Clock` abstraction + `SystemClock` |
| CREATE | `lib/game/game_state.dart` | Minimal `@immutable` game state snapshot |
| CREATE | `lib/game/game_command.dart` | Sealed command hierarchy (Noop placeholder) |
| CREATE | `lib/game/game_event.dart` | Sealed event hierarchy (Tick placeholder, `DateTime at` field) |
| CREATE | `lib/game/game_world.dart` | Root aggregator: `tick`, `applyCommand`, `state`, `events` |
| CREATE | `test/helpers/fake_clock.dart` | Test double for `Clock` with controllable time |
| CREATE | `test/game/game_world_test.dart` | GameWorld tests (tick, applyCommand, events stream) |
| CREATE | `test/game/game_command_test.dart` | GameCommand sealed hierarchy tests |
| CREATE | `test/game/game_event_test.dart` | GameEvent sealed hierarchy tests |
| CREATE | `test/game/game_state_test.dart` | GameState construction/equality tests |
| CREATE | `test/game/support/clock_test.dart` | Clock + FakeClock tests |

### Testing Standards

- **ALL test files** use `package:test/test.dart` only (NOT `flutter_test`). All source files are pure Dart under `lib/game/`.
- Test `GameWorld` construction, `tick` no-op behavior, `applyCommand` returns `Result.success`, events stream is broadcast + multi-subscriber safe.
- Test `GameCommand` and `GameEvent` sealed hierarchies: construction, `==`, `hashCode`, exhaustive switch compilation.
- Test `Clock`/`FakeClock`: `SystemClock` returns a `DateTime`; `FakeClock` returns controlled time and `advance` works.
- `ContentRegistry` is available from Story 1.7 — construct one in tests using the test JSON loader pattern established there.

### Anti-Patterns to Avoid

- Do NOT add Flutter imports to ANY file in this story — all files live in `lib/game/` or `lib/game/support/`.
- Do NOT call `DateTime.now()` inside `GameWorld` or any `lib/game/` code — use injected `Clock`.
- Do NOT use `StreamController()` (non-broadcast) — MUST be `StreamController.broadcast(sync: true)`.
- Do NOT add a catch-all `case _ =>` in the `applyCommand` switch — the whole point of the sealed hierarchy is exhaustive checking. When Epic 2 adds `TapCountry`, the compiler forces you to handle it here.
- Do NOT preemptively add commands/events for features that don't exist yet (no `TapCountry`, `PurchaseUpgrade`, etc.). This story is the skeleton — future stories add variants.
- Do NOT make `GameState` hold country maps, influence totals, or feature state slices yet. Keep it minimal — just enough to compile. Epic 2 expands it.
- Do NOT add `package:logging` to `GameWorld` yet — the `tick` and `applyCommand` methods are no-ops. Logging arrives when real logic lands.
- Do NOT create `GameWorldNotifier` (Riverpod wrapper) — that lives in `lib/providers/` and is NOT this story's scope. `GameWorld` is pure Dart.
- Do NOT make `GameWorld` extend or mix in any Flutter class — it's a plain Dart class.
- Do NOT use `async` on `tick()` or `applyCommand()` — both are synchronous. Drift persistence is event-driven and handled by subscribers outside `lib/game/`.

### Previous Story Intelligence

**From Story 1.8 (GameError + Result):**
- `Result<T, E>` at `lib/game/values/result.dart` — generic sealed type with `Success`/`Failure`. `applyCommand` returns `Result<void, GameError>`.
- `GameError` at `lib/game/game_error.dart` — two-level sealed hierarchy. `applyCommand` may return errors in future; for now, `Noop` always succeeds.
- Pattern: `const Result.success(null)` for void success, `Result.failure(GameError.xxx(...))` for failures.
- Import: `import 'package:global_domination/game/values/result.dart';`
- Import: `import 'package:global_domination/game/game_error.dart';`
- 178 total tests passing, zero analyzer issues.

**From Story 1.7 (ContentRegistry):**
- `ContentRegistry` at `lib/game/content/content_registry.dart` — loaded from assets at boot, immutable.
- `GameWorld` constructor takes `ContentRegistry` — used by future reducers.
- Import: `import 'package:global_domination/game/content/content_registry.dart';`
- Test construction: use `ContentRegistry(countries: {}, continents: {}, leaders: [], achievements: [], missions: [], globalUpgrades: [])` or use the test JSON loader from Story 1.7 tests.

**From Story 1.5 (Value Objects):**
- `Influence`, `Intel`, `CountryId`, `ContinentId` all exist in `lib/game/values/`.
- Not directly needed in this skeleton but available for future `GameState` fields.

**From Story 1.3 (Architecture Boundary):**
- `test/architecture/game_boundary_test.dart` enforces no Flutter imports in `lib/game/`. New files automatically covered.

**Key patterns established across stories 1.1–1.8:**
- File naming: `snake_case.dart`, one public class per file (sealed hierarchies excepted)
- Test naming: `{source_name}_test.dart` mirroring lib path
- All `lib/game/` tests use `package:test/test.dart`
- `@immutable` on value/data classes, `const` constructors
- Manual `==`/`hashCode`/`toString` — no `freezed`

### Project Structure Notes

- `lib/game/game_world.dart` — top-level file in `lib/game/` per architecture file tree [Source: game-architecture.md, line 551]
- `lib/game/game_state.dart` — alongside `game_world.dart` [Source: game-architecture.md, line 552]
- `lib/game/game_command.dart` — sealed command hierarchy [Source: game-architecture.md, line 553]
- `lib/game/game_event.dart` — sealed event hierarchy [Source: game-architecture.md, line 554]
- `lib/game/support/clock.dart` — injectable time source [Source: game-architecture.md, line 586]
- `test/helpers/fake_clock.dart` — test helper directory (alongside future `GameStateBuilder`, etc.)

### References

- [Source: epics.md#Story 1.9] — Acceptance criteria, user story statement
- [Source: game-architecture.md#Simulation Layering, lines 203-209] — GameWorld description, tick, applyCommand, state, events, Clock injection
- [Source: game-architecture.md#Sealed Command/Event Dispatch, lines 807-842] — GameCommand sealed hierarchy, applyCommand implementation pattern, exhaustive switch, sync StreamController
- [Source: game-architecture.md#Event System, lines 452-490] — GameEvent sealed hierarchy with `DateTime at`, broadcast StreamController
- [Source: game-architecture.md#Game Loop, lines 218-225] — Single Ticker, variable timestep, lifecycle hooks
- [Source: game-architecture.md#File Structure, lines 550-588] — File locations for all new files
- [Source: game-architecture.md#GameWorldNotifier, lines 1018-1033] — Riverpod wrapper pattern (NOT this story's scope but shows how GameWorld is consumed)
- [Source: game-architecture.md#Standard Patterns, lines 947-985] — Immutable state with manual copyWith
- [Source: project-context.md#Engine-Specific Rules] — Clock injection mandatory, sync: true StreamController, no Flutter in lib/game/
- [Source: project-context.md#Anti-patterns] — DateTime.now() forbidden in lib/game/, commands are input, events are output

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M context)

### Debug Log References

- Initial analyzer run surfaced 4 issues:
  - `_clock` and `_content` flagged `unused_field` (intentionally retained per spec for future reducer access) — suppressed with `// ignore: unused_field`.
  - `_state` flagged `prefer_final_fields` (intentionally non-final per spec; future epics mutate it) — suppressed with `// ignore: prefer_final_fields`.
  - `result.valueOrNull` invocation on `Result<void, _>` failed with `use_of_void_result` — replaced with `isFailure`/`errorOrNull` assertions which prove the same invariant without dereferencing void.
- After fixes: `flutter analyze --fatal-infos` → 0 issues; `dart test test/game/` → 208 passed; `flutter test` (full suite incl. architecture boundary) → 235 passed.

### Completion Notes List

- **Code review (2026-04-21):** 3 MEDIUM findings fixed in-place.
  - M1 — `GameWorld.dispose()` made idempotent (guard with `_events.isClosed`) to tolerate double-dispose during hot restart / test teardown cascades. Added test `is idempotent — second dispose() does not throw`.
  - M2 — Added test `tick(dt) emits no event on the events stream` to lock in the current no-emit contract alongside the existing `applyCommand` no-emit test.
  - M3 — Added debug-only `assert(!dt.isNegative, ...)` in `tick()` to catch bad inputs early (future reducers will assume `dt >= 0`). Added test `tick asserts on negative Duration in debug mode`.
  - Post-fix: analyzer clean on Story 1.9 files (`lib/game/`, `test/game/`, `test/helpers/`); architecture boundary test passes; `dart test test/game/` → 211 pass (+3 from review); `flutter test test/game/ test/helpers/ test/architecture/` → 215 pass.
- All 11 tasks and 41 subtasks complete. All 4 ACs satisfied.
- `GameWorld` is a plain Dart class (zero `package:flutter` imports) holding `Clock`, `ContentRegistry`, immutable `GameState`, and a `StreamController<GameEvent>.broadcast(sync: true)` per the architecture mandate.
- `applyCommand` uses an exhaustive `switch` over the sealed `GameCommand` hierarchy — adding a new variant in a future story will force a compile error here, ensuring every command is wired.
- `GameEvent` carries a `DateTime at` field per architecture; sealed hierarchy currently has a single `Tick` placeholder for stream-typing tests.
- `_clock`, `_content`, and `_state` are intentionally unused/non-final at this point — they are wired into the constructor so future epics extending `tick`/reducers don't have to touch the constructor signature again. Lint suppressions are scoped to the lines.
- New test counts: GameWorld (10), GameCommand (5), GameEvent (6), GameState (5), Clock+FakeClock (5) = 31 new tests; full pure-Dart suite 208, full Flutter suite 235.
- Architecture boundary test (`test/architecture/game_boundary_test.dart`) automatically picked up the new `lib/game/` files and continues to pass.

### File List

- `lib/game/support/clock.dart` (CREATE) — `Clock` interface + `SystemClock`
- `lib/game/game_state.dart` (CREATE) — minimal `@immutable` `GameState` skeleton
- `lib/game/game_command.dart` (CREATE) — sealed `GameCommand` with `Noop` placeholder
- `lib/game/game_event.dart` (CREATE) — sealed `GameEvent` with `Tick` placeholder, `DateTime at` field
- `lib/game/game_world.dart` (CREATE) — root aggregator: `tick`, `applyCommand`, `state`, `events`, `dispose`
- `test/helpers/fake_clock.dart` (CREATE) — `FakeClock` test double with `advance`
- `test/game/game_world_test.dart` (CREATE) — 10 tests covering construction, tick, applyCommand, broadcast events, dispose
- `test/game/game_command_test.dart` (CREATE) — 5 tests: construction, equality, hashCode, toString, exhaustive switch
- `test/game/game_event_test.dart` (CREATE) — 6 tests: construction, equality, inequality, hashCode, toString, exhaustive switch
- `test/game/game_state_test.dart` (CREATE) — 5 tests: construction, equality, hashCode, toString, copyWith
- `test/game/support/clock_test.dart` (CREATE) — 5 tests: SystemClock returns DateTime + bounded by now; FakeClock returns initial time, advance moves forward, multiple advances accumulate

## Change Log

| Date       | Change                                                                                       |
|------------|----------------------------------------------------------------------------------------------|
| 2026-04-21 | Story 1.9 implemented: skeleton `GameWorld` (`tick`, `applyCommand`, `state`, `events`) + `Clock`, `GameState`, `GameCommand`, `GameEvent`, `FakeClock`. 31 new tests; analyzer clean; full suite 235/235. Status → review. |
| 2026-04-21 | Code review: 3 MEDIUM fixed — idempotent `dispose()`, `tick` no-event test, `tick` negative-Duration assert. +3 tests. Analyzer clean on scope; 215 tests pass in scope. Status → done. |

