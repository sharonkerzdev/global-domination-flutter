# Story 2.6: Tap-to-Collect Collects Banked Influence

Status: done

## Story

As a player,
I want tapping an unlocked country to collect its banked Influence and add it to my total,
So that I can see the number go up and feel the core loop.

## Acceptance Criteria

1. **Given** a country has banked influence > 0 **When** the `TapCountry` command is applied **Then** the country's `bankedInfluence` resets to 0, the world's `totalInfluence` increases by that amount, and a `CountryTapped` event is emitted with the collected amount.

2. **Given** a country has banked influence = 0 **When** `TapCountry` is applied **Then** `Result.success` is returned but no `CountryTapped` event is emitted (UI treats zero as no-op — no "0" flyout animation).

3. **Given** a `CountryTapped` event **When** the HUD is watching `totalInfluenceProvider` **Then** the HUD updates to the new total in the next frame.

## Tasks / Subtasks

- [x] Task 1: Create `CountryTapped` event variant in `GameEvent` sealed hierarchy (AC: 1, 3)
  - [x] 1.1 Add `CountryTapped({required CountryId countryId, required Influence collected})` to `GameEvent` in `lib/game/game_event.dart`
  - [x] 1.2 Ensure exhaustive switch coverage in any existing event consumers (AudioService, HapticsService if present)

- [x] Task 2: Implement countries collect reducer (AC: 1, 2)
  - [x] 2.1 Create `lib/game/features/countries/countries_collect_reducer.dart` — pure function: `Result<(GameState, GameEvent?), GameError> collectInfluence(GameState state, TapCountry cmd, {required DateTime now})`
  - [x] 2.2 Precondition: country must exist in `state.countries` → `GameError.internalMissingCountry` if missing (invariant breach, not user error — UI only surfaces loaded countries)
  - [x] 2.3 Precondition: country must be `unlocked == true` → `GameError.locked` if not
  - [x] 2.4 If `bankedInfluence == Decimal.zero` → return `Result.success((state, null))` — no event emitted
  - [x] 2.5 If `bankedInfluence > 0` → compute `newCountryState = country.copyWith(bankedInfluence: Decimal.zero, lastCollectedAt: now)`, `newTotalInfluence = state.totalInfluence + collected`, build new `GameState`, return with `CountryTapped` event
  - [x] 2.6 All arithmetic via `Influence` value object operators — never raw `Decimal` outside game layer

- [x] Task 3: Wire reducer into `GameWorld.applyCommand` (AC: 1, 2)
  - [x] 3.1 Add `TapCountry` case to the `switch` in `GameWorld.applyCommand()`
  - [x] 3.2 Call `countriesCollectReducer.collectInfluence(state, cmd, now: _clock.now())`
  - [x] 3.3 On success: update `_state`, emit event to `_eventController` if non-null event returned
  - [x] 3.4 On failure: return the error (no state change, no event)

- [x] Task 4: Unit tests for collect reducer (AC: 1, 2)
  - [x] 4.1 Test: country with banked > 0 → totalInfluence increases, banked resets, event emitted with correct amount
  - [x] 4.2 Test: country with banked = 0 → success, no event emitted
  - [x] 4.3 Test: country not found → `GameError.invalidTarget`
  - [x] 4.4 Test: country locked → `GameError.locked`
  - [x] 4.5 Test: large Decimal values (1e30+) — precision preserved through collect
  - [x] 4.6 Test: `lastCollectedAt` updated to injected `now`
  - [x] 4.7 Test: collecting from one country does not affect other countries' bankedInfluence

- [x] Task 5: GameWorld integration tests (AC: 1, 2, 3)
  - [x] 5.1 Test: tick accumulates → applyCommand(TapCountry) → totalInfluence correct, banked reset
  - [x] 5.2 Test: event stream emits `CountryTapped` with correct `collected` amount
  - [x] 5.3 Test: zero-banked tap → no event on stream
  - [x] 5.4 Test: sequential collects — tick, collect, tick again, collect again — totals accumulate correctly

