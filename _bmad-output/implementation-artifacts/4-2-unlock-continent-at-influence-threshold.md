# Story 4.2: unlock-continent-at-influence-threshold

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the next continent to unlock automatically when my total Influence crosses its threshold,
So that new geography opens as my power grows without extra friction.

## Acceptance Criteria

1. **Given** the continent thresholds (Africa=0, Europe=1e9, Middle East=1e14, Asia=1e20, South America=1e26, North America=1e32, Oceania=1e38)
   **When** my `totalInfluence` crosses a threshold
   **Then** the `ContinentUnlocked(continentId)` event fires exactly once, the continent's `unlocked` flag becomes `true`, and its countries become `UnlockCountry`-eligible.
2. **Given** my total Influence is already past multiple thresholds (e.g. fresh state loaded after a jump)
   **When** the game ticks
   **Then** all crossed-but-unhandled continents unlock in order with separate events.
3. **Given** a continent is unlocked
   **When** I check the state
   **Then** the `ContinentUnlocked` event is emitted only once per continent per game — idempotent.

## Tasks / Subtasks

- [ ] Task 1: Extend `GameState` to track unlocked continents (AC: 1, 3)
  - [ ] Add `Set<ContinentId> unlockedContinents` to `GameState` (or similar representation like `Map<ContinentId, ContinentState>`).
  - [ ] Update `GameState.initialSeed` to seed the initial unlocked continent (e.g., Africa).
  - [ ] Update `GameState` equality, hashCode, copyWith, and toString.
- [ ] Task 2: Add `ContinentUnlocked` event (AC: 1)
  - [ ] Add `ContinentUnlocked(ContinentId)` to `GameEvent` sealed class in `lib/game/game_event.dart`.
- [ ] Task 3: Implement Continent Unlocking Logic (AC: 1, 2, 3)
  - [ ] Create `lib/game/features/continents/continents_reducer.dart`.
  - [ ] Implement a pure reducer function that checks `totalInfluence` against `ContinentDef.unlockThreshold` for all locked continents.
  - [ ] Return a `Result<(GameState, List<GameEvent>), GameError>` or similar, emitting `ContinentUnlocked` for each newly unlocked continent in threshold order.
- [ ] Task 4: Wire Reducer into `GameWorld` (AC: 1, 2)
  - [ ] Update `GameWorld.tick` (and/or `applyCommand` if influence jumps) to invoke the continents reducer.
  - [ ] Ensure multiple continents can unlock in a single tick if influence jumps significantly.
- [ ] Task 5: Tests (AC: 1, 2, 3)
  - [ ] Write pure Dart tests in `test/game/features/continents/continents_reducer_test.dart`.
  - [ ] Test multiple unlocks in one tick.
  - [ ] Test idempotency (no duplicate events).

## Dev Notes

- **Relevant architecture patterns and constraints**:
  - `lib/game/` has ZERO Flutter imports. Pure Dart only.
  - Reducers are pure functions. NO clock reads, NO RNG reads, NO I/O.
  - `ContinentDef.unlockThreshold` contains the threshold values (parsed as `Decimal`).
  - `GameState` is immutable. Use `copyWith`.
  - `GameEvent` is a sealed hierarchy. Exhaustive `switch` must be maintained.
- **Source tree components to touch**:
  - `lib/game/game_state.dart`
  - `lib/game/game_event.dart`
  - `lib/game/features/continents/continents_reducer.dart`
  - `lib/game/game_world.dart`
  - `test/game/features/continents/continents_reducer_test.dart`
- **Testing standards summary**:
  - Use `package:test/test.dart` for pure Dart tests in `test/game/`.
  - Use `GameStateBuilder` to construct test states.
  - Test the reducer in isolation.

### Project Structure Notes

- Alignment with unified project structure: `lib/game/features/continents/` is the correct location for continent-related reducers.

### Project Context Rules

- **Third-party frameworks**: `decimal` for big numbers. Wrap in `Influence` / `Intel` if applicable, or use `Decimal` directly if comparing raw thresholds.
- **Coding conventions**: No `freezed`. Manual `copyWith`, `==`, `hashCode`.
- **Architecture constraints**: `GameWorld` is the only mutator. Reducers return `Result`. `GameEvent`s are emitted by `GameWorld`.
- **Anti-patterns**: No `package:flutter/*` in `lib/game/`. No `DateTime.now()`. No `print()`.

### References

- [Source: _bmad-output/game-architecture.md#7-event-bus]
- [Source: _bmad-output/planning-artifacts/epics.md#Epic-4]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
