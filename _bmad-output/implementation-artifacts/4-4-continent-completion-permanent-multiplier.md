# Story 4.4: Continent Completion Permanent Multiplier

Status: ready-for-dev

## Story

As a player,
I want a permanent global multiplier when I own 100% of a continent's countries,
So that every subsequent action is amplified by my completed conquests.

## Acceptance Criteria

1. **Given** I own all countries in a continent
   **When** `ContinentCompleted(continentId)` fires
   **Then** `state.continentCompletions[continentId] = true` and the `continentCompletionBonus` factor in `IncomeCalculator` uses the per-continent bonus (Africa +0.25×, Europe +0.50× ... Oceania +1.75×).
2. **Given** multiple continents are complete
   **When** `IncomeCalculator.compute` runs
   **Then** the `continentCompletionBonus` factor is the product `∏(1 + bonus)` over all completed continents.
3. **Given** a continent was previously completed and is loaded from save
   **When** the game boots
   **Then** the bonus applies without re-firing `ContinentCompleted` (idempotent — save records completion state, not just event log).

## Developer Context & Guardrails

### Technical Requirements

- **Event**: Add `ContinentCompleted(ContinentId)` to `game_event.dart`.
- **State Mutation**: The event `ContinentCompleted` should be emitted when the last country in a continent is unlocked. Since Story 4.1 handles unlocking countries, you may need to add logic there (or in a new continent completion reducer) to check if all countries in the continent are now unlocked, and if so, emit `ContinentCompleted` and update `state.continentCompletions[continentId] = true`.
- **IncomeCalculator**: Update `_continentCompletionBonus` in `lib/game/features/economy/income_calculator.dart`. Currently, it only applies the bonus of the *country's* continent. It must be updated to multiply `(1 + bonus)` for *all* completed continents in `state.continentCompletions`, not just the country's continent.

### Architecture Compliance

- **No Flutter Imports**: `lib/game/` must remain pure Dart.
- **Immutable State**: Use `copyWith` for all state mutations.
- **Multiplier Stack**: The multiplier stack order in `IncomeCalculator.compute` must remain unchanged, but the value of `continentCompletionBonus` must be the product of all completed continent bonuses.

### Project Context Rules

- **Big Numbers**: Use `Decimal` for multipliers.
- **Event Bus**: Emit `ContinentCompleted`. Ensure it's part of the sealed `GameEvent` hierarchy.
- **Persistence**: `GameState` already has `continentCompletions`. Ensure it is correctly persisted and loaded (Epic 6 will handle full persistence, but ensure the state structure is correct).

## Completion Status

Ultimate context engine analysis completed - comprehensive developer guide created.