- [x] Task 6: Full validation (AC: all)
  - [x] 6.1 `flutter analyze` — 0 warnings
  - [x] 6.2 `dart format --set-exit-if-changed`
  - [x] 6.3 `flutter test` — all pass

## Dev Notes

### Architecture Compliance

- **Reducer is pure function** — `now` injected as parameter, no `DateTime.now()`, no I/O, no RNG
- **Return type:** `Result<(GameState, GameEvent?), GameError>` — nullable event for zero-banked case
- **Only `GameWorld` calls the reducer** and emits events to `_eventController`
- **`lib/game/` has ZERO Flutter imports** — use `package:test` not `flutter_test` for game-layer tests
- **Immutable state only** — `copyWith` on both `CountryState` and `GameState`, never mutate

### Implementation Approach

**Collect formula (simple — NOT income calculation):**
```
collected = country.bankedInfluence  // the full banked amount
newTotal = state.totalInfluence + Influence(collected)
newCountry = country.copyWith(bankedInfluence: Decimal.zero, lastCollectedAt: now)
```
This is NOT the multiplier stack — IncomeCalculator is only used during tick for generation rate. Collection is a simple transfer of the already-computed banked amount.

**Zero-banked handling:** Return success with null event. The UI layer (future stories) checks for `CountryTapped` events to trigger flyout animations — null event = no animation. This is simpler than emitting a zero-amount event and filtering downstream.

**Event structure:** `CountryTapped` carries `countryId` and `collected` (Influence). Downstream consumers (AudioService for tap sound, HapticsService for haptic pulse) will subscribe to this event in later stories — for now, ensure the event is properly emitted on the broadcast stream.

### Dependencies — What Must Exist Before This Story

| Dependency | Source Story | What It Provides |
|---|---|---|
| `TapCountry` command variant | Story 2.4 | `TapCountry({required CountryId countryId})` in sealed `GameCommand` |
| `CountryState` with `bankedInfluence` | Story 2.5 | `CountryState.bankedInfluence: Decimal`, `CountryState.lastCollectedAt: DateTime?` |
| `GameState.countries` map | Story 2.5 | `Map<CountryId, CountryState>` on `GameState` |
| `GameState.totalInfluence` field | Story 2.5 | `Influence` field tracking player's collected total |
| `GameWorld.tick()` wired | Story 2.5 | Tick loop populating `bankedInfluence` over time |
| `Influence` value object | Story 1.5 | `Influence` wrapping `Decimal` with `+` operator |
| `GameError` sealed hierarchy | Story 1.8 | `GameError.invalidTarget`, `GameError.locked` variants |
| `Result<T, GameError>` | Story 1.8 | Result type for reducer returns |
| `GameWorld` skeleton | Story 1.9 | `applyCommand` switch, `_state`, `_eventController` |

**If `TapCountry` command does not exist yet** (Story 2.4 not implemented), you must add it to the `GameCommand` sealed class as part of this story — but prefer waiting for 2.4 if possible.

### Project Structure Notes

**Files to CREATE:**
| File | Purpose |
|---|---|
| `lib/game/features/countries/countries_collect_reducer.dart` | Pure collect reducer function |
| `test/game/features/countries/countries_collect_reducer_test.dart` | Unit tests for collect reducer |

**Files to MODIFY:**
| File | Change |
|---|---|
| `lib/game/game_event.dart` | Add `CountryTapped` variant to sealed `GameEvent` |
| `lib/game/game_world.dart` | Add `TapCountry` case in `applyCommand` switch |
| `test/game/game_world_test.dart` | Integration tests for collect flow |

**Files to READ (reference only — do not modify):**
| File | Why |
|---|---|
| `lib/game/game_command.dart` | Verify `TapCountry` variant exists |
| `lib/game/game_state.dart` | Verify `countries`, `totalInfluence` fields exist |
| `lib/game/features/countries/country_state.dart` | Verify `bankedInfluence`, `lastCollectedAt` fields |
| `lib/game/values/influence.dart` | Verify `+` operator available |
| `lib/game/game_error.dart` | Verify `invalidTarget`, `locked` variants |

### Testing Standards

