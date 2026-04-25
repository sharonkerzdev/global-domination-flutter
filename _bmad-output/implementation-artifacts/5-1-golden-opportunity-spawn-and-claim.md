# Story 5.1: Golden Opportunity — Spawn and Claim

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want Golden Opportunities to randomly spawn on my owned countries and be claimable by tapping for a 10–100× multiplier burst,
so that active play feels explosive and rewarding.

## Acceptance Criteria

1. **Given** the per-tick `evaluateGoldens` scheduler runs (called from `GameWorld.tick`)
   **When** the supplied `Rng` draw against `BalanceConfig.goldenSpawnProbabilityPerSecond × dtSeconds` succeeds, AND `state.activeGoldens.length < BalanceConfig.goldenMaxConcurrent`, AND at least one country in `state.countries` is `unlocked == true`
   **Then** exactly one new `ActiveGolden` is appended to `state.activeGoldens` with: a deterministically-derived `id`, a uniformly random `countryId` chosen from the unlocked countries (sorted by `CountryId.value`), a uniformly random integer `multiplier ∈ [BalanceConfig.goldenMinMultiplier, BalanceConfig.goldenMaxMultiplier]`, and `expiresAt = now + Duration(seconds: BalanceConfig.goldenSpawnExpirySeconds)`; AND a single `GoldenSpawned(at: now, goldenId, countryId, multiplier, expiresAt)` event fires.

2. **Given** an entry in `state.activeGoldens` whose `expiresAt <= now`
   **When** `evaluateGoldens` runs on tick
   **Then** the entry is removed from `state.activeGoldens` and a `GoldenExpired(at: now, goldenId, claimed: false)` event fires — the golden is not claimable after expiry.

3. **Given** a fixed `Rng` seed and a fixed sequence of `(now, dt)` ticks
   **When** `evaluateGoldens` is run twice over the same input
   **Then** the produced `(state, events)` tuples are byte-identical — spawns, multipliers, and chosen countries are exactly reproducible from `(seed, clock, state)`. (No `DateTime.now()` or `Random()` reads inside `evaluateGoldens`; `now` and `rng` are parameters.)

4. **Given** an active `ActiveGolden` on country X (i.e. `state.activeGoldens` contains an entry with `countryId == X` and `expiresAt > now`)
   **When** the player dispatches `ClaimGolden(goldenId)` via `GameWorld.applyCommand`
   **Then** the entry is removed from `state.activeGoldens`, `state.activeGoldenEffect` is set to `ActiveGoldenEffect(multiplier: claimed.multiplier, expiresAt: now + Duration(seconds: BalanceConfig.goldenEffectDurationSeconds))`, `state.goldenOpportunityMultiplier` is set to `Decimal.fromInt(claimed.multiplier)`, AND a `GoldenClaimed(at: now, goldenId, countryId, multiplier, durationSeconds)` event fires.

