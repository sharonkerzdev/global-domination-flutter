# Story 7.9: Map as Default Cold-Launch Screen, Auto-Focus Post-Tutorial

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Story 7.9 depends on the shell, map, and recently-landed Epic 7 work already present in the current worktree:

- `lib/ui/app_scaffold.dart` already initializes `_selectedIndex = 0` and mounts `MapScreen` at `IndexedStack` index 0. This story locks that behavior, **does not persist tab selection**, and explicitly guarantees cold launch always opens on the Map tab.
- `lib/ui/features/map/map_screen.dart` already owns pan/zoom via `_MapView` (a `ConsumerStatefulWidget` whose `_viewTransform = Matrix4.identity()` starts at world-fit). This story extends `_MapViewState` with a one-shot auto-focus on first frame after content load.
- `lib/providers/game_providers.dart` exposes `gameWorldProvider` (state) and `gameWorldEventsProvider` (broadcast event stream).
- `lib/game/game_event.dart` already emits `CountryUnlocked(at, countryId, continent, cost)`. We will subscribe to that event in a UI-local provider to track "most recently unlocked country."
- `lib/game/game_state.dart` does **NOT** have a `tutorialCompleted` field. Story 9-1 (Tutorial State Persistence) is still in backlog. This story therefore introduces a UI-local **`tutorialCompletedProvider`** that returns `true` by default (no tutorial system exists yet → all current players are effectively post-tutorial). When Story 9-1 lands, the provider implementation is rewritten to read from `gameWorldProvider.select((s) => s.tutorialCompleted)`. **Do NOT add `tutorialCompleted` to `GameState`, `lib/game/**`, or any Drift schema in this story** — Story 9-1 owns that work.
- `lib/ui/features/map/country_path.dart` exposes `CountryPath { id, continent, rings, bbox, path }` where `bbox` is a `Rect` in normalized [0,1]² projection space. Use it to compute the focal point and the continent-fit zoom level.
- `lib/providers/geo_providers.dart` exposes `geoProvider` (FutureProvider<List<CountryPath>>) — already loaded once on boot and kept in the `IndexedStack`. Reuse, do not re-parse.
- `lib/providers/app_providers.dart` exposes `contentRegistryProvider` (with `ContinentDef` data including `id` and `name`).
- `GameState.initialSeed()` seeds Egypt as `unlocked: true, ipLevel: 1`. There is always at least one unlocked country, so "first unlocked country" is a well-defined fallback when no `CountryUnlocked` event has fired this session.
- `_MapView` rebuilds the painter when `_viewTransform != _lastTransform`. Setting `_viewTransform` programmatically via `setState(() => _viewTransform = ...)` already triggers a correct repaint — no new painter wiring is required.
- `test/ui/app_scaffold_test.dart` already covers tab integration, `IndexedStack` initial index (`expect(stack().index, 0)`), and pan/zoom survival across tab switches. **Preserve and extend** these tests rather than rewriting them.
- `test/helpers/map_screen_test_providers.dart` provides `mapWidgetTestGameWorldOverride([GameState? initial])` and `mapWidgetTestEmptyContent`. Reuse for MapScreen widget tests.

Before coding, verify with `git status --short` and inspect the current versions of `app_scaffold.dart`, `map_screen.dart`, `game_providers.dart`, `game_event.dart`, `country_path.dart`, `geo_providers.dart`, and `app_providers.dart`.

## Story

As a player,
I want the app to open directly on the Map tab every cold launch, and (once the tutorial is complete) zoom focused on my latest unlocked country,
so that I land on the gameplay surface, oriented on my current frontier.

## Acceptance Criteria

1. Given the app cold-launches, when `AppScaffold` first builds, then the `IndexedStack` index is 0 (Map) **regardless** of any prior tab navigation in any previous session. Selected-tab state is in-memory only; it MUST NOT be persisted to Drift, `GameState`, `SharedPreferences`, or any repository in this story.

2. Given the app warm-resumes (paused → resumed via `WidgetsBindingObserver`), then the previously selected tab is preserved (existing `IndexedStack` + `_selectedIndex` ephemeral state behavior is unchanged). This story does NOT introduce tab-restoration on resume and does NOT force the Map tab on resume — only on cold launch / first `AppScaffold` build.