- **Pure Dart tests** in `test/game/` — use `package:test`, NOT `flutter_test`
- **Use `GameStateBuilder`** (if it exists from prior stories) for constructing test states
- **Use `FakeClock`** for injecting `now` parameter — do NOT use `DateTime.now()`
- **Decimal precision tests** — verify collect works at 1e30+ scale with no precision loss
- **No mocks for game layer** — reducers are pure functions, test inputs → outputs directly
- **Event stream tests** — use `expectLater` with `emitsInOrder` on `gameWorld.events` stream

### Anti-Patterns to Avoid

- **DO NOT** read `DateTime.now()` inside the reducer — `now` must be a parameter
- **DO NOT** use `double` for influence amounts — always `Decimal` / `Influence`
- **DO NOT** emit events from anywhere except `GameWorld` after calling the reducer
- **DO NOT** import Flutter in `lib/game/` — this is pure Dart
- **DO NOT** add income calculation logic — collection is a simple banked→total transfer
- **DO NOT** add UI/animation/sound logic — those are downstream story concerns
- **DO NOT** modify `IncomeCalculator` — generation rate is not part of collection
- **DO NOT** allocate new objects in hot paths — reducer runs on every tap, keep it lean

### Previous Story Intelligence

**From Story 2.5 (Tick Drives Influence Generation):**
- `CountryState` has `bankedInfluence: Decimal` and `lastCollectedAt: DateTime?` — these are the fields this story reads and resets
- `GameState` has `countries: Map<CountryId, CountryState>` and `totalInfluence: Influence` — these are the fields this story updates
- Tick reducer pattern in `lib/game/features/countries/countries_tick_reducer.dart` — follow same pure function signature pattern
- `GameWorld.tick()` already updates `_state` and emits events via `_eventController` — follow same pattern in `applyCommand`

### Cross-Story Context

- **Story 2.7** (Initial Seed) will set Egypt as unlocked — test states should include at least one unlocked country
- **Story 3.1** (IncomeCalculator) will formalize the multiplier stack — this story does NOT need it; collection is a simple transfer
- **Epic 6** (Persistence) will save/load `totalInfluence` — for now it's in-memory only
- **Future UI stories** will subscribe to `CountryTapped` events for flyout animations, tap sounds, and haptic feedback

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 2, Story 2.6]
- [Source: _bmad-output/game-architecture.md#Command Pattern & Event Sourcing]
- [Source: _bmad-output/game-architecture.md#Reducer Composition Architecture]
- [Source: _bmad-output/project-context.md#Commands vs Events]
- [Source: _bmad-output/project-context.md#Reducers]

## Dev Agent Record

### Agent Model Used
claude-sonnet-4-6

### Debug Log References

### Completion Notes List
- Implemented `CountryTapped` event in `GameEvent` sealed class with `countryId` + `collected` fields; updated exhaustive switch in `game_event_test.dart`.
- Created pure `collectInfluence` reducer: `MissingCountry` error if country absent, `Locked` error if not unlocked, null event for zero-banked, `CountryTapped` event + state update for positive banked.
- Wired `_applyTapCountry` in `GameWorld.applyCommand` via `Result.map`: updates `_state` and conditionally emits event.
- 9 unit tests (reducer) + 6 integration tests (GameWorld) added. Updated pre-existing `TapCountry` stub tests to reflect real behavior (locked → failure).
- 390 tests pass; `flutter analyze` 0 issues; `dart format` clean.

### Code Review (2026-04-22)
- AC1/AC2 fully verified through reducer unit tests and GameWorld integration tests.
- AC3 (HUD reactive update) deferred to Epic 7 / Story 7.3 — `totalInfluenceProvider` is not part of this story's scope. State update is synchronous and will flow correctly once the provider is wired.
- Task 2.2 description updated to match the deliberate `internalMissingCountry` vs `invalidTarget` decision (missing country is an invariant breach, not user error).
- 0 High / 0 Medium / 1 Low findings. No code fixes required.
- Status → done.

### File List
lib/game/game_event.dart
lib/game/features/countries/countries_collect_reducer.dart
lib/game/game_world.dart
test/game/features/countries/countries_collect_reducer_test.dart
test/game/game_world_test.dart
test/game/game_event_test.dart
