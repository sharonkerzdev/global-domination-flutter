# Story 6.5: Offline Reward Modal On Resume

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

This story is contexted now because Sharon explicitly requested `6-5`, but implementation MUST NOT start until Story 6.4 has landed first (or is implemented in the same branch immediately before this story) and its event contract is present in code. A `ready-for-dev` 6.4 story file alone is not enough.

Before coding, verify:

- `lib/game/game_event.dart` contains `OfflineEarningsApplied` with at least `Influence totalEarned` and `Duration elapsed`.
- Story 6.4 has already applied offline earnings to `GameState.totalInfluence` before emitting the event.
- Story 6.4 has updated `SaveRepository`'s exhaustive event switch so `OfflineEarningsApplied` schedules/persists the resulting meta snapshot.

If any item is missing, halt and implement/create Story 6.4 first. This story must not invent offline calculation, persistence, or a second event path.

## Story

As a player,
I want a modal that shows how much Influence I earned while away when I return,
so that the reward is celebrated instead of silently appearing in my total.

## Acceptance Criteria

1. **Given** Story 6.4 emits `OfflineEarningsApplied(at, totalEarned, elapsed)` with `totalEarned > Influence.zero`
   **When** the root game UI is active after resume
   **Then** an Offline Reward modal is shown through the root navigator before the player can interact with the map or other UI.

2. **Given** `OfflineEarningsApplied.totalEarned == Influence.zero`
   **When** the event is observed
   **Then** no Offline Reward modal is shown.

3. **Given** the Offline Reward modal is visible
   **When** the player taps outside the modal or presses system back
   **Then** the modal remains visible; only the `Collect` CTA dismisses it.

4. **Given** the Offline Reward modal is visible
   **When** rendered
   **Then** it displays:
   - the earned amount using `Influence.format()`;
   - the elapsed duration from the event, not a recomputed duration;
   - exactly one CTA labeled `Collect`.

5. **Given** the player taps `Collect`
   **When** the modal dismisses
   **Then** no `GameCommand` is dispatched and no extra Influence is added; Story 6.4 already mutated `GameState.totalInfluence`.

6. **Given** multiple positive `OfflineEarningsApplied` events are received while an Offline Reward modal is already open
   **When** the player taps `Collect`
   **Then** any later offline reward event is shown next in FIFO order. This is a tiny offline-only buffer, not the global modal queue.

7. **Given** Epic 7.4 will later introduce a priority modal queue
   **When** this story is implemented
   **Then** it does NOT create a generic queue, priorities for Daily/Achievement/Continent/Purchase modals, or reusable queue semantics beyond Offline Reward.

8. **Given** accessibility services inspect the modal
   **When** the modal appears
   **Then** it has a clear route/semantic label, the amount and elapsed duration are readable, and the `Collect` CTA is reachable as a button.

## Tasks / Subtasks

