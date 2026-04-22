# Story 2.7: Initial Seed — One or More Countries Unlocked by Default

Status: done

## Story

As a first-time player,
I want at least one country (Egypt in Africa) already unlocked when I launch the game,
So that I can immediately tap and start the core loop without first needing unlocks (which don't exist until Epic 4).

## Acceptance Criteria

1. **Given** a fresh install (empty save) **When** the `GameWorld` initializes from `ContentRegistry` **Then** the country `egypt` is flagged `unlocked = true` with `ipLevel = 1` and `leaderTier = LeaderTier.none`.

2. **Given** the initial state **When** the map renders **Then** Egypt is painted in the "generating" / "ready" state colors (per its banked influence) and all other countries are painted in the "locked" color.

3. **Given** the seed state is re-applied on subsequent launches after Epic 6 persistence lands **When** the player has progressed past the seed **Then** their actual progression state loads, not the seed.

## Tasks / Subtasks

- [x] Task 1: Create `GameState.initialSeed` factory (AC: 1, 3)
  - [x] 1.1 Add a named factory or static method `GameState.initialSeed(ContentRegistry content)` in `lib/game/game_state.dart`
  - [x] 1.2 Build `Map<CountryId, CountryState>` from `content.countries` — all countries default to `unlocked: false, ipLevel: 0, leaderTier: LeaderTier.none, bankedInfluence: Decimal.zero, lastCollectedAt: null`
  - [x] 1.3 Override Egypt (`CountryId('egypt')`) to `unlocked: true, ipLevel: 1` — use `assert(content.countries.containsKey(CountryId('egypt')))` to catch missing content
  - [x] 1.4 Set `totalInfluence: Influence.zero`
  - [x] 1.5 Return the fully constructed `GameState`

- [x] Task 2: Wire `GameWorld` constructor to use `initialSeed` (AC: 1)
  - [x] 2.1 In `GameWorld` constructor, replace the current `_state = const GameState()` (or equivalent inline construction) with `_state = GameState.initialSeed(content)`
  - [x] 2.2 Verify that `GameWorld` still accepts `ContentRegistry` in its constructor (it does — from Story 1.9/2.5)
  - [x] 2.3 Ensure the existing `applyCommand` and `tick` methods work correctly with the seeded state

- [x] Task 3: Support overriding seed state for persistence (AC: 3)
  - [x] 3.1 Add an optional `GameState? initialState` parameter to `GameWorld` constructor — if provided, use it instead of `initialSeed`. This enables Epic 6 `loadOrCreateInitial` to pass a loaded save
  - [x] 3.2 Default behavior: `_state = initialState ?? GameState.initialSeed(content)`
  - [x] 3.3 Update `gameWorldProvider` in `lib/providers/game_providers.dart` if it currently constructs `GameWorld` — pass no `initialState` for now (fresh installs use seed)

- [x] Task 4: Unit tests for `GameState.initialSeed` (AC: 1, 3)
  - [x] 4.1 Create `test/game/game_state_seed_test.dart` using `package:test/test.dart`
  - [x] 4.2 Test: `initialSeed` produces exactly `content.countries.length` entries in `countries` map
  - [x] 4.3 Test: Egypt is `unlocked: true, ipLevel: 1, leaderTier: LeaderTier.none, bankedInfluence: Decimal.zero`
  - [x] 4.4 Test: All non-Egypt countries are `unlocked: false, ipLevel: 0, leaderTier: LeaderTier.none, bankedInfluence: Decimal.zero`
  - [x] 4.5 Test: `totalInfluence == Influence.zero`
  - [x] 4.6 Test: passing `initialState` to `GameWorld` overrides the seed — verify `gameWorld.state` matches the provided state, not the seed

- [x] Task 5: Integration tests — seed + tick + collect flow (AC: 1, 2)
  - [x] 5.1 In `test/game/game_world_test.dart`, add test: fresh `GameWorld` from `ContentRegistry` → `state.countries[CountryId('egypt')].unlocked == true`
  - [x] 5.2 Test: tick for 1 second → Egypt's `bankedInfluence > Influence.zero` (Egypt is unlocked, generates influence)
  - [x] 5.3 Test: tick for 1 second → Nigeria's `bankedInfluence == Decimal.zero` (Nigeria is locked, no generation)
  - [x] 5.4 Test: verify `countries` map has all 3 countries from test content (egypt, nigeria, south_africa)

- [x] Task 6: Full validation (AC: all)
  - [x] 6.1 `flutter analyze` — 0 warnings
  - [x] 6.2 `dart format --set-exit-if-changed .`
  - [x] 6.3 `flutter test` — all pass (existing + new)

## Dev Notes

### Architecture Compliance

- **`GameState.initialSeed` is a pure function** — receives `ContentRegistry`, returns `GameState`. No I/O, no `DateTime.now()`, no RNG.
- **`lib/game/` has ZERO Flutter imports** — seed logic is pure Dart.
- **Immutable state only** — `initialSeed` constructs a new `GameState` with `Map.unmodifiable` (or const-safe map). Never mutate.
- **Egypt is the ONLY seed country.** The GDD specifies Egypt (Africa) as the starter country with `unlockCost: "0"` in `countries.json`. No other countries are unlocked at start.
- **`ipLevel: 1`** (not 0) — per AC, the seed country starts at IP level 1 so it immediately generates influence via the tick reducer. A country with `ipLevel: 0` would still have `baseInfluence` from `CountryDef` but level 1 is the architectural expectation per the epics.

### Implementation Approach

**Seed construction (simple — one-time at boot):**
```
countries = { for each CountryDef in content.countries:
  CountryId → CountryState(
    id: def.id,
    unlocked: def.id == CountryId('egypt'),
    ipLevel: def.id == CountryId('egypt') ? 1 : 0,
    leaderTier: LeaderTier.none,
    bankedInfluence: Decimal.zero,
    lastCollectedAt: null,
  )
}
```

**Where to put seed logic.** `GameState.initialSeed(ContentRegistry content)` is a static factory on `GameState` itself — this keeps the seed definition close to the state shape and makes it easy to test. The alternative (a separate `SeedService`) is over-engineering for a single constant.

**Persistence forward-compatibility (AC: 3).** The `GameWorld(initialState: ...)` optional parameter ensures Epic 6's `loadOrCreateInitial` pattern works: if a save exists, the loaded `GameState` is passed in and the seed is skipped entirely. The architecture already shows this pattern:
```dart
final state = await repo.loadOrCreateInitial(content);
```
Where `loadOrCreateInitial` calls `GameState.initialSeed(content)` internally when no save exists. For now, `GameWorld` always seeds — Epic 6 wires the persistence layer.

**Map rendering (AC: 2).** No changes to `WorldMapPainter` are needed — it already reads `CountryState.unlocked` / `CountryState.bankedInfluence` to determine fill colors (Stories 2.2). Egypt will naturally render as "generating"/"ready" and all locked countries render in the "locked" color. This story only ensures the data is correct; the painter is already set up to handle it.

### Dependencies — What Must Exist Before This Story

| Dependency | Source Story | What It Provides |
|---|---|---|
| `CountryState` with all fields | Story 2.5 | `CountryState(id, unlocked, ipLevel, leaderTier, bankedInfluence, lastCollectedAt)` |
| `GameState.countries` map | Story 2.5 | `Map<CountryId, CountryState>` and `totalInfluence` on `GameState` |
| `LeaderTier` enum | Story 2.5 | `LeaderTier { none, tier1, tier2, tier3 }` at `lib/game/features/leaders/leader_tier.dart` |
| `ContentRegistry.countries` | Story 1.7 | `Map<CountryId, CountryDef>` with Egypt's `baseInfluence`, `generationSeconds` |
| `CountryId` value type | Story 1.5 | `CountryId('egypt')` with equality/hashCode |
| `Influence` value type | Story 1.5 | `Influence.zero`, `Influence` wrapping `Decimal` |
| `GameWorld` skeleton | Story 1.9 | Constructor accepts `ContentRegistry` and `Clock` |
| `GameWorld.tick()` wired | Story 2.5 | Tick reducer uses `countries` map to accumulate influence on unlocked countries |

**Critical dependency note:** Story 2.5 creates `GameState` expansion and `GameWorld` initial state construction. Currently (per Story 2.5 tasks), `GameWorld` builds initial state with ALL countries `unlocked: false`. This story changes that to seed Egypt as unlocked. If 2.5 lands first, modify the existing initialization. If this story lands first, include the full `GameState` expansion (but 2.5 should land first per sprint order).

### Project Structure Notes

**Files to CREATE:**
| File | Purpose |
|---|---|
| `test/game/game_state_seed_test.dart` | Unit tests for `GameState.initialSeed` |

**Files to MODIFY:**
| File | Change |
|---|---|
| `lib/game/game_state.dart` | Add `initialSeed(ContentRegistry)` factory method |
| `lib/game/game_world.dart` | Use `initialSeed` in constructor, add optional `initialState` parameter |
| `lib/providers/game_providers.dart` | Update `GameWorld` construction if needed (no `initialState` yet) |
| `test/game/game_world_test.dart` | Add seed integration tests (Egypt unlocked, others locked, tick generates for Egypt only) |

**Files to READ (reference only — do not modify):**
| File | Why |
|---|---|
| `lib/game/content/content_registry.dart` | Verify `.countries` map shape |
| `lib/game/content/country_def.dart` | Verify `CountryDef` fields (`id`, `baseInfluence`, etc.) |
| `lib/game/features/countries/country_state.dart` | Verify `CountryState` constructor signature |
| `lib/game/features/leaders/leader_tier.dart` | Verify `LeaderTier.none` enum value |
| `lib/game/values/country_id.dart` | Verify `CountryId` equality semantics |
| `lib/game/values/influence.dart` | Verify `Influence.zero` |
| `assets/data/countries.json` | Verify Egypt's definition (`unlockCost: "0"`, `baseInfluence: "1"`, `generationSeconds: 1`) |

### Testing Standards

- **Pure Dart tests** in `test/game/` — use `package:test/test.dart`, NOT `flutter_test`
- **Use test `ContentRegistry`** — construct via `ContentRegistry.fromJsonStrings()` with inline JSON matching `assets/data/countries.json` structure (pattern established in existing `game_world_test.dart`)
- **Use `FakeClock`** for any time-dependent integration tests
- **No mocks for game layer** — `initialSeed` is a pure factory, test inputs → outputs directly
- **Verify map completeness** — test that every `CountryDef` in `ContentRegistry` has a corresponding `CountryState` in the seed (no missing countries)

### Anti-Patterns to Avoid

- **DO NOT** hardcode Egypt's `CountryId` as a magic string in multiple places — define `const seedCountryId = CountryId('egypt')` in one location (either in `GameState.initialSeed` as a local, or in `lib/game/config/constants.dart` if it's referenced elsewhere)
- **DO NOT** set `ipLevel: 0` for Egypt — the seed requires `ipLevel: 1` per AC. Level 0 means "no generation tier" in the multiplier stack
- **DO NOT** unlock multiple countries — only Egypt is the starter. The GDD and epics are explicit: one country
- **DO NOT** add any persistence/save logic — that's Epic 6. This story only creates the in-memory seed state
- **DO NOT** modify `WorldMapPainter` — it already handles country state colors. Just ensure the data is correct
- **DO NOT** modify `countries.json` — the content data is already correct (`egypt` has `unlockCost: "0"`)
- **DO NOT** use `DateTime.now()` in the seed — no time-dependent logic; `lastCollectedAt: null` for all countries
- **DO NOT** import Flutter in `lib/game/` — seed logic is pure Dart
- **DO NOT** create a separate `SeedService` or `InitializationService` — `GameState.initialSeed` is sufficient

