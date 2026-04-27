# Story 6.4: Offline Earnings Calculation on Resume

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Implementation MUST start only after Story 6.1 is done and Story 6.2's persistence event stream work is present in the branch. At the time this story was created, `sprint-status.yaml` marks 6.1 `done`, 6.2 `review`, 6.3 `ready-for-dev`, 6.5 `ready-for-dev`, and this story is being moved from `backlog` to `ready-for-dev`.

Before coding, verify:

- `lib/data/mappers/game_state_mapper.dart`, `GameStateRows`, and `AppDatabase.loadAll()` exist from Story 6.1.
- `lib/data/repositories/save_repository.dart`, `saveRepositoryProvider`, and `gameWorldEventsProvider` exist from Story 6.2.
- `lib/services/game_lifecycle_observer.dart` flushes on paused/inactive/detached/hidden and currently no-ops on resumed.
- If Story 6.3 has already landed, preserve its `databaseBootstrapProvider` and `SaveRecoveryScreen` boot gate. Do not undo migration recovery work.

If 6.2 is not merged or its code is absent, halt and finish 6.2 first. This story depends on the event stream and meta snapshot writer.

## Story

As a player,
I want my Leader-automated countries to have earned Influence while the app was closed, up to 8 hours,
so that returning to the game feels respectful of my time.

## Acceptance Criteria

1. **Given** persisted rows from `AppDatabase.loadAll()` and a loaded `ContentRegistry`
   **When** the app boots with an existing `meta` row
   **Then** the initial `GameWorld` state is created from `GameStateMapper.fromRows(rows, content)` before the playable UI is shown, and `rows.meta.lastSavedAt.toUtc()` is retained as the offline clock source for the boot catch-up.

2. **Given** an empty first-launch database where `rows.meta == null`
   **When** the app boots
   **Then** `GameState.initialSeed(content)` is used, no offline earnings are applied, no `OfflineEarningsApplied` event is emitted, and the first later `SaveRepository` meta snapshot remains responsible for inserting the singleton `meta` row.

3. **Given** `meta.lastSavedAt` and an injected `Clock`
   **When** the app boots or receives `AppLifecycleState.resumed`
   **Then** `OfflineCatchup.apply(...)` computes `elapsed = min(clock.now().toUtc() - lastSavedAt.toUtc(), Duration(hours: 8))`, clamps negative elapsed to `Duration.zero`, and runs before the foreground ticker restarts or the player can interact with the map.

4. **Given** `elapsed > Duration.zero`
   **When** offline catch-up runs
   **Then** it considers only unlocked countries whose `CountryState.leaderTier != LeaderTier.none`, computes `earned = offlineRatePerSecond * Decimal.fromInt(elapsed.inSeconds)` per eligible country, sums the result into one `Influence totalEarned`, and increments `GameState.totalInfluence` by `totalEarned`.

5. **Given** a country has no Leader, is locked, has missing content, or has a zero computed rate
   **When** catch-up runs
   **Then** that country contributes `Influence.zero`, no error is thrown for content-missing rows already handled by the mapper, and no per-country `bankedInfluence` is modified.

6. **Given** active Boosts or Goldens existed at pause time
   **When** offline catch-up computes rates
   **Then** `activeBoost`, `goldenOpportunityMultiplier`, and `activeGoldenEffect` do NOT affect offline earnings, no partial boost or golden time credit is given, and the existing boost/golden expiry reducers remain responsible for clearing expired effects on the next foreground tick.

7. **Given** catch-up has positive elapsed, even if `totalEarned == Influence.zero`
   **When** it is applied
   **Then** exactly one `OfflineEarningsApplied(at, totalEarned, elapsed)` event is emitted by `GameWorld` after the state mutation; for `totalEarned == Influence.zero`, total Influence is unchanged but the event still allows persistence to advance `lastSavedAt` and Story 6.5 to suppress the modal.

