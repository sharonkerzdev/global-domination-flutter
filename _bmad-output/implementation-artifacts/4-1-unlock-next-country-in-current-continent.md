# Story 4.1: Unlock Next Country in Current Continent

Status: ready-for-dev

## Story

As a player,
I want to spend Influence to unlock the next locked country in my current continent,
So that I can expand my influence footprint geographically.

## Acceptance Criteria

1. **Given** a continent with at least one locked country whose prerequisites are met, and enough Influence
   **When** I dispatch `UnlockCountry(countryId)`
   **Then** the country's `unlocked` flag becomes `true`, its `ipLevel` starts at 1, Influence decreases by `unlockCost`, and `CountryUnlocked` event fires.
2. **Given** `unlockCost` formula per GDD
   **When** the Nth country in a continent unlocks
   **Then** `unlockCost = previousCountry.unlockCost × 5` (with the continent's base unlock cost seeding N=1).
3. **Given** I try to unlock a country in a continent not yet unlocked
   **When** `UnlockCountry` is dispatched
   **Then** the reducer returns `Result.failure(GameError.userLocked(reason: 'continent_locked'))`.
4. **Given** all countries in the current continent are unlocked
   **When** I look for the next unlock
   **Then** no country in that continent is unlockable; only the next continent is.

## Developer Context & Guardrails

### Technical Requirements

- **Command & Event**: Add `UnlockCountry(CountryId)` to `game_command.dart` and `CountryUnlocked(DateTime, CountryId, ContinentId, Influence)` to `game_event.dart`.
- **Reducer**: Implement `applyUnlockCountry` in `countries_reducer.dart` (or a dedicated `unlocks_reducer.dart` if preferred, but `countries_reducer.dart` is where country state lives).
- **Validation**:
  - Check if the country exists.
  - Check if the country is already unlocked.
  - Check if the continent is unlocked (Epic 4.2 handles continent unlocking, but we must enforce the check here).
  - Check if the player has enough Influence.
  - Check if the country is the *next* country in sequence for that continent (countries unlock sequentially).
- **Cost Calculation**: The cost formula `unlockCost = previousCountry.unlockCost * 5` should be implemented in a pure function, likely in `IncomeCalculator` or a new `CostCalculator` / `UnlockCalculator`, or simply read from `ContentRegistry` if the costs are pre-calculated in `countries.json`. According to the GDD, the JSON has an `unlockCost` field. *Correction*: The JSON has `unlockCost`, use that directly from `ContentRegistry.countries[id].unlockCost` rather than calculating at runtime, but verify if the JSON has the `* 5` curve baked in. If the JSON has it, just use the JSON value.
- **State Mutation**: Update the country's `unlocked` to `true`, `ipLevel` to `1`, and deduct the cost from `state.influence`.

### Architecture Compliance

- **No Flutter Imports**: `lib/game/` must remain pure Dart.
- **Result Return Type**: Reducers must return `Result<(GameState, GameEvent), GameError>`.
- **Immutable State**: Use `copyWith` for all state mutations.
- **Error Handling**: Use `GameError.userLocked(reason: '...')` or `GameError.userInsufficientFunds(required: ...)` for expected failures.

### Previous Story Intelligence (from 3.3)

- **Invariant Enforcement**: Be sure to write defensive tests for negative values and invalid states.
- **Continuous Generation**: Remember that countries with leaders generate continuously. A newly unlocked country starts at `ipLevel = 1` and `leaderTier = none`, so it will use timer-based generation until upgraded.
- **Testing**: Add comprehensive `Result.failure` tests for all edge cases (insufficient funds, already unlocked, continent locked, wrong sequence).

### Project Context Rules

- **Big Numbers**: Use `Influence` value objects. Do not use raw `double` or `int` for influence.
- **Event Bus**: Emit `CountryUnlocked`. The `AudioService` and `HapticsService` will subscribe to this to play effects.
- **Persistence**: `SaveRepository` will need to persist the `unlocked` state when `CountryUnlocked` is emitted. Update `SaveRepository.persistEvent` to handle `CountryUnlocked`.

## Completion Status

Ultimate context engine analysis completed - comprehensive developer guide created.