### Previous Story Intelligence

**From Story 2.5 (Tick Drives Influence Generation — ready-for-dev):**
- Story 2.5 Task 2.4 explicitly states: "all countries start `unlocked: false, ipLevel: 0, leaderTier: LeaderTier.none, bankedInfluence: Decimal.zero` (Story 2.7 handles seeding Egypt as unlocked)" — this story is the designated place to seed Egypt
- `GameWorld` constructor builds initial `GameState` from `ContentRegistry` — this story modifies that initialization
- Countries tick reducer only processes `unlocked == true` countries — once Egypt is seeded as unlocked, it will immediately start generating influence on tick
- `GameState` has `countries: Map<CountryId, CountryState>` and `totalInfluence: Influence` fields

**From Story 2.6 (Tap-to-Collect — ready-for-dev):**
- Story 2.6 cross-story context says: "Story 2.7 (Initial Seed) will set Egypt as unlocked — test states should include at least one unlocked country"
- `TapCountry` command collects `bankedInfluence` from unlocked countries — without this seed, there's nothing to collect
- The full core loop depends on this seed: Egypt unlocked → tick generates influence → player taps to collect

**From Story 2.4 (Hit Testing — ready-for-dev):**
- Hit testing dispatches `TapCountry` via `ref.read(gameWorldProvider.notifier).apply(cmd)` — the seeded Egypt is the first tappable country

