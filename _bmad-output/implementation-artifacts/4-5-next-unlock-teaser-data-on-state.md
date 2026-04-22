# Story 4.5: Next-Unlock Teaser Data on State

Status: ready-for-dev

## Story

As a player,
I want to know which country is next and what it will cost,
So that I have a clear near-term goal.

## Acceptance Criteria

1. **Given** the player is in continent C with unlocked and locked countries
   **When** a UI watches `nextUnlockInContinentProvider(C)`
   **Then** it returns `{ countryId, unlockCost }` for the next locked country in continent order, or `null` if C is fully unlocked.
2. **Given** multiple continents are unlocked
   **When** a UI watches `nextUnlockOverallProvider`
   **Then** it returns `{ countryId, unlockCost, continent }` for the next locked country in the earliest-unlocked continent with locked countries, or `null` if world is complete.

## Tasks / Subtasks

- [ ] Task 1: Define `NextUnlockTeaser` record/class
  - [ ] Create `NextUnlockTeaser` in `lib/game/features/continents/continent_state.dart` or a new file `next_unlock_teaser.dart`
  - [ ] Include `countryId`, `unlockCost` (as `Influence`), and optional `continentId`
- [ ] Task 2: Implement `nextUnlockInContinentProvider` (AC 1)
  - [ ] Create family provider taking `ContinentId`
  - [ ] Watch `gameWorldProvider` for `countries` state
  - [ ] Read `ContentRegistry.continents[C].countries` for order
  - [ ] Find first locked country and return its `NextUnlockTeaser` reading `unlockCost` from `ContentRegistry.countries[id].unlockCost`
- [ ] Task 3: Implement `nextUnlockOverallProvider` (AC 2)
  - [ ] Watch `gameWorldProvider` for `continents` and `countries`
  - [ ] Iterate continents in order to find the first unlocked continent with locked countries
  - [ ] Return the `NextUnlockTeaser` for that continent
- [ ] Task 4: Tests
  - [ ] Write unit tests for both providers verifying correct country selection and `null` when fully unlocked

## Dev Notes

### Technical Requirements
- **Providers**: Create `nextUnlockInContinentProvider(String continentId)` and `nextUnlockOverallProvider` in `lib/providers/feature_providers.dart` or a dedicated `lib/providers/unlock_providers.dart`.
- **Data Source**: The providers will need to watch `gameWorldProvider` (to get `state.countries` and `state.continents`) and read `ContentRegistry.countries` / `ContentRegistry.continents` to determine the order and unlock costs.
- **Continent Order**: The order of countries in a continent is defined in `ContentRegistry.continents[C].countries`. The "next locked country in continent order" is the first country in that list where `state.countries[id]?.unlocked == false`.
- **Unlock Cost**: The unlock cost is `ContentRegistry.countries[id].unlockCost`. Use that directly from `ContentRegistry.countries[id].unlockCost` (as established in Story 4.1).
- **Earliest-unlocked continent**: The `nextUnlockOverallProvider` should iterate through `ContentRegistry.continents` in order, find the first continent that is unlocked (`state.continents[C]?.unlocked == true`) AND has at least one locked country. Return the next unlock for that continent.
- **Return Type**: Define a simple immutable struct/record `NextUnlockTeaser(String countryId, Influence unlockCost, [String? continentId])` in `lib/game/features/continents/` to hold the result.

### Architecture Compliance
- **No Flutter Imports**: `lib/game/` must remain pure Dart.
- **Riverpod**: Use `.select()` aggressively to avoid unnecessary widget rebuilds. The providers themselves can watch the specific parts of the state they need, e.g., `ref.watch(gameWorldProvider.select((s) => s.countries))`.

### Previous Story Intelligence (from 4.1)
- **Unlock Cost**: Use `ContentRegistry.countries[id].unlockCost` directly rather than calculating at runtime.
- **Testing**: Add comprehensive tests for edge cases (all countries unlocked, continent locked, etc.).

### Project Context Rules
- **Big Numbers**: `unlockCost` must be an `Influence` value object. Do not use raw `double` or `int`.
- **Testing**: Use `package:test/test.dart` for pure-Dart tests under `test/game/`. Use `ProviderContainer` to test Riverpod providers.

## Completion Status
Ultimate context engine analysis completed - comprehensive developer guide created.