8. **Given** `elapsed == Duration.zero` after clamping
   **When** catch-up is requested
   **Then** no state mutation, no event emission, and no persistence write occur.

9. **Given** `OfflineEarningsApplied` is emitted
   **When** `SaveRepository._handleEvent` receives it
   **Then** the exhaustive event switch has an explicit `OfflineEarningsApplied()` case that schedules a meta snapshot for `totalInfluence`, `totalIntel`, transient multiplier fields, and `lastSavedAt`; the resume/boot catch-up runner immediately awaits `saveRepository.flush()` after applying catch-up so the offline reward is not replayed after a fast app kill.

10. **Given** the app resumes from background
    **When** lifecycle observers receive `resumed`
    **Then** there is one ordered path: stop/no ticker while catch-up is running, apply catch-up, flush persistence if an offline event was emitted, then restart the existing `GameLoop` ticker. Do not create a second ticker and do not let `GameLoop` restart before catch-up completes.

11. **Given** Story 6.5 consumes `OfflineEarningsApplied`
    **When** this story is implemented
    **Then** the event payload is stable and contains at least `Influence totalEarned` and `Duration elapsed`; this story does not build the modal, a modal queue, or any UI presentation beyond preserving the event contract.

12. **Given** all tests for this story
    **When** targeted tests and verification run
    **Then** pure game tests cover deterministic math, stable-multiplier exclusion, 8-hour cap, negative/zero elapsed, zero-earned positive elapsed, and large `Decimal` values; provider/widget tests cover boot gating and resume ordering; data tests cover the new `SaveRepository` event case.

## Tasks / Subtasks

