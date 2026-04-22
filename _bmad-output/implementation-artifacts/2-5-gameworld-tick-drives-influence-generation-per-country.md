# Story 2.5: GameWorld Tick Drives Influence Generation per Country

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want each owned country to accumulate Influence over time based on its tier's generation seconds,
So that sitting with the map open produces ready-to-collect countries without tapping.

## Acceptance Criteria

1. **Given** a `GameLoop` widget owns the single `Ticker` **When** the app is foreground and the loop runs **Then** each frame calls `gameWorld.tick(elapsed)` with real wall-clock delta, clamped to `Duration(milliseconds: 100)` to avoid tab-switch spikes.

2. **Given** a country with `generationSeconds = 1`, `baseInfluence = Decimal.parse('1')`, and no upgrades **When** 1 second of ticks elapses **Then** the country's banked influence increases by `1.0` — verified via unit test with an injected `FakeClock`.

3. **Given** the app transitions to `AppLifecycleState.paused` or `inactive` **When** the lifecycle observer fires **Then** the ticker stops and no further `tick` calls happen.

4. **Given** the app returns to `resumed` **When** the lifecycle observer fires **Then** the ticker restarts (offline catch-up is handled in Epic 6 — this story only requires the ticker to resume, not apply offline gains).

## Tasks / Subtasks

