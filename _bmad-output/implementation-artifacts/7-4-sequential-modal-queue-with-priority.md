# Story 7.4: Sequential Modal Queue With Priority

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Story 7.4 replaces the offline-only modal queue from Story 6.5 with the Epic 7 global modal queue. Do not create a second generic modal system beside the existing one.

Before coding, verify:

- Story 7.3 is either complete or the current branch clearly owns any concurrent shell/HUD edits. At story creation time, sprint status marks `7-3-global-hud-with-influence-and-intel-currency-badges` as `in-progress`, while `lib/ui/features/hud/global_hud.dart` is not present in this workspace. Coordinate with that work before editing shared shell files.
- `lib/providers/modal_providers.dart` currently contains an offline-only FIFO controller, `OfflineRewardModalController`, and `offlineRewardModalControllerProvider`.
- `lib/ui/features/modals/offline_reward_modal_host.dart` currently turns that offline-only queue into a root `showDialog`.
- `lib/app.dart` currently watches `offlineRewardModalControllerProvider.notifier` before `offlineCatchupBootProvider`. Preserve this boot-time subscription-before-catchup rule with the new queue provider.
- `OfflineEarningsApplied`, `DailyRewardClaimed`, `ContinentCompleted`, and `AchievementEarned` already exist in `lib/game/game_event.dart`.
- `dailyRewardAvailableProvider` exists in `lib/providers/feature_providers.dart`, but it does not re-evaluate at local midnight on its own. The modal queue integration must explicitly re-check on boot/resume.
- `AppScaffold` from Story 7.2 owns the `BottomNavigationBar` plus `IndexedStack`. Do not alter tab order, map preservation, or the single `GameLoop` ticker while implementing this queue.

If Story 7.3 has unmerged changes to `app.dart`, `AppScaffold`, HUD stats/settings actions, or shared modal files, integrate with those changes rather than reverting them.

## Story

As a player,
I want modals like Offline Reward, Daily Reward, Continent Complete, Achievement Earned, and Purchase Confirm to appear one after another in priority order,
so that rewards and confirmations feel clear instead of stacked or overwhelming.

## Acceptance Criteria

1. Given multiple modal-triggering conditions happen in a short window, when the queue drains, then modals display in this priority order: Offline Reward, Daily Reward, Celebration/Continent Complete, Achievement Earned, Purchase Confirm.

2. Given a modal is already showing, when a new higher-priority trigger fires, then the current modal remains visible and the new modal waits in the queue. There is no preemption and no stacked overlay.

3. Given several pending entries share the same priority, when the queue drains, then those entries display FIFO in enqueue order.

4. Given `OfflineEarningsApplied` fires with `totalEarned > Influence.zero`, when observed by the modal queue, then an Offline Reward entry is enqueued using the event's `totalEarned`, `elapsed`, and `at` payloads.

5. Given `OfflineEarningsApplied` fires with zero or negative earned Influence, when observed by the modal queue, then no modal entry is enqueued.

6. Given the player returns on a day where `dailyRewardAvailableProvider == true`, when the game surface becomes active after boot or app resume, then a Daily Reward entry is enqueued behind any Offline Reward entry and ahead of celebration/achievement/purchase entries.

7. Given the Daily Reward modal is shown, when the player taps its primary CTA, then `ClaimDailyReward()` is dispatched through `gameWorldProvider.notifier`, the modal dismisses, and the queue continues with the next entry.

8. Given the player has already claimed the daily reward for the current local calendar day, when the app rebuilds or resumes again, then no duplicate Daily Reward entry is enqueued for that day.

9. Given `ContinentCompleted` fires, when observed by the modal queue, then a Continent Complete celebration entry is enqueued at Celebration priority with the continent id and timestamp from the event.

10. Given `AchievementEarned` fires, when observed by the modal queue, then an Achievement Earned entry is enqueued at Achievement priority with the achievement id, reward type, reward value, and timestamp from the event.