- [x] Task 1: Re-check prerequisites and current branch shape (AC: #1, #9, #10)
  - [x] 1.1 Confirm 6.1 is `done` and `GameStateMapper.fromRows(rows, content)` round-trips current state.
  - [x] 1.2 Confirm 6.2's `SaveRepository` exists and subscribes to `gameWorld.events` through `gameWorldEventsProvider`.
  - [x] 1.3 Confirm `GameLifecycleObserver` currently handles paused/inactive/detached/hidden and no-ops on resumed; this story owns the resumed branch.
  - [x] 1.4 If 6.3 has changed `appDatabaseProvider` to `databaseBootstrapProvider.requireValue`, adapt to that provider rather than restoring the older direct `AppDatabase()` provider.

- [x] Task 2: Add offline constants and event contract (AC: #3, #7, #11)
  - [x] 2.1 Create `lib/game/config/constants.dart` if still missing, with `abstract final class GameConstants { static const int maxOfflineHours = 8; }`. Do not hardcode `8` in reducer logic.
  - [x] 2.2 Add `OfflineEarningsApplied` to `lib/game/game_event.dart`:
    ```dart
    final class OfflineEarningsApplied extends GameEvent {
      const OfflineEarningsApplied(
        super.at, {
        required this.totalEarned,
        required this.elapsed,
      });

      final Influence totalEarned;
      final Duration elapsed;
    }
    ```
  - [x] 2.3 Implement equality, `hashCode`, and `toString()` matching existing event classes. Add tests in `test/game/game_event_test.dart`.
  - [x] 2.4 Do not add a `GameCommand`; offline catch-up is lifecycle/system time, not player intent.

- [x] Task 3: Implement pure offline catch-up math in the game layer (AC: #3-#8)
  - [x] 3.1 Create `lib/game/features/economy/offline_catchup.dart`.
  - [x] 3.2 Add an immutable result type, for example:
    ```dart
    class OfflineCatchupResult {
      const OfflineCatchupResult({
        required this.state,
        required this.elapsed,
        required this.totalEarned,
        required this.event,
      });

      final GameState state;
      final Duration elapsed;
      final Influence totalEarned;
      final OfflineEarningsApplied? event;
      bool get emittedEvent => event != null;
    }
    ```
  - [x] 3.3 Public API:
    ```dart
    abstract final class OfflineCatchup {
      static OfflineCatchupResult apply(
        GameState state,
        ContentRegistry content, {
        required DateTime now,
        required DateTime lastSavedAt,
      }) {
        // implementation in this story
      }
    }
    ```
    Normalize both dates with `.toUtc()` inside the function. No `DateTime.now()` inside `lib/game/`.
  - [x] 3.4 Clamp elapsed:
    - `rawElapsed = nowUtc.difference(savedAtUtc)`
    - if `rawElapsed <= Duration.zero`, return the original state, zero earned, and `event: null`
    - if `rawElapsed > Duration(hours: GameConstants.maxOfflineHours)`, use the max duration
  - [x] 3.5 Build a stable multiplier state for math by reusing the current state but clearing transient multipliers:
    ```dart
    final stableState = state.copyWith(
      goldenOpportunityMultiplier: Decimal.one,
      activeBoost: null,
      activeGoldenEffect: null,
    );
    ```
    Do not clear ledgers, `activeGlobalUpgradeIds`, `earnedAchievementIds`, `continentCompletions`, or leader tiers.
  - [x] 3.6 For each country, skip unless `country.unlocked` and `country.leaderTier != LeaderTier.none`. For eligible countries, call the existing `IncomeCalculator.compute(country, stableState, content)` and multiply by `Decimal.fromInt(elapsed.inSeconds)`. This preserves the single source of truth for IP, Leader, continent, achievement, and global upgrade math.
  - [x] 3.7 Sum into `totalEarned`. Return `state.copyWith(totalInfluence: state.totalInfluence + totalEarned)` when elapsed is positive, even if the sum is zero.
  - [x] 3.8 Emit exactly one `OfflineEarningsApplied(nowUtc, totalEarned: totalEarned, elapsed: elapsed)` when elapsed is positive. Do not emit `Tick`, `ContinentUnlocked`, `AchievementEarned`, `MissionCompleted`, or any modal/UI event from this reducer.

- [x] Task 4: Add a GameWorld keyhole for lifecycle catch-up (AC: #7, #10, #11)
  - [x] 4.1 Import `offline_catchup.dart` into `lib/game/game_world.dart`.
  - [x] 4.2 Add a public method on `GameWorld`, for example:
    ```dart
    OfflineCatchupResult applyOfflineCatchup({required DateTime lastSavedAt})
    ```
    It calls the pure reducer with `_state`, `_content`, `now: _clock.now()`, and the provided `lastSavedAt`.
  - [x] 4.3 If the returned event is non-null, assign `_state = result.state` before `_events.add(result.event!)`. The event stream must remain `StreamController.broadcast(sync: true)`.
  - [x] 4.4 If the event is null, leave `_state` unchanged and emit nothing.
  - [x] 4.5 Do not route this through `_emitBatchWithMissions`; offline earnings must not complete missions or trigger achievements in the same microtask. Future foreground ticks can evaluate normal progression.
  - [x] 4.6 Add a matching method on `GameWorldNotifier`, e.g. `OfflineCatchupResult applyOfflineCatchup({required DateTime lastSavedAt})`, and set `state = _world.state` after invoking it.

- [x] Task 5: Add persisted snapshot loading for boot (AC: #1, #2, #3)
  - [x] 5.1 Add a provider-layer snapshot type, preferably in `lib/providers/offline_catchup_providers.dart`:
    ```dart
    class PersistedGameSnapshot {
      const PersistedGameSnapshot({
        required this.state,
        required this.lastSavedAt,
      });

      final GameState state;
      final DateTime? lastSavedAt;
    }
    ```
  - [x] 5.2 Add `persistedGameSnapshotProvider = FutureProvider<PersistedGameSnapshot>(...)` that awaits `contentRegistryProvider.future`, reads `AppDatabase.loadAll()`, maps rows through `GameStateMapper.fromRows(rows, content)`, and returns `lastSavedAt: rows.meta?.lastSavedAt.toUtc()`.
  - [x] 5.3 Modify `gameWorldProvider` so the production path uses `persistedGameSnapshotProvider.requireValue.state` as `GameWorld.initialState` once the app boot gate has resolved. Keep tests ergonomic by allowing provider overrides; do not boot real Drift in widget tests.
  - [x] 5.4 Update `GlobalDominationApp.build` so the normal game surface is shown only after content, database bootstrap if present, and persisted snapshot have all resolved. Loading and error branches should remain simple boot screens.
  - [x] 5.5 If `rows.meta == null`, the snapshot provider returns `GameState.initialSeed(content)` and `lastSavedAt: null`; boot catch-up must no-op.

- [x] Task 6: Add boot and resume catch-up orchestration (AC: #3, #7, #9, #10)
  - [x] 6.1 Add an `offlineCatchupControllerProvider` in `lib/providers/offline_catchup_providers.dart`. It may be a small provider-layer class that composes `AppDatabase`, `SaveRepository`, `GameWorldNotifier`, `Clock`, and the latest `PersistedGameSnapshot`.
  - [x] 6.2 Implement `Future<OfflineCatchupResult?> applyFromLastSavedAt(DateTime? lastSavedAt)`:
    - return `null` if `lastSavedAt == null`
    - call `gameWorldProvider.notifier.applyOfflineCatchup(lastSavedAt: lastSavedAt)`
    - if `result.emittedEvent`, call `await saveRepository.flush()` so the meta singleton gets the new `lastSavedAt`
    - return the result for tests
  - [x] 6.3 Add a boot gate provider, for example `offlineCatchupBootProvider = FutureProvider<void>(...)`, that waits for `persistedGameSnapshotProvider.future`, runs `applyFromLastSavedAt(snapshot.lastSavedAt)` once, and completes before `_GameScreen` is rendered.
  - [x] 6.4 Extend `GameLifecycleObserver` to accept an optional `Future<void> Function() onResume` callback. On `AppLifecycleState.resumed`, call it with error logging via `Logger('GameLifecycleObserver')`; do not throw from lifecycle callbacks.
  - [x] 6.5 Register the observer only after the providers it needs have resolved. The current `app.dart` reads `saveRepositoryProvider` in `initState`; after this story, avoid reading `saveRepositoryProvider` before the persisted snapshot/database gate is ready.
  - [x] 6.6 On resume, read the latest `meta.lastSavedAt` from `AppDatabase.loadAll()` rather than reusing the boot snapshot timestamp. The resume path must use the most recent flushed pause timestamp.
  - [x] 6.7 Coordinate `GameLoop` so it does not restart its ticker before `onResume` catch-up completes. Acceptable approaches:
    - move resume restart responsibility into a provider-controlled callback that awaits catch-up, then restarts the existing ticker; or
    - keep `GameLoop` as the ticker owner but add a small `resumeGate`/controller it awaits before calling `_ticker.start()`.
    In either approach, keep exactly one ticker in the app.

- [x] Task 7: Persist offline application through SaveRepository (AC: #7, #9)
  - [x] 7.1 Update `lib/data/repositories/save_repository.dart` exhaustive switch with:
    ```dart
    case OfflineEarningsApplied():
      _scheduleMetaSnapshot();
    ```
    This case must schedule even when `totalEarned == Influence.zero`, because `lastSavedAt` must advance.
  - [x] 7.2 Do not write country rows, mission rows, active boost rows, active golden rows, or achievement rows for `OfflineEarningsApplied`; the only persistence change is the meta snapshot.
  - [x] 7.3 Keep the switch exhaustive with no `default` or `case _`.
  - [x] 7.4 Add/extend tests in `test/data/repositories/save_repository_test.dart` proving `OfflineEarningsApplied` schedules a meta write and `flush()` persists `totalInfluence` and a new UTC `lastSavedAt`.

- [x] Task 8: Tests for pure math and GameWorld emission (AC: #3-#8, #11)
  - [x] 8.1 Add `test/game/features/economy/offline_catchup_test.dart` using `package:test/test.dart`, not `flutter_test`.
  - [x] 8.2 Cover no meta/zero elapsed by calling the pure function with `now == lastSavedAt` and with `now < lastSavedAt`; expect original state and `event == null`.
  - [x] 8.3 Cover 8-hour cap by using `lastSavedAt = now - Duration(hours: 12)` and expecting exactly 8 hours of earnings.
  - [x] 8.4 Cover leader-only behavior: no Leader earns zero; tier1/tier2/tier3 leaders earn using existing `IncomeCalculator` rates.
  - [x] 8.5 Cover stable multipliers: active boost and active golden effect present in state must not change offline earnings; achievements, continent completions, and global upgrades must apply.
  - [x] 8.6 Cover zero-earned positive elapsed: elapsed positive, no eligible leaders, event emitted with `Influence.zero`.
  - [x] 8.7 Cover large values around the existing 1e38 precision expectations; do not introduce `double`.
  - [x] 8.8 Add `GameWorld` tests proving `applyOfflineCatchup` mutates before emitting, emits exactly one `OfflineEarningsApplied`, and leaves missions/achievements untouched.

- [x] Task 9: Provider, lifecycle, and ticker-ordering tests (AC: #1, #2, #3, #9, #10)
  - [x] 9.1 Add provider tests for `persistedGameSnapshotProvider`: existing meta row maps to saved state and timestamp; empty meta maps to `initialSeed` with null timestamp.
  - [x] 9.2 Add an app/widget or provider-container test showing boot waits for `offlineCatchupBootProvider` before rendering `_GameScreen`.
  - [x] 9.3 Extend `test/services/game_lifecycle_observer_test.dart`: resumed calls the injected `onResume`; errors are logged/swallowed; paused/inactive/detached/hidden still flush.
  - [x] 9.4 Extend `test/ui/features/map/game_loop_test.dart` or create a focused test proving resume catch-up completes before ticker restart.
  - [x] 9.5 Keep Drift tests on `NativeDatabase.memory()` and close every `AppDatabase` in teardown.

- [x] Task 10: Verification (AC: #12)
  - [x] 10.1 Run `dart format --set-exit-if-changed` on all changed files.
  - [x] 10.2 Run targeted tests:
    - `flutter test test/game/game_event_test.dart`
    - `dart test test/game/features/economy/offline_catchup_test.dart` if pure Dart test discovery works in this Flutter package; otherwise use `flutter test` for the same file.
    - `flutter test test/game/game_world_test.dart`
    - `flutter test test/data/repositories/save_repository_test.dart`
    - `flutter test test/services/game_lifecycle_observer_test.dart`
    - provider/widget tests added in Task 9
  - [x] 10.3 Run `flutter analyze`.
  - [x] 10.4 Run full `flutter test` if time permits, because this story touches boot, providers, lifecycle, and game event exhaustiveness.

## Dev Notes

### Implementation Scope

This story owns offline math, lifecycle/boot ordering, the `OfflineEarningsApplied` event contract, and the persistence meta snapshot hook. It does not own the reward modal UI; Story 6.5 consumes the event. It does not own typed migration refactoring or save recovery; Story 6.3 and 6.6 own those surfaces.

The intended contract is:

```dart
meta.lastSavedAt + Clock.now()
  -> OfflineCatchup.apply(...)
  -> GameWorld mutates totalInfluence
  -> GameWorld emits OfflineEarningsApplied(totalEarned, elapsed)
  -> SaveRepository schedules and flushes meta snapshot
  -> Story 6.5 shows a modal only when totalEarned > Influence.zero
```

### Current Codebase Observations

- `lib/game/features/economy/income_calculator.dart` is the only income stack. It currently applies active golden and active boost in slots 7 and 8, so offline math must call it with a stable copy of state where those transient multipliers are neutralized.
- `lib/game/game_world.dart` currently exposes `tick` and `applyCommand`; there is no `applyEvent` despite older architecture text mentioning one. Add a narrow `applyOfflineCatchup` keyhole rather than a generic arbitrary-event injector.
- `lib/game/game_event.dart` currently has no offline event. Story 6.5's file already gates on `OfflineEarningsApplied(totalEarned, elapsed)`, so this story must provide exactly that surface.
- `lib/data/mappers/game_state_mapper.dart` maps `MetaRow.lastSavedAt` into no `GameState` field. Do not add persistence metadata to `GameState`; carry `lastSavedAt` in a provider-layer snapshot.
- `lib/services/game_lifecycle_observer.dart` currently flushes on non-resumed states and no-ops on resumed. Extend it with an injected callback instead of making the service reach directly into Riverpod.
- `lib/ui/features/map/game_loop.dart` currently restarts immediately on `resumed`. This story must change that ordering so catch-up finishes before ticker restart.

### Offline Math Rules

- Offline earnings are paid directly into `GameState.totalInfluence`, not into per-country `bankedInfluence`.
- Only Leader-automated countries participate. A country with `LeaderTier.none` earns nothing offline even if it would bank timer-gated income during foreground ticks.
- Stable multipliers are: IP, Leader, continent completion, achievements, and active global upgrades.
- Transient multipliers are excluded: active boost, golden opportunity multiplier, and active golden effect. No partial credit is given if they were active for part of the offline window.
- Use `Decimal.fromInt(elapsed.inSeconds)` and `Influence` value objects. Do not use `double` or `num` for game math.
- Do not trigger missions, achievements, continent unlocks, daily rewards, boost expiry, or golden expiry from offline catch-up. The existing tick path handles expiries after resume.

### Architecture Compliance

- No Flutter imports under `lib/game/**`.
- No Drift imports under `lib/game/**`.
- No UI code touches Drift directly; boot/resume orchestration lives in providers and services.
- No raw SQL for this story. If Story 6.3 already uses `customSelect('SELECT 1')` for database bootstrap, leave that existing force-open path alone; do not add new custom SQL here.
- Keep `SaveRepository._handleEvent` exhaustive. Adding `OfflineEarningsApplied` should create a compiler/analyzer failure until the repository switch is updated.
- Do not add packages. Use existing Flutter lifecycle APIs, Riverpod providers, Drift typed APIs, Decimal, and project value objects.
- Do not create another ticker. `GameLoop` remains the ticker owner.

### Library / Framework Requirements

- `flutter_riverpod: ^2.6.1` / `riverpod: ^2.6.1`: use provider gates and `ref.onDispose`; no generator.
- `drift: ^2.26.1`: use `AppDatabase.loadAll()` and typed Drift tests with `NativeDatabase.memory()`.
- `decimal: ^3.0.2`: all offline math stays in `Decimal` via `Influence`.
- Flutter lifecycle: `AppLifecycleState.hidden` is part of the modern lifecycle enum; keep the existing hidden-as-paused flush behavior.
- `WidgetsBindingObserver` must be detached when the owner disposes.

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/game/config/constants.dart` | `GameConstants.maxOfflineHours = 8` if still missing |
| `lib/game/features/economy/offline_catchup.dart` | Pure offline elapsed clamp, stable-rate math, result object |
| `lib/providers/offline_catchup_providers.dart` | Persisted snapshot provider, boot catch-up gate, resume catch-up controller |
| `test/game/features/economy/offline_catchup_test.dart` | Pure math coverage |
| Provider/lifecycle tests as needed under `test/providers/`, `test/services/`, and `test/ui/features/map/` | Boot/resume ordering |

**Modify:**

| File | Change |
|---|---|
| `lib/game/game_event.dart` | Add `OfflineEarningsApplied` |
| `lib/game/game_world.dart` | Add narrow `applyOfflineCatchup` method |
| `lib/providers/game_providers.dart` | Initialize `GameWorld` from persisted snapshot and expose notifier method |
| `lib/providers/data_providers.dart` | Reuse existing DB/mapper/save providers; adapt only if necessary for snapshot loading |
| `lib/services/game_lifecycle_observer.dart` | Add injected resumed callback |
| `lib/ui/features/map/game_loop.dart` | Ensure ticker restart waits until catch-up completes |
| `lib/app.dart` | Gate normal game surface on persisted snapshot and boot catch-up; register lifecycle observer after gate |
| `lib/data/repositories/save_repository.dart` | Add `OfflineEarningsApplied` switch case |
| Existing tests | Extend event, repository, lifecycle, and game-world coverage |

**Do NOT modify:**

- `lib/ui/features/modals/**` or modal queue code. Story 6.5 owns UI.
- `lib/data/database/tables/**` or schema version. No new table/column is required.
- `lib/data/database/migrations/**` unless Story 6.3 has already created it and a compile fix is required. This story has no schema change.
- `assets/**`, `pubspec.yaml`, `build.yaml`, or `analysis_options.yaml`.

### Previous Story Intelligence

- **Story 6.1 (done):** v3 schema persists `totalInfluence`, `totalIntel`, active boost, missions, daily streak, achievements, goldens, continents, and countries. It deliberately keeps `meta.lastSavedAt` in `MetaRow`, not `GameState`.
- **Story 6.2 (review in sprint status, code present):** `SaveRepository` already has an exhaustive event switch. Add an offline case; do not replace the event-driven write strategy with a full-state dump.
- **Story 6.3 (ready-for-dev):** may add database bootstrap and save recovery. If present, preserve its boot error gate and use its opened `AppDatabase`.
- **Story 6.5 (ready-for-dev):** depends on this story's event. Its modal must not recompute earnings, mutate Influence, or dispatch a command on Collect.
- **Story 5.2:** boost expiry is evaluated before foreground country ticking. This is important after offline resume: expired boosts get cleared before the next foreground income tick and never affect offline math.
- **Story 5.1:** golden effect expiry is separate from offline math. Offline excludes the multiplier but does not clear the effect; the scheduler/reducer handles expiry after resume.

### Latest Technical Notes

- Flutter's `AppLifecycleState` docs include `resumed`, `inactive`, `hidden`, `paused`, and `detached`, and state changes can be observed via `WidgetsBindingObserver.didChangeAppLifecycleState`. Keep the existing hidden/detached handling rather than assuming only paused/resumed exist.
- Flutter's `WidgetsBindingObserver` docs call out unregistering observers to avoid leaks; keep `attach()`/`detach()` symmetrical.
- Riverpod's `Ref` docs support `watch`, `listen`, and lifecycle hooks such as `onDispose`; use providers for boot/resume orchestration instead of passing globals.
- Drift migration docs reaffirm that schema changes require migrations, but this story has no schema change; do not bump `schemaVersion`.

### Testing Requirements

- Pure `lib/game/` tests use `package:test/test.dart` unless the package test runner forces `flutter test`; no Flutter bindings in game tests.
- Provider/widget tests use `flutter_test` and `ProviderScope(overrides: [...])`. Do not mount real Drift unless the test is explicitly a data/provider integration test.
- Drift tests use `NativeDatabase.memory()` and close DBs in teardown.
- Use `FakeClock` from `test/helpers/fake_clock.dart`. Do not call `DateTime.now()` in tests for deterministic assertions.
- Prefer existing `test/helpers/test_content_registry.dart` and `GameStateBuilder` fixtures where they fit. Add a small local fixture only if the existing helper cannot express a stable multiplier case clearly.

## References

- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.4: Offline Earnings Calculation on Resume] - original story and ACs.
- [Source: _bmad-output/planning-artifacts/gdd.md#Offline Progression] - automated countries earn offline, resume calculation, 8-hour cap, modal on return.
- [Source: _bmad-output/game-architecture/architectural-decisions.md#6. Offline Earnings] - lifecycle trigger, stable multipliers, single offline event.
- [Source: _bmad-output/project-context.md#Game loop] - paused/inactive flush and resumed catch-up before ticker restart.
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules] - boosts/goldens excluded offline, one ticker, no per-tick saves.
- [Source: _bmad-output/implementation-artifacts/6-1-drift-schema-and-gamestatemapper.md] - v3 schema, mapper, `MetaRow.lastSavedAt` source.
- [Source: _bmad-output/implementation-artifacts/6-2-persistence-write-strategy-event-driven-and-debounced-snapshot.md] - SaveRepository event switch and lifecycle flush prerequisite.
- [Source: _bmad-output/implementation-artifacts/6-5-offline-reward-modal-on-resume.md] - downstream modal contract and dependency gate.
- [Source: lib/game/features/economy/income_calculator.dart] - authoritative multiplier stack.
- [Source: lib/game/game_world.dart] - current event stream, tick, and command application patterns.
- [Source: lib/game/game_event.dart] - sealed event hierarchy to extend.
- [Source: lib/data/repositories/save_repository.dart] - exhaustive persistence switch to update.
- [Source: lib/data/mappers/game_state_mapper.dart] - persisted state mapping and `MetaRow` separation.
- [Source: lib/services/game_lifecycle_observer.dart] - lifecycle service to extend.
- [Source: lib/ui/features/map/game_loop.dart] - current ticker lifecycle behavior to reorder.
- [Source: https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html] - current Flutter lifecycle states.
- [Source: https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html] - observer lifecycle and app lifecycle callback.
- [Source: https://riverpod.dev/docs/concepts2/refs] - provider refs, listening, and `onDispose`.
- [Source: https://drift.simonbinder.eu/Migrations/] - Drift migration discipline; confirms no schema bump belongs here.
- [Source: https://drift.simonbinder.eu/migrations/api/] - Drift migrator API; not directly changed by this story.

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Implemented `GameConstants.maxOfflineHours`, `OfflineEarningsApplied` event, pure `OfflineCatchup.apply` with stable `IncomeCalculator` path, `GameWorld.applyOfflineCatchup` + notifier, `PersistedGameSnapshot` + `persistedGameSnapshotProvider` (in `game_providers.dart`), `database_providers.dart` split to break import cycles, `offline_catchup_providers` (controller, boot gate, `resumeOfflineCatchupProvider`), `SaveRepository` meta case, `GlobalDominationApp` gates for snapshot + boot catch-up, `GameLoop` awaits resume catch-up before `Ticker.start`, optional `GameLifecycleObserver.onResume` (tests + error swallowing). Map UI tests use `mapWidgetTestGameWorldOverride` to avoid async content/DB. `flutter test` 777 passed, `dart analyze` clean (2026-04-27).

### File List

- lib/app.dart
- lib/data/repositories/save_repository.dart
- lib/game/config/constants.dart
- lib/game/features/economy/offline_catchup.dart
- lib/game/game_event.dart
- lib/game/game_world.dart
- lib/providers/data_providers.dart
- lib/providers/database_providers.dart
- lib/providers/game_providers.dart
- lib/providers/offline_catchup_providers.dart
- lib/services/game_lifecycle_observer.dart
- lib/ui/features/map/game_loop.dart
- test/data/repositories/save_repository_test.dart
- test/game/features/economy/offline_catchup_test.dart
- test/game/game_event_test.dart
- test/game/game_world_test.dart
- test/helpers/map_screen_test_providers.dart
- test/providers/offline_catchup_boot_provider_test.dart
- test/providers/persisted_snapshot_provider_test.dart
- test/services/game_lifecycle_observer_test.dart
- test/ui/features/map/game_loop_test.dart
- test/ui/features/map/map_screen_gesture_test.dart
- test/ui/features/map/world_map_painter_test.dart
- _bmad-output/implementation-artifacts/6-4-offline-earnings-calculation-on-resume.md
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-04-27: Story 6.4 — offline catch-up (8h cap, stable multipliers), `OfflineEarningsApplied` + meta snapshot, boot + resume ordering, tests and map widget test harness