- [x] Task 1: Create `CountryState` immutable class (AC: #2)
  - [x] 1.1 Create `lib/game/features/countries/country_state.dart`
  - [x] 1.2 Fields: `CountryId id`, `bool unlocked`, `int ipLevel`, `LeaderTier leaderTier`, `Decimal bankedInfluence`, `DateTime? lastCollectedAt` — matches architecture §CountryState exactly
  - [x] 1.3 Manual `copyWith`, `==`, `hashCode`, `@immutable`
  - [x] 1.4 Create `LeaderTier` enum at `lib/game/features/leaders/leader_tier.dart`: `{ none, tier1, tier2, tier3 }` — needed by `CountryState`

- [x] Task 2: Expand `GameState` with country map and total influence (AC: #2)
  - [x] 2.1 Add `Map<CountryId, CountryState> countries` field to `GameState`
  - [x] 2.2 Add `Influence totalInfluence` field to `GameState`
  - [x] 2.3 Update `copyWith`, `==`, `hashCode`, `toString`
  - [x] 2.4 Update `GameWorld` constructor to build initial `GameState` from `ContentRegistry` — all countries start `unlocked: false, ipLevel: 0, leaderTier: LeaderTier.none, bankedInfluence: Decimal.zero` (Story 2.7 handles seeding Egypt as unlocked)
  - [x] 2.5 `const GameState()` no longer works — update constructor to accept required fields with sensible defaults

- [x] Task 3: Create countries tick reducer (AC: #2)
  - [x] 3.1 Create `lib/game/features/countries/countries_reducer.dart`
  - [x] 3.2 Implement pure function: `(Map<CountryId, CountryState> countries, Duration dt, ContentRegistry content) → Map<CountryId, CountryState>` — for each unlocked country where `generationSeconds > 0`, accumulate `baseInfluence * (dt.inMicroseconds / (generationSeconds * 1e6))` into `bankedInfluence`
  - [x] 3.3 Only process `unlocked == true` countries — locked countries do not generate
  - [x] 3.4 No upgrades/multipliers yet — this story uses `baseInfluence` only. Story 3.1 introduces `IncomeCalculator` for the full multiplier stack
  - [x] 3.5 Return the same map instance (no copy) if no countries are unlocked — avoid per-tick allocation when nothing changes

- [x] Task 4: Wire tick reducer into `GameWorld.tick()` (AC: #1, #2)
  - [x] 4.1 In `GameWorld.tick(Duration dt)`: call the countries tick reducer with current `_state.countries`, `dt`, and `_content`
  - [x] 4.2 Update `_state` with the new countries map via `copyWith`
  - [x] 4.3 Do NOT emit a `Tick` event on every frame — the existing `Tick` event type is available but should only be emitted if state actually changed (an unlocked country generated influence). If no state change occurred (no unlocked countries), skip event emission and state update entirely
  - [x] 4.4 Clamp `dt` to max 100ms is NOT done here — it's the caller's (`GameLoop`) responsibility. The `tick` method already has `assert(!dt.isNegative)`. Optionally add `assert(dt.inMilliseconds <= 100)` as a debug-only guard

- [x] Task 5: Create `GameLoop` widget (AC: #1, #3, #4)
  - [x] 5.1 Create `lib/ui/features/map/game_loop.dart`
  - [x] 5.2 `GameLoop` is a `StatefulWidget` that mixes in `SingleTickerProviderStateMixin` and `WidgetsBindingObserver`
  - [x] 5.3 It wraps a `child` widget — placed above `MapScreen` in the widget tree (or at the app scaffold level)
  - [x] 5.4 Creates a `Ticker` in `initState`, calls `gameWorld.tick(elapsed)` each frame with clamped delta: `final clamped = elapsed > const Duration(milliseconds: 100) ? const Duration(milliseconds: 100) : elapsed`
  - [x] 5.5 `didChangeAppLifecycleState`: on `paused`/`inactive` → stop ticker; on `resumed` → start ticker
  - [x] 5.6 `GameLoop` reads `gameWorldProvider` via Riverpod — it's a `ConsumerStatefulWidget`
  - [x] 5.7 Dispose: stop ticker, remove `WidgetsBindingObserver`

- [x] Task 6: Create `gameWorldProvider` (AC: #1)
  - [x] 6.1 Create `lib/providers/game_providers.dart` if it doesn't exist
  - [x] 6.2 Implement `gameWorldProvider` as a `StateNotifierProvider<GameWorldNotifier, GameState>` — architecture pattern §B
  - [x] 6.3 `GameWorldNotifier` extends `StateNotifier<GameState>`, wraps `GameWorld`, exposes `apply(GameCommand)` and `tick(Duration)`
  - [x] 6.4 Subscribes to `GameWorld.events` and syncs `state = _world.state` on each event
  - [x] 6.5 Add `clockProvider` as a `Provider<Clock>` returning `const SystemClock()` — needed by `gameWorldProvider`

- [x] Task 7: Write pure-Dart unit tests (AC: #2)
  - [x] 7.1 Create `test/game/features/countries/countries_reducer_test.dart` using `package:test/test.dart`
  - [x] 7.2 **Test: unlocked country accumulates baseInfluence over 1s** — create one unlocked country with `generationSeconds: 1, baseInfluence: 1`. Tick for 1 second (e.g., 60 ticks of 16.67ms). Verify `bankedInfluence ≈ 1.0` (use tolerance for floating-point accumulation)
  - [x] 7.3 **Test: locked country does not accumulate** — create one locked country, tick for 5s, verify `bankedInfluence == 0`
  - [x] 7.4 **Test: multiple countries accumulate independently** — 2 unlocked countries with different `generationSeconds` and `baseInfluence`, tick for 2s, verify each has correct banked amount
  - [x] 7.5 **Test: zero-duration tick produces no change** — tick with `Duration.zero`, verify state unchanged
  - [x] 7.6 **Test: sub-second accumulation** — tick for 500ms with `generationSeconds: 1, baseInfluence: 1`, verify `bankedInfluence ≈ 0.5`

- [x] Task 8: Write GameWorld integration tests (AC: #2)
  - [x] 8.1 Update `test/game/game_world_test.dart` — existing tests still pass (empty state now has empty countries map + zero totalInfluence)
  - [x] 8.2 **Test: tick with unlocked country emits event and updates state** — set up GameWorld with one unlocked country, tick for 1s, verify `state.countries[id].bankedInfluence > 0`
  - [x] 8.3 **Test: tick with no unlocked countries does not change state** — all locked, tick for 1s, state unchanged
  - [x] 8.4 Ensure `GameState` equality works correctly with the new fields

- [x] Task 9: Write GameLoop widget test (AC: #1, #3, #4)
  - [x] 9.1 Create `test/ui/features/map/game_loop_test.dart` using `package:flutter_test/flutter_test.dart`
  - [x] 9.2 **Test: GameLoop calls tick each frame** — mount `GameLoop` with overridden `gameWorldProvider`, pump frames, verify tick was called
  - [x] 9.3 **Test: lifecycle paused stops tick calls** — simulate `AppLifecycleState.paused`, pump frames, verify no new ticks
  - [x] 9.4 **Test: lifecycle resumed restarts ticks** — simulate resume after pause, verify ticks resume
  - [x] 9.5 Override all providers: `gameWorldProvider`, `contentRegistryProvider`, `clockProvider`

- [x] Task 10: Verify full test suite (AC: all)
  - [x] 10.1 Run `flutter analyze --fatal-infos` — zero issues
  - [x] 10.2 Run `dart format --set-exit-if-changed .` — clean
  - [x] 10.3 Run `flutter test` — all prior tests plus new tests pass
  - [x] 10.4 No `print()` — `Logger` only if needed (but no logging in tick hot path)

## Dev Notes

### Architecture Compliance

**`GameWorld.tick(Duration dt)` is the sole entry point for time-based simulation.** Each frame, `GameLoop` (the ONE `Ticker` owner) calls `gameWorld.tick(elapsed)`. The tick method delegates to per-feature reducers. [Source: game-architecture.md#Game Loop, line 220-225]

**Countries tick reducer is a pure function in `lib/game/features/countries/`.** Per architecture: "Reducers: Pure functions. NO clock reads, NO RNG reads, NO I/O. `now` and `rng` flow in as parameters. Return `Result<(NewState, Event), GameError>` — no exceptions for control flow. Only `GameWorld` calls reducers and emits events on the stream." [Source: game-architecture.md, project-context.md#Engine-Specific Rules]

**`CountryState` is an `@immutable` class with manual `copyWith`.** Fields: `id`, `unlocked`, `ipLevel`, `leaderTier`, `bankedInfluence`, `lastCollectedAt` — exactly as defined in architecture §CountryState (line 950-985). No `freezed`. [Source: game-architecture.md#Standard Implementation Patterns §A]

**No Flutter imports in `lib/game/`.** All new code under `lib/game/features/countries/` is pure Dart. `GameLoop` (Flutter widget) lives in `lib/ui/`. [Source: project-context.md#Engine-Specific Rules, rule 1]

**No logging in tick hot path.** `GameWorld.tick()` and the countries reducer must NOT call `Logger`. Use `assert(...)` for invariants. [Source: project-context.md#Performance Rules — "Forbidden in hot paths"]

**`gameWorldProvider` is a `StateNotifierProvider<GameWorldNotifier, GameState>`.** Architecture pattern §B defines the exact shape: notifier wraps `GameWorld`, subscribes to events stream, syncs state. [Source: game-architecture.md, line 1018-1033]

### Implementation Approach

**Influence accumulation formula (this story — no multipliers).** For each unlocked country per tick:
```
delta = baseInfluence * (dt.inMicroseconds / (generationSeconds * 1,000,000))
newBanked = country.bankedInfluence + delta
```
Story 3.1 introduces `IncomeCalculator` with the full multiplier stack. This story uses ONLY `baseInfluence` from `CountryDef`. Do NOT implement any multiplier logic here — it would duplicate `IncomeCalculator` and drift.

**`GameState` expansion.** Currently `GameState` is an empty `@immutable` class. This story adds:
- `Map<CountryId, CountryState> countries` — keyed by `CountryId`, built from `ContentRegistry.countries` at `GameWorld` construction
- `Influence totalInfluence` — starts at `Influence.zero`

The constructor changes from `const GameState()` to a named-parameter constructor. Existing tests use `const GameState()` — update them to use the new constructor (or provide a factory that creates an empty-but-valid state).

**`GameLoop` widget placement.** `GameLoop` should wrap the app content at a high level (e.g., inside `AppScaffold` or as a parent of the main content area). It must persist across tab switches (`IndexedStack` keeps it alive). It is NOT inside `MapScreen` — the tick loop runs regardless of which tab is visible.

**Ticker delta clamping.** The `Ticker` callback receives elapsed time since start, not since last frame. Track `_lastElapsed` and compute `frameDelta = elapsed - _lastElapsed`. Clamp `frameDelta` to max 100ms before passing to `gameWorld.tick()`.

**No state mutation on zero-generation tick.** If no unlocked countries exist, `tick` returns immediately without copying state or emitting events. This is critical for performance — the game starts with all countries locked until Story 2.7 seeds Egypt.

### Library/Framework Requirements

- No new packages needed
- `package:decimal` — already a dependency, used for `Influence` and `bankedInfluence`
- `package:flutter_riverpod` — already a dependency, for `gameWorldProvider`
- `package:meta` — already a dependency, for `@immutable`

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/game/features/countries/country_state.dart` | `CountryState` immutable class |
| CREATE | `lib/game/features/leaders/leader_tier.dart` | `LeaderTier` enum (`none, tier1, tier2, tier3`) |
| CREATE | `lib/game/features/countries/countries_reducer.dart` | Pure-function tick reducer for country influence accumulation |
| MODIFY | `lib/game/game_state.dart` | Add `countries` map and `totalInfluence` fields |
| MODIFY | `lib/game/game_world.dart` | Wire countries reducer into `tick()`, build initial state from `ContentRegistry` |
| CREATE | `lib/ui/features/map/game_loop.dart` | `GameLoop` widget: single `Ticker`, lifecycle observer |
| CREATE | `lib/providers/game_providers.dart` | `gameWorldProvider`, `GameWorldNotifier`, `clockProvider` |
| CREATE | `test/game/features/countries/countries_reducer_test.dart` | Unit tests for countries tick reducer |
| MODIFY | `test/game/game_world_test.dart` | Update for new `GameState` shape, add influence generation tests |
| CREATE | `test/ui/features/map/game_loop_test.dart` | Widget tests for `GameLoop` ticker and lifecycle |

### Testing Standards

- **Countries reducer tests use `package:test/test.dart`** — pure Dart, no Flutter
- **GameWorld tests use `package:test/test.dart`** — pure Dart, no Flutter (existing pattern in `test/game/game_world_test.dart`)
- **GameLoop widget tests use `package:flutter_test/flutter_test.dart`** — needs Flutter's `TestWidgetsFlutterBinding` for ticker simulation
- **Use `FakeClock`** from `test/helpers/fake_clock.dart` for deterministic time
- **Accumulation tolerance:** Decimal arithmetic is exact (no floating-point), but accumulated values across many small ticks may differ from a single multiplication — test with tolerance or test with a single large tick for exactness
- **Override all providers in widget tests** — `gameWorldProvider`, `contentRegistryProvider`, `clockProvider`
- **No `print()`** — `Logger` only, never in hot paths

### Anti-Patterns to Avoid

- Do NOT use `double` for influence accumulation — use `Decimal` via `Influence` value objects
- Do NOT implement multiplier logic (IP level, leaders, achievements, etc.) — that's Story 3.1's `IncomeCalculator`. This story uses `baseInfluence` only
- Do NOT call `DateTime.now()` inside `lib/game/` — use injected `Clock`
- Do NOT emit events on every tick frame — only emit when state actually changed
- Do NOT allocate new `Map<CountryId, CountryState>` if no country changed — return same instance
- Do NOT log inside `tick()` or the reducer — hot path, use `assert` for invariants
- Do NOT create a second `Ticker` — `GameLoop` owns the ONE ticker in the entire app
- Do NOT put `GameLoop` inside `MapScreen` — it goes at a higher level so ticks continue on all tabs
- Do NOT store `Duration` elapsed since app start as the tick argument — compute per-frame delta from consecutive `Ticker` callbacks
- Do NOT handle offline catch-up in this story — Epic 6 scope
- Do NOT use `print()` anywhere — `Logger('Tag')` only
- Do NOT use `freezed` — manual `copyWith` per architecture
- Do NOT put `saveRepository.flush()` in the lifecycle observer yet — that's Epic 6. This story only starts/stops the ticker

### Previous Story Intelligence

**From Story 2-4 (Point-in-Polygon Hit Testing — ready-for-dev, not yet implemented):**
- Story 2.4 dispatches `TapCountry(countryId)` via `ref.read(gameWorldProvider.notifier).apply(cmd)` — this story CREATES `gameWorldProvider`, so 2.4 depends on it
- Story 2.4 may create a stub `gameWorldProvider` at `lib/providers/game_providers.dart` if it lands first. If so, replace the stub with the full implementation. If this story lands first, the full provider is created here
- `TapCountry` command is added to `game_command.dart` by Story 2.4 — if it exists, the `applyCommand` switch must handle it

**From Story 1-9 (GameWorld skeleton — done):**
- `GameWorld` currently has `tick(Duration dt)` as a no-op with `assert(!dt.isNegative)`
- `GameState` is an empty class with `const GameState()` constructor
- `GameCommand` has only `Noop` — `applyCommand` switch must remain exhaustive after any new variants
- `GameEvent` has `Tick(DateTime at)` — reuse or extend as needed
- Event stream is `StreamController.broadcast(sync: true)` — subscribers observe state + event in same microtask

**From Story 1-5 (Influence/Intel value objects — done):**
- `Influence` wraps `Decimal`, has `+`, `-`, `*`, comparison operators, `zero`, `isZero`, `format()`
- `Influence.multiplyByNum(num)` exists for multiplying by numeric values
- Use `Influence` for all banked influence tracking, NOT raw `Decimal` in public APIs

**From Story 1-7 (ContentRegistry — done):**
- `ContentRegistry.countries` is `Map<CountryId, CountryDef>` — each `CountryDef` has `baseInfluence` (Decimal) and `generationSeconds` (int)
- `contentRegistryProvider` at `lib/providers/app_providers.dart` loads from assets

**From Story 1-8 (GameError — done):**
- `GameError` sealed hierarchy with `UserError` and `InternalError` subtypes
- `Result<T, GameError>` at `lib/game/values/result.dart` — use for `applyCommand` return type

### Git Intelligence

Only 4 infrastructure commits exist. All implementation code is in the working tree (uncommitted). No merge conflicts expected.

### Project Structure Notes

- `lib/game/features/countries/` is a new directory — first feature folder created. Architecture shows: `features/ { countries/ upgrades/ leaders/ ... }` with `{ state, reducer }` per feature
- `lib/game/features/leaders/leader_tier.dart` — `LeaderTier` enum is needed by `CountryState` but the leaders feature folder is created minimally (just the enum)
- `lib/providers/game_providers.dart` — new file, composition root for game-layer providers. Story 2.4 may also need to create this; whoever lands first creates it
- `lib/ui/features/map/game_loop.dart` — GameLoop lives under map feature for now; could be elevated to `lib/ui/` root level later if needed for other screens

### Cross-Story Context

- **Story 2.4** (prerequisite for tap) creates `TapCountry` command + hit-testing — independent of tick, but both need `gameWorldProvider`
- **Story 2.6** (depends on this) implements `TapCountry` handler in `applyCommand` — collects `bankedInfluence`, emits `CountryTapped` event. Story 2.6 needs `CountryState.bankedInfluence` to exist (created here)
- **Story 2.7** (depends on this) seeds Egypt as `unlocked: true, ipLevel: 1` in initial state — without this seed, no country generates influence (all locked)
- **Story 3.1** creates `IncomeCalculator.compute()` — the authoritative multiplier stack. This story's simple `baseInfluence`-only accumulation will be replaced by a call to `IncomeCalculator.compute()` in the reducer
- **Epic 6** adds persistence and offline catch-up — lifecycle observer will additionally call `saveRepository.flush()` and `OfflineCatchup.apply()` on resume

### References

- [Source: epics.md#Story 2.5, line 702] — User story, acceptance criteria
- [Source: game-architecture.md#Game Loop, line 218-225] — Single Ticker, variable timestep, lifecycle hooks
- [Source: game-architecture.md#Simulation Layering, line 202-209] — GameWorld tick/applyCommand/events
- [Source: game-architecture.md#CountryState, line 950-985] — Immutable state class with fields
- [Source: game-architecture.md#Pattern §B, line 990-1033] — gameWorldProvider + GameWorldNotifier
- [Source: game-architecture.md#Content, line 443-451] — countries.json with baseInfluence and generationSeconds
- [Source: project-context.md#Engine-Specific Rules] — No Flutter in lib/game/, reducers are pure, UI dispatches commands
- [Source: project-context.md#Performance Rules] — No logging in hot paths, no per-tick allocations
- [Source: project-context.md#Testing Rules] — package:test for lib/game/, flutter_test for lib/ui/

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Decimal 3.x `Decimal / Decimal` returns `Rational`, not `Decimal` — used `.toDecimal(scaleOnInfinitePrecision: 18)` in reducer
- `GameState()` const constructor removed — existing `game_state_test.dart` updated to use non-const constructor
- `StateNotifierProvider.overrideWith` requires exact `GameWorldNotifier` type — spy notifiers extend `GameWorldNotifier` with a stub `GameWorld(emptyContent)`

### Completion Notes List

- Created `LeaderTier` enum and `CountryState` immutable class with manual `copyWith`/`==`/`hashCode`
- Expanded `GameState` with `countries: Map<CountryId, CountryState>` and `totalInfluence: Influence`; added optional `initialState` param to `GameWorld` constructor (used for testing and by Story 2.7 seeding)
- `tickCountries` pure function: returns same map instance if nothing changed — zero allocation on all-locked start
- `GameWorld.tick()`: only updates state and emits `Tick` event when countries map actually changed
- `GameLoop`: `ConsumerStatefulWidget` with `SingleTickerProviderStateMixin` + `WidgetsBindingObserver`; clamps frame delta to 100ms
- Refactored `gameWorldProvider` to `StateNotifierProvider<GameWorldNotifier, GameState>` per architecture §B; added `clockProvider`
- 377 tests pass (27 new); `flutter analyze --fatal-infos` zero issues; `dart format` clean

### File List

- lib/game/features/leaders/leader_tier.dart (CREATE)
- lib/game/features/countries/country_state.dart (CREATE)
- lib/game/features/countries/countries_reducer.dart (CREATE)
- lib/game/game_state.dart (MODIFY)
- lib/game/game_world.dart (MODIFY)
- lib/ui/features/map/game_loop.dart (CREATE)
- lib/providers/game_providers.dart (MODIFY)
- test/game/features/countries/countries_reducer_test.dart (CREATE)
- test/game/game_world_test.dart (MODIFY)
- test/game/game_state_test.dart (MODIFY)
- test/ui/features/map/game_loop_test.dart (CREATE)
- test/ui/features/map/map_screen_tap_test.dart (MODIFY)
- _bmad-output/implementation-artifacts/sprint-status.yaml (MODIFY)

## Change Log

- 2026-04-22: Implemented Story 2.5 — CountryState + countries reducer + GameLoop ticker + gameWorldProvider refactor; 377 tests pass
- 2026-04-22: Code review passed — 0 HIGH, 0 MEDIUM findings. All 4 ACs implemented, all 10 tasks verified. 377 tests pass, `flutter analyze --fatal-infos` clean, `dart format` clean. LOW notes (not fixed): `CountryState.copyWith` cannot clear `lastCollectedAt` (latent, unexercised); `GameLoop` not yet wired in app tree (Epic 7 scaffold scope); `GameWorldNotifier.apply` drops `Result` (no failing commands exist yet — Story 2.6 revisits).