11. Given a future UI flow needs purchase confirmation, when it calls the modal queue API with a purchase-confirm request, then a Purchase Confirm entry is enqueued at Purchase priority and does not dispatch its command until the player confirms.

12. Given a Purchase Confirm modal is visible, when the player taps Cancel, then no `GameCommand` is dispatched and the queue advances. When the player taps Confirm, then the configured command is dispatched exactly once and the queue advances.

13. Given any queue modal is visible, when the player taps outside the modal or presses system back, then reward/celebration modals remain visible until their CTA is used. Purchase Confirm may close through Cancel only; barrier/back must not accidentally confirm.

14. Given the queue state is inspected in tests, when reading `modalQueueProvider`, then the current entry and pending entries are visible as immutable state and can be advanced with a fake dismissal stream or an explicit notifier dismissal method.

15. Given boot offline catch-up emits `OfflineEarningsApplied` before the root modal host mounts, when `ModalQueueHost` later mounts, then the queued Offline Reward still displays. This preserves the Story 6.5 review fix.

16. Given modals render, when accessibility tooling inspects them, then each modal has a readable route/semantic label, every CTA is exposed as a button, and interactive targets meet 44/48dp mobile minimums.

17. Given new modal UI files are added, when token guardrails run, then they use `Theme.of(context).colorScheme`, `textTheme`, `ThemeExtension` tokens, and `Spacing.*` rather than raw widget color literals.

18. Given this story is complete, when verification runs, then `flutter analyze`, modal provider tests, modal host/widget tests, offline reward modal regression tests, app boot ordering tests, and architecture tests pass.

## Tasks / Subtasks