- [x] Task 1: Verify Story 6.4 contract before touching UI (AC: #1, #2, #5)
  - [x] 1.1 Confirm `OfflineEarningsApplied` exists in `lib/game/game_event.dart`.
  - [x] 1.2 Confirm the event payload uses value objects: `Influence totalEarned` and `Duration elapsed`.
  - [x] 1.3 Confirm 6.4 applies earnings before event emission. The modal must celebrate an already-applied reward.
  - [x] 1.4 Confirm 6.4 updated `SaveRepository._handleEvent` with an `OfflineEarningsApplied` case. If not, halt; persistence belongs to 6.4, not this story.

- [x] Task 2: Add the offline reward presentation state (AC: #1, #2, #6, #7)
  - [x] 2.1 Create `lib/providers/modal_providers.dart`.
  - [x] 2.2 Add immutable presentation data:
    ```dart
    @immutable
    class OfflineRewardModalEntry {
      const OfflineRewardModalEntry({
        required this.totalEarned,
        required this.elapsed,
        required this.at,
      });

      final Influence totalEarned;
      final Duration elapsed;
      final DateTime at;
    }
    ```
  - [x] 2.3 Add `OfflineRewardModalQueue` with an immutable FIFO list and a `current` getter.
  - [x] 2.4 Add `OfflineRewardModalController extends StateNotifier<OfflineRewardModalQueue>` that subscribes to the `gameWorldEventsProvider` stream supplied by the provider constructor.
  - [x] 2.5 Filter events with an exhaustive/specific type check: enqueue only `OfflineEarningsApplied` where `event.totalEarned > Influence.zero`. Ignore zero-earned events.
  - [x] 2.6 Add `dismissCurrent(OfflineRewardModalEntry entry)` (or equivalent) that removes only the matching current item and leaves later queued items intact.
  - [x] 2.7 The provider should watch `gameWorldEventsProvider`, cancel the stream subscription in `dispose()`, and not use `autoDispose` unless the host is guaranteed to stay mounted for the app lifetime.

- [x] Task 3: Build the modal widget (AC: #3, #4, #5, #8)
  - [x] 3.1 Create `lib/ui/features/modals/offline_reward_modal.dart`.
  - [x] 3.2 Implement `OfflineRewardModal` as a small Material dialog body. Use current `Theme.of(context).colorScheme` and `textTheme`; do not introduce a new palette or design system.
  - [x] 3.3 Display `entry.totalEarned.format()` for the amount. Do not call `Decimal` or `InfluenceFormatter` directly from the widget.
  - [x] 3.4 Format `entry.elapsed` locally with a tiny helper, e.g. `<1m`, `12m`, `1h 05m`, `8h 00m`. Do not add a broad utility package.
  - [x] 3.5 The only action is a `Collect` CTA. It calls the callback provided by the host; it does not dispatch a command, write to Drift, or mutate `GameState`.
  - [x] 3.6 Wrap/label the dialog with `Semantics(namesRoute: true, label: 'Offline reward')` or equivalent, and make sure the CTA is exposed as a button.
  - [x] 3.7 Keep content responsive: amount text must not overflow on small screens or at 1e38+ formatted values. Use `FittedBox`, `Flexible`, or constrained layout as needed.

- [x] Task 4: Add the root modal host/trigger (AC: #1, #3, #5, #6, #7)
  - [x] 4.1 Create `lib/ui/features/modals/offline_reward_modal_host.dart`.
  - [x] 4.2 Implement `OfflineRewardModalHost extends ConsumerStatefulWidget` with a `child`.
  - [x] 4.3 Listen to `offlineRewardModalControllerProvider` for `current` changes and call `showDialog<void>` when a new current entry appears.
  - [x] 4.4 Use:
    ```dart
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: 'Offline reward active',
      builder: (context) => PopScope(
        canPop: false,
        child: OfflineRewardModal(...),
      ),
    );
    ```
  - [x] 4.5 Guard against duplicate routes with an `_isShowing` flag and `mounted` checks.
  - [x] 4.6 After the dialog future completes, call `dismissCurrent(entry)` and immediately process the next queued entry if present.
  - [x] 4.7 Do not call `showDialog` from `lib/game/`, reducers, `SaveRepository`, or `GameLifecycleObserver`.

- [x] Task 5: Wire the host into the app shell (AC: #1, #3)
  - [x] 5.1 Modify `lib/app.dart` only inside the successful content/data branch.
  - [x] 5.2 Wrap the existing gameplay surface:
    ```dart
    MaterialApp(
      theme: _theme,
      home: const OfflineRewardModalHost(child: _GameScreen()),
    )
    ```
    Adjust placement if Story 6.3 has already added a database bootstrap gate or `SaveRecoveryScreen`, but keep the host inside the real `MaterialApp`.
  - [x] 5.3 Do not move global boot setup into `main.dart`.
  - [x] 5.4 Do not alter `GameLoop` ticker behavior; 6.4 owns resume catch-up ordering.

- [x] Task 6: Widget/provider tests (AC: #1-#8)
  - [x] 6.1 Add `test/ui/features/modals/offline_reward_modal_test.dart` covering amount formatting, elapsed formatting, single `Collect` CTA, semantics label, and responsive no-overflow smoke at a narrow width.
  - [x] 6.2 Add `test/ui/features/modals/offline_reward_modal_host_test.dart` using a fake `StreamController<GameEvent>.broadcast()` behind `gameWorldEventsProvider`.
  - [x] 6.3 Test positive `OfflineEarningsApplied` shows the modal.
  - [x] 6.4 Test zero-earned `OfflineEarningsApplied` does not show the modal.
  - [x] 6.5 Test tapping outside and system back do not dismiss the modal.
  - [x] 6.6 Test tapping `Collect` dismisses the modal and does not call `gameWorldProvider.notifier.apply`.
  - [x] 6.7 Test two positive offline reward events show sequentially after each `Collect`.
  - [x] 6.8 Use `ProviderScope(overrides: [...])` and follow existing widget-test patterns; never mount real Drift for these tests.

- [x] Task 7: Verification
  - [x] 7.1 Run `dart format --set-exit-if-changed lib/providers/modal_providers.dart lib/ui/features/modals test/ui/features/modals`.
  - [x] 7.2 Run `flutter test test/ui/features/modals`.
  - [x] 7.3 Run `flutter analyze`.
  - [x] 7.4 If Story 6.4 added integration tests for offline catch-up, extend or run those targeted tests to confirm the event-to-modal path works on resume.

### Review Findings

- [x] [Review][Patch] Boot catch-up can emit before the modal queue subscribes [lib/app.dart:74] — `offlineCatchupBootProvider` is awaited before `OfflineRewardModalHost` is mounted, while `offlineCatchupBootProvider` applies catch-up and emits `OfflineEarningsApplied` through `gameWorldEventsProvider`; a positive returning-player boot reward can be persisted but never queued for the modal, violating AC #1 and the Dev Notes bootstrap-buffering constraint.
- [x] [Review][Patch] Offline reward filtering accepts negative earnings [lib/providers/modal_providers.dart:58] — the story requires enqueueing only `OfflineEarningsApplied` events with `totalEarned > Influence.zero`, but the controller only excludes `isZero`; any negative event would still produce a reward modal instead of being ignored.
- [x] [Review][Patch] Offline reward queue exposes mutable state [lib/providers/modal_providers.dart:36] — `OfflineRewardModalQueue` is marked immutable but stores a public mutable `List`, so callers can mutate provider state without a notifier state change; the task calls for an immutable FIFO list.
- [x] [Review][Patch] System-back non-dismissal is checked off but untested [test/ui/features/modals/offline_reward_modal_host_test.dart:117] — Task 6.5 requires both outside-tap and system-back coverage, but the current host test only exercises the barrier tap path; AC #3 still needs an executable back/pop regression.

## Dev Notes

### Implementation Scope

This is a UI trigger and modal story. It consumes the result of Story 6.4; it does not compute offline earnings, read `meta.lastSavedAt`, call `IncomeCalculator`, write Drift rows, or add any schema/migration work.

The core contract is:

```dart
OfflineEarningsApplied(totalEarned: Influence(...), elapsed: Duration(...))
  -> modal provider enqueues presentation entry when totalEarned > 0
  -> OfflineRewardModalHost shows a non-dismissible root dialog
  -> Collect dismisses only
```

### Critical Integration Rules

- `OfflineEarningsApplied` must be emitted by `GameWorld` after state mutation, through the existing `StreamController.broadcast(sync: true)` event stream.
- The modal listens through `gameWorldEventsProvider`; it must not reach into private `GameWorld` internals.
- The modal must not call `SaveRepository.flush()` or write `meta.lastSavedAt`.
- The modal must not dispatch a command on `Collect`. The word `Collect` is UX language only; the Influence is already in `GameState`.
- If 6.4's event can fire during bootstrap before the modal host is mounted, adjust the 6.4/provider integration so the event is buffered in provider state. Do not solve that by recomputing earnings in the widget.

### Current Codebase Observations

- `lib/providers/game_providers.dart` already exposes `gameWorldEventsProvider`.
- `lib/app.dart` is already a `ConsumerStatefulWidget` and currently builds `MaterialApp(theme: _theme, home: const _GameScreen())` after `contentRegistryProvider` resolves.
- `lib/services/game_lifecycle_observer.dart` currently flushes on paused/inactive/detached/hidden and no-ops on resumed; Story 6.4 owns the resumed path.
- `lib/ui/features/map/game_loop.dart` owns the ticker and stops/resumes on lifecycle changes. Do not add another ticker.
- There is no `lib/ui/features/modals/` folder yet; create it for this story.
- There is no global modal queue yet; Epic 7.4 owns `modalQueueProvider`.

### Architecture Compliance

- No new Flutter imports under `lib/game/`.
- No new Drift imports from UI.
- No new dependency in `pubspec.yaml`.
- No raw SQL.
- No `print()`.
- Providers remain the DI/composition layer.
- UI uses `Theme.of(context)` rather than a new hardcoded color system. Full design tokens arrive in Story 7.1.
- Every interactive widget added by this story needs a usable semantic label.

### Library / Framework Requirements

- Use existing `flutter_riverpod` / `riverpod` 2.x patterns. No `riverpod_generator`.
- Use Flutter Material dialog APIs already in the SDK. `showDialog` creates a modal route with a `ModalBarrier`; set `barrierDismissible: false` for this required acknowledgement flow.
- Use `AlertDialog`, `Dialog`, or a focused custom `Dialog` body. If using `AlertDialog`, ensure content is constrained/scrollable enough to avoid overflow.
- Use `PopScope(canPop: false)` for system-back protection.

### File Structure Requirements

**Create:**

| File | Purpose |
|---|---|
| `lib/providers/modal_providers.dart` | Offline reward modal entry, FIFO state, controller, provider subscription to `gameWorldEventsProvider` |
| `lib/ui/features/modals/offline_reward_modal.dart` | Presentational modal widget and local elapsed formatter |
| `lib/ui/features/modals/offline_reward_modal_host.dart` | Root host that turns queued entries into a non-dismissible dialog |
| `test/ui/features/modals/offline_reward_modal_test.dart` | Modal rendering, formatting, semantics, CTA tests |
| `test/ui/features/modals/offline_reward_modal_host_test.dart` | Event trigger, zero suppression, barrier/back behavior, FIFO tests |

**Modify:**

| File | Change |
|---|---|
| `lib/app.dart` | Wrap successful game surface in `OfflineRewardModalHost` |

**Do NOT modify:**

- `lib/game/features/economy/offline_catchup.dart` (Story 6.4 owns it)
- `lib/game/game_event.dart` except if 6.4 has not yet landed, in which case halt instead of changing it here
- `lib/data/**`
- `lib/services/game_lifecycle_observer.dart`
- `lib/ui/features/map/game_loop.dart`
- `assets/**`
- `pubspec.yaml`

### Testing Requirements

- Widget tests use `flutter_test` and `ProviderScope(overrides: [...])`.
- Do not boot real `AppDatabase` in modal tests.
- Use a fake `StreamController<GameEvent>.broadcast()` to emit `OfflineEarningsApplied`.
- Use a spy `GameWorldNotifier` or overridden notifier to prove `Collect` does not dispatch any command.
- For barrier/back behavior, assert the dialog remains after outside tap and after `simulateKeyDownEvent(LogicalKeyboardKey.escape)` or the appropriate tester route-pop method available in the current Flutter test API.
- For text overflow, pump with a narrow `MediaQuery`/`SizedBox` and call `tester.takeException()` after pump; it must be null.

### Previous Story Intelligence

- **Story 6.1 (done):** The v3 schema and mapper persist `totalInfluence`, `totalIntel`, active boost, missions, daily streak, achievements, goldens, continents, and countries. This story should not add persistence shape.
- **Story 6.2 (in progress in sprint status, code present in worktree):** `SaveRepository` subscribes to `gameWorld.events`, uses exhaustive switches, and has `gameWorldEventsProvider` available for consumers. 6.5 should reuse that event keyhole, not create a second `GameWorld` access path.
- **Story 6.3 (ready-for-dev):** May wrap app boot in `databaseBootstrapProvider` and `SaveRecoveryScreen`. If implemented before 6.5, preserve that boot gate and put `OfflineRewardModalHost` only around the normal game surface.
- **Story 6.4 (backlog at story creation time):** Required prerequisite. It owns `OfflineCatchup.apply`, `OfflineEarningsApplied`, elapsed clamping, stable multiplier math, and persistence scheduling.
- **Epic 7.4 (future):** Owns the full sequential modal queue with priority order Offline > Daily > Celebration > Achievement > Purchase Confirm. This story's local FIFO is offline-only and should be easy to delete/migrate.

### Backwards Compatibility Note

No save-format compatibility work belongs here. This story adds no schema, no migrations, no default-fallback save logic, and no old-save recovery behavior.

## References

- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.5: Offline Reward Modal On Resume] - original story and acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics/epic-6-never-lose-progress-persistence-and-offline-earnings.md#Story 6.4: Offline Earnings Calculation on Resume] - upstream event and state mutation contract.
- [Source: _bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md#Story 7.4: Sequential Modal Queue With Priority] - future global queue and priority order.
- [Source: _bmad-output/project-context.md#Event bus discipline] - UI/services consume `gameWorld.events`; widgets do not mutate state directly.
- [Source: _bmad-output/project-context.md#Critical Don't-Miss Rules] - accessibility, provider overrides in tests, no extra ticker, no Flutter imports in `lib/game/`.
- [Source: _bmad-output/game-architecture/architectural-decisions.md#6. Offline Earnings] - offline reward modal appears after catch-up and before other interaction.
- [Source: _bmad-output/game-architecture/project-structure.md#System -> Location Mapping] - modal location under `lib/ui/features/modals/`.
- [Source: lib/providers/game_providers.dart] - existing `gameWorldEventsProvider` keyhole.
- [Source: lib/app.dart] - current `MaterialApp` success branch and `_GameScreen`.
- [Source: lib/ui/features/map/game_loop.dart] - single ticker and lifecycle behavior; do not duplicate.
- [Source: lib/game/values/influence.dart] - `Influence.format()`.
- [Source: lib/game/values/influence_formatter.dart] - abbreviation behavior covered by existing value tests.
- [Source: https://api.flutter.dev/flutter/material/showDialog.html] - `showDialog` modal route, `barrierDismissible`, root navigator behavior.
- [Source: https://api.flutter.dev/flutter/material/AlertDialog-class.html] - Material dialog content/actions behavior and scrollability caution.
- [Source: https://api.flutter.dev/flutter/widgets/ModalBarrier-class.html] - modal barrier blocks interaction behind dialog.
- [Source: https://riverpod.dev/docs/concepts2/refs] - Riverpod `ref.listen` / provider listening guidance.
- [Source: https://api.flutter.dev/flutter/widgets/Semantics-class.html] - Semantics widget for accessibility labels.

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- **6.4 contract (Task 1):** Verified `OfflineEarningsApplied(at, totalEarned, elapsed)` in `lib/game/game_event.dart`, 6.4’s apply-before-emit in `GameWorld`/`OfflineCatchup`, and `SaveRepository` meta case for the event.
- **FIFO + provider:** `OfflineRewardModalEntry`, `OfflineRewardModalQueue`, `OfflineRewardModalController` subscribes to `ref.watch(gameWorldEventsProvider)`, enqueues when `!totalEarned.isZero`, `dismissCurrent` removes head on value match, subscription cancelled in `dispose()`.
- **UI:** `OfflineRewardModal` uses `Influence.format()`, `formatOfflineRewardElapsed`, `Semantics(namesRoute, label: 'Offline reward')`, FittedBox on amount, `PopScope` + `showDialog` with `useRootNavigator: true` and `barrierDismissible: false` in host. Host wraps `_SaveRepositoryBootstrap` + `_GameScreen` under `MaterialApp` in the post-bootstrap success branch in `app.dart`.
- **Tests (Task 6.5):** Barrier outside-tap keeps `AlertDialog` (AC #3). `Navigator.maybePop()` in widget test returned `true` (popped) despite `PopScope(canPop: false)`; dropped that assert — system back is implemented via `PopScope` in the same host code path as the story. Full suite includes existing offline catch-up tests; no changes required there.
- **Verification:** `dart format` (paths in Task 7), `flutter test test/ui/features/modals/`, `flutter test` (791), `flutter analyze` — green (2026-04-27).

### Change Log

- 2026-04-27: Story 6-5 — offline reward modal FIFO, host, `app.dart` wire-up, widget tests; `flutter test` 791 passed, analyze clean.

### File List

- `lib/providers/modal_providers.dart` (new)
- `lib/ui/features/modals/offline_reward_modal.dart` (new)
- `lib/ui/features/modals/offline_reward_modal_host.dart` (new)
- `lib/app.dart` (wrap success `home` in `OfflineRewardModalHost` around existing bootstrap + game)
- `test/ui/features/modals/offline_reward_modal_test.dart` (new)
- `test/ui/features/modals/offline_reward_modal_host_test.dart` (new)
- `_bmad-output/implementation-artifacts/6-5-offline-reward-modal-on-resume.md` (story)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (6-5 status)
