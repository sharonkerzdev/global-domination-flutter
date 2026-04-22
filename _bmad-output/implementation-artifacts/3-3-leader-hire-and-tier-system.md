# Story 3.3: Leader Hire and Tier System

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to hire a Leader for a country once its IP reaches level 10, then upgrade that Leader through tiers,
so that my countries generate Influence passively and grow more powerful over time.

## Acceptance Criteria

1. **Given** a country with `ipLevel >= 10` and `leaderTier == LeaderTier.none`, and I have enough Influence
   **When** I dispatch `HireLeader(countryId)`
   **Then** `leaderTier` becomes `LeaderTier.tier1`, Influence decreases by the hire cost, and `LeaderHired` event fires.
2. **Given** a country with `ipLevel < 10`
   **When** I dispatch `HireLeader`
   **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'ip_below_10'))`.
3. **Given** a country with an existing Leader
   **When** I dispatch `HireLeader` again
   **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'leader_already_hired'))`.
4. **Given** a country with a Leader and the tick runs
   **When** the game loop processes the country
   **Then** the country's income is continuous (per-second) rather than timer-gated — banked influence accumulates without needing a generation cycle to complete.
5. **Given** a country with `leaderTier == tier1` and enough Influence
   **When** I dispatch `UpgradeLeader(countryId)`
   **Then** `leaderTier` becomes `tier2`, Influence decreases by the tier-2 cost, and `LeaderUpgraded` fires with the new tier.
6. **Given** `leaderTier == tier2` -> upgrade to `tier3` works identically.
7. **Given** `leaderTier == tier3`
   **When** I dispatch `UpgradeLeader`
   **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'leader_max_tier'))`.
8. **Given** `leaderTier == none`
   **When** I dispatch `UpgradeLeader`
   **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'no_leader_hired'))` — upgrade only applies after hire.
9. **Given** the multiplier lookup
   **When** `LeaderTier` values are read
   **Then** they map per the final mapping pinned in `BalanceConfig` at Epic 10 — the GDD documents `1.0x -> 1.5x -> 2.0x -> 3.0x` across 4 tiers. This story implements the lookup as a single named-constant table; exact values may be adjusted during Epic 10 tuning without code changes beyond that table.

## Tasks / Subtasks

- [x] Task 1: Add `HireLeader` and `UpgradeLeader` commands to `game_command.dart` (AC: 1, 2, 3, 5, 6, 7, 8)
- [x] Task 2: Add `LeaderHired` and `LeaderUpgraded` events to `game_event.dart` (AC: 1, 5)
- [x] Task 3: Create `leaders_reducer.dart` to handle leader commands (AC: 1, 2, 3, 5, 6, 7, 8)
  - [x] Subtask 3.1: Implement `applyHireLeader` logic and cost deduction
  - [x] Subtask 3.2: Implement `applyUpgradeLeader` logic and cost deduction
- [x] Task 4: Integrate commands into `GameWorld.applyCommand` (AC: 1, 5)
- [x] Task 5: Add `userLocked` reasons to `GameError` if needed (AC: 2, 3, 7, 8)
- [x] Task 6: Update `countries_reducer.dart` if needed to ensure continuous income for countries with leaders (AC: 4)
  - [x] Subtask 6.1: Verify `IncomeCalculator` and `tickCountries` correctly handle continuous generation.
- [x] Task 7: Ensure `LeaderTier` and `BalanceConfig` match the required multiplier lookup (AC: 9)
  - [x] Subtask 7.1: Verify `LeaderTier` enum has `none, tier1, tier2, tier3`
  - [x] Subtask 7.2: Verify `BalanceConfig.leaderMultipliers` maps to `1.0, 1.5, 2.0, 3.0`

### Review Findings

- [x] [Review][Patch] Enforce negative `ipLevel` invariant in `applyUpgradeLeader` [`lib/game/features/leaders/leaders_reducer.dart`]
- [x] [Review][Patch] Preserve non-positive `generationSeconds` guard for leader automation path [`lib/game/features/countries/countries_reducer.dart`]
- [x] [Review][Patch] Add `GameWorld.applyCommand(UpgradeLeader)` integration coverage [`test/game/game_world_test.dart`]
- [x] [Review][Patch] Add insufficient-funds and invariant edge-case tests for leader reducer [`test/game/features/leaders/leaders_reducer_test.dart`]