3. Given the Map tab first renders and `tutorialCompleted == true` (today: always true via the new UI-local `tutorialCompletedProvider`; tomorrow when Story 9-1 lands: read from `state.tutorialCompleted`), then the map view transform auto-focuses on the **most-recently-unlocked country** with a zoom level approximately equal to **"continent fit"** (the bounding box that contains every country in that country's continent fits within the visible canvas with a small token-based padding).

4. Given no `CountryUnlocked` event has fired in the current session (e.g., very first launch on the seeded country, or returning player whose only unlock predates this session), then auto-focus uses the **fallback target** = the country in `state.countries` where `unlocked == true` that comes **first in content order** (`ContentRegistry.countries.values` insertion order). When the seed is Egypt and nothing else is unlocked, the focus lands on Egypt's continent (Africa) at continent-fit zoom.

5. Given `tutorialCompletedProvider` returns `false` (future state once Story 9-1 lands and tutorial is in progress), then auto-focus is **suppressed** and `_viewTransform` stays at whatever value the user / tutorial set it to (today: `Matrix4.identity()` — world-fit). The map shows whatever pan/zoom the tutorial expects at its current step. No throw, no transform reset, no jitter.

6. Given auto-focus is eligible (AC #3 conditions met) and the map has just rendered for the first time, then auto-focus runs **exactly once** per `_MapView` widget lifetime. Subsequent rebuilds (state ticks, new `CountryUnlocked` events, tab switches that re-show the live `IndexedStack` child) do NOT re-trigger auto-focus and do NOT overwrite the user's manual pan/zoom.

7. Given auto-focus has not yet run and a `CountryUnlocked` event fires before the first frame completes, then the auto-focus target reflects that newly-unlocked country (the "most-recently-unlocked" tracker observed the event via `gameWorldEventsProvider`). If multiple `CountryUnlocked` events fire before the first auto-focus frame, the **last** event wins.

8. Given auto-focus eligibility depends on `geoProvider` (must have loaded `List<CountryPath>`) and `contentRegistryProvider` (must have loaded `ContentRegistry`) — both already gated by `app.dart`'s bootstrap `.when` chain — then auto-focus runs only after both are available. If either is loading or errored, the map renders its existing loading/error branches and auto-focus is silently skipped (no exception, no log).

9. Given the most-recently-unlocked country's `CountryId` does not match any `CountryPath` in `geoProvider`'s list (data divergence corner case), then auto-focus falls back to the rules in AC #4 (first-content-order unlocked country whose `CountryPath` exists). If no overlap exists at all, auto-focus is silently skipped and the transform stays at identity.

10. Given the user has manually panned or zoomed the map before auto-focus has run (extremely unlikely with first-frame post-frame callback, but possible during test or low-frame-rate scenarios), then auto-focus is still allowed to run on its first eligible frame. After that single run, manual gestures take precedence forever (AC #6 idempotence).

11. Given auto-focus computes a target transform, then the math is:
    - Find the continent the focal country belongs to via `CountryPath.continent`.
    - Compute the **union bounding box** of all `CountryPath.bbox` values whose `continent` matches that continent id (in normalized [0,1]² space).
    - Choose a `zoom` such that the larger of `bbox.width * canvasWidth` and `bbox.height * canvasHeight`, multiplied by `zoom`, equals `canvasSize` minus a token padding of `Spacing.lg` on each side. Clamp `zoom` to `[_minZoom (1.0), _maxZoom (15.0)]` (the existing constants in `_MapViewState`). A practical formula: `zoom = min(canvasWidth * (1 - 2*padFracX) / (bbox.width * canvasWidth), canvasHeight * (1 - 2*padFracY) / (bbox.height * canvasHeight))` then clamp.
    - Translate so the bounding box center maps to the canvas center. Use the same `Matrix4` composition pattern already in `_onScaleUpdate` (translate × scale × translate-back).

12. Given the `LayoutBuilder` reports a degenerate canvas (zero or NaN width / height — e.g., during a layout race before first paint), then auto-focus skips that frame and re-attempts on the next post-frame callback if still eligible (or remains pending and triggers when a valid canvas size arrives).

13. Given the Map tab is rebuilt because the bottom nav switches to it from another tab during the same app session, then auto-focus **does NOT re-run**; the previously-set `_viewTransform` is preserved (IndexedStack keeps the widget tree alive, AC #6 idempotence applies).

14. Given the Map tab is built for the first time during a widget test that does not pump beyond the loading frame, then auto-focus does not crash, does not pump indefinitely, and is gated by post-frame callbacks so tests using `tester.pump()` + a layout settle behave deterministically.

15. Given UI uses spacing, colors, typography, then it uses `Spacing.*`, `Theme.of(context).colorScheme`, and `textTheme` only — no raw `Color(...)`, `Colors.*`, emoji icons, bitmap assets, or one-off typography. (This story is mostly mechanics; the only UI surface is reuse of the existing `MapScreen` loading/error branches.)

16. Given any state change (Influence increases via tick or collect, an IP upgrade lands, a new country unlocks, a continent unlocks), then the map repaints reactively and the bottom nav stays mounted. None of the existing 60fps map performance budget is regressed by the auto-focus logic: the post-frame callback runs at most once per `_MapView` lifetime; the recently-unlocked tracker subscription is a single broadcast-stream listener that does no per-frame work.

17. Given implementation is complete, then `flutter analyze`, `app_scaffold_test.dart` (initial Map tab + tab switch survival), the new `map_auto_focus_test.dart` widget tests, the new `recently_unlocked_country_provider_test.dart` provider tests, the new `auto_focus_target_test.dart` pure-Dart math tests, UI design-token guardrails, no-duplicate-income-math guardrails, and game/data boundary tests all pass.

18. Given Story 7.9 is a UI/provider-only change, then `lib/game/**`, `lib/data/**`, `assets/**`, and `pubspec.yaml` are NOT modified. No new commands, events, reducers, balance constants, content fields, schema migrations, or persistence write changes belong to this story.

19. Given the auto-focus target math runs, then it is a **pure function** that takes `(targetCountry: CountryPath, allCountries: List<CountryPath>, canvasSize: Size, padding: double, minZoom: double, maxZoom: double)` and returns a `Matrix4`. No `DateTime.now()`, no `Random()`, no provider reads inside the pure function. It MUST live in `lib/ui/features/map/auto_focus_target.dart` (UI layer — depends on `dart:ui` `Matrix4` / `Rect` / `Size`) and MUST have a dedicated unit test file `test/ui/features/map/auto_focus_target_test.dart` using `flutter_test` (because `Matrix4` and `Rect` are Flutter-side types).

20. Given the most-recently-unlocked tracking lives in `lib/providers/`, then `recentlyUnlockedCountryProvider` (a `Provider<CountryId?>` driven by `gameWorldEventsProvider`) is the SOLE source of "latest unlock this session." It subscribes once, cancels its subscription on dispose, and never mutates `GameState`. Its initial value is `null` (no event observed yet) — auto-focus falls back to the AC #4 rule on `null`.

## Tasks / Subtasks

- [x] Task 1: Preflight current shell, map, and architecture (AC: #1, #2, #18)
  - [x] 1.1 Run `git status --short` and capture the current worktree. Story 7.8 artifacts (`lib/providers/leaders_providers.dart`, `lib/ui/features/leaders/leaders_screen.dart`, leaders tests) are `done`; do not revert.
  - [x] 1.2 Re-confirm `AppScaffold` initializes `_selectedIndex = 0` and that `MapScreen` is at `IndexedStack` index 0.
  - [x] 1.3 Confirm `MapScreen` / `_MapView` already owns `_viewTransform = Matrix4.identity()`, `_minZoom = 1.0`, `_maxZoom = 15.0`, and rebuilds the painter when transform changes.
  - [x] 1.4 Confirm `gameWorldEventsProvider` is a `Provider<Stream<GameEvent>>` already exported from `lib/providers/game_providers.dart`.
  - [x] 1.5 Confirm `CountryUnlocked(at, countryId, continent, cost)` is in `lib/game/game_event.dart`.
  - [x] 1.6 Confirm `CountryPath.bbox` is a normalized `Rect` (the existing `WorldMapPainter` already paints in [0,1]² space).
  - [x] 1.7 Confirm `GameState` has NO `tutorialCompleted` field. Verify Story 9-1 is still in backlog before adding the UI-local stub provider. If 9-1 has landed in the meantime, replace the stub with a state-read in step 3.5.

- [x] Task 2: Add the pure auto-focus target math (AC: #11, #12, #19)
  - [x] 2.1 Create `lib/ui/features/map/auto_focus_target.dart` with a top-level pure function:
    ```dart
    /// Pure Matrix4 builder used by [_MapViewState.didChangeDependencies] /
    /// post-frame callback. No clock, no RNG, no provider reads inside.
    Matrix4 computeContinentFitTransform({
      required CountryPath targetCountry,
      required List<CountryPath> allCountries,
      required Size canvasSize,
      double paddingLogical = Spacing.lg,
      double minZoom = 1.0,
      double maxZoom = 15.0,
    });
    ```
  - [x] 2.2 Implementation:
    - Find continent id: `final continent = targetCountry.continent;`.
    - Build continent union bbox: iterate `allCountries.where((c) => c.continent == continent)`, union their `bbox` (use `Rect.fromLTRB(min(...))`-style accumulator). If the iterable is empty, return `Matrix4.identity()` (defensive — should not happen in practice, but documented invariant).
    - If `canvasSize.width <= 0 || canvasSize.height <= 0 || !canvasSize.width.isFinite || !canvasSize.height.isFinite`, return `Matrix4.identity()` (caller will retry on next valid layout).
    - Compute usable canvas: `usableW = canvasSize.width - 2 * paddingLogical`, `usableH = canvasSize.height - 2 * paddingLogical`. Guard against `usableW <= 0` / `usableH <= 0` by returning `Matrix4.identity()`.
    - Bbox in canvas space: `bboxW = unionBbox.width * canvasSize.width`, `bboxH = unionBbox.height * canvasSize.height`. Guard against zero/NaN.
    - Compute zoom: `zoom = min(usableW / bboxW, usableH / bboxH)`. Clamp `zoom` to `[minZoom, maxZoom]`.
    - Compute center of union bbox in canvas-space coordinates: `centerX = (unionBbox.left + unionBbox.width / 2) * canvasSize.width`, `centerY = (unionBbox.top + unionBbox.height / 2) * canvasSize.height`.
    - Target transform: translate canvas-center → scale `zoom` → translate `-(centerX, centerY)`. Use the same `Matrix4` composition pattern as `_onScaleUpdate`:
      ```dart
      final canvasCenterX = canvasSize.width / 2;
      final canvasCenterY = canvasSize.height / 2;
      return Matrix4.translationValues(canvasCenterX, canvasCenterY, 0)
          .multiplied(Matrix4.diagonal3Values(zoom, zoom, 1))
          .multiplied(Matrix4.translationValues(-centerX, -centerY, 0));
      ```
  - [x] 2.3 Document the function with a one-line `///` summary. No multi-paragraph docstring.
  - [x] 2.4 Add `test/ui/features/map/auto_focus_target_test.dart` with cases:
    - Single-country continent → transform centers that bbox at clamped zoom.
    - Multi-country continent → union bbox is the rectangle that contains all of them; transform centers that union and fits it.
    - Degenerate `canvasSize: Size.zero` → returns `Matrix4.identity()`.
    - NaN width → returns identity.
    - Continent has no countries in the list → returns identity.
    - Zoom clamps at `maxZoom` for very small bboxes (e.g., a 0.001 × 0.001 country).
    - Zoom clamps at `minZoom` for very large bboxes (e.g., a single hypothetical "continent" covering 0.9 × 0.9). Verify that even when the math suggests `< 1.0` the result is `>= 1.0`.

- [x] Task 3: Track the most-recently-unlocked country via the event stream (AC: #7, #9, #20)
  - [x] 3.1 Create `lib/providers/map_focus_providers.dart` (new file; do not pollute `feature_providers.dart`).
  - [x] 3.2 Add a `StateNotifier<CountryId?>`-style or `Provider`-driven implementation. Recommended shape:
    ```dart
    class RecentlyUnlockedCountryNotifier extends StateNotifier<CountryId?> {
      RecentlyUnlockedCountryNotifier(Stream<GameEvent> events) : super(null) {
        _sub = events.listen((e) {
          if (e is CountryUnlocked) state = e.countryId;
        });
      }
      late final StreamSubscription<GameEvent> _sub;
      @override void dispose() { _sub.cancel(); super.dispose(); }
    }
    final recentlyUnlockedCountryProvider =
        StateNotifierProvider<RecentlyUnlockedCountryNotifier, CountryId?>((ref) {
          final events = ref.watch(gameWorldEventsProvider);
          return RecentlyUnlockedCountryNotifier(events);
        });
    ```
  - [x] 3.3 Do NOT subscribe in widgets directly; route through this provider only.
  - [x] 3.4 Add the **tutorial-completion gate provider** in the same file (no separate `tutorial_providers.dart` until Story 9-1 lands):
    ```dart
    /// Returns `true` whenever no tutorial system is active. Story 9-1 will
    /// rewrite this provider to read [GameState.tutorialCompleted]. Today
    /// there is no tutorial code path; all players are post-tutorial.
    final tutorialCompletedProvider = Provider<bool>((ref) => true);
    ```
    The comment above is one of the rare cases where a comment is justified: it documents *why* the value is hardcoded (no system yet) and *what* changes when 9-1 lands. Keep it to two lines.
  - [x] 3.5 When Story 9-1 lands, the only change required to satisfy AC #5 will be to rewrite `tutorialCompletedProvider` to `(ref) => ref.watch(gameWorldProvider.select((s) => s.tutorialCompleted))`. Do not bake that future state into this story.

- [x] Task 4: Wire auto-focus into `_MapViewState` (AC: #3, #4, #5, #6, #7, #8, #10, #12, #13, #14)
  - [x] 4.1 Convert `_MapView` from `ConsumerStatefulWidget` (already is) and `_MapViewState` to read `recentlyUnlockedCountryProvider` and `tutorialCompletedProvider` via `ref.read` (NOT `ref.watch`) inside the post-frame callback — auto-focus is a one-shot side effect, not a reactive render.
  - [x] 4.2 Add `bool _autoFocusApplied = false;` to `_MapViewState`.
  - [x] 4.3 Add private method `void _tryAutoFocus(Size canvasSize)`:
    - Returns early if `_autoFocusApplied == true`.
    - Returns early if `canvasSize.width <= 0 || canvasSize.height <= 0 || !canvasSize.width.isFinite || !canvasSize.height.isFinite` (the function does not flip the flag — caller may retry).
    - Reads `tutorialCompletedProvider`. Returns early if `false` — do NOT set the flag; auto-focus stays pending until tutorial completes (this is the Story 9-1 hand-off contract).
    - Resolves the target country:
      - Read `recentlyUnlockedCountryProvider`. If non-null, locate it in `widget.countries`.
      - Else iterate `widget.gameState.countries.values` in content order (well-defined because `GameState.countries` is built from `ContentRegistry.countries` insertion order), pick the first `unlocked == true` whose `CountryId` matches a `CountryPath` in `widget.countries`. (Validate by quick membership check.)
      - If no candidate exists, return early without setting the flag.
    - Compute the new transform via `computeContinentFitTransform(targetCountry, widget.countries, canvasSize)`.
    - If the result equals `Matrix4.identity()` (e.g., the function returned the degenerate fallback), do not commit — return early without setting the flag.
    - `setState(() { _viewTransform = newTransform; _autoFocusApplied = true; });`
  - [x] 4.4 Trigger `_tryAutoFocus` from a `WidgetsBinding.instance.addPostFrameCallback` in `build()` whenever `_autoFocusApplied == false`. Use `mounted` guard inside the callback. The `LayoutBuilder` provides `canvasSize` to the callback (capture from `constraints.biggest`).
    - Schedule pattern (no manual timer / Future.delayed):
      ```dart
      if (!_autoFocusApplied) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _tryAutoFocus(canvasSize);
        });
      }
      ```
    - The callback runs after layout, so `canvasSize` is real. If a layout race still produces a degenerate size, AC #12 says we silently retry on the next frame — the post-frame callback re-schedules naturally because `_autoFocusApplied` stays `false`.
  - [x] 4.5 Do NOT call `_tryAutoFocus` from `initState` — at that point `LayoutBuilder` has not yet produced a `canvasSize`.
  - [x] 4.6 Do NOT use `didChangeDependencies` for this — Riverpod's `ConsumerStatefulWidget` does not require it for `ref.read`, and we want a single post-layout hook.
  - [x] 4.7 Existing pan/zoom gesture handlers MUST NOT touch `_autoFocusApplied`. The flag flips once; user gestures from that point are normal.

- [x] Task 5: Lock cold-launch tab = Map (AC: #1, #2)
  - [x] 5.1 Re-confirm `_AppScaffoldState._selectedIndex = 0` is the literal default. Add a `// Story 7.9: cold launch always opens Map (do not persist).` short comment ONLY if it survives review — preference is to keep no comment; the dedicated `test/ui/app_scaffold_test.dart` `IndexedStack index tracks taps; initial tab is Map` test already documents the contract.
  - [x] 5.2 Do NOT add any persistence wiring (no Drift table, no SharedPreferences, no Riverpod-stored "last tab index"). Tab selection remains ephemeral.
  - [x] 5.3 Do NOT change the existing AppScaffold lifecycle observer behavior. Resume preserves the in-memory `_selectedIndex`.

- [x] Task 6: Preserve architecture boundaries and state ownership (AC: #18, #20)
  - [x] 6.1 UI dispatches commands only through `gameWorldProvider.notifier.apply(...)` (this story does not dispatch any new commands).
  - [x] 6.2 No `lib/game/**` changes are required. Do not add new commands, events, reducers, or balance constants. Do not add `tutorialCompleted` to `GameState` — that is Story 9-1.
  - [x] 6.3 No `lib/data/**` changes, schema migrations, generated Drift files, save repository edits, or persistence write changes. Selected-tab index is ephemeral; "most recently unlocked" is derived in-memory from the event stream.
  - [x] 6.4 No package additions (`go_router`, `auto_route`, animation packages, etc.).
  - [x] 6.5 No new `Ticker` or `AnimationController`. The transform jump on auto-focus is intentionally **instant** (no tween). Animated camera moves are Epic 8 polish; AC #15 forbids one-off animations here.
  - [x] 6.6 No SFX, no haptics, no flying numbers, no celebrations.
  - [x] 6.7 `lib/providers/map_focus_providers.dart` MUST NOT import anything under `lib/data/**`. Verify with the data boundary architecture test (see Task 9).
  - [x] 6.8 `lib/ui/features/map/auto_focus_target.dart` MAY import `dart:ui` types (`Matrix4`, `Rect`, `Size`) and `lib/ui/features/map/country_path.dart`. It MUST NOT import `lib/data/**`, `lib/providers/**`, or `flutter_riverpod`. It is pure Flutter-side math.

- [x] Task 7: Provider tests (AC: #7, #9, #20)
  - [x] 7.1 Add `test/providers/recently_unlocked_country_provider_test.dart`.
  - [x] 7.2 Use a `StreamController<GameEvent>.broadcast(sync: true)` and override `gameWorldEventsProvider` with `(ref) => controller.stream`. Mirror the pattern from `test/ui/features/modals/offline_reward_modal_host_test.dart` or 7.4's modal queue tests.
  - [x] 7.3 Cover:
    - Initial state is `null`.
    - Emitting `CountryUnlocked` updates state to the event's `countryId`.
    - Emitting multiple `CountryUnlocked` events sets state to the **last** one observed (AC #7).
    - Non-`CountryUnlocked` events (`Tick`, `CountryTapped`, `UpgradePurchased`, `LeaderHired`, etc.) do NOT change state.
    - Disposing the container cancels the stream subscription (verify by emitting after dispose and asserting no thrown exception; ProviderContainer.dispose() should cancel the subscription so the listener is gone).
  - [x] 7.4 Add `test/providers/tutorial_completed_provider_test.dart` (small file):
    - Default returns `true`.
    - A note in the file (one line) flags that this stub will be replaced when Story 9-1 lands and the test will be updated to read from `GameState`.

- [x] Task 8: Widget and shell tests (AC: #1, #2, #3, #4, #5, #6, #7, #8, #10, #13, #14, #16)
  - [x] 8.1 Extend `test/ui/app_scaffold_test.dart` (preserve all existing tests):
    - Add a test: `IndexedStack initial index stays 0 even when test pump cycles include simulated resume`. Use `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused)` then `.resumed` and confirm the index is still 0 on first build.
    - Add a test: `tutorialCompletedProvider override to false suppresses auto-focus`. Pump `AppScaffold` with the override; assert `_MapView`'s `_viewTransform` (extract via `WorldMapPainter.viewTransform` getter, already used in existing tests via `_mapPainter(tester).viewTransform`) equals `Matrix4.identity()`.
    - Add a test: `tutorialCompletedProvider == true + a fired CountryUnlocked event causes auto-focus to apply on first frame`. Pump with the event stream override emitting a single `CountryUnlocked` for a known fake country, then `await tester.pumpAndSettle()`, then assert the painter's `viewTransform != Matrix4.identity()` and that the center maps approximately to the country's continent bbox center.
  - [x] 8.2 Add `test/ui/features/map/map_auto_focus_test.dart`:
    - Use `mapWidgetTestGameWorldOverride()` with a `GameState` seeded so that Egypt is unlocked.
    - Override `geoProvider` with two fake `CountryPath`s in continent `africa` (Egypt + one other) and one in continent `asia` (China).
    - Test 1: With `tutorialCompletedProvider = true` and no `CountryUnlocked` event fired, auto-focus targets Egypt (AC #4 fallback to first-content-order unlocked country) and applies once. Use `_mapPainter(tester).viewTransform != Matrix4.identity()`.
    - Test 2: With `tutorialCompletedProvider = true` and a `CountryUnlocked` event for `china` (which is unlocked in this state), auto-focus targets China's continent (`asia`) — verify by checking the transform's translation/scale roughly matches the expected continent center via a tolerance comparison.
    - Test 3: With `tutorialCompletedProvider = false`, auto-focus does NOT apply (`viewTransform == Matrix4.identity()`).
    - Test 4: After auto-focus has applied once, a subsequent `CountryUnlocked` event does NOT re-trigger auto-focus (AC #6, AC #13). Verify `viewTransform` is unchanged after pumping the event.
    - Test 5: Manual pan/zoom AFTER auto-focus applied is respected (drag gesture moves the transform from the auto-focus value; auto-focus does not snap back).
    - Test 6: Degenerate-canvas guard — pump in a `SizedBox(width: 0, height: 0, child: MapScreen())` wrapper; assert no crash and `viewTransform == Matrix4.identity()`. (Skip this test if `LayoutBuilder` refuses to lay out zero-size children — document the skip reason.)
    - Test 7: Recently-unlocked country whose `CountryId` is NOT in `geoProvider`'s list falls back to AC #4 rule (auto-focus still applies on Egypt).
    - Test 8: `tester.binding` lifecycle paused → resumed does NOT cause auto-focus to re-run on resume.
  - [x] 8.3 Test fixtures should reuse `_fakeCountry(...)` style from `test/ui/app_scaffold_test.dart` (continent-tagged `CountryPath`s).
  - [x] 8.4 Use `flutter_test` `findsOneWidget` patterns + `WorldMapPainter.viewTransform` extraction (already wired in the existing scaffold tests). Do not introduce new test-only widgets to surface transform state.

- [x] Task 9: Architecture and regression guardrails (AC: #15, #17, #18)
  - [x] 9.1 Run `test/architecture/ui_design_tokens_test.dart`; the new files must not introduce raw `Color(...)` / `Colors.*`. (Auto-focus math has no colors, but the test sweeps `lib/ui/`.)
  - [x] 9.2 Run `test/architecture/no_duplicate_income_math_test.dart`; auto-focus must not introduce any `def.baseInfluence *` math (it does not).
  - [x] 9.3 Run `test/architecture/game_boundary_test.dart`; no Flutter imports under `lib/game/**`. This story does not touch `lib/game/**`; confirm.
  - [x] 9.4 Run `test/architecture/data_boundary_test.dart`; the new providers and UI files must not import `lib/data/**` Drift/repository/mapper code.
  - [x] 9.5 Add a focused source guard if needed to ensure `auto_focus_target.dart` does not import `flutter_riverpod` or `lib/data/**`.
  - [x] 9.6 Ensure `pubspec.yaml` is unchanged.

- [x] Task 10: Verification (AC: all)
  - [x] 10.1 Run `dart format --set-exit-if-changed` on changed Dart/test files.
  - [x] 10.2 Run `flutter test test/ui/features/map/auto_focus_target_test.dart`.
  - [x] 10.3 Run `flutter test test/ui/features/map/map_auto_focus_test.dart`.
  - [x] 10.4 Run `flutter test test/providers/recently_unlocked_country_provider_test.dart`.
  - [x] 10.5 Run `flutter test test/providers/tutorial_completed_provider_test.dart`.
  - [x] 10.6 Run `flutter test test/ui/app_scaffold_test.dart`.
  - [x] 10.7 Run `flutter test test/architecture`.
  - [x] 10.8 Run `flutter analyze`.
  - [x] 10.9 Run full `flutter test`. Expect zero regressions over the Story 7.8 baseline (~990 tests).

### Review Findings

- [x] [Review][Patch] Eagerly subscribe to recently-unlocked tracker before the first auto-focus decision [lib/ui/features/map/map_screen.dart:131]
- [x] [Review][Patch] Select fallback auto-focus target in content order, not persisted `GameState.countries` map order [lib/ui/features/map/map_screen.dart:159]
- [x] [Review][Patch] Separate terminal skip/valid identity transform from retryable auto-focus failures [lib/ui/features/map/map_screen.dart:194]

## Dev Notes

### Implementation Scope

This story productizes the Map tab as the canonical landing surface. It does two things:

1. **Cold-launch tab lock** — `AppScaffold._selectedIndex = 0` is the literal default. No persistence; this is documented via a passing scaffold test rather than a runtime check.
2. **Post-tutorial auto-focus** — On the first eligible frame after content + geo load, the map view transform jumps to a continent-fit zoom centered on the most-recently-unlocked country (or the first-unlocked fallback). It runs once per `_MapView` widget lifetime, then user gestures and other state changes take over forever.

It does NOT implement: tab persistence, animated camera moves (Epic 8), tutorial state itself (Story 9-1), tutorial overlay UI (Story 9-1), continent progression visual indicators (Story 7-10), milestone glow polish, or any persistence/migration work.

### Current Codebase Observations

- `lib/ui/app_scaffold.dart` initializes `_selectedIndex = 0`. Cold launch already opens on Map. This story locks the behavior with a test and a comment-light implementation.
- `lib/ui/features/map/map_screen.dart` is a `ConsumerWidget` wrapping `_MapView` (a `ConsumerStatefulWidget`). `_MapView` owns `_viewTransform`, `_minZoom`, `_maxZoom`, gesture handlers, and the painter rebuild logic. Auto-focus belongs in `_MapViewState`, not `MapScreen`.
- `_MapViewState.build` already uses a `LayoutBuilder` that exposes `constraints` → `canvasSize`. Use it for the post-frame callback.
- `WorldMapPainter.viewTransform` is already exposed for tests (the existing scaffold tests read it via `_mapPainter(tester).viewTransform`).
- `CountryPath.bbox` is in normalized [0,1]² space; the world map paints into the entire canvas at zoom=1. The math in AC #11 is therefore continent-bbox-in-normalized-space → multiply by `canvasSize` → standard center-on-canvas + scale composition.
- `lib/providers/game_providers.dart` exposes `gameWorldEventsProvider`. Subscribe to it in `recentlyUnlockedCountryProvider`; do NOT subscribe in widgets.
- `GameState.initialSeed()` ensures Egypt is always unlocked at startup. So AC #4's "first unlocked country in content order" fallback always resolves to something concrete on first launch.
- `GameState` has NO `tutorialCompleted` field. Story 9-1 is still backlog. Use the UI-local `tutorialCompletedProvider` stub described in Task 3.4 — when 9-1 lands, the provider becomes a one-line `(ref) => ref.watch(gameWorldProvider.select((s) => s.tutorialCompleted))`.
- `CountryUnlocked` event payload includes `countryId` AND `continent`. We only need `countryId` for AC #3 / #7 — the continent is re-derived via `CountryPath.continent` lookup.
- The map widget tree is kept alive across tab switches by `IndexedStack` (AC #13 idempotence is naturally satisfied by `_autoFocusApplied = true` on the state object).

### Previous Story Intelligence

- Story 7.1 established `Spacing.*`, `Theme.of(context)` extension tokens, and raw-color guardrails. Auto-focus padding uses `Spacing.lg`.
- Story 7.2 established `AppScaffold` + `IndexedStack`. `_selectedIndex = 0` is already the cold-launch default; this story locks it with a test and explicit non-persistence.
- Story 7.3 established `GlobalHud`, `CurrencyBadge`, total currency providers. Not relevant to this story's UI surface.
- Story 7.4 established the generic modal queue and the `gameWorldEventsProvider` consumer pattern (one subscription, cancel on dispose). Mirror that pattern in `recentlyUnlockedCountryProvider`.
- Story 7.5 established Stats route push/pop on top of the map; the existing scaffold test asserts that the map transform survives the push/pop cycle. Auto-focus must preserve this — it runs once on `_MapView` first build, NOT on Stats route pop.
- Story 7.6 settings modal is unrelated; do not touch.
- Story 7.7 established the Tab DTO + Provider pattern. Our pattern is simpler (one `Provider<CountryId?>` driven by an event subscription), but we should follow the same naming and file-organization conventions (`lib/providers/map_focus_providers.dart`).
- Story 7.8 established the `lib/providers/leaders_providers.dart` pattern of narrow `_StateSlice` watches; we don't need that here because auto-focus uses `ref.read` (one-shot side effect) instead of `ref.watch`.
- Story 6.2 made `gameWorldEventsProvider` the canonical event keyhole. Reuse, don't add a parallel one.
- Story 6.5 modal host subscribes to `gameWorldEventsProvider` exactly once and cancels on dispose. Mirror that subscription discipline.
- Story 9-1 (tutorial state persistence) is still backlog. This story's `tutorialCompletedProvider` stub is the contract handoff: 9-1 only has to rewrite the provider body to make AC #5 fully effective.

### Architecture Compliance

- UI reads Riverpod providers and dispatches commands. UI never mutates `GameState` directly. This story dispatches no commands.
- Providers are the composition root. `recentlyUnlockedCountryProvider` and `tutorialCompletedProvider` belong in `lib/providers/`, not inside widgets.
- `lib/game/**` remains pure Dart. No Flutter imports, no widget helpers, no service calls. No `tutorialCompleted` field added — Story 9-1 owns that.
- `lib/data/**` remains untouched. No Drift, repository, mapper, schema, migration, or generated-file work. Tab selection is ephemeral.
- All game quantities remain `Influence`, `Intel`, or `Decimal` through existing value objects/helpers. Auto-focus math operates only on `Rect` / `Size` / `Matrix4` — Flutter-side geometry types.
- Navigation remains `BottomNavigationBar` + `IndexedStack`; no router package.
- One `Ticker` rule preserved (Epic 8 owns animated transitions; this story does an instant transform jump).
- Sealed `switch` exhaustiveness preserved: we add no new commands, events, or reducers.
- Accessibility: the map already wraps interactive surfaces in `Semantics`. Auto-focus does not change a11y semantics — it changes only the painter's transform matrix.

### Library / Framework Requirements

- Use the pinned project dependencies from `pubspec.yaml`: Flutter/Dart SDK, `flutter_riverpod: ^2.6.1`, `riverpod: ^2.6.1`, `decimal: ^3.0.2`, `collection: ^1.19.1`, `vector_math: ^2.1.4` (transitively, via Flutter — `MapScreen` already uses `Vector3`). Do not bump packages.
- Use manual Riverpod providers; the project does not use `riverpod_generator`.
- Flutter `WidgetsBinding.instance.addPostFrameCallback` is the correct hook for "do something after first layout" — it runs once after the next frame, and our `_autoFocusApplied` flag makes it idempotent. Source: https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html
- `Matrix4` composition follows the same translate → scale → translate-back pattern the existing `_onScaleUpdate` uses. Reuse the pattern; do not invent a new transform pipeline.
- `Rect.fromLTRB` + manual min/max accumulation is fine for the union bbox. The `rect_union` helper does not exist in Flutter — implement inline (5 lines).

### File Structure Requirements

Create:

| File | Purpose |
| --- | --- |
| `lib/ui/features/map/auto_focus_target.dart` | Pure `computeContinentFitTransform` function (Matrix4 math) |
| `lib/providers/map_focus_providers.dart` | `recentlyUnlockedCountryProvider` + `tutorialCompletedProvider` stub |
| `test/ui/features/map/auto_focus_target_test.dart` | Unit tests for the pure math function |
| `test/ui/features/map/map_auto_focus_test.dart` | Widget tests for `_MapView` auto-focus behavior |
| `test/providers/recently_unlocked_country_provider_test.dart` | Provider tests with a fake event stream |
| `test/providers/tutorial_completed_provider_test.dart` | Single-test stub to lock the default |

Modify:

| File | Purpose |
| --- | --- |
| `lib/ui/features/map/map_screen.dart` | Wire `_MapViewState` to call `_tryAutoFocus` from a post-frame callback; consume providers via `ref.read` |
| `test/ui/app_scaffold_test.dart` | Extend with cold-launch + lifecycle + auto-focus integration assertions (do not remove existing tests) |

Do not modify:

| Area | Reason |
| --- | --- |
| `lib/game/**` | No new state fields, commands, events, or reducers (Story 9-1 owns `tutorialCompleted`) |
| `lib/data/**` | No persistence/schema work |
| `lib/providers/upgrades_providers.dart`, `leaders_providers.dart`, `stats_providers.dart`, `modal_providers.dart`, `feature_providers.dart` | Out of scope |
| `lib/ui/features/upgrades/**`, `lib/ui/features/leaders/**`, `lib/ui/features/stats/**`, `lib/ui/features/settings/**`, `lib/ui/features/modals/**`, `lib/ui/features/achievements/**`, `lib/ui/features/minigames/**`, `lib/ui/features/hud/**` | Out of scope |
| `assets/**` | No content population or asset edits |
| `pubspec.yaml` | No new dependency |

### Testing Requirements

Provider tests should use `ProviderContainer` with overrides; do not boot real Drift or hit the real event stream.

Recommended provider-test shape (mirror 6.5/7.4):

```dart
final eventBus = StreamController<GameEvent>.broadcast(sync: true);
addTearDown(eventBus.close);

final container = ProviderContainer(
  overrides: [
    gameWorldEventsProvider.overrideWith((ref) => eventBus.stream),
  ],
);
addTearDown(container.dispose);

expect(container.read(recentlyUnlockedCountryProvider), isNull);

eventBus.add(CountryUnlocked(
  DateTime.utc(2026, 1, 1),
  countryId: const CountryId('egypt'),
  continent: const ContinentId('africa'),
  cost: Influence.zero,
));
// Pump microtask
await Future<void>.delayed(Duration.zero);
expect(container.read(recentlyUnlockedCountryProvider), const CountryId('egypt'));
```

Widget-test shape for auto-focus (extend the existing `test/ui/app_scaffold_test.dart` helpers):

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      geoProvider.overrideWith((ref) async => _fakeCountries),
      mapWidgetTestGameWorldOverride(initialStateWithEgyptUnlocked),
      gameWorldEventsProvider.overrideWith((ref) => eventBus.stream),
      tutorialCompletedProvider.overrideWith((ref) => true),
    ],
    child: MaterialApp(theme: appTheme(), home: const AppScaffold()),
  ),
);
await tester.pumpAndSettle();
expect(_mapPainter(tester).viewTransform, isNot(equals(Matrix4.identity())));
```

Use the existing `_matricesNearlyEqual` helper from `test/ui/app_scaffold_test.dart` (or copy it locally to the new test file) for tolerance comparisons.

### Out of Scope

- Tab selection persistence (Drift, SharedPreferences, or otherwise) — explicitly forbidden by AC #1.
- Animated camera moves / tweens (Epic 8 owns camera juice).
- Tutorial state field on `GameState`, tutorial overlay UI, tutorial step state machine, tutorial skip flow (Stories 9-1 through 9-4).
- Tutorial-step-driven map focus (Story 9-2 handles "auto-advance on triggering action" which may include focus shifts during tutorial).
- Continent progression visual indicators / progress bars / milestone tick marks (Story 7-10).
- Milestone glow polish, country pulse, flying numbers, SFX, haptics (Epic 8).
- New `GameCommand`, `GameEvent`, reducer, balance constant, or content field.
- Persistence write changes, Drift migrations, save repository edits.
- New packages or dependency bumps.
- Stats route, settings modal, upgrades tab, leaders tab, achievements screen, modal queue changes.
- Continent zoom-to-fit on Upgrades / Leaders headers — those tabs already render scrollable lists, not maps.
- Performance profiling beyond confirming the post-frame callback runs at most once. Epic 11 owns 60fps regression sweeps.

### Latest Technical Information

- Flutter `WidgetsBinding.instance.addPostFrameCallback((_) {...})` schedules a callback for after the current frame's layout/paint completes. It is the canonical hook for "do X once after first render." It fires exactly once per call; re-scheduling requires another call. Source: https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html
- Flutter `LayoutBuilder` exposes `BoxConstraints` to its builder; `constraints.biggest` gives the canvas `Size` available for the child. Use this for the auto-focus canvas size. Source: https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html
- Flutter `Matrix4.translationValues(...).multiplied(Matrix4.diagonal3Values(s, s, 1)).multiplied(...)` is the standard 2D transform-compose pattern. The existing `_onScaleUpdate` in `map_screen.dart` uses this exact pattern; auto-focus follows it. Source: https://api.flutter.dev/flutter/vector_math_64/Matrix4-class.html
- Riverpod `ref.read` inside a one-shot callback (rather than `ref.watch`) is the correct choice for side effects that should not rebuild the consumer. The auto-focus callback is a side effect, not a rebuild trigger. Source: https://riverpod.dev/docs/concepts/combining_providers#avoid-using-ref.read

### Git Intelligence Summary

Recent commits frame the current shell:

- `a6bbe42 feat(ui): priority modal queue, stats screen, and settings overlay` — Stories 7.4/7.5/7.6 wiring; do not touch their files.
- `8a74e35 feat(ui): global HUD, currency badges, stats and settings` — HUD lineage; unrelated.
- `0db66e0 feat(ui): extract AppScaffold with IndexedStack and Minigames tab` — established tab order. **Story 7.9 locks `_selectedIndex = 0` as the cold-launch default with explicit test coverage.**
- `7a28f09 feat(ui): design tokens, theme extensions, and tab scaffold` — token guardrails active.
- `ef0faba feat: save recovery on corrupt database and related UI` — do not disturb boot path; auto-focus runs after the bootstrap `.when` chain resolves.

Uncommitted in the working tree at story-creation time (Story 7.8 artifacts now `done`):

- `M _bmad-output/implementation-artifacts/7-7-upgrades-tab-unlocked-countries-next-unlock-teaser-per-continent.md`, `M _bmad-output/implementation-artifacts/sprint-status.yaml`, `M lib/ui/features/leaders/leaders_screen.dart`, `M lib/ui/features/upgrades/upgrades_screen.dart`, `?? _bmad-output/implementation-artifacts/7-8-leaders-tab-grouped-by-continent-accordion.md`, `?? lib/providers/leaders_providers.dart`, `?? lib/providers/upgrades_providers.dart`, `?? test/providers/leaders_providers_test.dart`, `?? test/providers/upgrades_providers_test.dart`, `?? test/ui/features/leaders/`, `?? test/ui/features/upgrades/` — Stories 7-7 and 7-8 artifacts. Do not revert or "clean up."

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` — Story 7.9]
- [Source: `_bmad-output/planning-artifacts/epics/epic-9-onboard-tutorial-and-contextual-hints.md` — Stories 9-1 through 9-4 (tutorial dependency)]
- [Source: `_bmad-output/planning-artifacts/gdd.md` — Core loop, Map as primary surface]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` — Riverpod, Navigation, IndexedStack]
- [Source: `_bmad-output/game-architecture/project-structure.md` — `lib/ui/features/map/`, `lib/providers/`, architectural boundaries]
- [Source: `_bmad-output/game-architecture/implementation-patterns.md` — Widget → Provider → Notifier]
- [Source: `_bmad-output/project-context.md` — architecture boundaries, token rules, value objects, forbidden packages, accessibility]
- [Source: `_bmad-output/implementation-artifacts/7-2-app-scaffold-with-5-tab-bottom-navigation-and-indexedstack.md` — IndexedStack tab order]
- [Source: `_bmad-output/implementation-artifacts/7-7-upgrades-tab-unlocked-countries-next-unlock-teaser-per-continent.md` — Tab DTO + Provider pattern]
- [Source: `_bmad-output/implementation-artifacts/7-8-leaders-tab-grouped-by-continent-accordion.md` — Previous story; narrow state slice provider pattern]
- [Source: `_bmad-output/implementation-artifacts/6-5-offline-reward-modal-on-resume.md` — `gameWorldEventsProvider` subscription discipline]
- [Source: `_bmad-output/implementation-artifacts/7-4-sequential-modal-queue-with-priority.md` — Event-stream provider override pattern for tests]
- [Source: `lib/ui/app_scaffold.dart` — tab order; cold-launch default `_selectedIndex = 0`]
- [Source: `lib/ui/features/map/map_screen.dart` — `_MapView` + `_viewTransform` + gesture pipeline to extend]
- [Source: `lib/ui/features/map/country_path.dart` — `CountryPath { id, continent, bbox, path, rings }`]
- [Source: `lib/ui/theme/spacing.dart` — `Spacing.lg = 24` used as padding in continent-fit math]
- [Source: `lib/providers/game_providers.dart` — `gameWorldProvider`, `gameWorldEventsProvider`, `GameWorldNotifier`]
- [Source: `lib/providers/geo_providers.dart` — `geoProvider` (already loaded once at boot)]
- [Source: `lib/providers/app_providers.dart` — `contentRegistryProvider`]
- [Source: `lib/game/game_event.dart` — `CountryUnlocked(at, countryId, continent, cost)`]
- [Source: `lib/game/game_state.dart` — `GameState.initialSeed()` seeds Egypt unlocked; **NO `tutorialCompleted` field today**]
- [Source: `lib/game/features/countries/country_state.dart` — `CountryState { id, unlocked, ipLevel, leaderTier, bankedInfluence, lastCollectedAt }`]
- [Source: `test/ui/app_scaffold_test.dart` — initial-tab + pan/zoom survival + Stats route push/pop tests to preserve & extend]
- [Source: `test/helpers/map_screen_test_providers.dart` — `mapWidgetTestGameWorldOverride([GameState? initial])`, `mapWidgetTestEmptyContent`]
- [Source: Flutter SchedulerBinding.addPostFrameCallback API — https://api.flutter.dev/flutter/scheduler/SchedulerBinding/addPostFrameCallback.html]
- [Source: Flutter LayoutBuilder API — https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html]
- [Source: Flutter Matrix4 API — https://api.flutter.dev/flutter/vector_math_64/Matrix4-class.html]
- [Source: Riverpod ref.read vs ref.watch guidance — https://riverpod.dev/docs/concepts/combining_providers#avoid-using-ref.read]

### Project Context Rules

Extracted from `_bmad-output/project-context.md` (authoritative source: `_bmad-output/game-architecture.md`):

- **Pinned versions only.** Flutter 3.41.6 / Dart `^3.11.4`, `flutter_riverpod ^2.6.1`, `decimal ^3.0.2`, `collection ^1.19.1`, `flutter_lints ^6.0.0`. Do not bump or add packages. No `freezed`, no `go_router`/`auto_route`, no `get_it`, no analytics SDKs, no animation packages.
- **`lib/game/` has zero Flutter imports** and never imports from `lib/data/`. This story does not touch `lib/game/**` at all.
- **UI never touches Drift directly.** Tab selection is ephemeral; no SharedPreferences, no Drift settings row.
- **UI never mutates `GameState` directly.** This story does not dispatch any commands.
- **Services subscribe to events; they never emit `GameEvent`s.** The `recentlyUnlockedCountryProvider` is a Riverpod provider, not a service — it consumes the event stream as a value, never re-emits.
- **Only `lib/providers/` imports `game/` + `data/` + `services/` together.** `recentlyUnlockedCountryProvider` lives there.
- **One `Ticker` only — owned by `GameLoop`.** Do not introduce animation controllers, custom tickers, or tweened transforms. The auto-focus transform jump is intentionally instant; animated camera moves are Epic 8.
- **Multiplier stack is locked in `IncomeCalculator`.** This story introduces zero income math.
- **Big numbers** flow through `Influence` / `Intel` value objects. Not used by this story (geometry only).
- **Riverpod `ref.read` for side effects, `ref.watch` for rebuilds.** Auto-focus is a one-shot side effect — use `ref.read` inside the post-frame callback. Subscribing to the event stream uses `ref.watch(gameWorldEventsProvider)` inside the provider definition (because the stream identity must be stable).
- **Sealed switch exhaustiveness.** This story does not add new commands or events.
- **Accessibility is not optional.** Auto-focus does not change a11y semantics — it changes only the painter's transform matrix. Country `Semantics` labels (Epic 11 / Story 11-1) are unaffected.
- **Tokens only — no raw colors.** `Theme.of(context).colorScheme`, `Spacing.*`, theme extensions only. Auto-focus math uses `Spacing.lg` for canvas padding.
- **Naming.** `snake_case.dart` files (`auto_focus_target.dart`, `map_focus_providers.dart`, `auto_focus_target_test.dart`, `map_auto_focus_test.dart`, `recently_unlocked_country_provider_test.dart`, `tutorial_completed_provider_test.dart`), `PascalCase` classes (`RecentlyUnlockedCountryNotifier`), `camelCase` providers (`recentlyUnlockedCountryProvider`, `tutorialCompletedProvider`), `camelCase` functions (`computeContinentFitTransform`).
- **No `print`.** Use `Logger('MapAutoFocus')` if logging becomes necessary (not expected; auto-focus is silent on failure).
- **No hot-path logging.** Auto-focus runs once per `_MapView` lifetime; this rule is naturally satisfied.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Claude Code)

### Debug Log References

- The post-frame callback in `_MapViewState.build()` reads `recentlyUnlockedCountryProvider` via `ref.read`. The notifier is lazy: it only subscribes to `gameWorldEventsProvider`'s stream when first read. In widget tests that emit `CountryUnlocked` *before* the post-frame fires, the event would otherwise be dropped (broadcast streams drop events without listeners). The dedicated provider tests cover the event-stream → state path exhaustively; the widget tests use `recentlyUnlockedCountryProvider.overrideWith(...)` for deterministic continent-target assertions.
- `pumpAndSettle` in `test/ui/app_scaffold_test.dart` cannot be used for the `tutorialCompleted=false` suppression test because the production AppScaffold tree mounts a `GameLoop`-driven HUD ticker that keeps requesting frames. Switched to manual `pump()` + frame-time advances.

### Completion Notes List

- AC #1, #2: `_AppScaffoldState._selectedIndex = 0` literal default preserved; new test asserts initial Map index survives a paused→resumed lifecycle cycle. No persistence introduced (Drift, SharedPreferences untouched).
- AC #3, #11: Continent-fit Matrix4 composition (`translate canvas-center → diagonal3Values(zoom, zoom, 1) → translate -bboxCenter`) implemented in pure `computeContinentFitTransform`; clamped `[1.0, 15.0]` with `Spacing.lg` padding.
- AC #4: Fallback iterates `widget.gameState.countries.entries` in content-insertion order and picks first unlocked country whose `CountryPath` is present in the geo list.
- AC #5: `_tryAutoFocus` early-returns without flipping `_autoFocusApplied` when `tutorialCompletedProvider` is `false`, leaving the transform at `Matrix4.identity()` and allowing Story 9-1 to flip the gate later.
- AC #6, #13: `_autoFocusApplied` is set inside the same `setState` that commits the transform; gesture handlers never touch it; IndexedStack keeps the state alive across tab switches.
- AC #7: `RecentlyUnlockedCountryNotifier` writes `state = e.countryId` on every `CountryUnlocked`; last event wins by virtue of stream order.
- AC #8: `geoProvider.when` gate in `MapScreen` still renders loading/error branches; `_MapView` (where auto-focus lives) is only built on the data branch.
- AC #9: When `recentlyUnlockedCountryProvider` is non-null but the country is absent from `widget.countries`, `target` falls through to the AC #4 fallback rule.
- AC #10, #14, #12: Post-frame callback registered from inside `LayoutBuilder.builder` so degenerate canvas frames silently return early without setting the flag; the next valid layout re-schedules naturally because `_autoFocusApplied` stays `false`.
- AC #15: Padding uses `Spacing.lg`; no raw colors introduced; design-token guardrail (`test/architecture/ui_design_tokens_test.dart`) passes.
- AC #16: Single post-frame callback per `_MapView` lifetime; the `RecentlyUnlockedCountryNotifier` subscribes once and cancels on dispose.
- AC #17: `flutter analyze` clean; full `flutter test` passes 1014/1014 (+24 over the 7-8 baseline of 990).
- AC #18: `lib/game/**`, `lib/data/**`, `assets/**`, and `pubspec.yaml` untouched. No new commands/events/reducers/schemas.
- AC #19: `computeContinentFitTransform` is a top-level pure function in `lib/ui/features/map/auto_focus_target.dart` with 9 dedicated unit tests covering single/multi-country continents, degenerate canvas (zero / NaN), missing continent, max-zoom and min-zoom clamps, and padding-swallow.
- AC #20: `recentlyUnlockedCountryProvider` is a `StateNotifierProvider`; subscription cancelled on `dispose`; never mutates `GameState`. Mirror of Story 6.5 / 7.4 subscription discipline.
- Sprint status preserved 7-7 and 7-8 worktree artifacts; no reverts.
- Review patch: `_MapViewState.initState()` now eagerly keeps `recentlyUnlockedCountryProvider` alive before the first post-frame focus decision; the focus decision remains a one-shot `ref.read` side effect.
- Review patch: fallback target resolution now uses `ContentRegistry.countries` order from `MapScreen`, not persisted `GameState.countries` map order.
- Review patch: terminal no-target skips mark auto-focus complete, while tutorial-blocked and degenerate-layout cases remain retryable without repeatedly queuing callbacks.
- Review patch verification: `flutter analyze` clean; full `flutter test` passes 1015/1015.

### File List

Created:

- `lib/ui/features/map/auto_focus_target.dart`
- `lib/providers/map_focus_providers.dart`
- `test/ui/features/map/auto_focus_target_test.dart`
- `test/ui/features/map/map_auto_focus_test.dart`
- `test/providers/recently_unlocked_country_provider_test.dart`
- `test/providers/tutorial_completed_provider_test.dart`

Modified:

- `lib/ui/features/map/map_screen.dart`
- `test/helpers/map_screen_test_providers.dart`
- `test/ui/app_scaffold_test.dart`
- `test/ui/features/map/world_map_painter_test.dart`
- `test/ui/features/map/map_screen_gesture_test.dart`
- `test/ui/features/map/map_screen_tap_test.dart`
- `test/ui/features/map/map_screen_golden_tap_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/7-9-map-as-default-cold-launch-screen-auto-focus-post-tutorial.md`

### Change Log

- 2026-05-15: Code review patches applied - eager recently-unlocked provider subscription before first focus decision, fallback target locked to `ContentRegistry.countries` order, terminal skip / retry scheduling separated, and isolated map widget tests updated with content-order fixtures. `flutter analyze` clean; full `flutter test` 1015 passing.

- 2026-05-15: Story 7-9 implemented — Map as cold-launch default + post-tutorial continent-fit auto-focus. New `lib/ui/features/map/auto_focus_target.dart` pure Matrix4 builder, new `lib/providers/map_focus_providers.dart` with `recentlyUnlockedCountryProvider` (StateNotifier on `gameWorldEventsProvider`) and `tutorialCompletedProvider` stub. `_MapViewState` extended with `_autoFocusApplied` flag and post-frame callback hook using `ref.read`. Pure-math + provider + widget + scaffold lifecycle tests added; full suite 1014 passing, `flutter analyze` clean. No `lib/game/**`, `lib/data/**`, or `pubspec.yaml` changes.