### Cross-Story Context

- **Story 2.5** creates `CountryState`, `GameState` expansion, and `GameWorld` initial construction — this story modifies the initial construction to seed Egypt
- **Story 2.6** depends on at least one unlocked country existing for the tap-to-collect loop
- **Story 3.1** (`IncomeCalculator`) will formalize the multiplier stack — `ipLevel: 1` for Egypt means `(1 + 1 * IP_MULT_PER_LEVEL)` will apply when multipliers are wired
- **Epic 4** (Expand) implements the unlock system — `unlockCost: "0"` for Egypt means it would also auto-unlock through that system, but the seed ensures it's available before Epic 4 lands
- **Epic 6** (Persistence) will call `loadOrCreateInitial(content)` which uses `initialSeed` for fresh installs. The `initialState` parameter on `GameWorld` is the forward-compatibility hook

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 2, Story 2.7]
- [Source: _bmad-output/game-architecture.md#Standard Implementation Patterns §A — CountryState]
- [Source: _bmad-output/game-architecture.md#Async Initialization Gate — loadOrCreateInitial pattern]
- [Source: _bmad-output/project-context.md#Engine-Specific Rules — No Flutter in lib/game/]
- [Source: _bmad-output/project-context.md#Code Organization Rules — GameState, GameWorld]
- [Source: assets/data/countries.json — Egypt definition: unlockCost "0", baseInfluence "1", generationSeconds 1]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

None — implementation was straightforward.

### Completion Notes List

- Added `GameState.initialSeed(ContentRegistry)` static factory to `lib/game/game_state.dart`; seeds Egypt as `unlocked: true, ipLevel: 1`, all others `unlocked: false, ipLevel: 0`; uses `Map.unmodifiable` for immutability; assert guards against missing egypt content.
- Replaced `GameWorld._buildInitialState` private method with `GameState.initialSeed(content)` call in constructor; `initialState?` override parameter was already present from Story 2.5.
- Fixed two UI test stubs (`game_loop_test.dart`, `map_screen_tap_test.dart`) that constructed `GameWorld` with empty `ContentRegistry` — added `initialState: GameState()` to bypass seed assert.
- Created `test/game/game_state_seed_test.dart` with 7 unit tests covering AC 1, 3.
- Extended `test/game/game_world_test.dart` with 4 seed integration tests (AC 1, 2) and updated existing tests broken by the seed change.
- All 401 tests pass; `flutter analyze` clean; `dart format` clean.

**Code Review (2026-04-22):** Applied fixes for MEDIUM/LOW findings.
- MEDIUM: `gameWorldProvider` previously fell back to an empty `ContentRegistry` during `contentRegistryProvider` loading — post-seed that would fire the egypt assert. Updated [lib/providers/game_providers.dart](lib/providers/game_providers.dart) to pass `initialState: GameState()` when content is still null, so the seed is skipped until real content arrives.
- LOW: Set `lastCollectedAt: null` explicitly in the seed for clarity, and assert null in unit tests for both egypt and non-egypt entries.
- LOW: De-duplicated the triple `GameState.initialSeed(content)` call in test 4.6.
- All 401 tests still pass; analyze/format clean.

### File List

- `lib/game/game_state.dart` (modified — added `initialSeed` factory; explicit `lastCollectedAt: null`)
- `lib/game/game_world.dart` (modified — replaced `_buildInitialState` with `GameState.initialSeed`, removed unused imports)
- `lib/providers/game_providers.dart` (modified — `gameWorldProvider` now passes `initialState: GameState()` when content is still loading so the seed assert doesn't fire)
- `test/game/game_state_seed_test.dart` (created — unit tests for `initialSeed`; `lastCollectedAt` null assertions)
- `test/game/game_world_test.dart` (modified — seed integration tests, fixed broken tests)
- `test/ui/features/map/game_loop_test.dart` (modified — fixed empty-content GameWorld stub)
- `test/ui/features/map/map_screen_tap_test.dart` (modified — fixed empty-content GameWorld stub)

## Change Log

- 2026-04-22: Story 2.7 implemented — `GameState.initialSeed` factory seeds Egypt unlocked/ipLevel=1; `GameWorld` wired to use seed; 11 new tests added (401 total); analyze+format clean.
- 2026-04-22: Code review — fixed `gameWorldProvider` empty-content assert landmine; tightened seed (`lastCollectedAt: null` explicit) and tests. Status → done.