## Dev Notes

- Relevant architecture patterns and constraints:
  - `lib/game/` has ZERO Flutter imports. Pure Dart only.
  - Reducers are pure functions returning `Result<(GameState, GameEvent?), GameError>`.
  - Commands and Events are sealed class hierarchies.
  - Big numbers flow through `Influence` value objects.
  - Multiplier stack is single source of truth in `IncomeCalculator.compute`.
  - No exceptions for control flow; use `Result.failure(GameError.userLocked(...))`.
- Source tree components to touch:
  - `lib/game/game_command.dart`
  - `lib/game/game_event.dart`
  - `lib/game/game_world.dart`
  - `lib/game/game_error.dart`
  - `lib/game/features/leaders/leaders_reducer.dart` (new)
  - `test/game/features/leaders/leaders_reducer_test.dart` (new)
- Testing standards summary:
  - Pure-Dart tests for `lib/game/` using `package:test/test.dart`.
  - Use `GameStateBuilder` to construct test states.
  - Exhaustive testing of `Result.failure` cases.

### Project Structure Notes

- Alignment with unified project structure (paths, modules, naming)
  - Feature logic should be isolated in `lib/game/features/leaders/`.
- Detected conflicts or variances (with rationale)
  - `LeaderTier` and `BalanceConfig.leaderMultipliers` already exist and match requirements.

### Project Context Rules

- Project-wide constraints, required frameworks, MCP integrations, and conventions extracted from project-context.md
  - **`lib/game/` has ZERO Flutter imports.** No `package:flutter/*`, no `dart:ui`. Pure Dart only.
  - **UI never mutates `GameState` directly.** UI dispatches a `GameCommand` via `ref.read(gameWorldProvider.notifier).apply(cmd)`.
  - **Reducers:** Pure functions. NO clock reads, NO RNG reads, NO I/O. `now` and `rng` flow in as parameters. Return `Result<(NewState, Event), GameError>` — no exceptions for control flow.
  - **Commands vs Events:** Commands (input to sim): imperative. Events (output from sim): past tense. Both are sealed class hierarchies. Exhaustive switch.
  - **Big numbers:** All game math flows through `Influence` / `Intel` value objects. `double` for game quantities is a bug. Raw `Decimal` outside `lib/game/values/` is a lint violation.
  - **Result / error handling:** `Result<T, GameError>` (sealed) for anything that can fail meaningfully. NO exceptions for control flow.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 3]
- [Source: _bmad-output/game-architecture.md#1. Simulation Layering]

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

### Completion Notes List

- Implemented `HireLeader` / `UpgradeLeader`, `leaders_reducer` with locked-reason and insufficient-fund handling; `BalanceConfig` + `IncomeCalculator` for hire/upgrade cost curves; `tickCountries` uses 1s accrual period when `leaderTier != none` (continuous automation).
- `flutter test`: 449 passed (new reducer, game command/event, game_world, countries tick, and income cost tests).

### File List

- `lib/game/config/balance.dart`
- `lib/game/features/economy/income_calculator.dart`
- `lib/game/features/countries/countries_reducer.dart`
- `lib/game/features/leaders/leaders_reducer.dart` (new)
- `lib/game/game_command.dart`
- `lib/game/game_event.dart`
- `lib/game/game_world.dart`
- `test/game/features/economy/income_calculator_test.dart`
- `test/game/features/leaders/leaders_reducer_test.dart` (new)
- `test/game/features/countries/countries_reducer_test.dart`
- `test/game/game_command_test.dart`
- `test/game/game_event_test.dart`
- `test/game/game_world_test.dart`

### Change Log

- 2026-04-22: Story 3.3 — leader hire/upgrade commands and reducer; continuous tick when leader hired; cost helpers in `IncomeCalculator`; tests and sprint status → review