- [ ] Task 1: Preflight current modal and shell state (AC: #1, #2, #15)
  - [ ] 1.1 Confirm Story 7.3's branch status and avoid overlapping edits to HUD/shell files where possible.
  - [ ] 1.2 Confirm `OfflineRewardModalHost` is still the only production host for modal dialogs before this story.
  - [ ] 1.3 Confirm `lib/app.dart` initializes the modal provider before `offlineCatchupBootProvider`; preserve the same ordering with `modalQueueProvider.notifier`.
  - [ ] 1.4 Confirm `GameLoop` remains the only runtime owner of `Ticker` / `SingleTickerProviderStateMixin`.
  - [ ] 1.5 Confirm `dailyRewardAvailableProvider` and `ClaimDailyReward` exist before adding Daily Reward UI. If either is missing, halt and finish Story 5.4 work first.

- [ ] Task 2: Replace offline-only queue with generic modal queue state (AC: #1, #2, #3, #4, #5, #11, #14, #15)
  - [ ] 2.1 Refactor `lib/providers/modal_providers.dart` into the home of the global modal queue. Do not create a parallel `global_modal_providers.dart` unless the old file becomes a compatibility export only.
  - [ ] 2.2 Add a priority model with stable ordering:
    - Offline Reward = 0
    - Daily Reward = 1
    - Celebration/Continent Complete = 2
    - Achievement Earned = 3
    - Purchase Confirm = 4
  - [ ] 2.3 Add immutable queue entry types. Preferred shape:
    - `OfflineRewardModalEntry`
    - `DailyRewardModalEntry`
    - `ContinentCompleteModalEntry`
    - `AchievementEarnedModalEntry`
    - `PurchaseConfirmModalEntry`
  - [ ] 2.4 Preserve the existing `OfflineRewardModalEntry` public fields (`totalEarned`, `elapsed`, `at`) if practical so `OfflineRewardModal` changes stay small.
  - [ ] 2.5 Add a `ModalQueueState` with `current`, immutable `pending`, and helper getters for test inspection. No public mutable `List`.
  - [ ] 2.6 Add `ModalQueueController extends StateNotifier<ModalQueueState>`.
  - [ ] 2.7 Queue rule: if no modal is current, a new entry becomes `current`; if a modal is current, the new entry is inserted into pending by priority, then FIFO sequence within the same priority. Current is never preempted.
  - [ ] 2.8 Add duplicate prevention by stable entry key for Daily Reward and Purchase Confirm. Do not dedupe Offline Reward, Continent Complete, or Achievement entries that can legitimately happen multiple times with different event timestamps/ids.
  - [ ] 2.9 Add `dismissCurrent(String entryId)` or equivalent that removes only the matching current entry and promotes the next pending entry.
  - [ ] 2.10 Add a fake-dismissal test seam, such as `modalDismissalStreamProvider`, that provider tests can override to drive `dismissCurrent` without widget dialogs.
  - [ ] 2.11 Remove or deprecate `OfflineRewardModalController`, `OfflineRewardModalQueue`, and `offlineRewardModalControllerProvider` so there is one production queue. If a temporary alias is kept, it must not subscribe to `gameWorldEventsProvider` independently.

- [ ] Task 3: Map game events and daily availability into queue entries (AC: #4, #5, #6, #8, #9, #10, #15)
  - [ ] 3.1 The queue controller subscribes to `gameWorldEventsProvider` once and cancels the subscription in `dispose()`.
  - [ ] 3.2 On `OfflineEarningsApplied`, enqueue only when `totalEarned > Influence.zero`.
  - [ ] 3.3 On `ContinentCompleted`, enqueue `ContinentCompleteModalEntry(continentId, at)`.
  - [ ] 3.4 On `AchievementEarned`, enqueue `AchievementEarnedModalEntry(achievementId, rewardType, rewardValue, at)`.
  - [ ] 3.5 Do not enqueue anything for `MilestoneReached(25/50/75)` in this story. Epic 8/Story 7.10 can decide milestone-specific visual treatment later.
  - [ ] 3.6 Add a Daily Reward enqueue bridge that checks `dailyRewardAvailableProvider` after boot and after app resume. It may live in `ModalQueueHost` if it needs `WidgetsBindingObserver`, but queue insertion still goes through `modalQueueProvider.notifier`.
  - [ ] 3.7 Use `clockProvider.now().toLocal()` to create a stable daily entry key such as `daily:YYYY-MM-DD`; never use `DateTime.now()` directly.
  - [ ] 3.8 When `DailyRewardClaimed` is observed, ensure the daily entry for that local date cannot be re-enqueued in the same app session.
  - [ ] 3.9 On app resume, invalidate or re-read `dailyRewardAvailableProvider` before deciding whether to enqueue Daily Reward. This avoids the provider's documented midnight staleness caveat.
  - [ ] 3.10 Do not compute offline earnings, inspect Drift, or read `meta.lastSavedAt` from this story. Offline math remains Story 6.4.

- [ ] Task 4: Add or refactor modal widgets (AC: #7, #12, #13, #16, #17)
  - [ ] 4.1 Keep `lib/ui/features/modals/offline_reward_modal.dart` as the Offline Reward presentation widget and continue using `Influence.format()` plus event `elapsed`.
  - [ ] 4.2 Add `lib/ui/features/modals/daily_reward_modal.dart`. It may show a concise reward-ready surface and a single primary Claim CTA. If it previews reward values, compute them from existing `GameState`, `ContentRegistry.dailyRewards`, and `clockProvider` without duplicating reducer side effects.
  - [ ] 4.3 Add `lib/ui/features/modals/continent_complete_modal.dart`. Resolve a friendly continent name from `ContentRegistry.continents[continentId]?.name` when available; fall back to the id value.
  - [ ] 4.4 Add `lib/ui/features/modals/achievement_earned_modal.dart`. Resolve a friendly achievement name from `ContentRegistry.achievements` when available; fall back to the achievement id.
  - [ ] 4.5 Add `lib/ui/features/modals/purchase_confirm_modal.dart` or a generic confirmation modal that displays title/message/confirm/cancel text from `PurchaseConfirmModalEntry`.
  - [ ] 4.6 Every modal must use current Material theme, `Spacing.*`, `textTheme`, and `colorScheme`/theme extensions. Do not introduce raw `Color(...)` or `Colors.*` outside `lib/ui/theme/**`.
  - [ ] 4.7 Reward/celebration modals should use a single CTA such as `Collect`, `Claim`, or `Continue`. Purchase Confirm must use `Cancel` and `Confirm`.
  - [ ] 4.8 Wrap each dialog route body with readable `Semantics(namesRoute: true, label: ...)` or equivalent.
  - [ ] 4.9 Keep layouts narrow-width safe. Long numbers, continent names, achievement names, and larger text scaling must not overflow.

- [ ] Task 5: Replace the root host with `ModalQueueHost` (AC: #1, #2, #7, #12, #13, #15, #16)
  - [ ] 5.1 Create `lib/ui/features/modals/modal_queue_host.dart`.
  - [ ] 5.2 `ModalQueueHost` listens to `modalQueueProvider` and calls `showDialog<void>` only when a new `current` entry exists and no modal route is already showing.
  - [ ] 5.3 Use `useRootNavigator: true`, `barrierDismissible: false`, and a route-specific barrier label.
  - [ ] 5.4 Wrap route builders with `PopScope(canPop: false, child: ...)` so system back does not bypass the queue.
  - [ ] 5.5 After a modal Future completes, call `dismissCurrent(entry.id)` and drain the next pending entry on a post-frame callback.
  - [ ] 5.6 For Daily Reward Claim, dispatch `const ClaimDailyReward()` before dismissing. Do not add reward amounts directly in UI.
  - [ ] 5.7 For Purchase Confirm, dispatch the stored `GameCommand` exactly once only on Confirm. Cancel dismisses without dispatch.
  - [ ] 5.8 Preserve `_isShowing`, `mounted` checks, and deferred post-frame drain behavior from `OfflineRewardModalHost`.
  - [ ] 5.9 Replace `OfflineRewardModalHost` usage in `lib/app.dart` with `ModalQueueHost`.
  - [ ] 5.10 Delete `offline_reward_modal_host.dart` or leave it as a compatibility wrapper around `ModalQueueHost` only if existing imports require it. It must not read `offlineRewardModalControllerProvider`.

- [ ] Task 6: Preserve boot/resume ordering in `app.dart` (AC: #6, #8, #15)
  - [ ] 6.1 In the successful persisted snapshot branch, initialize the new queue provider before `offlineCatchupBootProvider`, mirroring the old Story 6.5 pattern:
    ```dart
    ref.watch(modalQueueProvider.notifier);
    final offlineBoot = ref.watch(offlineCatchupBootProvider);
    ```
  - [ ] 6.2 Keep `OfflineCatchupBootProvider` and `GameLoop` resume catch-up behavior unchanged.
  - [ ] 6.3 Keep `ModalQueueHost` inside the real `MaterialApp` and outside `_SaveRepositoryBootstrap(child: _GameScreen())`.
  - [ ] 6.4 Do not move `ProviderScope`, `MaterialApp`, database bootstrap, content bootstrap, save recovery, or support long-press setup.
  - [ ] 6.5 If Story 7.3 has added HUD stats/settings placeholders or imports, preserve them.

- [ ] Task 7: Provider and ordering tests (AC: #1, #2, #3, #4, #5, #8, #9, #10, #11, #14, #15)
  - [ ] 7.1 Add `test/providers/modal_providers_test.dart`.
  - [ ] 7.2 Test offline positive events enqueue; zero and negative events do not.
  - [ ] 7.3 Test current modal is not preempted by a higher-priority entry.
  - [ ] 7.4 Test pending entries are promoted by priority order after dismissal.
  - [ ] 7.5 Test FIFO order within the same priority.
  - [ ] 7.6 Test two achievement events with different ids/timestamps both enqueue.
  - [ ] 7.7 Test Daily Reward duplicate suppression for the same local calendar date.
  - [ ] 7.8 Test `modalDismissalStreamProvider` or the chosen fake-dismiss seam advances the queue without widget dialogs.
  - [ ] 7.9 Test queue state pending lists are immutable.
  - [ ] 7.10 Test purchase confirm entry remains pending/current until dismissed and carries the configured command without dispatching during enqueue.

- [ ] Task 8: Host and modal widget tests (AC: #1, #2, #7, #12, #13, #15, #16, #17)
  - [ ] 8.1 Replace or extend `test/ui/features/modals/offline_reward_modal_host_test.dart` with `modal_queue_host_test.dart`.
  - [ ] 8.2 Test an event buffered before host mount still shows when `ModalQueueHost` starts.
  - [ ] 8.3 Test Offline Reward followed by Daily Reward followed by Achievement displays sequentially after each CTA, with only one dialog visible at a time.
  - [ ] 8.4 Test outside barrier tap and system back do not dismiss reward/celebration dialogs.
  - [ ] 8.5 Test Daily Claim dispatches `ClaimDailyReward` exactly once through a spy `GameWorldNotifier`.
  - [ ] 8.6 Test Purchase Cancel dispatches no command; Purchase Confirm dispatches the configured command exactly once.
  - [ ] 8.7 Test modal semantics labels for Offline Reward, Daily Reward, Continent Complete, Achievement Earned, and Purchase Confirm.
  - [ ] 8.8 Test narrow-width and large-value layouts do not overflow.
  - [ ] 8.9 Keep existing `offline_reward_modal_test.dart` coverage for elapsed formatting, amount formatting, CTA behavior, and large Influence values.

- [ ] Task 9: Architecture and regression guardrails (AC: #17, #18)
  - [ ] 9.1 Run or extend `test/architecture/ui_design_tokens_test.dart` so every new modal widget avoids raw widget color literals.
  - [ ] 9.2 Run `test/architecture/game_boundary_test.dart`; this story should not add Flutter imports under `lib/game/**`.
  - [ ] 9.3 Add or extend a small source guard if needed to ensure `ModalQueueHost` is the only production modal host wired in `app.dart`.
  - [ ] 9.4 Ensure no new Drift imports appear in `lib/ui/**`.
  - [ ] 9.5 Ensure no new packages are added to `pubspec.yaml`.

- [ ] Task 10: Verification (AC: all)
  - [ ] 10.1 Run `dart format --set-exit-if-changed` on changed Dart and test files.
  - [ ] 10.2 Run `flutter test test/providers/modal_providers_test.dart`.
  - [ ] 10.3 Run `flutter test test/ui/features/modals`.
  - [ ] 10.4 Run `flutter test test/providers/feature_providers_test.dart`.
  - [ ] 10.5 Run `flutter test test/ui/app_scaffold_test.dart` if Story 7.3 shell/HUD changes are present.
  - [ ] 10.6 Run `flutter test test/architecture`.
  - [ ] 10.7 Run `flutter analyze`.
  - [ ] 10.8 Run full `flutter test` if time permits.

## Dev Notes

### Implementation Scope

This story creates the queue, event bridges, root host, and minimal modal presentations for the modal types named in FR31. It does not implement the full Stats screen, Settings modal, Upgrades tab, Leaders tab, tutorial, audio/haptics, flying numbers, or Epic 8 celebration polish.

The intended production shape after this story:

```dart
// app.dart success branch, shape only:
ref.watch(modalQueueProvider.notifier);
final offlineBoot = ref.watch(offlineCatchupBootProvider);

MaterialApp(
  theme: _theme,
  home: const ModalQueueHost(
    child: _SaveRepositoryBootstrap(
      child: _GameScreen(), // GameLoop(child: AppScaffold())
    ),
  ),
)
```

The queue should be a presentation layer over existing sim events and commands. The simulation remains the source of truth for rewards and state changes.

### Current Codebase Observations

- `lib/providers/modal_providers.dart` currently owns only Offline Reward presentation state.
- `OfflineRewardModalQueue` currently stores a public immutable-looking queue; Story 6.5 review already fixed mutable-list exposure once. Keep the new generic state strictly immutable.
- `OfflineRewardModalHost` already has the right root-dialog mechanics: `_isShowing`, `useRootNavigator: true`, `barrierDismissible: false`, `PopScope(canPop: false)`, and post-frame draining. Reuse this pattern rather than inventing a route manager.
- `lib/app.dart` currently initializes the offline modal controller before boot offline catch-up so `OfflineEarningsApplied` is not missed before the host mounts. This is load-bearing.
- `GameWorld.events` is a synchronous broadcast stream exposed through `gameWorldEventsProvider`.
- `DailyRewardClaimed` is emitted only after `ClaimDailyReward` succeeds. The "daily is available" prompt is not an event; it comes from `dailyRewardAvailableProvider`.
- `dailyRewardAvailableProvider` explicitly documents that it does not re-evaluate at local midnight on its own.
- `ContentRegistry` has friendly `ContinentDef.name` and `AchievementDef.name` fields, which modal widgets can use for display.
- `GameWorldNotifier.apply` currently returns `void`, even though `GameWorld.applyCommand` returns `Result<void, GameError>`. Do not broaden this story into an app-wide error-routing refactor. Daily and purchase confirm command failures can be handled in later UI stories if a user-facing error route is needed.

### Previous Story Intelligence

- Story 6.5's offline-only FIFO exists because the global queue did not exist yet. This story should migrate that code path into the global queue and remove the "offline-only" limitation.
- Story 6.5 review found three important issues: missed boot events before subscription, filtering non-positive offline earnings, and mutable queue state. This story must preserve all three fixes.
- Story 5.4 deliberately deferred Daily Reward modal UI to Story 7.4. It exposed `dailyRewardAvailableProvider` and `ClaimDailyReward`; reuse them.
- Story 5.5 emits `AchievementEarned` after post-command achievement evaluation. This story should present the achievement; it must not re-evaluate achievements.
- Story 4.4 emits `ContinentCompleted` and flips `state.continentCompletions` atomically. This story should present the celebration; it must not mutate completion state.
- Story 7.2 established the app shell and `IndexedStack`. Modal queue work should wrap the shell, not change tab behavior.
- Story 7.3 is in progress. If it lands before this story, preserve `GlobalHud`, stats/settings placeholders, and any shell layout decisions it introduces.

### Architecture Compliance

- `lib/game/**` should not need changes for this story. If a tiny pure helper is required for Daily Reward preview, keep it Flutter-free, deterministic, and covered by pure-Dart tests.
- UI widgets dispatch commands through `gameWorldProvider.notifier.apply(...)`; they never mutate `GameState` directly.
- Providers are the composition root. Event subscription and queue state belong in `lib/providers/`.
- UI never imports Drift database classes or repositories.
- No persistence, migration, schema, save repository, or offline catch-up math changes belong here.
- No second ticker, animation controller, or app loop.
- No `go_router`, `auto_route`, `freezed`, `riverpod_generator`, or new package.
- All modal UI must be accessible and token-styled.

### Library / Framework Requirements

- Use the existing pinned SDK and packages from `pubspec.yaml`: Dart `^3.11.4`, Flutter stable, `flutter_riverpod: ^2.6.1`, `riverpod: ^2.6.1`, `decimal: ^3.0.2`, and `flutter_lints: ^6.0.0`.
- Use Riverpod 2.x manual providers/StateNotifier patterns. Do not introduce `@riverpod` generation.
- Flutter `showDialog` returns a Future that completes when `Navigator.pop` closes the dialog; use that Future to advance the queue after the route is gone.
- Flutter `showDialog` supports `useRootNavigator`; keep it `true` so queue modals appear above the whole shell.
- Flutter `showDialog` barrier dismissal defaults to allowing outside-tap dismissal unless configured; set `barrierDismissible: false` for queue-owned reward/celebration/confirm routes.
- Flutter `PopScope(canPop: false)` is the modern system-back guard for modal routes that should not pop through back gestures.
- Riverpod provider overrides are the official testing mechanism for swapping streams/controllers in `ProviderScope` or `ProviderContainer`; use them for queue tests.

### File Structure Requirements

Create:

| File | Purpose |
| --- | --- |
| `lib/ui/features/modals/modal_queue_host.dart` | Root queue host that turns `modalQueueProvider.current` into one root dialog at a time |
| `lib/ui/features/modals/daily_reward_modal.dart` | Daily reward prompt and Claim CTA |
| `lib/ui/features/modals/continent_complete_modal.dart` | Continent completion celebration |
| `lib/ui/features/modals/achievement_earned_modal.dart` | Achievement earned celebration |
| `lib/ui/features/modals/purchase_confirm_modal.dart` | Generic purchase confirmation surface |
| `test/providers/modal_providers_test.dart` | Queue ordering, event mapping, duplicate suppression, fake dismissal stream |
| `test/ui/features/modals/modal_queue_host_test.dart` | Host sequencing, CTA behavior, semantics, barrier/back behavior |

Modify:

| File | Purpose |
| --- | --- |
| `lib/providers/modal_providers.dart` | Replace offline-only queue with generic priority modal queue |
| `lib/ui/features/modals/offline_reward_modal.dart` | Keep or lightly adapt to generic entry type |
| `lib/app.dart` | Initialize `modalQueueProvider.notifier` before offline boot catch-up and wrap game surface in `ModalQueueHost` |
| `test/ui/features/modals/offline_reward_modal_test.dart` | Preserve amount/elapsed/responsive coverage if entry type changes |
| `test/ui/features/modals/offline_reward_modal_host_test.dart` | Replace old host expectations with queue host expectations |

Delete or convert:

| File | Decision |
| --- | --- |
| `lib/ui/features/modals/offline_reward_modal_host.dart` | Remove, or make a compatibility wrapper around `ModalQueueHost` only. It must not subscribe to a separate offline queue. |

Do not modify:

| Area | Reason |
| --- | --- |
| `lib/game/features/economy/offline_catchup.dart` | Offline math already complete |
| `lib/data/**` | No persistence/schema changes in this story |
| `lib/ui/features/map/game_loop.dart` | Single ticker and resume catch-up behavior already exist |
| `lib/ui/app_scaffold.dart` | Only touch if required to resolve Story 7.3 integration conflicts |
| `assets/**` | No new content/assets required |
| `pubspec.yaml` | No new dependency required |

### Testing Requirements

Use `flutter_test` for widget tests and Riverpod provider overrides for all UI/provider tests. Do not mount real Drift in modal tests.

Recommended provider-test setup:

```dart
final events = StreamController<GameEvent>.broadcast();
final dismissals = StreamController<ModalDismissal>.broadcast();
final container = ProviderContainer(
  overrides: [
    gameWorldEventsProvider.overrideWith((ref) => events.stream),
    modalDismissalStreamProvider.overrideWith((ref) => dismissals.stream),
  ],
);
addTearDown(events.close);
addTearDown(dismissals.close);
addTearDown(container.dispose);
```

Recommended host-test shape:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      gameWorldEventsProvider.overrideWith((ref) => bus.stream),
      gameWorldProvider.overrideWith((ref) => spyNotifier),
      clockProvider.overrideWithValue(fakeClock),
    ],
    child: MaterialApp(
      theme: appTheme(),
      home: const ModalQueueHost(child: Text('app')),
    ),
  ),
);
```

For app boot ordering, keep a regression equivalent to Story 6.5's "event buffered before host mount shows modal when host starts" test.

### Out of Scope

- Full Stats screen (Story 7.5).
- Real Settings modal toggles, credits, and Support long-press migration (Story 7.6).
- Upgrades tab UI and purchase-confirm call sites (Story 7.7).
- Leaders tab UI and hire/upgrade confirmation call sites (Story 7.8).
- Map default/autofocus behavior (Story 7.9).
- Continent progress indicators and milestone tick UI (Story 7.10).
- SFX, haptics, flying numbers, pulse animations, and visual celebration polish (Epic 8).
- New game commands/events/reducers, content JSON, Drift tables, migrations, or save repository writes.

### Latest Technical Information

- No dependency upgrade is required. The implementation should use the SDK APIs already available from Flutter and pinned dependencies in `pubspec.yaml`.
- Flutter `showDialog` is the right primitive for this story because it creates a modal route, can target the root navigator, and returns a Future when dismissed.
- `PopScope` should be used instead of legacy `WillPopScope` for current Flutter system-back handling.
- Riverpod's documented provider override mechanism is sufficient for fake event/dismissal streams in tests.

### Git Intelligence Summary

Recent commits are directly relevant:

- `0db66e0 feat(ui): extract AppScaffold with IndexedStack and Minigames tab` - Story 7.2 shell is in place.
- `7a28f09 feat(ui): design tokens, theme extensions, and tab scaffold` - token usage and raw-color guardrails are active.
- `ef0faba feat: save recovery on corrupt database and related UI` - do not disturb save recovery.
- `c442514 feat: offline catchup and reward modal on resume` - source of the offline-only queue this story migrates.
- `af0cc92 Update offline earnings story status` - sprint bookkeeping around offline reward flow.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` - Story 7.4]
- [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` - FR31, FR14, FR19, FR29, NFR18, NFR21]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` - Navigation, Modals, Event bus, Riverpod, single ticker]
- [Source: `_bmad-output/game-architecture/project-structure.md` - `lib/ui/features/modals/` and `lib/providers/` locations]
- [Source: `_bmad-output/game-architecture/implementation-patterns.md` - Event stream, provider override, widget test patterns]
- [Source: `_bmad-output/project-context.md` - event bus discipline, accessibility, token, provider, and no-duplicate-ticker rules]
- [Source: `_bmad-output/implementation-artifacts/6-5-offline-reward-modal-on-resume.md` - offline-only FIFO and review lessons]
- [Source: `_bmad-output/implementation-artifacts/5-4-7-day-daily-reward-streak.md` - daily availability/provider and modal-queue deferral]
- [Source: `_bmad-output/implementation-artifacts/5-5-27-achievements-granting-permanent-multipliers.md` - `AchievementEarned` event and achievement content names]
- [Source: `_bmad-output/implementation-artifacts/4-4-continent-completion-permanent-multiplier.md` - `ContinentCompleted` event semantics]
- [Source: `_bmad-output/implementation-artifacts/7-2-app-scaffold-with-5-tab-bottom-navigation-and-indexedstack.md` - shell dependency]
- [Source: `_bmad-output/implementation-artifacts/7-3-global-hud-with-influence-and-intel-currency-badges.md` - current in-progress dependency and shell/HUD boundaries]
- [Source: `lib/providers/modal_providers.dart` - existing offline-only modal queue]
- [Source: `lib/ui/features/modals/offline_reward_modal_host.dart` - current root dialog host pattern]
- [Source: `lib/ui/features/modals/offline_reward_modal.dart` - existing Offline Reward widget]
- [Source: `lib/app.dart` - boot ordering and host placement]
- [Source: `lib/providers/feature_providers.dart` - `dailyRewardAvailableProvider`]
- [Source: `lib/game/game_event.dart` - event payloads consumed by the queue]
- [Source: `lib/providers/game_providers.dart` - `gameWorldEventsProvider` and `GameWorldNotifier.apply`]
- [Source: Flutter showDialog API - https://api.flutter.dev/flutter/material/showDialog.html]
- [Source: Flutter PopScope API - https://api.flutter.dev/flutter/widgets/PopScope-class.html]
- [Source: Riverpod provider overrides - https://riverpod.dev/es/docs/concepts2/overrides]

## Dev Agent Record

### Agent Model Used

TBD by dev agent.

### Debug Log References

### Completion Notes List

### File List

## Story Completion Status

Ultimate context engine analysis completed - comprehensive developer guide created.
