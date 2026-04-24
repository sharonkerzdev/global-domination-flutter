# Story 4.5: Next-Unlock Teaser Data on State

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to know which country is next and what it will cost,
so that I have a clear near-term goal.

## Acceptance Criteria

1. **Given** continent C with at least one country whose `state.countries[id].unlocked == false`
   **When** a UI watches `nextUnlockInContinentProvider(C)`
   **Then** it returns `NextUnlockTeaser(countryId, unlockCost: Influence(def.unlockCost), continent: C)` for the FIRST locked country in continent declaration order, or `null` if every country in C is unlocked.
2. **Given** at least one continent is "effectively unlocked" (`state.totalInfluence >= continentDef.unlockThreshold`) and that continent has locked countries
   **When** a UI watches `nextUnlockOverallProvider`
   **Then** it returns `NextUnlockTeaser(countryId, unlockCost, continent)` for the next locked country in the **lowest-`unlockThreshold` effectively-unlocked continent that still has a locked country**, or `null` if no continent qualifies.
3. **Given** continent C has zero `CountryDef`s in `ContentRegistry` (defensive — e.g. unknown id)
   **When** `nextUnlockInContinentProvider(C)` is read
   **Then** the result is `null` (no throw, no assertion).
4. **Given** the lowest-threshold effectively-unlocked continent has every country unlocked but a higher-threshold continent (also effectively unlocked) still has locked countries
   **When** `nextUnlockOverallProvider` is read
   **Then** the result is the next locked country from that higher-threshold continent — selectors skip fully-unlocked continents.
5. **Given** no continent is effectively unlocked (every `continentDef.unlockThreshold > state.totalInfluence`)
   **When** `nextUnlockOverallProvider` is read
   **Then** the result is `null`.
