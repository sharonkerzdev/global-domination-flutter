# Story 6.2: Persistence Write Strategy — Event-Driven Writes and Debounced Snapshot

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a `SaveRepository` that subscribes to `gameWorld.events`, performs targeted typed Drift row updates per discrete event, debounces a 2-second `meta` snapshot for currency totals, and flushes pending writes on `AppLifecycleState.paused`,
So that progress persists with minimal DB churn (no per-tick writes), saves coalesce when state changes rapidly, and the player never loses meaningful state on backgrounding.

## Acceptance Criteria

1. **Given** the `GameWorld.events` stream and a `SaveRepository` constructed with `(AppDatabase db, GameStateMapper mapper, Stream<GameEvent> events, GameState Function() readState, Clock clock)`
   **When** the repository is constructed
   **Then** it `listen()`s to the events stream once and stores the subscription internally; it does NOT await first-event before returning; multiple constructions share no global state (each instance owns its own subscription + debounce timer); `dispose()` cancels the subscription, cancels the pending timer, and flushes any pending meta write synchronously (`await`-able).

2. **Given** the discrete `GameEvent` variants currently defined under `lib/game/game_event.dart` (Tick, CountryTapped, UpgradePurchased, LeaderHired, LeaderUpgraded, ContinentUnlocked, CountryUnlocked, MilestoneReached, ContinentCompleted, GoldenSpawned, GoldenClaimed, GoldenExpired)
   **When** each fires
   **Then** the repository routes it through an **exhaustive `switch (event)`** (no `default` / no `case _`) producing exactly the row-write contract below. Adding a new `GameEvent` variant in a future story (e.g. Story 5-2's `BoostActivated`) MUST cause `flutter analyze` to fail at the switch site — that compile-time error IS the contract; downstream stories own their own write handlers.

   | Event | Write |
   |---|---|
   | `Tick` | **No write.** No-op case. |
   | `CountryTapped` | **No write.** Banked-influence reset is captured by the debounced meta snapshot; per-country `bankedInfluence` between collects is intentionally volatile per Epic 6 scope (see Dev Notes "Banked-influence volatility"). |
   | `CountryUnlocked` | `update(countries).where(id = event.countryId.value).write(CountriesCompanion(unlocked: Value(true), ipLevel: Value(state.countries[id].ipLevel), bankedInfluence: Value(state.countries[id].bankedInfluence.value), lastCollectedAt: Value(state.countries[id].lastCollectedAt)))` AND `_scheduleMetaSnapshot()` (because `state.totalInfluence` decreased by `event.cost`). |
   | `UpgradePurchased` | `update(countries).where(id = event.countryId.value).write(CountriesCompanion(ipLevel: Value(state.countries[id].ipLevel)))` AND `_scheduleMetaSnapshot()`. |
   | `LeaderHired` / `LeaderUpgraded` | `update(countries).where(id = event.countryId.value).write(CountriesCompanion(leaderTier: Value(event.newTier.name)))` AND `_scheduleMetaSnapshot()`. |
   | `ContinentUnlocked` | `into(continents).insertOnConflictUpdate(ContinentsCompanion.insert(id: event.continentId.value, unlocked: true, completed: false))`. |
   | `MilestoneReached` | `into(continentMilestones).insertOnConflictUpdate(ContinentMilestonesCompanion.insert(continentId: event.continentId.value, milestone: event.percent))` AND `_scheduleMetaSnapshot()` (rewards may have changed `totalInfluence` or `goldenOpportunityMultiplier`/`boostMultiplier`). |
   | `ContinentCompleted` | `into(continents).insertOnConflictUpdate(ContinentsCompanion.insert(id: event.continentId.value, unlocked: true, completed: true))`. |
   | `GoldenSpawned` | `into(activeGoldens).insert(ActiveGoldensCompanion.insert(id: event.goldenId, countryId: event.countryId.value, multiplier: event.multiplier, expiresAt: event.expiresAt))`. |
   | `GoldenClaimed` | `into(activeGoldenEffect).insertOnConflictUpdate(ActiveGoldenEffectCompanion.insert(singletonId: const Value(0), goldenId: event.goldenId, multiplier: event.multiplier, expiresAt: state.activeGoldenEffect!.expiresAt))` AND `delete(activeGoldens).where(id = event.goldenId).go()` AND `_scheduleMetaSnapshot()` (because `state.goldenOpportunityMultiplier` changed). |
   | `GoldenExpired` | If `state.activeGoldenEffect == null` (effect-expiry) → `delete(activeGoldenEffect).go()` AND `_scheduleMetaSnapshot()` (multiplier reverted to 1). Otherwise (map-expiry pre-claim) → `delete(activeGoldens).where(id = event.goldenId).go()` (no meta snapshot — the multiplier didn't change since the golden was never claimed). Disambiguation via `state.activeGoldens.containsKey(event.goldenId)` at handler-time: if the golden is still in `state.activeGoldens` post-event, the reducer kept it (impossible — expiry removes); the correct disambiguation is `event.claimed`: `event.claimed == false` AND golden was unclaimed → map-expiry; `event.claimed == true` → effect-expiry. **Reuse `GoldenExpired.claimed`** (already on the event per `lib/game/game_event.dart` line 322).

3. **Given** the discrete event handlers above
   **When** any of them fires
   **Then** the row write executes via **typed Drift DSL only** (`update(table).where(...).write(Companion(...))`, `into(table).insertOnConflictUpdate(...)`, `delete(table).where(...).go()`); **NO raw SQL strings**; NO `customStatement(...)`; NO full-state dump (no `mapper.toCompanions` followed by full table truncate-then-insert).

4. **Given** any event handler that calls `_scheduleMetaSnapshot()`
   **When** invoked
   **Then** it (a) cancels any pending `Timer`, (b) starts a new `Timer` of `_debounceDuration` (default `Duration(seconds: 2)`, settable in tests via constructor parameter `debounceDuration`), (c) the timer's callback runs `_writeMetaSnapshot()`. **No `await`** in the scheduling path — schedule is synchronous; the actual write is async but not awaited from event handlers (fire-and-forget, errors logged).

5. **Given** `_writeMetaSnapshot()` runs
   **When** invoked (either from the debounce timer or `flush()`)
   **Then** it executes a single `update(meta).write(MetaCompanion(totalInfluence: Value(state.totalInfluence.value), goldenOpportunityMultiplier: Value(state.goldenOpportunityMultiplier), boostMultiplier: Value(state.boostMultiplier), lastSavedAt: Value(clock.now().toUtc())))`. The update has no `where` clause because the singleton `CHECK(singletonId = 0)` constraint guarantees ≤ 1 row. **First-launch case (no `meta` row yet)**: if `update(...).write(...)` returns 0 affected rows, fall back to `into(meta).insertOnConflictUpdate(MetaCompanion.insert(schemaVersion: 3, lastSavedAt: clock.now().toUtc(), totalInfluence: state.totalInfluence.value, goldenOpportunityMultiplier: state.goldenOpportunityMultiplier, boostMultiplier: state.boostMultiplier))` — emits the singleton row Story 6-1's `onCreate` deliberately leaves empty (per 6-1 Task 3.4). Subsequent calls hit the update-returning-1 branch and never re-insert.

6. **Given** rapid event bursts that each call `_scheduleMetaSnapshot()` within a 2-second window
   **When** the burst concludes (no further events for 2 seconds)
   **Then** **exactly one** `_writeMetaSnapshot()` call executes — verified by a counter test using `FakeAsync` from `package:fake_async/fake_async.dart` (already a transitive dep via `flutter_test`) OR by injecting a counting `AppDatabase` test double. Burst of 50 `CountryTapped` events → 0 meta writes (CountryTapped doesn't schedule). Burst of 50 `UpgradePurchased` events → 1 meta write at 2s after the last.

7. **Given** the app transitions to `AppLifecycleState.paused` (or `inactive`, or `detached`)
   **When** the lifecycle observer fires `didChangeAppLifecycleState`
   **Then** the observer calls `await saveRepository.flush()` and AWAITS completion. `flush()` MUST: (a) cancel any pending debounce timer; (b) if there was a pending snapshot OR if the timer was active when cancelled, run `_writeMetaSnapshot()` synchronously (`await`); (c) return a `Future<void>` that resolves only after the meta write completes. If no debounce was pending, `flush()` returns a completed `Future` immediately (no spurious write). **Never throws** — DB errors are logged via `Logger('SaveRepository')` and swallowed (a corrupt DB in `flush()` cannot block the lifecycle hook from returning in time for the OS to background-suspend the app).

8. **Given** a new `GameLifecycleObserver` `WidgetsBindingObserver` subclass added under `lib/services/`
   **When** instantiated and `WidgetsBinding.instance.addObserver(observer)` is called from the app shell (NOT from `main.dart` — boot-time setup is reserved for global error handlers per project-context.md line 264)
   **Then** the observer's `didChangeAppLifecycleState(state)` calls `await saveRepository.flush()` for `paused`, `inactive`, OR `detached` (any non-`resumed` state); for `resumed`, it is a no-op in this story (Story 6-4 owns `OfflineCatchup.apply()` on resume); for `hidden` (Flutter 3.13+), it calls `flush()` (treat as paused). The observer accepts a `SaveRepository` via constructor (no global lookup); `dispose()` removes itself from `WidgetsBinding`.

9. **Given** the architectural boundary `lib/data/ → lib/game/` (one-way) established by Story 6-1's `data_boundary_test.dart`
   **When** `lib/data/repositories/save_repository.dart` is examined
   **Then** the file imports BOTH `lib/data/database/...` AND `lib/game/...` (it is a bridge file). The architecture test in 6-1 asserts the **mapper** is the ONLY dual-import file; the test must be **extended** in this story to add `save_repository.dart` to a small **allowlist** of dual-import files (mapper + save_repository). **No other file added in 6-2** may be in this allowlist. (`game_lifecycle_observer.dart` lives in `lib/services/` — orthogonal to the data-boundary test which scopes only to `lib/data/`.)

10. **Given** the providers under `lib/providers/`
    **When** new providers are wired
    **Then** `data_providers.dart` adds `gameStateMapperProvider = Provider<GameStateMapper>((_) => const GameStateMapper())` AND `saveRepositoryProvider = Provider.autoDispose<SaveRepository>((ref) { ... })` that constructs the repository with `appDatabaseProvider`, `gameStateMapperProvider`, the `GameWorld.events` stream from `gameWorldProvider.notifier`, a `() => ref.read(gameWorldProvider)` state-reader closure, and `clockProvider`; `ref.onDispose(() => repo.dispose())` is wired. **`game_providers.dart`** exposes `gameWorldEventsProvider = Provider<Stream<GameEvent>>((ref) => ref.watch(gameWorldProvider.notifier).events)` so `saveRepositoryProvider` does not reach into `Notifier.world` privates (add a public `Stream<GameEvent> get events => _world.events;` on `GameWorldNotifier`).

11. **Given** the Riverpod composition root
    **When** `saveRepositoryProvider` is read
    **Then** the side effect of construction (`listen()`) starts persistence. The provider MUST be **eagerly read** at app startup (in `app.dart` or wherever the `GameLifecycleObserver` is registered — see Task 4); a `Provider.autoDispose` that nobody watches will leak nothing-no-side-effect. To make the lifecycle clean: use a `keepAlive` `Provider` (NOT `autoDispose`) so the repository lives for the app's lifetime and Riverpod's automatic teardown calls `dispose()` only when the `ProviderContainer` itself is disposed. **Final decision: `Provider<SaveRepository>` (no `autoDispose`)** with `ref.onDispose(repo.dispose)`.

12. **Given** all unit + widget tests authored for this story
    **When** `flutter test test/data/repositories/save_repository_test.dart test/services/game_lifecycle_observer_test.dart test/architecture/data_boundary_test.dart` runs
    **Then** every test uses `NativeDatabase.memory()` (NEVER touches the real filesystem), every `AppDatabase` instance is `await db.close()`'d in `tearDown`, every `SaveRepository` is `await repo.dispose()`'d in `tearDown`, and new tests cover at minimum: each event variant produces the expected typed write (12 cases — one per variant including the two no-op cases); 2s debounce coalesces a burst of meta-changing events into 1 write (1 test using `fake_async`); `flush()` writes immediately and awaits completion (1 test); `flush()` is a no-op when no debounce pending (1 test); first-launch insert-then-update meta path (1 test); lifecycle observer routes paused/inactive/detached/hidden → `flush()` and `resumed` → no-op (4 cases in 1 test using a fake `SaveRepository`); architecture test allowlist accepts `save_repository.dart` (1 test).

## Tasks / Subtasks

- [ ] Task 1: Add `events` getter on `GameWorldNotifier` (AC: #10)
  - [ ] 1.1 Open `lib/providers/game_providers.dart`. Add a public `Stream<GameEvent> get events => _world.events;` getter on `GameWorldNotifier` (after the `apply`/`tick` methods). This is the single keyhole through which `SaveRepository` reaches into the GameWorld's event stream — keeps the `_world` field private.
  - [ ] 1.2 Add `final gameWorldEventsProvider = Provider<Stream<GameEvent>>((ref) => ref.watch(gameWorldProvider.notifier).events);` after the existing `gameWorldProvider` definition.

- [ ] Task 2: Implement `SaveRepository` (AC: #1, #2, #3, #4, #5, #6, #7, #9)
  - [ ] 2.1 Create `lib/data/repositories/save_repository.dart`. Imports: `'dart:async'`, `package:drift/drift.dart`, `package:logging/logging.dart`, `'../database/app_database.dart'`, `'../mappers/game_state_mapper.dart'`, `'package:global_domination/game/game_event.dart'`, `'package:global_domination/game/game_state.dart'`, `'package:global_domination/game/support/clock.dart'`. **NO `package:flutter/...` imports** (this file lives in `lib/data/`; lifecycle bridging happens in `lib/services/` per Task 4).
  - [ ] 2.2 Class shape:
    ```dart
    class SaveRepository {
      SaveRepository({
        required AppDatabase db,
        required GameStateMapper mapper,
        required Stream<GameEvent> events,
        required GameState Function() readState,
        required Clock clock,
        Duration debounceDuration = const Duration(seconds: 2),
      }) : _db = db,
           _mapper = mapper,
           _readState = readState,
           _clock = clock,
           _debounceDuration = debounceDuration {
        _subscription = events.listen(_handleEvent, onError: _handleError);
      }

      static final _log = Logger('SaveRepository');
      final AppDatabase _db;
      final GameStateMapper _mapper; // reserved for future full-state writes (offline catch-up; Story 6-4)
      final GameState Function() _readState;
      final Clock _clock;
      final Duration _debounceDuration;
      late final StreamSubscription<GameEvent> _subscription;
      Timer? _metaTimer;
      bool _metaPending = false;
      bool _metaSeeded = false; // tracks whether we've ever inserted the singleton meta row

      Future<void> dispose() async { ... }
      Future<void> flush() async { ... }
      void _scheduleMetaSnapshot() { ... }
      Future<void> _writeMetaSnapshot() async { ... }
      void _handleEvent(GameEvent e) { ... } // exhaustive switch
      void _handleError(Object e, StackTrace s) { _log.warning('event stream error', e, s); }
    }
    ```
    `_mapper` is intentionally retained even though 6-2 doesn't use `toCompanions` directly — Story 6-4's `OfflineCatchup` reuses this repository for its post-resume re-write, and forcing the mapper through the same boundary keeps the Riverpod wiring stable across stories.
  - [ ] 2.3 Implement `_handleEvent` as a single **exhaustive `switch`** over every variant in `lib/game/game_event.dart`:
    ```dart
    void _handleEvent(GameEvent e) {
      switch (e) {
        case Tick():
          break; // intentional no-op
        case CountryTapped():
          break; // banked transfer captured by debounced meta snapshot
        case CountryUnlocked(:final countryId):
          unawaited(_writeCountryRow(countryId.value));
          _scheduleMetaSnapshot();
        case UpgradePurchased(:final countryId):
          unawaited(_writeCountryIpLevel(countryId.value));
          _scheduleMetaSnapshot();
        case LeaderHired(:final countryId, :final newTier):
          unawaited(_writeCountryLeaderTier(countryId.value, newTier.name));
          _scheduleMetaSnapshot();
        case LeaderUpgraded(:final countryId, :final newTier):
          unawaited(_writeCountryLeaderTier(countryId.value, newTier.name));
          _scheduleMetaSnapshot();
        case ContinentUnlocked(:final continentId):
          unawaited(_upsertContinent(continentId.value, unlocked: true, completed: false));
        case MilestoneReached(:final continentId, :final percent):
          unawaited(_upsertMilestone(continentId.value, percent));
          _scheduleMetaSnapshot();
        case ContinentCompleted(:final continentId):
          unawaited(_upsertContinent(continentId.value, unlocked: true, completed: true));
        case GoldenSpawned(:final goldenId, :final countryId, :final multiplier, :final expiresAt):
          unawaited(_insertActiveGolden(goldenId, countryId.value, multiplier, expiresAt));
        case GoldenClaimed(:final goldenId):
          unawaited(_writeGoldenClaim(goldenId));
          _scheduleMetaSnapshot();
        case GoldenExpired(:final goldenId, :final claimed):
          if (claimed) {
            unawaited(_clearGoldenEffect());
            _scheduleMetaSnapshot();
          } else {
            unawaited(_deleteActiveGolden(goldenId));
          }
      }
    }
    ```
    Each `_writeXxx` private helper uses **only typed Drift DSL**. **No raw SQL.** Errors from each `unawaited` future are caught and logged via `_log.warning('write failed', e, s)` (wrap each helper in `try/catch` OR use `.catchError` on the future). `_writeXxx` helpers must be unit-testable in isolation (they accept primitives, not events).
  - [ ] 2.4 `_scheduleMetaSnapshot()`:
    ```dart
    void _scheduleMetaSnapshot() {
      _metaPending = true;
      _metaTimer?.cancel();
      _metaTimer = Timer(_debounceDuration, () {
        _metaTimer = null;
        unawaited(_writeMetaSnapshot());
      });
    }
    ```
    Synchronous; the timer cancels any pending fire and replaces it.
  - [ ] 2.5 `_writeMetaSnapshot()`:
    ```dart
    Future<void> _writeMetaSnapshot() async {
      if (!_metaPending) return;
      _metaPending = false;
      final state = _readState();
      final savedAt = _clock.now().toUtc();
      try {
        if (!_metaSeeded) {
          await _db.into(_db.meta).insertOnConflictUpdate(
            MetaCompanion.insert(
              schemaVersion: 3,
              lastSavedAt: savedAt,
              totalInfluence: state.totalInfluence.value,
              goldenOpportunityMultiplier: state.goldenOpportunityMultiplier,
              boostMultiplier: state.boostMultiplier,
            ),
          );
          _metaSeeded = true;
        } else {
          await _db.update(_db.meta).write(
            MetaCompanion(
              lastSavedAt: Value(savedAt),
              totalInfluence: Value(state.totalInfluence.value),
              goldenOpportunityMultiplier: Value(state.goldenOpportunityMultiplier),
              boostMultiplier: Value(state.boostMultiplier),
            ),
          );
        }
      } catch (e, s) {
        _log.warning('meta snapshot write failed', e, s);
      }
    }
    ```
    **Why `_metaSeeded` flag instead of `update`-returns-zero detection**: the `update(...).write(...)` Drift API returns the affected-row count, but threading that through the upsert fallback is awkward. A boolean instance flag is simpler and equally correct — a `SaveRepository` only needs to insert-once-per-instance because Story 6-1's `onCreate` leaves the singleton row unset, but once any production code path has written the row, every subsequent write is an UPDATE. **Edge case**: a fresh app reuses the repository across resumes — `_metaSeeded` correctly stays `true` for the lifetime of the instance. On restart with an existing meta row, the first call's UPDATE writes 1 row; we don't bother to set `_metaSeeded` proactively but the upsert fallback would degenerate to UPDATE-then-no-op for an existing row anyway. **Decision**: keep the boolean simple; tests will cover both first-launch and subsequent-launch paths (Task 5.6).
  - [ ] 2.6 `flush()`:
    ```dart
    Future<void> flush() async {
      _metaTimer?.cancel();
      _metaTimer = null;
      if (!_metaPending) return;
      await _writeMetaSnapshot();
    }
    ```
    No-op when nothing pending. Awaitable. Never throws (errors swallowed by `_writeMetaSnapshot`'s try/catch).
  - [ ] 2.7 `dispose()`:
    ```dart
    Future<void> dispose() async {
      await _subscription.cancel();
      await flush();
    }
    ```
  - [ ] 2.8 Per-event helpers (concrete bodies):
    ```dart
    Future<void> _writeCountryRow(String id) async {
      final state = _readState();
      final c = state.countries[CountryId(id)];
      if (c == null) return; // defensive; impossible per reducer guards
      try {
        await (_db.update(_db.countries)..where((t) => t.id.equals(id))).write(
          CountriesCompanion(
            unlocked: Value(c.unlocked),
            ipLevel: Value(c.ipLevel),
            leaderTier: Value(c.leaderTier.name),
            bankedInfluence: Value(c.bankedInfluence.value),
            lastCollectedAt: Value(c.lastCollectedAt),
          ),
        );
      } catch (e, s) {
        _log.warning('countries row write failed for $id', e, s);
      }
    }

    Future<void> _writeCountryIpLevel(String id) async { /* same shape, only ipLevel */ }
    Future<void> _writeCountryLeaderTier(String id, String tierName) async { /* only leaderTier */ }

    Future<void> _upsertContinent(String id, {required bool unlocked, required bool completed}) async {
      try {
        await _db.into(_db.continents).insertOnConflictUpdate(
          ContinentsCompanion.insert(id: id, unlocked: unlocked, completed: completed),
        );
      } catch (e, s) { _log.warning('continents upsert failed for $id', e, s); }
    }

    Future<void> _upsertMilestone(String continentId, int percent) async {
      try {
        await _db.into(_db.continentMilestones).insertOnConflictUpdate(
          ContinentMilestonesCompanion.insert(continentId: continentId, milestone: percent),
        );
      } catch (e, s) { _log.warning('milestone upsert failed for $continentId/$percent', e, s); }
    }

    Future<void> _insertActiveGolden(String id, String countryId, int multiplier, DateTime expiresAt) async {
      try {
        await _db.into(_db.activeGoldens).insertOnConflictUpdate(
          ActiveGoldensCompanion.insert(id: id, countryId: countryId, multiplier: multiplier, expiresAt: expiresAt),
        );
      } catch (e, s) { _log.warning('active golden insert failed for $id', e, s); }
    }

    Future<void> _writeGoldenClaim(String goldenId) async {
      final effect = _readState().activeGoldenEffect;
      if (effect == null) return; // defensive; reducer always sets it on claim
      try {
        await _db.transaction(() async {
          await _db.into(_db.activeGoldenEffect).insertOnConflictUpdate(
            ActiveGoldenEffectCompanion.insert(
              singletonId: const Value(0),
              goldenId: effect.goldenId,
              multiplier: effect.multiplier,
              expiresAt: effect.expiresAt,
            ),
          );
          await (_db.delete(_db.activeGoldens)..where((t) => t.id.equals(goldenId))).go();
        });
      } catch (e, s) { _log.warning('golden claim write failed for $goldenId', e, s); }
    }

    Future<void> _deleteActiveGolden(String id) async { /* delete activeGoldens */ }
    Future<void> _clearGoldenEffect() async { /* delete activeGoldenEffect */ }
    ```
  - [ ] 2.9 **No FK-cascade reliance.** When a `ContinentCompleted` event flips a row that has child `continent_milestones`, the milestone rows stay intact (correct — completion doesn't invalidate milestones). When `delete` is called on a `continents` row in any future story, the cascade in Story 6-1's schema (`onDelete: KeyAction.cascade`) handles it; this story does not delete continents.
  - [ ] 2.10 **`unawaited` discipline**: every fire-and-forget call uses `dart:async`'s `unawaited(...)` wrapper to satisfy the `unawaited_futures` lint (project-context.md line 348). Imports add `import 'dart:async';` and the helper at the top of the file. Each helper itself returns `Future<void>` and contains its own `try/catch` so `unawaited` never propagates an error.

- [ ] Task 3: Wire providers (AC: #10, #11)
  - [ ] 3.1 Open `lib/providers/data_providers.dart`. Add:
    ```dart
    final gameStateMapperProvider = Provider<GameStateMapper>((_) => const GameStateMapper());

    final saveRepositoryProvider = Provider<SaveRepository>((ref) {
      final repo = SaveRepository(
        db: ref.watch(appDatabaseProvider),
        mapper: ref.watch(gameStateMapperProvider),
        events: ref.watch(gameWorldEventsProvider),
        readState: () => ref.read(gameWorldProvider),
        clock: ref.watch(clockProvider),
      );
      ref.onDispose(() => repo.dispose());
      return repo;
    });
    ```
    Add the imports for `GameStateMapper`, `SaveRepository`, `gameWorldProvider`, `gameWorldEventsProvider`, `clockProvider`. **Do NOT use `autoDispose`** (per AC #11 reasoning).
  - [ ] 3.2 Open `lib/providers/game_providers.dart` (already modified in Task 1) and confirm `gameWorldEventsProvider` is exported.
  - [ ] 3.3 No changes to `lib/main.dart` (boot-time setup is reserved for global error handlers per project rules; lifecycle observer registration lives in `app.dart` per Task 4).

- [ ] Task 4: `GameLifecycleObserver` and registration (AC: #7, #8)
  - [ ] 4.1 Create `lib/services/game_lifecycle_observer.dart`:
    ```dart
    import 'dart:async';
    import 'package:flutter/widgets.dart';
    import 'package:logging/logging.dart';
    import 'package:global_domination/data/repositories/save_repository.dart';

    class GameLifecycleObserver with WidgetsBindingObserver {
      GameLifecycleObserver(this._save);

      static final _log = Logger('GameLifecycleObserver');
      final SaveRepository _save;

      void attach() {
        WidgetsBinding.instance.addObserver(this);
      }

      void detach() {
        WidgetsBinding.instance.removeObserver(this);
      }

      @override
      void didChangeAppLifecycleState(AppLifecycleState state) {
        switch (state) {
          case AppLifecycleState.paused:
          case AppLifecycleState.inactive:
          case AppLifecycleState.detached:
          case AppLifecycleState.hidden:
            unawaited(_flushAndLog());
          case AppLifecycleState.resumed:
            // Story 6-4 owns OfflineCatchup.apply() on resume.
            break;
        }
      }

      Future<void> _flushAndLog() async {
        try {
          await _save.flush();
        } catch (e, s) {
          _log.warning('lifecycle flush failed', e, s);
        }
      }
    }
    ```
    `WidgetsBindingObserver` ships from `package:flutter/widgets.dart` — services layer is allowed to import Flutter (per project-context.md line 200 — services subscribe to events; lifecycle hooks are the only reason this layer exists).
  - [ ] 4.2 Wire registration in `lib/app.dart` (NOT `main.dart`). Convert the root widget to a `ConsumerStatefulWidget` (if not already) and:
    ```dart
    @override
    void initState() {
      super.initState();
      _observer = GameLifecycleObserver(ref.read(saveRepositoryProvider));
      _observer.attach();
    }

    @override
    void dispose() {
      _observer.detach();
      super.dispose();
    }
    ```
    The `ref.read(saveRepositoryProvider)` call is what eagerly instantiates the repository (forcing the events-stream subscription to start).
  - [ ] 4.3 If `lib/app.dart` is currently a stateless `ConsumerWidget`, convert minimally to `ConsumerStatefulWidget`. Preserve every other property (theme, home, etc.) byte-identical. **No new functional changes** beyond observer wiring.
  - [ ] 4.4 **Do NOT register the observer in `main.dart`.** Per project-context.md line 264, only boot-time global setup (error handlers, logger, Riverpod scope) lives there.

- [ ] Task 5: Tests for `SaveRepository` (AC: #2, #3, #4, #5, #6, #7, #12)
  - [ ] 5.1 Create `test/data/repositories/save_repository_test.dart`. Use `package:flutter_test/flutter_test.dart` (Drift in-memory requires `TestWidgetsFlutterBinding`).
  - [ ] 5.2 Helper: a `_TestHarness` class that wires (`AppDatabase(NativeDatabase.memory())`, in-memory `StreamController<GameEvent>.broadcast()`, a mutable `GameState` cell, a `FakeClock` from `test/helpers/fake_clock.dart`, and a `SaveRepository` with `debounceDuration: Duration(milliseconds: 50)` for tests). Provide `tearDown` that calls `await repo.dispose(); await db.close();`.
  - [ ] 5.3 Test group `'event-driven row writes'`:
    - **`CountryUnlocked` writes country row**: seed initial-state, push `CountryUnlocked` event, await microtask + 100ms, assert `countries` row at id has `unlocked: true`, `ipLevel: 0` (or whatever state holds), `leaderTier: 'none'`. (Wait > debounce so the meta snapshot also writes, exercising both row-write and meta-write paths.)
    - **`UpgradePurchased` writes ipLevel** — push event with ipLevel 1→3 in state, assert row's ipLevel is 3.
    - **`LeaderHired` writes leaderTier** — push with `newTier: LeaderTier.tier1`, assert row's `leaderTier` column is `'tier1'`.
    - **`LeaderUpgraded` writes leaderTier** — same shape, `tier2`.
    - **`ContinentUnlocked` upserts continent** — row appears with `unlocked: true, completed: false`.
    - **`MilestoneReached` upserts milestone** — `(continentId, percent)` row appears.
    - **`ContinentCompleted` upserts continent** — sets `completed: true`.
    - **`GoldenSpawned` inserts active golden** — row appears.
    - **`GoldenClaimed` upserts effect + deletes spawn** — `active_goldens` row gone, `active_golden_effect` singleton row exists with matching multiplier/expiresAt.
    - **`GoldenExpired(claimed: true)` deletes effect** — `active_golden_effect` table empty.
    - **`GoldenExpired(claimed: false)` deletes spawn** — `active_goldens` row gone, `active_golden_effect` untouched.
    - **`Tick` and `CountryTapped` write nothing** — push event, wait < debounce, assert NO writes (no countries rows changed, no continents rows). Also assert that pushing `CountryTapped` does NOT schedule a meta snapshot (verified by counting `meta` writes after 2× `_debounceDuration` — should be 0).
  - [ ] 5.4 Test group `'debounce + meta snapshot'`:
    - **`'1 meta-changing event → 1 meta write after 2s'`**: push `UpgradePurchased`, wait 49ms (< debounce of 50ms in tests), assert `meta` table empty; wait 60ms more (total > debounce), assert `meta` row exists with current `totalInfluence`.
    - **`'burst of 50 events coalesces to 1 meta write'`**: push 50 `UpgradePurchased` events with 1ms gaps in a `fakeAsync.run((async) {...})` block (use `package:fake_async/fake_async.dart` — already a transitive dep from `clock` package, OR drive the test with manual `await Future.delayed(...)` and a small delay). Advance time past debounce. Count `meta` writes via instrumented `AppDatabase` subclass OR by polling `_metaSeeded` (preferred: assert exactly 1 row in `meta` table — first-launch insert + 49 update-on-conflict-update would still be 1 row but multiple write operations; to count operations, use a `MockAppDatabase` with a counter). **Simpler approach**: capture `clock.now()` calls — `_writeMetaSnapshot` reads `clock.now()` once per call; assert the `FakeClock`'s call counter advanced exactly once. This avoids subclassing `AppDatabase`.
    - **`'CountryTapped does NOT schedule meta'`**: push 10 `CountryTapped` events, advance time past debounce, assert `clock.now()` was NOT called by SaveRepository (counter still 0) AND `meta` table is empty.
    - **`'first-launch path: insert then subsequent updates'`**: push event, await debounce, assert one `meta` row exists with `schemaVersion: 3`. Mutate state, push another meta-changing event, await debounce, assert still ONE row (no duplicate insert), with updated values.
  - [ ] 5.5 Test group `'flush()'`:
    - **`'flush writes immediately when debounce pending'`**: push `UpgradePurchased`, immediately call `await repo.flush()`, assert `meta` row exists BEFORE the debounce timer would have fired naturally (we can't easily prove "before", but we can assert flush returns and meta is present within a `Future.microtask`).
    - **`'flush is no-op when nothing pending'`**: construct repo, immediately `await repo.flush()`, assert `meta` table empty AND no error thrown AND `clock.now()` not called.
    - **`'flush cancels pending timer'`**: push event, `await repo.flush()`, push NO further events, advance time past 2× debounce, assert exactly 1 `meta` row (the timer didn't fire a second time).
    - **`'flush is idempotent'`**: `await repo.flush(); await repo.flush();` — no error, no extra writes.
  - [ ] 5.6 Test group `'dispose'`:
    - **`'dispose cancels subscription'`**: push event, `await repo.dispose()`, push another event AFTER dispose, advance time, assert no further writes (subscription cancelled).
    - **`'dispose flushes pending'`**: push meta-changing event, `await repo.dispose()` immediately, assert `meta` row exists (dispose's awaited `flush` ran).
  - [ ] 5.7 Test group `'error swallowing'`:
    - Use a custom `_FailingDatabase extends AppDatabase` that throws on the first `update(meta)`. Push event, await debounce, assert NO unhandled exception bubbles up (test passes), AND `Logger('SaveRepository')` recorded a `WARNING` (use `Logger.root.onRecord` listener in test setup).

- [ ] Task 6: Tests for `GameLifecycleObserver` (AC: #8, #12)
  - [ ] 6.1 Create `test/services/game_lifecycle_observer_test.dart`. Use `flutter_test`.
  - [ ] 6.2 Helper: `_FakeSaveRepository` with `int flushCount = 0; Future<void> flush() async { flushCount++; }; Future<void> dispose() async {}`.
  - [ ] 6.3 Tests:
    - **`'paused triggers flush'`**: instantiate observer, call `observer.didChangeAppLifecycleState(AppLifecycleState.paused)`, await pump, assert `flushCount == 1`.
    - **`'inactive triggers flush'`** — same shape.
    - **`'detached triggers flush'`** — same.
    - **`'hidden triggers flush'`** — same.
    - **`'resumed does NOT trigger flush'`** — `flushCount == 0`.
    - **`'flush errors do not throw'`**: `_FakeSaveRepository.flush` throws; observer should swallow + log; assert no unhandled exception.
    - **`'attach/detach round-trip'`**: call `attach()`, then `detach()`, push `paused` lifecycle change via `WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused)` — assert `flushCount` did NOT increment (observer was detached). Use `WidgetsFlutterBinding.ensureInitialized()` in `setUp`.

- [ ] Task 7: Extend architecture boundary test (AC: #9)
  - [ ] 7.1 Open `test/architecture/data_boundary_test.dart` (created by Story 6-1). The 6-1 implementation asserts that the **mapper** is the ONLY file under `lib/data/` importing both `package:global_domination/data/database/...` AND `package:global_domination/game/...`.
  - [ ] 7.2 **Extend** the dual-import predicate to allow an explicit allowlist:
    ```dart
    const dualImportAllowlist = <String>{
      'lib/data/mappers/game_state_mapper.dart',
      'lib/data/repositories/save_repository.dart',
    };
    ```
    Update the assertion: every file matching the dual-import predicate MUST be in `dualImportAllowlist`. **Do not add the lifecycle observer** to this list — it lives in `lib/services/`, outside the data boundary's scope.
  - [ ] 7.3 Add a sub-test `'save_repository.dart is in the dual-import allowlist'` to make the contract explicit (tests should fail loudly if 6-2 is reverted before 6-1).
  - [ ] 7.4 If Story 6-1 has not yet landed when this story is implemented, **block** — depends on 6-1's `data_boundary_test.dart`. Note in Dev Agent Record: cannot start until 6-1 is `done`.

- [ ] Task 8: Run code generation, format, analyze, full test suite (AC: all)
  - [ ] 8.1 No new tables → no `build_runner` run is required for this story (mapper + tables are 6-1's deliverables). If the dev agent finds `app_database.g.dart` stale because 6-1 was just landed, run `dart run build_runner build --delete-conflicting-outputs` to regenerate; otherwise skip.
  - [ ] 8.2 `flutter analyze` — 0 warnings, 0 errors. The exhaustive-switch in `_handleEvent` is the highest-risk site for analyzer churn — if `flutter analyze` reports a missing case, **DO NOT add a `default:` arm**; instead, identify the new event variant and decide whether 6-2's contract should handle it (almost always: no, the variant's owning story handles it; widen the comment in `_handleEvent` to explain).
  - [ ] 8.3 `dart format --set-exit-if-changed .`.
  - [ ] 8.4 `flutter test` — full suite green. Expected new tests: ≈ 25–30 (≈ 12 event-routing + ≈ 5 debounce + ≈ 4 flush + ≈ 2 dispose + ≈ 1 error-swallow + ≈ 7 lifecycle + ≈ 2 architecture). Full suite should land at ≈ 605–625 (assuming Story 6-1 already added ≈ 30–40).
  - [ ] 8.5 Update `Status` to `review`. Append a Change Log entry and File List.

## Dev Notes

### Why this story is the contract surface for downstream Epic 6 stories

Story 6-1 establishes the **schema and lossless mapping**; Story 6-2 establishes the **write strategy and event routing**. Together they form the persistence contract everything else in Epic 6 (and downstream feature stories) leans on:

| Decision locked here | Used by |
|---|---|
| **Per-event row writes via exhaustive switch** (Task 2.3) | Story 5-2 (BoostActivated/Expired), Story 5-3 (MissionCompleted/Rotated), Story 5-4 (DailyRewardClaimed), Story 5-5 (AchievementEarned) — each adds a `case` in `_handleEvent` when it lands; the analyzer enforces it. |
| **2-second debounce coalescing** (Task 2.4 + AC #6) | Story 6-4's `OfflineCatchup` re-uses the same repository; its `OfflineEarningsApplied` event mutates `totalInfluence` and rides the debounce. |
| **`flush()` contract** (AC #7, Task 2.6) | Story 6-4 calls `flush()` before computing offline earnings; Story 6-6 (save recovery) calls `flush()` before tearing down the corrupt DB. |
| **`GameLifecycleObserver` registration in `app.dart`** (Task 4.2) | Story 6-4's resume hook lives in the same observer (`AppLifecycleState.resumed` arm); 6-2 leaves it as a documented no-op. |
| **`_metaSeeded` insert-once flag** (Task 2.5) | All future meta-column additions (Story 5-2's `totalIntel`, etc.) extend the same INSERT/UPDATE companion shape; the seeded-once invariant survives schema bumps. |
| **`gameWorldEventsProvider` keyhole** (Task 1.2) | Audio service (Epic 8), haptics service (Epic 8), and Story 6-4's offline catch-up consumer all reach for the events stream through this single Riverpod-friendly provider — `_world.events` stays private. |

### Banked-influence volatility

`CountryTapped` does NOT trigger a country-row write (AC #2 / Epic 6.2 AC). The ledger of "banked influence per country" is intentionally **not durable** between collects:

- After `CountryTapped` fires, the reducer zeros `bankedInfluence` and bumps `state.totalInfluence`. The new total IS persisted (via the debounced `meta` snapshot).
- Between collects, `bankedInfluence` accumulates per tick. If the player closes the app while a country has un-collected banked influence, the `paused` flush writes the meta snapshot but does NOT re-write country rows. The banked balance is **lost**.
- **This is acceptable per Epic 6 scope.** The amount lost is at most one tick's accumulation (small relative to `totalInfluence`); persisting per-tap would multiply DB writes by an order of magnitude.
- **A future story MAY widen `flush()`** to write all country rows that have non-zero `bankedInfluence`. Out of scope for 6-2.

If a tester reports "banked dropped on backgrounding," the answer is **"working as designed; tap to collect before backgrounding."**

### Why exhaustive switch + no `default` arm

Per project-context.md line 379: *"Sealed `switch` must stay exhaustive — when adding a new `GameCommand` or `GameEvent`, the compiler will force you to update every consumer; do NOT silence with a catch-all `case _ => …` except in `AudioService` / `HapticsService` where unhandled events are genuinely no-ops."*

`SaveRepository` is **not** a no-op-by-default consumer. New events have semantic persistence implications (a new `BoostActivated` event implies a `boosts` row write in Story 5-2). Forcing each story's implementer to add a case in `_handleEvent` is the contract — the analyzer error IS the documentation.

**Anti-example (do NOT do this):**
```dart
default:
  break; // unhandled events are not persisted
```
This silently swallows future variants and breaks the cross-story contract.

### `unawaited` discipline and error swallowing

Every event handler dispatches its row write via `unawaited(...)` because the events stream MUST NOT back-pressure on slow DB writes. If a row write fails (e.g. SQLite locked, disk full), the failure must NOT propagate to the events subscriber — otherwise the entire stream subscription dies and downstream consumers (audio, haptics) silently stop receiving events.

Each helper wraps its body in a top-level `try/catch (e, s) { _log.warning(...); }`. Errors are observable via the standard `package:logging` listener (which CrashReporter could later subscribe to in a future epic; out of scope here).

**Why not `Result<void, GameError>` here?** Because the consumer (the events subscriber) has no meaningful recovery path. Logging is the strictly correct response.

### `_writeMetaSnapshot` — UPDATE-vs-UPSERT decision

Story 6-1's Task 3.4 deliberately does NOT seed a `meta` row in `onCreate`. The first-ever save by `SaveRepository` must therefore INSERT, not UPDATE. Two options:

1. **Always `insertOnConflictUpdate`** — works, but emits an INSERT statement with full schemaVersion + lastSavedAt every time. Wasted bytes.
2. **Boolean flag (`_metaSeeded`)**: first call uses `insertOnConflictUpdate(MetaCompanion.insert(...))` (full row); subsequent calls use `update(meta).write(MetaCompanion(...))` (partial — only changed fields).

Choosing option 2 (Task 2.5) for write efficiency. The flag is per-`SaveRepository`-instance state. The repository's lifetime equals the `ProviderContainer`'s lifetime (no autoDispose), so `_metaSeeded` persists across hundreds of saves until the app process dies. On process restart, the flag resets to `false`, the next call is an upsert (NOOP because the row exists), then the flag flips to `true`. **Cost on restart: one extra INSERT-OR-UPDATE statement, run once.** Acceptable.

**Edge case: SQLite UPDATE returns 0 affected rows when the row doesn't match the WHERE.** Our UPDATE has no WHERE (singleton via CHECK constraint), so this shouldn't happen — but the `_metaSeeded == false` branch defends against it anyway. No further runtime detection needed.

### `GoldenExpired` claimed-vs-unclaimed disambiguation

`GoldenExpired` fires in two scenarios per Story 5-1:

1. **Map-expiry (unclaimed)**: a spawned golden's `expiresAt` passes before the player taps it. The reducer removes it from `state.activeGoldens`. The DB row in `active_goldens` must also be deleted. **No `meta` snapshot needed** — multipliers didn't change.
2. **Effect-expiry (post-claim)**: the player claimed a golden earlier; its 30s effect window passes. The reducer clears `state.activeGoldenEffect` (sets to `null`). The DB row in `active_golden_effect` must be deleted. **Schedule a `meta` snapshot** — `state.goldenOpportunityMultiplier` reverted from the claimed multiplier (e.g. 50×) back to `1.0`.

The event payload carries `claimed: bool` (per `lib/game/game_event.dart` line 322). Use it as the authoritative discriminator. Don't infer from `state.activeGoldens.containsKey(goldenId)` — race condition if events fire in non-sync mode (we use `sync: true` per project rules, but defensive equality on the event payload is preferred).

### Architecture compliance (non-negotiable)

- **`lib/game/` has ZERO new imports under this story.** Sim layer is untouched.
- **`lib/data/repositories/save_repository.dart` is the new dual-import file** (data + game) — the `data_boundary_test.dart` allowlist (Task 7.2) records this explicitly.
- **No raw SQL.** Typed Drift DSL only. The `_writeXxx` helpers all use `update(...).where(...).write(...)`, `into(...).insertOnConflictUpdate(...)`, `delete(...).where(...).go()`. No `customStatement`.
- **No `dart:io` in `SaveRepository`.** It receives an `AppDatabase` instance; filesystem access is the database's concern.
- **No `Logger.info/.fine` in hot paths.** `_writeMetaSnapshot` runs at most once per 2s under normal play — not a hot path. `_handleEvent` dispatches to `unawaited` futures and is non-hot. `Logger.warning` calls are exception paths only.
- **`GameLifecycleObserver` lives in `lib/services/`.** Per project-context.md line 200, services may import `package:flutter/widgets.dart` for `WidgetsBindingObserver`. This is the correct layer.
- **No `print()` anywhere.** Use `Logger('SaveRepository')` and `Logger('GameLifecycleObserver')`.
- **No `DateTime.now()` in `SaveRepository`.** Always `_clock.now().toUtc()`. This story does not touch `lib/game/` (where `DateTime.now()` is forbidden), but matching the discipline keeps tests deterministic via `FakeClock`.
- **No `Random()` anywhere in this story.** Not needed.
- **Sealed-switch exhaustiveness in `_handleEvent`** — strictly enforced (Task 2.3, Dev Notes "Why exhaustive switch").
- **No new `GameCommand` or `GameEvent` variants** — this story consumes events; it does not emit them.
- **No `flame`, no `freezed`, no `json_serializable`** added.

### Library / framework requirements

- `drift: ^2.26.1` (already pinned per pubspec / project-context.md line 33). All writes use `package:drift/drift.dart`.
- `flutter_riverpod: ^2.6.1` for new providers in `data_providers.dart`.
- `logging` (already a transitive dep, used by `CrashReporter`). Add `import 'package:logging/logging.dart';` to both `save_repository.dart` and `game_lifecycle_observer.dart`.
- `package:flutter/widgets.dart` for `WidgetsBindingObserver`, `WidgetsBinding`, `AppLifecycleState`. Used **only** in `lib/services/game_lifecycle_observer.dart` and `lib/app.dart`.
- `package:fake_async/fake_async.dart` for debounce-coalescing tests. **Already a transitive dep** via `clock` package (used by Flutter's test infrastructure). If `flutter test` complains about a missing direct dependency, add it under `dev_dependencies` in `pubspec.yaml` (versions: `fake_async: ^1.3.1`).
- **NO new dependencies.** Specifically do NOT add `rxdart`, `stream_transform`, or any debounce-helper package — `Timer` does the job.

### File structure requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/data/repositories/save_repository.dart` | `SaveRepository` — event-driven persistence + 2s debounced meta snapshot + lifecycle flush |
| `lib/services/game_lifecycle_observer.dart` | `WidgetsBindingObserver` that flushes save on paused/inactive/detached/hidden |
| `test/data/repositories/save_repository_test.dart` | Per-event routing + debounce + flush + dispose + error tests |
| `test/services/game_lifecycle_observer_test.dart` | Lifecycle state → flush dispatching tests |

**Modify:**

| File | Change |
|---|---|
| `lib/providers/game_providers.dart` | Add public `Stream<GameEvent> get events` on `GameWorldNotifier` + `gameWorldEventsProvider` |
| `lib/providers/data_providers.dart` | Add `gameStateMapperProvider` + `saveRepositoryProvider` (with `ref.onDispose` wiring) |
| `lib/app.dart` | Convert root widget to `ConsumerStatefulWidget` (if not already); register `GameLifecycleObserver` in `initState` / `detach` in `dispose` |
| `test/architecture/data_boundary_test.dart` | Extend dual-import predicate with allowlist `{mapper, save_repository}` |

**Do NOT modify:**

- `lib/main.dart` — boot-time setup is reserved for global error handlers (per project-context.md line 264).
- `lib/game/**` — sim layer is untouched.
- `lib/data/database/app_database.dart`, `lib/data/database/tables/**`, `lib/data/database/converters/**` — Story 6-1's responsibility; this story consumes the schema.
- `lib/data/mappers/**` — Story 6-1's responsibility; the mapper is held by reference for forward compatibility (used in 6-4) but not invoked in 6-2.
- `lib/data/repositories/crash_log_repository.dart`, `crash_log_entry.dart` — orthogonal.
- `lib/services/crash_reporter.dart`, `content_registry_loader.dart` — orthogonal.
- `lib/ui/**` — no UI surface in this story (the modal in Story 6-5 is a separate concern).
- `assets/data/**` — no content changes.
- `pubspec.yaml`, `build.yaml`, `analysis_options.yaml` — no dep / config changes (unless `fake_async` needs explicit `dev_dependencies` declaration).

### Testing requirements

- **Drift tests** use `flutter_test` + `NativeDatabase.memory()`. Match the pattern from `test/data/database/app_database_test.dart`.
- **`AppDatabase` instances** ALWAYS get `await db.close()` in `tearDown`. Match the existing pattern.
- **`SaveRepository` instances** ALWAYS get `await repo.dispose()` in `tearDown`. Disposing flushes pending writes — tests that assert "no write occurred" must call `await repo.dispose()` AFTER the assertion (or use a dispose-then-reopen-and-query helper).
- **Event injection**: tests construct a `StreamController<GameEvent>.broadcast()` and pass `controller.stream` to the repository constructor. Push events via `controller.add(event)`. Use `await Future.delayed(Duration.zero)` between push and assert to flush microtasks.
- **`FakeClock`** lives at `test/helpers/fake_clock.dart` (per Story 5-1's notes). Reuse — do NOT reinvent. The clock returns deterministic UTC times so `meta.lastSavedAt` round-trips reliably.
- **`fake_async`** used only for the burst-coalescing test (Task 5.4). For all other timing tests, use `Duration(milliseconds: 50)` debounce + real `await Future.delayed(...)` — keeps tests readable and avoids `FakeAsync` edge cases.
- **Logger assertion pattern** (Task 5.7's error-swallow test): `Logger.root.level = Level.ALL;` + `Logger.root.onRecord.listen((rec) => log.add(rec));` in `setUp`. Match the pattern from any existing logging test (search `Logger.root.onRecord` if uncertain).
- **No property tests required** — debounce + event routing is fully exercisable via deterministic example-based tests.
- **Test count expectation:** ≈ 25–30 new tests (Task 8.4).
- **Architecture test**: extends Story 6-1's data-boundary test; add a small allowlist mechanism. The test must pass under both 6-1 and 6-2 — keep the predicate strict (allowlist exact-match).

### Previous story intelligence

- **Story 6-1 (sibling, ready-for-dev)**: ESTABLISHES the schema (v3) and `GameStateMapper`. **Story 6-2 cannot be implemented before 6-1 lands as `done`.** The dev agent should verify 6-1's status in `sprint-status.yaml` before starting; if 6-1 is not `done`, halt and report. The `data_boundary_test.dart` and the singleton-row patterns described in 6-1 are PREREQUISITES.

- **Story 5-1 (done)**: GoldenSpawned/GoldenClaimed/GoldenExpired events are stable; `event.claimed` discriminates effect-vs-map expiry (5-1 Task 9 + game_event.dart line 322). The fallback ClaimGolden switch arm cleanup from 5-1's review patch confirms exhaustive `switch` is the project's preferred discipline — match it here.

- **Story 4-3 (done)**: `MilestoneReached` event carries `(continentId, percent, rewardType, rewardValue)`. The DB write captures only `(continentId, percent)` — rewards are derived from content + the percent at load-time per the milestone reducer's contract. **Do not persist `rewardType` or `rewardValue`** in the milestone row; that would couple the schema to balance tuning.

- **Story 4-2 / 4-4 (done)**: `ContinentUnlocked` and `ContinentCompleted` are distinct events; both write to the same `continents` row via upsert. 4-4's "100% milestone flips `continentCompletions[id]=true`" is the reducer responsibility — by the time `ContinentCompleted` fires, `state.continentCompletions[id] == true`. The repository writes `unlocked: true, completed: true` (always — a completed continent is by definition unlocked).

- **Story 4-1 (done)**: `CountryUnlocked` carries `(countryId, continent, cost)`. The repository writes the country row with `unlocked: true` AND schedules a meta snapshot (totalInfluence decreased by `cost`). The 4-1 review patch added defensive guards for negative `cost`; reducer enforces this — repository trusts the event.

- **Story 3-2 (done)**: `UpgradePurchased` carries `(countryId, levelsAdded, bulkRequested, totalCost)`. The repository writes ONLY `ipLevel` (the new state value, not the delta). Schedule meta snapshot for `totalCost` deduction.

- **Story 3-3 (done)**: `LeaderHired` and `LeaderUpgraded` both carry `newTier`. The repository writes `leaderTier: newTier.name` for both. The two events are routed identically — keeping them as separate switch arms (rather than collapsing) preserves traceability when reading the source.

- **Story 1-9 (done)**: `GameWorld.events` is a `StreamController.broadcast(sync: true)` (line 26-27 of `game_world.dart`). Synchronous emission — multiple subscribers (Audio, Haptics, SaveRepository in this story) all receive each event in the same microtask. Test assertions can rely on `await Future.delayed(Duration.zero)` to flush.

- **Story 1-8 (done)**: `Result<T, GameError>` is the sim-layer error contract. **`SaveRepository` does NOT use `Result`** because there's no caller capable of acting on a persistence failure (the events stream subscriber has no error channel). Logging via `Logger.warning` is the correct response.

- **`FakeClock` and `GameStateBuilder`** under `test/helpers/` (`GameStateBuilder` introduced by Story 6-1's Task 8.10 — confirm existence before Task 5). If 6-1 did NOT yet promote `GameStateBuilder`, this story does NOT introduce it (out of scope); inline minimal `GameState` construction in tests.

### Project structure notes

- **`lib/data/repositories/` is the home for `SaveRepository`** alongside the existing `crash_log_repository.dart`. Naming convention: `<feature>_repository.dart`, class `<Feature>Repository`. Match.
- **`lib/services/game_lifecycle_observer.dart`** — services layer is the correct home for any class that imports `package:flutter/widgets.dart` AND coordinates between layers (per `_bmad-output/project-context.md` line 200 and architecture line 600).
- **No new top-level folders.** Both new files slot into existing layers.
- **Test mirror discipline:** `test/data/repositories/save_repository_test.dart` mirrors `lib/data/repositories/save_repository.dart`; `test/services/game_lifecycle_observer_test.dart` mirrors `lib/services/game_lifecycle_observer.dart`.
- **`test/architecture/data_boundary_test.dart` is shared** with Story 6-1; this story extends it.

### Project context rules

Extracted from `_bmad-output/project-context.md` — applies to this story:

- **`drift: ^2.26.1`** pinned (line 33). Use existing version.
- **No raw SQL — always typed Drift DSL** (line 117). All writes use `update(...).write(...)`, `into(...).insertOnConflictUpdate(...)`, `delete(...).where(...).go()`.
- **Write cadence is event-driven + debounced 2s `totalInfluence` snapshot. Never per-tick writes.** (line 119) — this is the headline rule THIS STORY IMPLEMENTS.
- **`meta.lastSavedAt` (UTC ISO8601) is the offline clock source** (line 122). Always pass `_clock.now().toUtc()` to `MetaCompanion.lastSavedAt`. Drift's `store_date_time_values_as_text: true` handles the ISO8601 serialization.
- **Direction: `data/ → game/` (mappers convert DB rows to sim types). Reverse is forbidden.** (line 60) — `SaveRepository` imports types from `lib/game/` (events, state) but `lib/game/` does not import from `lib/data/`. Architecture test enforces.
- **Audio/haptics/persistence subscribe to `gameWorld.events`. They NEVER call methods directly from widgets.** (line 90) — `SaveRepository` is the persistence subscriber; UI does not call `repo.save(...)`; lifecycle observer is the only non-event entry point (`flush()`).
- **`Result<T, GameError>` for anything that can fail meaningfully.** (line 130) — persistence failures have no caller-recoverable path; use `Logger.warning` instead of `Result`. (Documented above.)
- **`StreamController.broadcast(sync: true)`** (line 86) — synchronous events are foundational; tests rely on it.
- **Sealed `switch` must stay exhaustive — when adding a new `GameCommand` or `GameEvent`, the compiler will force you to update every consumer; do NOT silence with a catch-all `case _`** (line 379) — `_handleEvent` is the textbook example.
- **No `freezed` / `json_serializable`** (line 263) — `SaveRepository` and `GameLifecycleObserver` are hand-written.
- **Drift-generated `.g.dart` files MUST be excluded from lint and committed** (line 376) — no `build_runner` run for this story unless 6-1's `.g.dart` is stale.
- **No `print()` anywhere** (line 138) — use `Logger('SaveRepository')` / `Logger('GameLifecycleObserver')`.
- **No `DateTime.now()` / `Random()` in `lib/game/`** (lines 354–355) — this story does NOT touch `lib/game/`.
- **`lib/utils/` is leaf-level** (line 64) — this story does NOT touch `lib/utils/`.
- **Only `lib/providers/` imports `game/` + `data/` + `services/` together** (line 65) — `data_providers.dart` IS in `lib/providers/`; the new `saveRepositoryProvider` correctly composes `appDatabaseProvider` (data), `gameWorldEventsProvider` (game), and `clockProvider` (game). ✓

### Backwards-compatibility note (project rule)

Per the project rule: **"backward compatibility is out of scope unless explicitly requested. Do not add migrations, versioning, or default-fallback logic to keep older saved games loading; it's acceptable for old saves to break and require a reset during development."**

This story introduces no schema changes (Story 6-1 owns the v3 schema). The `_metaSeeded` flag is **not** a backwards-compatibility shim — it's a runtime optimization for INSERT-then-UPDATE on a fresh DB. If the `meta` table format changes in a future story (Story 5-2 adds `totalIntel` column via v4 migration), the `_writeMetaSnapshot` body extends to include the new column; old DBs will have already been migrated by Drift's `MigrationStrategy.onUpgrade(3 → 4)`.

The `unawaited`-with-try/catch pattern is **not** a backwards-compatibility crutch — it's defensive error containment around a fire-and-forget DB write. Errors are surfaced through logs, not through silent fallbacks.

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.2: Persistence Write Strategy] — original ACs (lines 37–67)
- [Source: _bmad-output/implementation-artifacts/6-1-drift-schema-and-gamestatemapper.md] — schema v3 contract; `MetaCompanion`, `CountriesCompanion`, `ContinentsCompanion`, `ContinentMilestonesCompanion`, `EarnedAchievementsCompanion`, `ActiveGlobalUpgradesCompanion`, `ActiveGoldensCompanion`, `ActiveGoldenEffectCompanion` shapes; singleton-row CHECK pattern; `data_boundary_test.dart` predicate
- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.3: Typed Migrations] — downstream story (does not depend on 6-2's repository surface but does run in same epic)
- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.4: Offline Earnings Calculation on Resume] — downstream consumer; `OfflineCatchup` dispatches an `OfflineEarningsApplied` event; `SaveRepository`'s exhaustive switch will need a case in 6-4
- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.5: Offline Reward Modal On Resume] — UI consumer of 6-4's event; orthogonal to 6-2's contract
- [Source: _bmad-output/project-context.md#Drift] — typed DSL, write-cadence rule, `lastSavedAt` UTC contract (lines 114–122)
- [Source: _bmad-output/project-context.md#Engine-Specific Rules] — `WidgetsBindingObserver: paused/inactive → stop ticker + saveRepository.flush() + record lastSavedAt; resumed → OfflineCatchup.apply() THEN restart ticker` (line 71) — this story implements the `paused/inactive → flush()` half
- [Source: _bmad-output/project-context.md#Event bus discipline] — `Audio/haptics/persistence subscribe to gameWorld.events. They NEVER call AudioService.play(...) from widgets.` (lines 89–91) — `SaveRepository` is the persistence subscriber
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules] — `Per-tick saveRepository.save(fullState). Writes are event-driven + debounced snapshots.` (line 366) — explicit no-no this story enforces
- [Source: lib/game/game_world.dart] — `_events` is `StreamController.broadcast(sync: true)` (lines 26–27); `events` getter exposes the stream (line 40)
- [Source: lib/game/game_event.dart] — every variant the exhaustive switch must handle; `GoldenExpired.claimed` (line 322) is the discriminator for effect-vs-map expiry
- [Source: lib/game/game_state.dart] — `totalInfluence`, `goldenOpportunityMultiplier`, `boostMultiplier` (lines 27–34) are the meta-snapshot fields
- [Source: lib/data/database/app_database.dart] — current schema version 2; will be at version 3 post-6-1; `_backupDatabase` pattern (lines 38–48)
- [Source: lib/data/repositories/crash_log_repository.dart] — pattern for typed Drift DSL repository (transaction, `into(...).insert(Companion.insert(...))`, `select(...).get()`)
- [Source: lib/providers/data_providers.dart] — current `appDatabaseProvider` and `crashLogRepositoryProvider` (lines 7–15); pattern for new `gameStateMapperProvider` + `saveRepositoryProvider`
- [Source: lib/providers/game_providers.dart] — `gameWorldProvider` + `GameWorldNotifier` shape; the `events` getter must be added here
- [Source: lib/main.dart] — boot-time setup pattern; observer registration explicitly NOT here
- [Source: lib/services/crash_reporter.dart] — pattern for service-layer Logger usage
- [Source: test/data/database/app_database_test.dart] — pattern for `flutter_test` + `NativeDatabase.memory()` + `tearDown` close
- [Source: test/architecture/game_boundary_test.dart] — pattern for static-analysis architecture tests; mirror in `data_boundary_test.dart` extension

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