5. **Given** an active `state.activeGoldenEffect`
   **When** `IncomeCalculator.compute` runs
   **Then** the `goldenOpportunityMultiplier` slot in the multiplier stack uses `state.goldenOpportunityMultiplier` (which equals the claimed effect's multiplier). **`IncomeCalculator` is NOT modified by this story** — the existing read of `state.goldenOpportunityMultiplier` (already in the multiplier stack since pre-Epic-5) is the single source of truth, and the scheduler keeps that scalar in sync with `state.activeGoldenEffect`.

6. **Given** `state.activeGoldenEffect != null` and `state.activeGoldenEffect!.expiresAt <= now`
   **When** `evaluateGoldens` runs on tick
   **Then** `state.activeGoldenEffect` is cleared to `null`, `state.goldenOpportunityMultiplier` is reset to `Decimal.one`, and a single `GoldenExpired(at: now, goldenId: <effect-id>, claimed: true)` event fires.

7. **Given** a `ClaimGolden` command is dispatched and:
   - case (a) `cmd.goldenId` is not present in `state.activeGoldens` → `Result.failure(GameError.userInvalidTarget(detail: 'golden_not_found'))` and no state mutation;
   - case (b) the targeted golden's `expiresAt <= now` → `Result.failure(GameError.userLocked(reason: 'golden_expired'))` and no state mutation; the entry is left as-is so the next tick's `evaluateGoldens` removes it via the AC #2 path (single-source-of-truth for expiry);
   - case (c) `state.countries[targetGolden.countryId]?.unlocked != true` (defensive — the country has been re-locked between spawn and claim, which is currently impossible but guarded) → `Result.failure(GameError.userLocked(reason: 'country_locked'))` and no state mutation.

8. **Given** the map UI receives a tap that hit-tests to country X in `MapScreen._onTapUp`
   **When** `state.activeGoldens` contains a non-expired entry with `countryId == X`
   **Then** the UI dispatches `ClaimGolden(goldenId)` (selecting the entry whose `expiresAt` is **earliest** among matches, for determinism) **instead of** `TapCountry(countryId: X)`. If no active golden matches, the existing `TapCountry` dispatch remains unchanged. (Visual overlay rendering of the golden is **out of scope**; deferred to Epic 8 — Game Feel / Juice. AC #8 covers tap-routing logic only.)

9. **Given** Story 5-1 introduces seedable RNG to the simulation
   **When** any sim code reads randomness
   **Then** it does so through the new `Rng` interface in `lib/game/support/rng.dart` (injected via `GameWorld` constructor and forwarded to `evaluateGoldens`). Pure-Dart tests pin a `SeededRng(42)` (or similar). `Random()` is forbidden inside `lib/game/`; production code uses `SystemRng` provided by `rngProvider`.

10. **Given** a tick's spawn roll succeeds but every country is `unlocked == false` (theoretical edge — `GameState.initialSeed` always seeds at least Egypt, but defensive)
    **When** the scheduler tries to pick a country
    **Then** no `ActiveGolden` is created, no `GoldenSpawned` event fires, and the RNG draws are still consumed deterministically (so tests with fixed seeds remain stable across countries-empty edge paths).

## Tasks / Subtasks

- [ ] Task 1: Introduce seedable `Rng` infrastructure under `lib/game/support/` (AC: #3, #9)
  - [ ] 1.1 Create `lib/game/support/rng.dart` defining `abstract class Rng { int nextInt(int max); double nextDouble(); }`. Pure Dart — NO Flutter imports, NO `dart:ui`.
  - [ ] 1.2 In the same file (one-public-class-per-file rule does not apply because these are interface + impls of one concept), define `final class SeededRng implements Rng` wrapping `dart:math` `Random(seed)` and `final class SystemRng implements Rng` wrapping `Random()` (the only place `Random()` is allowed in `lib/game/`). Add manual `==`/`hashCode` only on `SeededRng` keyed by `seed` (used for golden-path test fixtures). `SystemRng` needs no equality.
  - [ ] 1.3 Pure-Dart tests in `test/game/support/rng_test.dart` (NEW folder) using `package:test/test.dart`: SeededRng with same seed produces identical sequence; different seeds diverge; `nextInt(max)` always returns `[0, max)`; `nextDouble()` always returns `[0.0, 1.0)`.

- [ ] Task 2: Extend `BalanceConfig` with golden-tuning constants (AC: #1, #2, #4, #6)
  - [ ] 2.1 Add to `lib/game/config/balance.dart` (placeholders — Epic 10 retunes):
    ```dart
    /// Probability of attempting a Golden spawn per real wall-clock second of tick time.
    /// Per-tick draw: rng.nextDouble() < goldenSpawnProbabilityPerSecond × dtSeconds.
    /// Placeholder — Epic 10 retunes (target ~1 spawn per 30s of active play).
    static final Decimal goldenSpawnProbabilityPerSecond = Decimal.parse('0.0333');

    /// Inclusive lower bound for the random multiplier on a spawned Golden.
    static const int goldenMinMultiplier = 10;

    /// Inclusive upper bound for the random multiplier on a spawned Golden.
    static const int goldenMaxMultiplier = 100;

    /// Hard cap on simultaneous active Goldens on the map. Prevents pathological
    /// spawn streaks from cluttering the map; Epic 10 may retune.
    static const int goldenMaxConcurrent = 3;

    /// Seconds an unclaimed Golden remains on the map before despawning.
    static const int goldenSpawnExpirySeconds = 10;

    /// Seconds the post-claim multiplier burst remains active.
    static const int goldenEffectDurationSeconds = 30;
    ```
  - [ ] 2.2 Update `test/game/config/balance_test.dart` if it exists (check via `glob`); otherwise NO test file is added — `BalanceConfig` is exercised through reducer/scheduler tests. Add invariant assertions in the scheduler (e.g. `assert(goldenMinMultiplier <= goldenMaxMultiplier)`) only if you elect to defend the constants.

- [ ] Task 3: Define `ActiveGolden` and `ActiveGoldenEffect` value classes (AC: #1, #4)
  - [ ] 3.1 Create `lib/game/features/goldens/active_golden.dart`:
    ```dart
    @immutable
    class ActiveGolden {
      final String id;
      final CountryId countryId;
      final int multiplier;
      final DateTime expiresAt;
      const ActiveGolden({required this.id, required this.countryId,
                          required this.multiplier, required this.expiresAt});
      // manual ==, hashCode, toString covering all four fields
    }
    ```
  - [ ] 3.2 Create `lib/game/features/goldens/active_golden_effect.dart`:
    ```dart
    @immutable
    class ActiveGoldenEffect {
      final String goldenId;            // links to the ActiveGolden that produced it
      final int multiplier;
      final DateTime expiresAt;
      const ActiveGoldenEffect({required this.goldenId,
                                required this.multiplier, required this.expiresAt});
      // manual ==, hashCode, toString
    }
    ```
  - [ ] 3.3 Both files MUST be pure Dart — `package:meta/meta.dart` only, no Flutter imports.
  - [ ] 3.4 Pure-Dart tests `test/game/features/goldens/active_golden_test.dart` and `active_golden_effect_test.dart`: equality, `hashCode` parity for equal instances, `toString` includes all fields. Pattern mirrors `test/game/features/continents/next_unlock_teaser_test.dart` (if present) or the value-class tests embedded in `next_unlock_selector_test.dart`.

- [ ] Task 4: Extend `GameState` with golden fields (AC: #1, #4, #6)
  - [ ] 4.1 Modify `lib/game/game_state.dart` to add two new fields after `boostMultiplier`:
    - `final Map<String, ActiveGolden> activeGoldens;` — keyed by `ActiveGolden.id`. Defaults to `const <String, ActiveGolden>{}`. Wrap with `Map.unmodifiable(...)` in the constructor body, same pattern as `unlockedContinents`.
    - `final ActiveGoldenEffect? activeGoldenEffect;` — nullable.
  - [ ] 4.2 Add a `MapEquality<String, ActiveGolden>` static (`_activeGoldensEq`) to `GameState` for equality (mirror `_unlockedContinentsEq`).
  - [ ] 4.3 Extend `copyWith` to accept both new fields. For `activeGoldenEffect`, use the same explicit-null sentinel pattern as `CountryState.lastCollectedAt` (lines 9, 33–43 of `country_state.dart`) so the reducer can clear the effect to `null`. Search the file for `_lastCollectedAtUnchanged` and replicate exactly.
  - [ ] 4.4 Extend `==`, `hashCode`, `toString` to include both new fields. Note: `goldenOpportunityMultiplier` is ALREADY a field on `GameState` (do not re-add); the scheduler keeps it in sync with `activeGoldenEffect`.
  - [ ] 4.5 No changes needed to `initialSeed(...)` — defaults of empty map / null effect / `Decimal.one` multiplier are already correct.

- [ ] Task 5: Add `ClaimGolden` command (AC: #4, #7)
  - [ ] 5.1 Add to `lib/game/game_command.dart` after `UnlockCountry`:
    ```dart
    final class ClaimGolden extends GameCommand {
      const ClaimGolden({required this.goldenId});
      final String goldenId;
      // manual ==, hashCode keyed by goldenId, toString
    }
    ```
  - [ ] 5.2 Update `test/game/game_command_test.dart` with equality + `toString` coverage for `ClaimGolden`.

- [ ] Task 6: Add `GoldenSpawned`, `GoldenClaimed`, `GoldenExpired` events (AC: #1, #2, #4, #6)
  - [ ] 6.1 Add three sealed variants to `lib/game/game_event.dart` after `ContinentCompleted`:
    ```dart
    final class GoldenSpawned extends GameEvent {
      final String goldenId;
      final CountryId countryId;
      final int multiplier;
      final DateTime expiresAt;
      const GoldenSpawned(super.at, {required this.goldenId, required this.countryId,
                                     required this.multiplier, required this.expiresAt});
      // manual ==, hashCode, toString — include all fields
    }

    final class GoldenClaimed extends GameEvent {
      final String goldenId;
      final CountryId countryId;
      final int multiplier;
      final int durationSeconds;
      const GoldenClaimed(super.at, {required this.goldenId, required this.countryId,
                                     required this.multiplier, required this.durationSeconds});
    }

    final class GoldenExpired extends GameEvent {
      final String goldenId;
      /// `true` if the expiry was of an effect (post-claim window),
      /// `false` if the expiry was of an unclaimed map-spawn.
      final bool claimed;
      const GoldenExpired(super.at, {required this.goldenId, required this.claimed});
    }
    ```
  - [ ] 6.2 Update `test/game/game_event_test.dart` with equality + `toString` coverage for all three new events.

- [ ] Task 7: Implement the per-tick scheduler `evaluateGoldens` (AC: #1, #2, #3, #6, #10)
  - [ ] 7.1 Create `lib/game/features/goldens/goldens_scheduler.dart` exposing one top-level pure function:
    ```dart
    (GameState, List<GameEvent>) evaluateGoldens(
      GameState state,
      ContentRegistry content,
      Duration dt, {
      required DateTime now,
      required Rng rng,
    });
    ```
  - [ ] 7.2 Behavior, in this exact order (tests pin the order):
    1. **Effect expiry first** (AC #6): if `state.activeGoldenEffect != null && state.activeGoldenEffect!.expiresAt.compareTo(now) <= 0`, prepare a `GoldenExpired(now, goldenId: effect.goldenId, claimed: true)` event, set `nextEffect = null`, and reset `nextMultiplier = Decimal.one`. Otherwise carry both forward unchanged.
    2. **Map-spawn expiry** (AC #2): scan `state.activeGoldens.values`; for each entry where `expiresAt.compareTo(now) <= 0`, remove it from the working map and emit `GoldenExpired(now, goldenId: entry.id, claimed: false)`. Iterate in `id` ASC order for deterministic event ordering.
    3. **Spawn roll** (AC #1, #10): if `dt > Duration.zero` and the working `activeGoldens.length < BalanceConfig.goldenMaxConcurrent`:
       - Compute `dtSeconds = Decimal.fromInt(dt.inMicroseconds) / Decimal.fromInt(1000000)` (or use `dt.inMilliseconds / 1000.0` and compare via `double` — see note below).
       - Compute `pTick = (BalanceConfig.goldenSpawnProbabilityPerSecond.toDouble()) * dtSeconds.toDouble()`. **The probability comparison uses `double` because `Rng.nextDouble()` returns `double` — do not detour through `Decimal` here**, this is a probability roll, not money math (NFR5 mandates `Decimal` for currency; not for RNG).
       - Draw `rng.nextDouble()`; if `< pTick` AND there is at least one unlocked country, proceed.
       - Pick the country: collect all `state.countries.values.where((c) => c.unlocked).map((c) => c.id).toList()..sort((a, b) => a.value.compareTo(b.value))`, then index `rng.nextInt(unlockedIds.length)` (ALWAYS draw — never short-circuit when only 1 unlocked, so RNG sequences stay deterministic across game-state perturbations within a fixture).
       - Pick the multiplier: `final m = BalanceConfig.goldenMinMultiplier + rng.nextInt(BalanceConfig.goldenMaxMultiplier - BalanceConfig.goldenMinMultiplier + 1);` (inclusive both ends).
       - Construct `id = '${countryId.value}@${now.microsecondsSinceEpoch}'`. (Two spawns in the same microsecond on the same country is impossibly rare under the Δ≥1ms tick clamp; skip uniqueness defenses for v1 — flag in story notes.)
       - Build `ActiveGolden(id, countryId, multiplier: m, expiresAt: now.add(Duration(seconds: BalanceConfig.goldenSpawnExpirySeconds)))`, append to working map, emit `GoldenSpawned(now, goldenId: id, countryId, multiplier: m, expiresAt: ...)`.
       - **Empty-unlocked guard (AC #10)**: if no unlocked countries exist, the RNG must STILL be drawn for the spawn-roll `nextDouble()`, but no further draws — no `nextInt` for country/multiplier. This keeps test seeds stable.
    4. Construct the new `GameState` only if anything changed:
       - `activeGoldens` map (replace if any spawn or expiry happened).
       - `activeGoldenEffect` (replace with `nextEffect` if expired).
       - `goldenOpportunityMultiplier` (replace with `nextMultiplier` if effect expired).
       - All other fields untouched.
       Return `(state, [])` (the original instance, no copy) when nothing changed — this keeps `tick`'s `identical(_state, ...)` short-circuits efficient.
  - [ ] 7.3 Reducer purity: NO `DateTime.now()`, NO `Random()`, NO I/O. The function MUST be exhaustively unit-testable with `(state, content, dt, now, rng)` inputs only.

- [ ] Task 8: Implement the `ClaimGolden` reducer (AC: #4, #7)
  - [ ] 8.1 Create `lib/game/features/goldens/goldens_reducer.dart`:
    ```dart
    Result<(GameState, GameEvent?), GameError> applyClaimGolden(
      GameState state,
      ClaimGolden cmd, {
      required DateTime now,
    });
    ```
  - [ ] 8.2 Validations (in order, each with no state mutation on failure):
    1. `state.activeGoldens[cmd.goldenId] == null` → `Result.failure(GameError.userInvalidTarget(detail: 'golden_not_found'))` (AC #7a).
    2. `targetGolden.expiresAt.compareTo(now) <= 0` → `Result.failure(GameError.userLocked(reason: 'golden_expired'))` (AC #7b — leave entry; scheduler will remove it on next tick).
    3. `state.countries[targetGolden.countryId]?.unlocked != true` → `Result.failure(GameError.userLocked(reason: 'country_locked'))` (AC #7c — defensive).
  - [ ] 8.3 On success, build:
    - `nextActiveGoldens = {...state.activeGoldens}..remove(cmd.goldenId)` (then `Map.unmodifiable`).
    - `nextEffect = ActiveGoldenEffect(goldenId: cmd.goldenId, multiplier: targetGolden.multiplier, expiresAt: now.add(Duration(seconds: BalanceConfig.goldenEffectDurationSeconds)))`.
    - `nextMultiplier = Decimal.fromInt(targetGolden.multiplier)`.
    - Emit `GoldenClaimed(now, goldenId: cmd.goldenId, countryId: targetGolden.countryId, multiplier: targetGolden.multiplier, durationSeconds: BalanceConfig.goldenEffectDurationSeconds)`.
  - [ ] 8.4 Replace-semantics for stacked claims: if `state.activeGoldenEffect != null` when a claim succeeds, **the new effect replaces the old**. The expiring old effect does NOT emit a separate `GoldenExpired` event — the new claim's effect supersedes it cleanly. Test this explicitly (claim twice in succession; only one effect remains; only the new `GoldenClaimed` event fires). (Mirrors Story 5-2's "boosts do not stack" decision-point but resolves differently: goldens replace.)
  - [ ] 8.5 NO interactions with `IncomeCalculator`, NO interactions with `state.countries` mutation. Only golden state changes.

- [ ] Task 9: Wire scheduler + reducer into `GameWorld` (AC: #1, #2, #4, #6, #7, #9)
  - [ ] 9.1 Modify `lib/game/game_world.dart`:
    - Add `final Rng _rng;` field. Add `required Rng rng` to the constructor parameter list and assign.
    - Update `tick(Duration dt)` after the existing `evaluateContinentUnlocks` block: call `evaluateGoldens(_state, _content, dt, now: _clock.now(), rng: _rng)`. If returned events are non-empty, replace `_state` and emit each event; combine the change-detection into the existing `if (countriesChanged || continentEvents.isNotEmpty || ...)` Tick-event-emission predicate so a tick that ONLY had a golden change still emits a `Tick(now)` event.
    - Extend the `applyCommand` switch (AC #4): add a `ClaimGolden()` branch that calls a new `_applyClaimGolden(cmd)` private method. Mirror the `_applyTapCountry` template (`result.map((tuple) { ... })`).
    - Implement `_applyClaimGolden(ClaimGolden cmd)` calling `applyClaimGolden(_state, cmd, now: _clock.now())`. **After a successful claim, do NOT call the continent-unlock or milestone evaluators** — claiming a golden does not change `totalInfluence`, country-unlocked flags, or continent state.
  - [ ] 9.2 Update the existing `applyCommand` switch's `Noop()`/`UnlockCountry()` cases — do NOT add a `ClaimGolden() => const Success(...)` no-op branch in the second switch (lines 86–93 currently). Instead, hoist the early-return for `ClaimGolden` to the top of `applyCommand` like the existing `UnlockCountry` early-return (lines 72–83 pattern). That avoids the post-command continent/milestone re-evaluation entirely.
  - [ ] 9.3 Update `test/game/game_world_test.dart` constructors that build `GameWorld(...)` to pass `rng: SeededRng(0)` (or similar). This is a constructor signature change — every `GameWorld` instantiation breaks until updated. Audit with grep: `rg "GameWorld\(" lib test`. Apply across all callers (production: `lib/providers/game_providers.dart`; tests: every `test/game/**` file that builds a `GameWorld`).

- [ ] Task 10: Add `rngProvider` and wire `GameWorld` (AC: #9)
  - [ ] 10.1 Modify `lib/providers/game_providers.dart`:
    - Import `package:global_domination/game/support/rng.dart`.
    - Add `final rngProvider = Provider<Rng>((_) => SystemRng());` near `clockProvider`.
    - In the `gameWorldProvider` body, `final rng = ref.watch(rngProvider);` and pass `rng: rng` to BOTH `GameWorld(...)` constructions (the empty-content fallback AND the real-content path).
  - [ ] 10.2 No new file under `lib/providers/`; this stays in `game_providers.dart` (composition root for game-loop dependencies).

- [ ] Task 11: Add UI tap routing for golden claim (AC: #8)
  - [ ] 11.1 Modify `lib/ui/features/map/map_screen.dart`'s `_onTapUp`:
    - After computing `countryId` from `_hitTester.hitTest(...)`, BEFORE the existing `TapCountry` dispatch:
      - Read `final state = ref.read(gameWorldProvider);` (state-notifier already exposes `GameState`).
      - Compute `final candidates = state.activeGoldens.values.where((g) => g.countryId == countryId).toList()..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));` (earliest-expiry-first per AC #8).
      - If `candidates.isNotEmpty`, dispatch `ClaimGolden(goldenId: candidates.first.id)` and `return;`.
      - Otherwise fall through to the existing `TapCountry(countryId: countryId)` dispatch.
  - [ ] 11.2 Use `ref.read` (NOT `ref.watch`) because `_onTapUp` is a one-shot callback, not a build-time dependency. Avoid rebuild churn.
  - [ ] 11.3 No visual overlay rendering — explicitly out of scope (deferred to Epic 8 — Game Feel / Juice). Add a `// TODO(epic-8): render golden_opportunity_overlay on country with active golden` comment ONLY if helpful to the next dev; do not over-comment.
  - [ ] 11.4 Widget test: `test/ui/features/map/map_screen_golden_tap_test.dart` (NEW). Strategy:
    - Override `gameWorldProvider` with a hand-built notifier exposing a `GameState` containing one `ActiveGolden(countryId: egypt, ...)`.
    - Pump `MapScreen` with a stubbed `geoProvider` (use existing `country_path_builder.dart` helper if available — see `test/helpers/country_path_builder.dart`).
    - Simulate a tap on the egypt polygon area; assert the test notifier received `ClaimGolden(...)` (NOT `TapCountry(...)`).
    - Reverse case: same setup with empty `activeGoldens`; assert the dispatch is `TapCountry(...)`.

- [ ] Task 12: Pure-Dart scheduler tests in `test/game/features/goldens/goldens_scheduler_test.dart` (AC: #1, #2, #3, #6, #10)
  - [ ] 12.1 Use `package:test/test.dart` (NOT `flutter_test`).
  - [ ] 12.2 Build a fixture `ContentRegistry` via `ContentRegistry.fromJsonStrings(...)` mirroring `test/game/features/economy/income_calculator_test.dart` lines 17–67 — single continent (africa @0), 2–3 countries (egypt unlocked, nigeria unlocked, kenya locked).
  - [ ] 12.3 Test "deterministic spawn under fixed seed" (AC #3): `evaluateGoldens(state, content, Duration(seconds: 1), now: clock, rng: SeededRng(42))` ran twice from the same input produces the same `(state, events)` tuple — including the chosen country, multiplier, and id.
  - [ ] 12.4 Test "no spawn when probability roll fails" (AC #1): seed an RNG whose first `nextDouble()` returns ≥ `pTick`. Strategy: use a tiny `dt = Duration(microseconds: 1)` so `pTick ≈ 0` for any reasonable `goldenSpawnProbabilityPerSecond`, OR override `goldenSpawnProbabilityPerSecond` indirectly by choosing a seed/dt combination known to skip. Confirm `state.activeGoldens.isEmpty` and no `GoldenSpawned` emitted.
  - [ ] 12.5 Test "spawn appends ActiveGolden and emits GoldenSpawned" (AC #1): with a seed that hits, assert exactly one `ActiveGolden` added, multiplier ∈ `[10, 100]`, expiresAt = `now + 10s`, event payload matches.
  - [ ] 12.6 Test "expired map-spawn is removed and emits GoldenExpired(claimed: false)" (AC #2): pre-populate `state.activeGoldens` with one entry whose `expiresAt < now`; pass `dt = Duration.zero` and a seed that wouldn't spawn. Assert removal + event with `claimed: false`. Also verify multiple expired entries emit events in `id` ASC order.
  - [ ] 12.7 Test "active-golden-effect expires and resets multiplier to one" (AC #6): pre-populate `state.activeGoldenEffect = ActiveGoldenEffect(goldenId: 'g1', multiplier: 50, expiresAt: now - 1s)` and `state.goldenOpportunityMultiplier = Decimal.fromInt(50)`. After `evaluateGoldens`, assert `activeGoldenEffect == null`, `goldenOpportunityMultiplier == Decimal.one`, and a single `GoldenExpired(goldenId: 'g1', claimed: true)` event.
  - [ ] 12.8 Test "no spawn when activeGoldens at goldenMaxConcurrent" (AC #1): pre-populate map up to cap with non-expired entries; even with a "would-spawn" seed, no new entry appears, no event.
  - [ ] 12.9 Test "empty-unlocked guard" (AC #10): build a state where every country is locked; even with a "would-spawn" seed, no new entry, no `GoldenSpawned` event. (Use the standard fixture but flip every CountryState.unlocked to false in the test setup.)
  - [ ] 12.10 Test "tick with dt = Duration.zero is a no-op for spawning" (defensive): same input as 12.5 but `dt = Duration.zero` → no spawn even with a hit-seed (because `pTick = 0`).
  - [ ] 12.11 Test "country chosen deterministically from sorted-by-id list": with two unlocked countries (egypt, nigeria) and a seed where `nextInt(2) == 1`, verify the chosen country is `nigeria` (sorted second). Flip the seed to confirm the other branch.

- [ ] Task 13: Pure-Dart reducer tests in `test/game/features/goldens/goldens_reducer_test.dart` (AC: #4, #7)
  - [ ] 13.1 Happy path (AC #4): pre-populate one `ActiveGolden`; dispatch `ClaimGolden(goldenId)`. Assert removal from map, `activeGoldenEffect` set with correct multiplier and `expiresAt = now + 30s`, `goldenOpportunityMultiplier == Decimal.fromInt(claimedMultiplier)`, and `GoldenClaimed` event payload.
  - [ ] 13.2 AC #7a: claim a non-existent goldenId → `Result.failure(GameError.userInvalidTarget(detail: 'golden_not_found'))`, state unchanged (use `expect(result.errorOrNull, isA<InvalidTarget>())` then check the detail).
  - [ ] 13.3 AC #7b: claim an entry whose `expiresAt <= now` → `Result.failure(GameError.userLocked(reason: 'golden_expired'))`, state unchanged INCLUDING the entry remaining in the map.
  - [ ] 13.4 AC #7c: pre-populate an `ActiveGolden(countryId: kenya)` where `state.countries[kenya].unlocked == false` → `Result.failure(GameError.userLocked(reason: 'country_locked'))`.
  - [ ] 13.5 Replace semantics (Task 8.4): pre-populate an existing `activeGoldenEffect` with multiplier 25 and `expiresAt = now + 15s`. Pre-populate a new `ActiveGolden` with multiplier 75. Dispatch `ClaimGolden`. Assert the resulting `activeGoldenEffect.multiplier == 75`, `expiresAt == now + 30s`, ONLY ONE `GoldenClaimed` event, NO extra `GoldenExpired` for the displaced effect.

- [ ] Task 14: Integration tests in `test/game/game_world_test.dart` (AC: #1, #2, #4, #6, #9)
  - [ ] 14.1 End-to-end spawn → claim → effect-expire flow:
    - Build `GameWorld(content: fixture, clock: FakeClock(t0), rng: SeededRng(seedThatSpawnsImmediately))`.
    - Subscribe to `world.events`.
    - `world.tick(Duration(seconds: 1))` → expect `GoldenSpawned` event observed; `world.state.activeGoldens.length == 1`.
    - Read the spawned `goldenId`; `world.applyCommand(ClaimGolden(goldenId))` → expect `Result.success(...)`, `GoldenClaimed` event observed, `world.state.activeGoldenEffect != null`, `world.state.goldenOpportunityMultiplier > Decimal.one`.
    - Advance fake clock by `goldenEffectDurationSeconds + 1s`; `world.tick(Duration(seconds: 1))` → expect `GoldenExpired(claimed: true)` event, `world.state.activeGoldenEffect == null`, `world.state.goldenOpportunityMultiplier == Decimal.one`.
  - [ ] 14.2 Income reflects active golden effect (AC #5): build a state with the effect set + `goldenOpportunityMultiplier == Decimal.fromInt(50)`; call `IncomeCalculator.compute(...)` and assert the rate is exactly `50×` the no-effect rate (composed with the rest of the stack at default values).
  - [ ] 14.3 Tick emits a `Tick(now)` event when only a golden change occurred: build a state with one expired map-spawn, no other state change; call `world.tick(Duration.zero)`; assert events stream emits `GoldenExpired` followed by `Tick(now)` (single Tick, after all golden events).

- [ ] Task 15: Architecture compliance checks (AC: #9, all)
  - [ ] 15.1 Run `flutter test test/architecture/game_boundary_test.dart` — new files under `lib/game/features/goldens/`, `lib/game/support/rng.dart`, and modified `lib/game/game_state.dart` MUST contain no `package:flutter/`, no `dart:ui`, no `lib/data/` imports. (`dart:math` is fine.)
  - [ ] 15.2 Run `flutter test test/architecture/no_duplicate_income_math_test.dart` — the goldens scheduler reads NO `def.baseInfluence *` patterns; this test should pass without modification.
  - [ ] 15.3 `lib/ui/features/map/map_screen.dart` is allowed to import `package:flutter/...` (it always has) — the boundary test only restricts `lib/game/`.

- [ ] Task 16: Full validation (AC: all)
  - [ ] 16.1 `flutter analyze` — 0 warnings.
  - [ ] 16.2 `dart format --set-exit-if-changed .`.
  - [ ] 16.3 `flutter test` — full suite green (existing 519 + new ~25–30).
  - [ ] 16.4 Update `Status` to `review` and append entries to the Completion Notes / File List.

## Dev Notes

### Why this story is the keystone of Epic 5

This is the FIRST story in Epic 5 (Active Play). It establishes infrastructure that downstream stories in this epic depend on:

| Decision locked here | Used by |
|---|---|
| `Rng` interface in `lib/game/support/rng.dart` (Task 1) | Story 5-2 (`ActivateBoost` does not need RNG, but downstream `BoostScheduler` for "should this boost re-roll something?" might); **Story 5-3 missions rotation** (mandatory); future event-spawn schedulers. **Treat the `Rng` interface as project-stable. Do NOT add `currentSeed`, `withSeed(...)`, or other state-exposing methods now**; we'll iterate when a use case lands. |
| **Per-tick scheduler pattern** (Task 7 — pure function `(state, content, dt, now, rng) → (state, events)`) | Story 5-2 (boost expiry tick), Story 5-3 (mission progress evaluator), Story 5-4 (daily reward at-clock-rollover). The shape `evaluateXxx(state, content, dt, {now, rng})` becomes the project pattern. |
| **`activeXxx` + `activeXxxEffect` state shape** (Tasks 3, 4) | Story 5-2 will mirror this for boosts: `state.activeBoost: ActiveBoost?` (singleton, no spawn-side). Use the same `@immutable` value class + null-sentinel `copyWith` pattern. |
| **`Tick` event emission predicate** (Task 9.1, last sub-bullet) | Story 5-2 must NOT regress this — every per-tick scheduler that mutates state needs to be in the `tickChanged ||= ...` chain that gates `Tick(now)` emission. |
| **No-content-JSON for goldens** (deliberate) | Story 5-2 (boost) and 5-3 (missions) rely on `BalanceConfig` constants + `assets/data/missions.json` respectively. Goldens have NO content file because spawn rules are pure tuning (Story 10-2 retunes `BalanceConfig`). |

**Out of scope (do NOT expand):**

- **Drift persistence for goldens.** Epic 6 owns the `goldens` table, the `GoldenStateMapper`, and the typed migration. Per the project rule "backward compatibility is out of scope," the in-flight goldens / effect simply vanish on app close until Epic 6. **Add NO Drift code. Add NO migration file.**
- **Visual rendering of goldens on the map.** Epic 8 owns `lib/ui/features/map/overlays/golden_opportunity_overlay.dart` (per game-architecture.md §Source-Tree §`overlays/`). This story changes ONLY tap routing (AC #8). A locked country with no overlay rendering is an acceptable v1 state — players still see goldens via audible feedback (Epic 8 wires `GoldenClaimed → AudioService.play(Sfx.golden)`).
- **Audio / haptics on `GoldenSpawned` / `GoldenClaimed` / `GoldenExpired`.** `AudioService` and `HapticsService` are introduced in Story 8-1; sealed-switch exhaustiveness will FORCE that story to handle the new events. **Do NOT add `case GoldenSpawned()` branches anywhere outside `GameWorld` and tests in this story** — services don't exist yet.
- **Tutorial hint on first golden** (FR42, Story 9-4). Out of scope; Story 9-4 will hook into `GoldenSpawned` via `state.tutorial.completed` gate.

### Critical decisions worth restating in code

- **Multiplier slot semantics (AC #5)**: `state.goldenOpportunityMultiplier` is a `Decimal` field on `GameState` (already exists, line 28 of `lib/game/game_state.dart`). Pre-Epic-5 it was always `Decimal.one`. Starting with this story, it's set by claim and reset by effect-expiry. **`IncomeCalculator.compute` is NOT modified.** The grep test `test/architecture/no_duplicate_income_math_test.dart` is unaffected.

- **Replace-semantics for stacked claims (Task 8.4)**: claiming a second golden while an effect is active replaces the effect. This is **different** from boosts (Story 5-2 will use fail-on-stack semantics — `userLocked(reason: 'boost_already_active')`). Don't conflate. Goldens are spawn-driven (player can't farm them); boosts are intel-driven (player CAN spam them). Stacking goldens is fine — replace freely.

- **Determinism for tests vs. real-time gameplay**: production code uses `SystemRng` (non-deterministic). Tests use `SeededRng(N)`. The same `evaluateGoldens` function services both — this is the same pattern as `Clock` / `FakeClock`.

- **RNG draw discipline (Task 7.2 step 3, AC #10)**: even when no country is unlocked, the spawn-roll `nextDouble()` is consumed. This keeps the test suite stable when a fixture is tweaked (e.g. flipping a country's `unlocked` flag should NOT shift downstream RNG sequences). Document this explicitly in `goldens_scheduler.dart` with a code comment.

- **Probability comparison uses `double`, not `Decimal`** (Task 7.2 step 3, second sub-bullet): `Rng.nextDouble()` returns `double`. Routing through `Decimal` for the comparison is unnecessary and slow on the per-tick hot path. NFR5 mandates `Decimal` for **currency math**, not for probability. This is consistent with how the architecture document treats RNG as a sim primitive.

- **Tick clamp (`dt ≤ 100ms`) interaction with spawn probability**: with `goldenSpawnProbabilityPerSecond = 0.0333` and a typical 16ms tick, `pTick ≈ 0.00053`. After 30s of ticks, cumulative spawn probability ≈ 1.0 (Bernoulli). This matches the design target of "1 spawn per ~30s of active play." If the player tab-switches and `dt` clamps to 100ms, the math still works because `gameWorld.tick` is called with the clamped dt. **No special-case logic needed.**

### Architecture Compliance (non-negotiable)

- **`lib/game/` has ZERO Flutter imports.** Every new file under `lib/game/` (rng, scheduler, reducer, value classes) must compile under `dart test`. The boundary test in `test/architecture/game_boundary_test.dart` enforces this.
- **`lib/game/` is the only place `Random()` may be used** — and ONLY inside `lib/game/support/rng.dart`'s `SystemRng` constructor. Reducers and schedulers MUST NOT call `Random()` directly; they take an injected `Rng`.
- **`now` is always injected via the `Clock` parameter chain.** Schedulers receive `now: _clock.now()` from `GameWorld`, never read `DateTime.now()` directly.
- **Reducer / scheduler purity:** no `print`, no `Logger(...).info` in the per-tick path (NFR3 — no logging in hot paths). If you must log, use `assert(...)` at most. The cheaply-checked invariants are: `assert(dt >= Duration.zero)`, `assert(BalanceConfig.goldenMinMultiplier <= BalanceConfig.goldenMaxMultiplier)` at top of file (compile-time-ish via const).
- **Sealed switch exhaustiveness:** adding `ClaimGolden` to `GameCommand` and three new `GameEvent` variants will produce compiler errors at every `switch (cmd)` and `switch (event)` site. The current sites are: `GameWorld.applyCommand` (the `switch (cmd)` on lines 86–93 of `game_world.dart`). There are NO consumer switches over `GameEvent` in `lib/` yet (the Riverpod notifier uses a generic listener). Update the command switch; verify no other switch breaks via `flutter analyze`.
- **Event emission rule (NFR11):** only `GameWorld` emits via `_events.add(event)`. Services (when they land in Epic 8) subscribe but never re-emit.
- **No income math here.** This story does NOT touch `lib/game/features/economy/income_calculator.dart`. The grep guard in `test/architecture/no_duplicate_income_math_test.dart` flags `def.baseInfluence *` patterns — the goldens scheduler reads no such patterns.
- **State equality with new fields (Task 4.4):** the existing `GameState.==` and `hashCode` use field-by-field comparison via `MapEquality`/`SetEquality`. Add `_activeGoldensEq.equals(...)` and a direct `==` on the nullable `activeGoldenEffect`. **Forgetting to extend equality breaks Riverpod's identity-based rebuild gate** — the test in 14.1 catches this.

### Library / Framework Requirements

- `dart:math` — `Random` (only inside `lib/game/support/rng.dart`'s `SystemRng`). No new `pubspec.yaml` entries.
- `package:decimal/decimal.dart` (already pinned `^3.0.2`) — for `goldenSpawnProbabilityPerSecond` and the `Decimal.fromInt(multiplier)` write to `state.goldenOpportunityMultiplier`.
- `package:meta/meta.dart` — for `@immutable` on the new value classes.
- `package:test/test.dart` for `test/game/**` (NOT `flutter_test`). `package:flutter_test/flutter_test.dart` ONLY for the widget test in Task 11.4.
- `package:collection/collection.dart` (already pinned `^1.19.1`) — `MapEquality<String, ActiveGolden>` for `_activeGoldensEq` in `GameState`.

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/game/support/rng.dart` | `Rng` abstract + `SeededRng` + `SystemRng` impls — first introduction of seedable randomness to the sim |
| `lib/game/features/goldens/active_golden.dart` | `ActiveGolden` immutable value class (`id, countryId, multiplier, expiresAt`) |
| `lib/game/features/goldens/active_golden_effect.dart` | `ActiveGoldenEffect` immutable value class (`goldenId, multiplier, expiresAt`) |
| `lib/game/features/goldens/goldens_scheduler.dart` | Pure-function `evaluateGoldens(state, content, dt, {now, rng})` |
| `lib/game/features/goldens/goldens_reducer.dart` | Pure-function `applyClaimGolden(state, ClaimGolden, {now})` |
| `test/game/support/rng_test.dart` | RNG impl unit tests |
| `test/game/features/goldens/active_golden_test.dart` | Value-class equality / hashCode / toString |
| `test/game/features/goldens/active_golden_effect_test.dart` | Value-class equality / hashCode / toString |
| `test/game/features/goldens/goldens_scheduler_test.dart` | Pure-Dart scheduler tests (Task 12) |
| `test/game/features/goldens/goldens_reducer_test.dart` | Pure-Dart reducer tests (Task 13) |
| `test/ui/features/map/map_screen_golden_tap_test.dart` | Widget test for tap routing (Task 11.4) |

**Modify:**

| File | Change |
|---|---|
| `lib/game/game_state.dart` | Add `activeGoldens` and `activeGoldenEffect` fields; extend `copyWith`, `==`, `hashCode`, `toString` |
| `lib/game/game_command.dart` | Add `final class ClaimGolden extends GameCommand` |
| `lib/game/game_event.dart` | Add `final class GoldenSpawned`, `GoldenClaimed`, `GoldenExpired` |
| `lib/game/game_world.dart` | Constructor takes `Rng rng`; `tick` calls `evaluateGoldens`; `applyCommand` routes `ClaimGolden` (early-return; no continent/milestone re-evaluation) |
| `lib/game/config/balance.dart` | Add 6 constants (Task 2.1) |
| `lib/providers/game_providers.dart` | Add `rngProvider`; pass `rng` to both `GameWorld(...)` constructions |
| `lib/ui/features/map/map_screen.dart` | `_onTapUp`: dispatch `ClaimGolden` when an active golden matches the hit-test; else `TapCountry` |
| `test/game/game_command_test.dart` | Equality / `toString` for `ClaimGolden` |
| `test/game/game_event_test.dart` | Equality / `toString` for the three new events |
| `test/game/game_world_test.dart` | Update every `GameWorld(...)` to pass `rng: SeededRng(0)`; add Task 14 integration tests |
| `test/game/features/economy/income_calculator_test.dart` | Add the AC #5 test (Task 14.2) — composes `state.goldenOpportunityMultiplier = 50` and asserts `compute` reflects it |
| Any other test file currently constructing a `GameWorld` directly | Pass `rng: SeededRng(0)` |

**Do NOT modify:**

- `lib/game/features/economy/income_calculator.dart` — multiplier stack stays exactly as-is. AC #5 is satisfied via the existing `state.goldenOpportunityMultiplier` field read.
- `lib/data/**` — no Drift schema changes (Epic 6's job).
- `lib/services/**` — services don't exist yet for game events (Epic 8).
- `assets/data/*.json` — content tuning is Epic 10. No `goldens.json` is needed (spawn rules live in `BalanceConfig`).
- `lib/game/features/continents/**`, `lib/game/features/economy/**`, `lib/game/features/leaders/**`, `lib/game/features/upgrades/**` — orthogonal features. The only cross-cutting change is `GameState` field additions.

### Testing Requirements

- **Pure-Dart tests for `lib/game/`**: `package:test/test.dart` (NOT `flutter_test`). Existing pattern in `test/game/features/economy/income_calculator_test.dart` (lines 1–67) — copy the `_buildSingleCountryContent()` helper or build a sibling.
- **Seeded RNG fixture**: every scheduler test uses `SeededRng(<int>)` so spawn outcomes are reproducible. Pin the seed values in test names (e.g. `"spawn determinism — seed 42 → nigeria multiplier 67"`).
- **Fake clock**: `test/helpers/fake_clock.dart` (`FakeClock(initial)` + `advance(Duration)`) is the canonical clock fake. Every scheduler test instantiates one.
- **Widget test (Task 11.4)** uses `flutter_test` + `flutter_riverpod` `ProviderContainer`/`ProviderScope` overrides. **Always `addTearDown(container.dispose);`**. Reference: `test/providers/feature_providers_test.dart` for the override-with-test-notifier pattern.
- **Integration test (Task 14.1)** is `flutter_test` (because it uses real `GameWorld` + real event stream). It does NOT need provider overrides because `GameWorld` is constructed directly.
- **NO property tests required** for this story. The seeded determinism tests (Task 12.3) cover the determinism invariant adequately for v1; bigger property tests can land in Epic 10 alongside balance retuning.
- **Test count expectation**: ~25–30 new tests (RNG: 4, value classes: 6, scheduler: 9, reducer: 5, integration: 3, widget: 2, command/event equality: 3+ existing-extension). Full suite should land at ~545–550 tests.

### Previous Story Intelligence (from Stories 4-1 through 4-5)

Direct guidance extracted from the most recent done stories — **read these patterns into your implementation**:

- **`copyWith` explicit-null sentinel pattern (from 4-1's Review Patch)**: `CountryState.copyWith` had a regression where `lastCollectedAt: null` couldn't override an existing non-null value because `?? this.lastCollectedAt` swallows the null. The fix uses an `Object _lastCollectedAtUnchanged` sentinel (see `country_state.dart:9, 33-43`). **Apply the SAME pattern when adding `activeGoldenEffect: ActiveGoldenEffect?` to `GameState.copyWith`** (Task 4.3). Without it, claiming an effect and later expiring it via `copyWith(activeGoldenEffect: null)` is a no-op — a silent bug that 4-1 already paid the tax for.

- **Reducer-first-then-evaluators pattern (from 4-1 Task 4 / `game_world.dart:67-99`)**: `applyCommand` runs the reducer first, then re-evaluates continent unlocks + milestones if state changed. **For `ClaimGolden`, take the early-return path (lines 67-83 pattern)** — claiming a golden does not affect total influence, country unlocks, or continent state. There's no reason to fire the post-command evaluators. Mirror the `UnlockCountry()` early-return shape (Task 9.2).

- **Tie-break by `id.value` ASC (from 4-2 / 4-5)**: when sorting otherwise-equal options, use lexicographic tie-break on the value field (`id.value.compareTo(...)`). Apply in Task 7.2 step 3 sub-bullet 4: "collect unlocked country ids... sort by `CountryId.value`." This makes seeded tests stable across content reordering.

- **MapEquality / SetEquality pattern (from 4-1 / 4-3)**: `GameState.==` uses `MapEquality<ContinentId, bool>` for nested-map equality. Mirror this with `MapEquality<String, ActiveGolden>` for `activeGoldens` (Task 4.2). Forgetting equality wiring causes silent Riverpod rebuild bugs.

- **Provider tests need a `_TestGameWorldNotifier` (from 4-5 Task 5 / `feature_providers_test.dart`)**: when a widget test needs to set arbitrary `GameState` without booting a real `GameWorld`, build a minimal `StateNotifier<GameState>` shim and override `gameWorldProvider` with it. **Reuse this pattern for the widget test in Task 11.4** — see `test/providers/feature_providers_test.dart` for `_TestGameWorldNotifier extends GameWorldNotifier` if it exists, or compose your own.

- **Dispose teardown discipline (from 4-5 Task 5.8)**: every `ProviderContainer` in tests gets `addTearDown(container.dispose);` immediately after construction. Dropping this leaks subscribers and causes flaky tests in subsequent runs.

### Project Structure Notes

- **Folder choice (`lib/game/features/goldens/`)**: matches game-architecture.md §System→Location Mapping ("Active play (Goldens/Boosts/Missions) | `lib/game/features/{goldens,boosts,missions}/` | Schedulers + reducers"). Stories 5-2 and 5-3 will create sibling `boosts/` and `missions/` folders — do not preempt.
- **Folder choice (`lib/game/support/`)**: `rng.dart` joins `clock.dart` here per game-architecture.md §Source-Tree (line 588: `rng.dart # seedable for determinism`). The folder is the canonical home for "injectable sim primitives."
- **Provider file location (`lib/providers/game_providers.dart`)**: `rngProvider` lives here alongside `clockProvider`. Both are sim-primitive providers; do NOT split into a new file.
- **No `goldens.json`** under `assets/data/`: deliberate. Spawn tuning is `BalanceConfig` (code), not content. Story 10-2 is the place to retune; do not invent a content file.
- **Test mirror**: `test/game/features/goldens/` mirrors source. `test/game/support/rng_test.dart` mirrors `lib/game/support/rng.dart`.
- **No `lib/data/database/tables/goldens_table.dart`**: Epic 6 adds it; this story explicitly does NOT.

### Project Context Rules

Extracted from `_bmad-output/project-context.md` — applies to this story:

- **`lib/game/` has ZERO Flutter imports.** Every new file under `lib/game/features/goldens/` and `lib/game/support/rng.dart` is pure Dart. Enforced by `test/architecture/game_boundary_test.dart`.
- **The only place `Random()` is allowed in `lib/game/`** is inside `lib/game/support/rng.dart`'s `SystemRng` impl — and even then, schedulers / reducers receive `Rng`, never call `Random()` directly. (Mirror of "Calling `DateTime.now()` in `lib/game/` — always use the injected `Clock`.")
- **UI never mutates `GameState` directly.** UI dispatches commands via `ref.read(gameWorldProvider.notifier).apply(cmd)`. This story adds one new command (`ClaimGolden`); the UI uses it from `_onTapUp` exactly the same way it already uses `TapCountry`.
- **Reducers / schedulers are pure functions.** NO clock reads, NO RNG reads (except the injected parameter), NO I/O. `evaluateGoldens` and `applyClaimGolden` follow this rule strictly.
- **Multiplier stack is single source of truth in `IncomeCalculator.compute`.** This story does NOT touch the multiplier stack code. The `goldenOpportunityMultiplier` slot already exists; the scheduler keeps the underlying state field in sync with `activeGoldenEffect`. Adding a new helper to `IncomeCalculator` is a scope creep and explicitly forbidden (per Story 4-1's "Do NOT modify `IncomeCalculator`" rule generalized to non-IP costs).
- **Big numbers:** `state.goldenOpportunityMultiplier` is a `Decimal` (already wired). Write via `Decimal.fromInt(multiplier)` from claim. Probability comparison (`pTick`, `rng.nextDouble()`) uses `double` — not currency math, not subject to NFR5.
- **Configuration discipline:** spawn probability, multiplier range, durations all live in `BalanceConfig` (Task 2). NO hardcoded magic numbers in scheduler / reducer / UI code.
- **No `freezed`, no `json_serializable`, no `riverpod_generator`.** Manual `==` / `hashCode` / `toString` on `ActiveGolden`, `ActiveGoldenEffect`, `ClaimGolden`, and the three new events. Manual provider declarations.
- **Sealed `switch` exhaustiveness:** adding `ClaimGolden` will compile-error every `switch (cmd)`. The only current site is `GameWorld.applyCommand`. Adding three `GameEvent` variants — verify no consumer switch breaks (`flutter analyze`).
- **Logging:** `package:logging` only. Schedulers / reducers MUST NOT log anything (NFR3 — no logging in hot paths). Use `assert(...)` for invariants if needed.
- **Persistence:** event-driven + 2s debounced snapshot, never per-tick — irrelevant for this story because Epic 6 owns persistence; this story has zero Drift work.
- **MCP `dart` / `flutter-mcp` tools** are available — prefer them over shell `dart` / `flutter` invocations during analysis and test runs.

### Backwards-compatibility note (project rule)

Per the project rule: **"backward compatibility is out of scope unless explicitly requested. Do not add migrations, versioning, or default-fallback logic to keep older saved games loading; it's acceptable for old saves to break and require a reset during development."**

This story adds new fields to `GameState`. Until Epic 6 lands persistence, the only impact is on in-memory state — no breakage. When Epic 6 introduces Drift schemas for goldens, **old saves will break** and a fresh-start is acceptable. Do NOT add a "default to empty `activeGoldens`" fallback in mappers; that's Epic 6's call.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.1: Golden Opportunity — Spawn and Claim] — original ACs (lines 990–1020) and FR11/FR45 cross-references
- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.2: BalanceConfig Constants Pinned] — naming convention for the new constants (`goldenSpawnProbability`, `goldenMinMultiplier`, `goldenMaxMultiplier`, `goldenDurationSeconds`)
- [Source: _bmad-output/game-architecture.md#12. DI & Multiplier Stack Ordering] — `goldenOpportunityMultiplier` slot is the second-to-last in the stack (lines 306–318)
- [Source: _bmad-output/game-architecture.md#Source-Tree] — `lib/game/features/goldens/ { state, scheduler, reducer }` (line 579) and `lib/game/support/rng.dart` (line 588)
- [Source: _bmad-output/game-architecture.md#Q6-offline] — Default: Goldens do NOT continue multiplying offline (line 326). This story does not implement offline behavior; Epic 6 will explicitly skip Goldens during `OfflineCatchup.apply`.
- [Source: _bmad-output/project-context.md#Engine-Specific Rules (Flutter / Dart)] — pure `lib/game/`, sealed hierarchies, `Clock` injection (mirror for `Rng`), `BalanceConfig` discipline
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules] — "Calling `DateTime.now()` in `lib/game/` — always use the injected `Clock`" generalizes to "Calling `Random()` in `lib/game/` — always use the injected `Rng`"
- [Source: _bmad-output/implementation-artifacts/4-1-unlock-next-country-in-current-continent.md#Review Findings] — `copyWith` explicit-null sentinel pattern (mandatory for `activeGoldenEffect`)
- [Source: _bmad-output/implementation-artifacts/4-3-continent-milestone-rewards-at-25-50-75-100.md] — pattern reference for "evaluator runs each tick after applyCommand and after tickCountries" (mirror this for `evaluateGoldens`)
- [Source: _bmad-output/implementation-artifacts/4-5-next-unlock-teaser-data-on-state.md#Provider test wiring] — `_TestGameWorldNotifier extends GameWorldNotifier` shim for widget/provider tests (reuse for Task 11.4)
- [Source: lib/game/game_state.dart] — existing `goldenOpportunityMultiplier` field (line 28); `MapEquality` patterns (lines 14–19); `_lastCollectedAtUnchanged`-style sentinel pattern (look at `country_state.dart:9`)
- [Source: lib/game/game_world.dart] — `tick(...)` structure (lines 36–65) and `applyCommand` pattern (lines 67–99) including the `UnlockCountry` early-return (lines 72–83) — model for the `ClaimGolden` early-return
- [Source: lib/game/features/continents/milestones_reducer.dart] — pure-function scheduler shape `(GameState, List<GameEvent>)` returning a tuple (mirror this exactly for `evaluateGoldens`)
- [Source: lib/game/features/continents/unlocks_reducer.dart] — `Result<(GameState, GameEvent?), GameError>` reducer shape (mirror this for `applyClaimGolden`)
- [Source: lib/providers/game_providers.dart] — `clockProvider` placement and `gameWorldProvider`'s dual-construction pattern (empty-content fallback + real-content) (lines 13, 42–62)
- [Source: lib/ui/features/map/map_screen.dart] — `_onTapUp` (lines 111–122) — modify here for golden tap routing
- [Source: lib/game/features/economy/income_calculator.dart] — line 47 reads `state.goldenOpportunityMultiplier`; verify untouched after this story
- [Source: test/architecture/game_boundary_test.dart] — boundary invariants for `lib/game/` (no Flutter, no `dart:ui`, no `data/` reverse imports)
- [Source: test/helpers/fake_clock.dart] — `FakeClock` pattern (mirror for any clock-dependent test)
- [Source: test/game/features/economy/income_calculator_test.dart] — fixture `ContentRegistry` construction pattern (lines 17–67)
- [Source: test/providers/feature_providers_test.dart] — provider override pattern for widget/provider tests (Task 11.4)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