6. **Given** the cost source rule from Story 4.1 ("`def.unlockCost` is the cost — do NOT recompute `previousCountry × 5` at runtime")
   **When** the selector builds a `NextUnlockTeaser`
   **Then** the `unlockCost` field equals `Influence(def.unlockCost)` — read directly from content. The selector MUST NOT call `IncomeCalculator` (per Story 4.1's "Do NOT modify `IncomeCalculator`" rule for unlock costs) and MUST NOT add a new helper to it.
7. **Given** any change in `state.countries[*].unlocked` or `state.totalInfluence`
   **When** Riverpod re-evaluates the providers
   **Then** the result reflects the new state (no stale cache, no manual invalidation needed — selectors are pure functions of `(GameState, ContentRegistry, [ContinentId])`).
8. **Given** Story 4.2 has not yet landed (no `state.unlockedContinents` field exists)
   **When** this story implements the providers
   **Then** the "effectively unlocked" predicate uses `state.totalInfluence >= continentDef.unlockThreshold` — symmetric with Story 4.1's continent-gate check, so the teaser is consistent with what `UnlockCountry` would actually accept. (After 4.2 lands, `state.unlockedContinents[id] == true` becomes the same predicate by 4.2's AC #1; no change required here unless a follow-up story asks for it.)

_(UI rendering of this teaser lands in Epic 7 — this story provides the derived state only.)_

## Tasks / Subtasks

- [ ] Task 1: Create the `NextUnlockTeaser` value class (AC: 1, 2)
  - [ ] 1.1 Create `lib/game/features/continents/next_unlock_teaser.dart`
  - [ ] 1.2 Define `@immutable class NextUnlockTeaser` with three final fields: `final CountryId countryId; final Influence unlockCost; final ContinentId continent;` and a `const` constructor that takes named required parameters
  - [ ] 1.3 Implement `==`, `hashCode`, `toString` manually (no `freezed`) — follow the pattern in `lib/game/features/countries/country_state.dart` and `lib/game/values/influence.dart`

- [ ] Task 2: Implement pure-Dart selector functions (AC: 1, 2, 3, 4, 5, 6, 8)
  - [ ] 2.1 Create `lib/game/features/continents/next_unlock_selector.dart` (NEW file in the SAME folder as Story 4.1's `unlocks_reducer.dart` and Story 4.2's `continents_reducer.dart`)
  - [ ] 2.2 Implement top-level function `NextUnlockTeaser? nextUnlockInContinent(GameState state, ContentRegistry content, ContinentId continentId)`:
        - Iterate `content.countries.values` in declaration order, skip those whose `continent != continentId`
        - For each remaining `def`, look up `state.countries[def.id]`; if missing or `!unlocked`, return `NextUnlockTeaser(countryId: def.id, unlockCost: Influence(def.unlockCost), continent: continentId)`
        - Otherwise continue; return `null` if every country in C is unlocked or C has no countries
  - [ ] 2.3 Implement top-level function `NextUnlockTeaser? nextUnlockOverall(GameState state, ContentRegistry content)`:
        - Build the list of `ContinentDef`s where `c.unlockThreshold <= state.totalInfluence.value` ("effectively unlocked")
        - Sort that list ascending by `unlockThreshold` (use `Decimal.compareTo`); tie-break by `id.value` ASC for determinism (matches Story 4.2's tie-break rule)
        - For each continent in that order, call `nextUnlockInContinent(state, content, c.id)` and return the first non-null result
        - Return `null` if no continent qualifies or every effectively-unlocked continent's `nextUnlockInContinent` returned `null`
  - [ ] 2.4 Both functions MUST be pure: no `DateTime.now()`, no `Random()`, no async, no I/O. The selector accesses `state` and `content` only.
  - [ ] 2.5 Read `def.unlockCost` directly. Do NOT call `IncomeCalculator.*` for cost. Do NOT add a new helper to `IncomeCalculator` (Story 4.1 explicitly forbids this).

- [ ] Task 3: Wire Riverpod providers in `lib/providers/feature_providers.dart` (AC: 1, 2, 7)
  - [ ] 3.1 Create `lib/providers/feature_providers.dart` (NEW file — first feature-derived provider file; matches the architecture's documented provider layout: `app_providers.dart game_providers.dart data_providers.dart service_providers.dart feature_providers.dart`)
  - [ ] 3.2 Use `import 'package:flutter_riverpod/flutter_riverpod.dart';` (matches `game_providers.dart`); do NOT use `riverpod_generator` / `@riverpod` (forbidden in v1)
  - [ ] 3.3 Add `final nextUnlockInContinentProvider = Provider.family<NextUnlockTeaser?, ContinentId>((ref, continentId) { ... })`:
        - Read `final state = ref.watch(gameWorldProvider);` (returns `GameState`)
        - Read `final content = ref.watch(contentRegistryProvider).valueOrNull;` (it's a `FutureProvider<ContentRegistry>` — see `lib/providers/app_providers.dart`)
        - If `content == null` (still loading) return `null`
        - Otherwise return `nextUnlockInContinent(state, content, continentId)`
  - [ ] 3.4 Add `final nextUnlockOverallProvider = Provider<NextUnlockTeaser?>((ref) { ... })` with the same dependency pattern, returning `nextUnlockOverall(state, content)` or `null` while content is loading
  - [ ] 3.5 Use `ref.watch` (NOT `ref.read`) so the providers re-evaluate on state changes
  - [ ] 3.6 Do NOT use `.select(...)` here — country `unlocked` flags AND `totalInfluence` are both inputs to the result, and `state` is a single immutable object so a full watch is correct

- [ ] Task 4: Pure-Dart unit tests for the selectors (AC: 1, 2, 3, 4, 5, 6, 8)
  - [ ] 4.1 Create `test/game/features/continents/next_unlock_selector_test.dart` using `package:test/test.dart` (NOT `flutter_test` — pure-Dart tests under `test/game/**` are an architectural invariant per `test/architecture/game_boundary_test.dart`)
  - [ ] 4.2 Build a multi-continent fixture `ContentRegistry` with at least 3 continents at distinct `unlockThreshold`s (e.g. africa=0, europe=1e9, asia=1e14) and 2–3 countries per continent; use the `_fixtureRegistry()` pattern from `test/game/features/economy/income_calculator_test.dart`
  - [ ] 4.3 Test `nextUnlockInContinent`: africa with all locked → returns first declared country (egypt) with `Influence(def.unlockCost)`
  - [ ] 4.4 Test `nextUnlockInContinent`: africa with egypt unlocked, nigeria locked → returns nigeria with its `def.unlockCost`
  - [ ] 4.5 Test `nextUnlockInContinent`: africa with every country unlocked → returns `null`
  - [ ] 4.6 Test `nextUnlockInContinent`: query an unknown continent id (e.g. `ContinentId('antarctica')`) not present in fixture → returns `null` (AC #3)
  - [ ] 4.7 Test `nextUnlockOverall`: only africa effectively unlocked (`totalInfluence < 1e9`) and africa still has locked countries → returns africa's next
  - [ ] 4.8 Test `nextUnlockOverall`: africa fully unlocked + `totalInfluence >= 1e9` so europe is also effectively unlocked → returns europe's next (AC #4)
  - [ ] 4.9 Test `nextUnlockOverall`: every country unlocked across all unlocked continents → returns `null`
  - [ ] 4.10 Test `nextUnlockOverall`: `totalInfluence < every continent's threshold` → returns `null` (AC #5) — note: with current content africa.unlockThreshold=0, this requires a special fixture where the lowest threshold > 0
  - [ ] 4.11 Test `nextUnlockOverall`: ties — two continents share `unlockThreshold` and both have locked countries → secondary sort picks the one with lexicographically smaller `id.value`
  - [ ] 4.12 Test cost source (AC #6): the returned `unlockCost` field equals `Influence(def.unlockCost)` for the corresponding `CountryDef` — assert via `expect(teaser.unlockCost, equals(Influence(def.unlockCost)))`
  - [ ] 4.13 Test `NextUnlockTeaser` value semantics: two equal-field instances compare equal and share `hashCode`; `toString` includes all three fields

- [ ] Task 5: Provider tests using `ProviderContainer` (AC: 1, 2, 7)
  - [ ] 5.1 Create `test/providers/feature_providers_test.dart` (NEW directory — first of its kind; this story establishes the convention) using `package:flutter_test/flutter_test.dart` + `package:flutter_riverpod/flutter_riverpod.dart`
  - [ ] 5.2 Build a fixture `ContentRegistry` (reuse the same multi-continent helper from Task 4 — extract to `test/helpers/continent_fixture_content.dart` if convenient, or inline)
  - [ ] 5.3 Strategy for state mutation in tests: override `gameWorldProvider` with a `StateProvider<GameState>`-shim approach (see "Provider test wiring" in Dev Notes) so tests can mutate state without invoking `UnlockCountry` (which doesn't exist until Story 4.1 lands)
  - [ ] 5.4 Test: `nextUnlockInContinentProvider(ContinentId('africa'))` returns the expected teaser when the override-state has egypt unlocked + nigeria locked
  - [ ] 5.5 Test: changing the underlying override-state (e.g. flip nigeria to unlocked) and re-reading the provider yields a NEW teaser (AC #7)
  - [ ] 5.6 Test: `nextUnlockOverallProvider` returns africa's next when only africa is effectively unlocked
  - [ ] 5.7 Test: while `contentRegistryProvider` is still in `AsyncValue.loading()` (override with `AsyncValue.loading()`), both providers return `null` rather than throwing
  - [ ] 5.8 Always `addTearDown(container.dispose);` to avoid leaks

- [ ] Task 6: Architecture compliance verification (AC: all)
  - [ ] 6.1 Run `flutter test test/architecture/` — the new files in `lib/game/features/continents/` MUST contain no `package:flutter/`, no `dart:ui`, no `lib/data/` imports (enforced by `test/architecture/game_boundary_test.dart`)
  - [ ] 6.2 Confirm `next_unlock_selector.dart` does NOT match the income-math grep guard in `test/architecture/no_duplicate_income_math_test.dart` — the guard fails on `def.baseInfluence *` / `country.baseInfluence *` patterns; this selector reads `def.unlockCost` (no asterisk math), so it's safe

- [ ] Task 7: Full validation (AC: all)
  - [ ] 7.1 `flutter analyze` — 0 warnings
  - [ ] 7.2 `dart format --set-exit-if-changed .`
  - [ ] 7.3 `flutter test` — all pass (existing + new)
  - [ ] 7.4 Update `Status` to `review` and append entries to the Completion Notes / File List

## Dev Notes

### Coordination with sibling Epic 4 stories (CRITICAL — read before starting)

Stories 4.1, 4.2, 4.3, and 4.5 were all created on 2026-04-24 and are simultaneously `ready-for-dev`. They were intentionally designed to be implementable in **any order** because each touches a disjoint concern. This story (4.5) is the read-only one — it adds NO commands, NO events, NO state fields, NO reducer changes.

**Decisions already locked in by sibling stories — DO NOT redebate, DO NOT diverge:**

| Decision | Source story | What this story does |
|---|---|---|
| Cost source = `def.unlockCost` (read directly from content) | Story 4.1 AC #2, Tasks 1–7 | Selector reads `def.unlockCost` directly. NEVER recompute `previousCountry × 5` at runtime. NEVER call `IncomeCalculator.*` for unlock cost. |
| `IncomeCalculator` MUST NOT be modified for unlock costs | Story 4.1 "Do NOT modify" list | This story does NOT add `IncomeCalculator.unlockCost(...)`. The selector uses `Influence(def.unlockCost)` inline. |
| Continent gate = `state.totalInfluence >= continentDef.unlockThreshold` | Story 4.1 AC #3 (UnlockCountry continent gate), Story 4.2 AC #1 (auto-unlock predicate) | Selector's "effectively unlocked" predicate = the same threshold check. After Story 4.2 lands, `state.unlockedContinents[id] == true` is logically equivalent (both derive from the same threshold) — this story does NOT need to re-read `state.unlockedContinents`. |
| Folder = `lib/game/features/continents/` | Game-architecture §System→Location Mapping; Stories 4.1, 4.2 already place `unlocks_reducer.dart` and `continents_reducer.dart` here | New files for this story go here too: `next_unlock_teaser.dart` and `next_unlock_selector.dart`. |
| No `freezed`, no `riverpod_generator`, no `@riverpod` | project-context.md | Manual `==`/`hashCode`/`toString`; raw `Provider`/`Provider.family`. |
| Tie-break for sorted continents | Story 4.2 AC #5 ("deterministic secondary order by `ContinentId.value` ASC") | This story uses the same tie-break in `nextUnlockOverall` to keep behavior consistent across reducers and selectors. |

**What might break / merge-conflict if Stories 4.1 or 4.2 land while this story is in flight:**
- **None of this story's files conflict** with 4.1 or 4.2: 4.1 modifies `game_command.dart`, `game_event.dart`, `game_world.dart`, and creates `unlocks_reducer.dart`; 4.2 modifies `game_state.dart`, `game_event.dart`, `game_world.dart`, and creates `continents_reducer.dart`. None of those overlap with `next_unlock_teaser.dart`, `next_unlock_selector.dart`, or `feature_providers.dart`.
- **Tests do not conflict.** This story creates `test/game/features/continents/next_unlock_selector_test.dart` and `test/providers/feature_providers_test.dart`. Story 4.1 creates `test/game/features/continents/unlocks_reducer_test.dart`; Story 4.2 creates `test/game/features/continents/continents_reducer_test.dart`. Different files.

### Architecture Compliance (non-negotiable)

- **`lib/game/` has ZERO Flutter imports.** `next_unlock_teaser.dart` and `next_unlock_selector.dart` MUST NOT import `package:flutter/*` or `dart:ui`. Use `package:meta/meta.dart` for `@immutable` (already used by `CountryState`, `Influence`, `GameState`).
- **Selectors are pure functions.** No `DateTime.now()`, no `Random()`, no I/O. Inputs: `(GameState, ContentRegistry, [ContinentId])`. Output: `NextUnlockTeaser?`. The architecture invariant for `lib/game/` purity is enforced by `test/architecture/game_boundary_test.dart`.
- **Providers compose; they don't compute.** `feature_providers.dart` only watches dependencies and forwards to the pure selector. No business logic in the provider body.
- **`ref.watch` for dependencies.** A plain `ref.watch(gameWorldProvider)` is correct (no `.select`) because country-`unlocked` flags AND `totalInfluence` both flow into the result, and `GameState` is a single immutable object.
- **No `riverpod_generator`, no `@riverpod`.** v1 uses raw `Provider` / `Provider.family` (see project-context: "no provider generator; no `@riverpod`").
- **No `freezed`.** Manual `==`, `hashCode`, `toString` for `NextUnlockTeaser` — same pattern as `CountryState` (`lib/game/features/countries/country_state.dart`) and `Influence` (`lib/game/values/influence.dart`).
- **Big numbers.** `def.unlockCost` is `Decimal`; wrap once in `Influence(def.unlockCost)` at the selector boundary. Never expose raw `Decimal` from the teaser API. Never use `double` for any cost.
- **No income math here.** This story does NOT touch `IncomeCalculator` or any multiplier-stack code. The grep guard in `test/architecture/no_duplicate_income_math_test.dart` flags `def.baseInfluence *` and `country.baseInfluence *` patterns — this selector reads `def.unlockCost` (no multiplication on baseInfluence) so it is safe.

### Library / Framework Requirements

- `package:meta/meta.dart` — for `@immutable` on `NextUnlockTeaser`. Already in transitive deps via `decimal`.
- `package:flutter_riverpod: ^2.6.1` — for `Provider`, `Provider.family`, `ProviderContainer` (already pinned in `pubspec.yaml`; matches `game_providers.dart`).
- `package:test/test.dart` — for pure-Dart selector tests (NOT `flutter_test`).
- `package:flutter_test/flutter_test.dart` — for provider tests under `test/providers/`.
- `package:decimal/decimal.dart` — for `Decimal.compareTo` in the continent sort. Already pinned.
- No new `pubspec.yaml` entries.

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/game/features/continents/next_unlock_teaser.dart` | `NextUnlockTeaser` value class |
| `lib/game/features/continents/next_unlock_selector.dart` | Pure-Dart `nextUnlockInContinent` and `nextUnlockOverall` top-level functions |
| `lib/providers/feature_providers.dart` | Riverpod providers (`nextUnlockInContinentProvider` family + `nextUnlockOverallProvider`) |
| `test/game/features/continents/next_unlock_selector_test.dart` | Pure-Dart selector tests |
| `test/providers/feature_providers_test.dart` | Provider behavior tests with `ProviderContainer` |

**Modify:**

(none — this story does NOT modify any existing source file)

**Do NOT modify:**

- `lib/game/features/economy/income_calculator.dart` — Story 4.1 explicitly forbids touching it for unlock costs; do not add a `unlockCost(...)` helper here.
- `lib/game/game_state.dart` — Story 4.2 owns the `unlockedContinents` field addition; do NOT pre-add it.
- `lib/game/game_event.dart`, `lib/game/game_command.dart` — owned by 4.1 / 4.2; this story emits no events.
- `lib/providers/game_providers.dart` — keep new providers in the new `feature_providers.dart` file per architecture.
- `assets/data/countries.json`, `assets/data/continents.json` — content tuning is Epic 10.

### Testing Requirements

- **Pure-Dart selector tests** use `package:test/test.dart` (NOT `flutter_test`). Existing pattern: see `test/game/features/economy/income_calculator_test.dart` and `test/game/features/leaders/leaders_reducer_test.dart` — both build a fixture `ContentRegistry` from `jsonEncode([...])` and call `ContentRegistry.fromJsonStrings(...)`. Reuse that helper style verbatim.
- **Fixture content for the multi-continent tests:** make sure to include continents at distinct thresholds so the `nextUnlockOverall` ordering is testable (e.g. africa@0, europe@1e9, asia@1e14). Use small `unlockCost`s (1, 5, 25, 100, 500) so affordability checks are intuitive.
- **Provider tests** go under `test/providers/` (NEW folder — first of its kind in this project; this story establishes the convention). Use `flutter_test` + `flutter_riverpod`'s `ProviderContainer`, override providers with `Provider.overrideWith` / `Provider.overrideWithValue`, always `addTearDown(container.dispose);`.
- **No widget tests** for this story — the AC explicitly says "UI rendering of this teaser lands in Epic 7."
- **Value-class equality** is required for `NextUnlockTeaser` so `expect(teaser, equals(otherTeaser))` works. Follow the `CountryState` pattern (manual `==` with `Object.hash` for `hashCode`).

### Provider test wiring (gotcha — read carefully)

`gameWorldProvider` (`lib/providers/game_providers.dart`) boots a real `GameWorld` from `contentRegistryProvider` + `clockProvider`. To test state-change reactivity (AC #7) without invoking `UnlockCountry` (which doesn't exist until Story 4.1 lands and may or may not have shipped), the cleanest options are:

**Option A — Override `gameWorldProvider` with a manual notifier (PREFERRED):**

```dart
class _TestGameStateNotifier extends StateNotifier<GameState> {
  _TestGameStateNotifier(super.state);
  // ignore: use_setters_to_change_properties
  void set(GameState newState) => state = newState;
}

// In test:
final notifier = _TestGameStateNotifier(initialState);
final container = ProviderContainer(overrides: [
  contentRegistryProvider.overrideWith((_) async => fixtureContent),
  gameWorldProvider.overrideWith((_) => notifier),
]);
addTearDown(container.dispose);

// Mutate state to test reactivity:
notifier.set(newState);
// Then re-read provider:
expect(container.read(nextUnlockInContinentProvider(continentId)), ...);
```

This isolates this story's selector behavior from upstream reducer correctness. It also avoids needing the real `Clock`, `Ticker`, etc.

**Option B — Boot real `GameWorld` and dispatch a `PurchaseUpgrade`** to trigger a state change. Works only if Story 4.1 / 4.2 are merged first AND you want an end-to-end signal. Not preferred for the unit-level provider tests in this story; if you want a happy-path E2E it can go in `integration_test/` later.

### Reference selector skeleton (do NOT reinvent)

```dart
// lib/game/features/continents/next_unlock_selector.dart
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/continents/next_unlock_teaser.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/influence.dart';

NextUnlockTeaser? nextUnlockInContinent(
  GameState state,
  ContentRegistry content,
  ContinentId continentId,
) {
  for (final def in content.countries.values) {
    if (def.continent != continentId) continue;
    final cs = state.countries[def.id];
    if (cs == null || !cs.unlocked) {
      return NextUnlockTeaser(
        countryId: def.id,
        unlockCost: Influence(def.unlockCost),
        continent: continentId,
      );
    }
  }
  return null;
}

NextUnlockTeaser? nextUnlockOverall(GameState state, ContentRegistry content) {
  final unlockedContinents = <ContinentDef>[];
  for (final c in content.continents.values) {
    if (c.unlockThreshold <= state.totalInfluence.value) {
      unlockedContinents.add(c);
    }
  }
  unlockedContinents.sort((a, b) {
    final byThreshold = a.unlockThreshold.compareTo(b.unlockThreshold);
    if (byThreshold != 0) return byThreshold;
    return a.id.value.compareTo(b.id.value);
  });
  for (final c in unlockedContinents) {
    final t = nextUnlockInContinent(state, content, c.id);
    if (t != null) return t;
  }
  return null;
}
```

(Pseudocode — adjust imports and naming to project style; do NOT add a class wrapper, top-level functions match the project's other selector-style helpers.)

### Project Structure Notes

- **Folder choice (`lib/game/features/continents/`):** matches game-architecture.md §System→Location Mapping ("Continent gating" → `lib/game/features/continents/`). Stories 4.1 and 4.2 also place files here. Putting the next-unlock selector here keeps Epic 4's logic cohesive.
- **Provider file location (`lib/providers/feature_providers.dart`, NEW):** matches the architecture's documented provider layout. This is the first concrete file of its kind; future stories adding feature-derived providers (e.g. mission progress, achievement teasers) should add to the same file or split if it grows past ~200 lines.
- **No conflict** with the existing `lib/game/features/countries/` folder — that's for per-country tick / collect logic, not for cross-country selectors.

### Project Context Rules

Extracted from `_bmad-output/project-context.md` — applies to this story:

- **`lib/game/` has ZERO Flutter imports.** No `package:flutter/*`, no `dart:ui`. Pure Dart only. (Enforced by `test/architecture/game_boundary_test.dart`.)
- **UI never mutates `GameState` directly.** UI dispatches commands via `ref.read(gameWorldProvider.notifier).apply(cmd)`. This story adds no commands; UI consumers will only `ref.watch(...)` the new providers.
- **Reducers / selectors are pure functions.** NO clock reads, NO RNG reads, NO I/O. The selectors here read only `(GameState, ContentRegistry, [ContinentId])` and return a value — strictest version of the rule.
- **Multiplier stack is single source of truth in `IncomeCalculator.compute`.** This story does NOT touch the multiplier stack and does NOT add cost helpers to `IncomeCalculator` (per Story 4.1's "Do NOT modify" rule).
- **Big numbers:** All cost values flow through `Influence` value objects. The selector wraps `def.unlockCost` (a `Decimal`) in `Influence(...)` once and never exposes raw `Decimal` outward.
- **Configuration discipline:** `def.unlockCost` is content data (`assets/data/countries.json`); the "× 5" scaling is encoded in JSON, not in code. Do NOT add a new constant to `BalanceConfig`.
- **No `freezed`, no `json_serializable`, no `riverpod_generator`.** Manual value-class boilerplate; raw `Provider` / `Provider.family`.
- **Riverpod tests** override providers via `ProviderContainer(overrides: [...])` — Riverpod is the DI mechanism.
- **Sealed `switch` exhaustiveness:** This story adds NO new `GameCommand` or `GameEvent` variants. If you find yourself adding a command/event, you've expanded scope — stop and re-read the AC.
- **Logging:** `package:logging` only. The selectors are pure and SHOULD NOT log anything (hot-path discipline).
- **MCP `dart` tools** are available — prefer them over shell `dart` / `flutter` invocations during analysis and test runs.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.5: Next-Unlock Teaser Data on State] — original ACs and story statement
- [Source: _bmad-output/implementation-artifacts/4-1-unlock-next-country-in-current-continent.md#Acceptance Criteria] — AC #2 cost source rule (read `def.unlockCost` directly; do NOT recompute) and AC #3 continent gate (`state.totalInfluence >= continentDef.unlockThreshold`)
- [Source: _bmad-output/implementation-artifacts/4-1-unlock-next-country-in-current-continent.md#File Structure Requirements] — "Do NOT modify `lib/game/features/economy/income_calculator.dart`" — applies to this story too
- [Source: _bmad-output/implementation-artifacts/4-2-unlock-continent-at-influence-threshold.md#Acceptance Criteria] — AC #1 auto-unlock predicate (same threshold check) and AC #5 tie-break (`id.value` ASC)
- [Source: _bmad-output/project-context.md#Engine-Specific Rules (Flutter / Dart)] — pure `lib/game/`, sealed hierarchies, multiplier-stack discipline
- [Source: _bmad-output/project-context.md#Code Organization Rules] — provider layout (`app/game/data/service/feature_providers.dart`)
- [Source: _bmad-output/project-context.md#Testing Rules] — pure-Dart vs widget test conventions, `ProviderScope(overrides: [...])`
- [Source: lib/game/features/countries/country_state.dart] — `@immutable` value-class style for `NextUnlockTeaser`
- [Source: lib/game/values/influence.dart] — `Influence` wrapper construction (`Influence(def.unlockCost)`)
- [Source: lib/providers/game_providers.dart] — `flutter_riverpod` import + `Provider` style for the new `feature_providers.dart`
- [Source: lib/providers/app_providers.dart] — `contentRegistryProvider = FutureProvider<ContentRegistry>` (read via `.valueOrNull`)
- [Source: test/game/features/economy/income_calculator_test.dart] — fixture `ContentRegistry` construction pattern (lines 17–67)
- [Source: test/game/features/leaders/leaders_reducer_test.dart] — secondary fixture pattern (continent-locked test setup)
- [Source: test/architecture/game_boundary_test.dart] — boundary invariants enforced by tests (no Flutter imports under `lib/game/`)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
