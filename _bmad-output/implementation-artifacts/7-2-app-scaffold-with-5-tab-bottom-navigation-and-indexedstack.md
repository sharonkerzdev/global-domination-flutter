# Story 7.2: App Scaffold with 5-Tab Bottom Navigation and IndexedStack

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Story 7.1 is currently in progress in this workspace. Before coding this story, verify the theme-token work compiles and do not revert any existing 7.1 edits.

Required pre-checks:

- `lib/ui/theme/app_theme.dart` must remain the single runtime theme builder.
- `lib/ui/theme/spacing.dart`, `hud_palette.dart`, `milestone_colors.dart`, and `country_colors.dart` may already exist from Story 7.1; consume them if present instead of creating competing token files.
- If Story 7.1 has not finished applying `theme: appTheme()` to every `MaterialApp` branch, keep this story scoped to the app shell and do not turn it into a broad token refactor.
- Preserve Epic 6 boot ordering: `offlineRewardModalControllerProvider.notifier` is watched before `offlineCatchupBootProvider`, and `OfflineRewardModalHost` stays mounted around the game shell.
- Preserve save recovery, boot error, persisted snapshot loading, save repository bootstrap, and lifecycle observer behavior.
- Do not implement the global HUD, generic modal queue, Stats screen, Settings modal, Upgrades feature UI, Leaders feature UI, tutorial auto-focus, or continent progress indicators. Those belong to Stories 7.3 through 7.10.

## Story

As a player,
I want five tabs across the bottom (Map, Upgrades, Leaders, Achievements, Minigames) and switching between them should not reparse the world map,
so that the app feels snappy and the map preserves pan/zoom state.

## Acceptance Criteria

1. Given the app has finished existing database/content/snapshot/offline boot gates, when the main game shell renders, then it uses `AppScaffold` from `lib/ui/app_scaffold.dart` as the primary shell.

2. Given `AppScaffold` renders, when I inspect the bottom navigation, then a `BottomNavigationBar` shows exactly five tabs in this order: Map, Upgrades, Leaders, Achievements, Minigames.

3. Given the bottom navigation renders five destinations, when the bar is built, then every destination has both a Material icon and a text label, `type` is explicitly `BottomNavigationBarType.fixed`, and the selected tab index is reflected by `currentIndex`.

4. Given the app starts from a cold launch, when `AppScaffold` initializes, then the selected tab is Map at index `0`. Do not persist or restore the last selected tab in this story.

5. Given I tap a non-selected bottom tab, when the tap completes, then only the selected index changes; the root `MaterialApp`, Riverpod `ProviderScope`, database bootstrap, content registry, `GameLoop`, and `OfflineRewardModalHost` are not recreated by tab selection code.

6. Given the tab body is rendered, when switching tabs, then `AppScaffold` uses `IndexedStack(index: selectedIndex, children: ...)` so all tab widget trees remain alive.

7. Given I pan or zoom on the Map tab, switch to Upgrades, then switch back to Map, when the map reappears, then the `WorldMapPainter.viewTransform` matches the transform from before tab switching.

8. Given the map has already loaded, when I switch away from Map and back repeatedly, then `assets/geo/countries.geojson.json` is not loaded or parsed again due to tab switching. The existing `geoProvider` remains the only GeoJSON loading path.

9. Given the Minigames tab is selected, when it renders, then it shows a token-styled placeholder screen containing "Coming Soon" and a brief message. It must not add gameplay, routing, or persistence.

10. Given Upgrades, Leaders, and Achievements tabs are selected, when they render, then each shows a lightweight token-styled placeholder screen that can be replaced by later stories. Do not implement feature logic, commands, reducers, or persistence for those tabs in this story.

11. Given Story 7.6 has not landed, when the temporary 5-second Support long-press path exists in `lib/app.dart`, then this story preserves that path or moves it around the new shell without removing release-accessible crash-log support.

12. Given the game loop exists, when this shell lands, then there is still exactly one app ticker: `GameLoop` remains the only owner of `SingleTickerProviderStateMixin`/`Ticker` for runtime gameplay.

13. Given this story changes UI widgets, when tests run, then all new interactive bottom-nav items meet accessibility basics through Material semantics and 44/48dp-class tap targets. Do not introduce emoji icons or image assets for nav icons.

14. Given the implementation is complete, when verification runs, then `flutter analyze`, `flutter test test/ui/app_scaffold_test.dart`, existing map widget tests, and offline reward modal host tests pass.

## Tasks / Subtasks

- [ ] Task 1: Create the shell widget (AC: #1, #2, #3, #4, #6, #13)
  - [ ] 1.1 Add `lib/ui/app_scaffold.dart`.
  - [ ] 1.2 Implement `AppScaffold` as a `StatefulWidget` with private selected-index state initialized to `0`.
  - [ ] 1.3 Build a root `Scaffold` with `body: IndexedStack(...)` and `bottomNavigationBar: BottomNavigationBar(...)`.
  - [ ] 1.4 Define the five nav items in one private constant/list in Map, Upgrades, Leaders, Achievements, Minigames order.
  - [ ] 1.5 Use Material icons from `Icons.*` only. Suggested icons: `Icons.public`, `Icons.trending_up`, `Icons.groups`, `Icons.emoji_events`, `Icons.sports_esports`.
  - [ ] 1.6 Set `BottomNavigationBarType.fixed` explicitly because Flutter defaults to shifting behavior for four or more items.
  - [ ] 1.7 Style selected/unselected colors from `Theme.of(context).colorScheme` or Story 7.1 tokens. Do not introduce raw widget colors.

- [ ] Task 2: Add placeholder tab screens without feature creep (AC: #9, #10, #13)
  - [ ] 2.1 Add lightweight placeholder screens for Upgrades, Leaders, Achievements, and Minigames.
  - [ ] 2.2 Preferred file locations:
    - `lib/ui/features/upgrades/upgrades_screen.dart`
    - `lib/ui/features/leaders/leaders_screen.dart`
    - `lib/ui/features/achievements/achievements_screen.dart`
    - `lib/ui/features/minigames/minigames_screen.dart`
  - [ ] 2.3 Keep placeholder screens UI-only and token-styled with `Spacing.*`, `Theme.of(context).textTheme`, and `ColorScheme`.
  - [ ] 2.4 Minigames must include the required "Coming Soon" text.
  - [ ] 2.5 Upgrades and Leaders placeholders must not dispatch `PurchaseUpgrade`, `UnlockCountry`, `HireLeader`, or `UpgradeLeader`; those belong to Stories 7.7 and 7.8.
  - [ ] 2.6 Achievements placeholder must not change `earnedAchievementIds`, achievement reducer behavior, or achievement content.

- [ ] Task 3: Wire AppScaffold into booted app flow (AC: #1, #5, #11, #12)
  - [ ] 3.1 Update `lib/app.dart` final successful boot branch to render `AppScaffold` instead of `MapScreen` as the direct game screen.
  - [ ] 3.2 Keep `OfflineRewardModalHost` outside the game shell exactly as the modal host for boot/resume offline rewards.
  - [ ] 3.3 Keep `_SaveRepositoryBootstrap` and `GameLifecycleObserver` behavior unchanged.
  - [ ] 3.4 Wrap the whole shell in the existing `GameLoop`, not just the Map tab, so simulation continues while the player views other tabs.
  - [ ] 3.5 Preserve the temporary Support long-press trigger until Story 7.6 replaces it with the HUD gear/settings path.
  - [ ] 3.6 Do not add another `MaterialApp`, nested `ProviderScope`, database bootstrap, content bootstrap, or ticker inside `AppScaffold`.

- [ ] Task 4: Preserve map state and GeoJSON loading behavior (AC: #6, #7, #8)
  - [ ] 4.1 Keep the Map tab child as the existing `MapScreen`; do not rewrite map gesture, painter, hit-test, or provider logic.
  - [ ] 4.2 Ensure `IndexedStack` keeps `MapScreen` and its `_MapViewState` alive while other tabs are selected.
  - [ ] 4.3 Do not call `rootBundle.loadString('assets/geo/countries.geojson.json')` anywhere outside `geoProvider`.
  - [ ] 4.4 Do not move GeoJSON parsing into `AppScaffold`, placeholder tabs, or `app.dart`.
  - [ ] 4.5 Avoid `PageView`, `TabBarView`, `Navigator` per tab, or rebuilding the selected tab with a `switch` that drops inactive tab subtrees.

- [ ] Task 5: Widget and architecture tests (AC: #2, #3, #4, #6, #7, #8, #9, #12, #14)
  - [ ] 5.1 Add `test/ui/app_scaffold_test.dart`.
  - [ ] 5.2 Test the bottom nav has exactly five labeled items in the required order and uses `BottomNavigationBarType.fixed`.
  - [ ] 5.3 Test `AppScaffold` contains an `IndexedStack` whose `index` changes when tapping each tab.
  - [ ] 5.4 Test initial selected tab is Map.
  - [ ] 5.5 Test Minigames tab renders "Coming Soon".
  - [ ] 5.6 Test map pan/zoom transform survives tab switching by reading `WorldMapPainter.viewTransform` before and after switching away/back.
  - [ ] 5.7 Test GeoJSON provider load count remains `1` across repeated tab switches using a provider override around `geoProvider`.
  - [ ] 5.8 Add or extend a small architecture/widget test that fails if `AppScaffold` imports database/repository classes directly.
  - [ ] 5.9 Existing map tests should continue to pump `MaterialApp(theme: appTheme(), home: const MapScreen())`; do not force them through `AppScaffold` unless the test purpose is shell integration.

- [ ] Task 6: Verification (AC: all)
  - [ ] 6.1 Run `dart format --set-exit-if-changed` on changed Dart files.
  - [ ] 6.2 Run `flutter test test/ui/app_scaffold_test.dart`.
  - [ ] 6.3 Run `flutter test test/ui/features/map`.
  - [ ] 6.4 Run `flutter test test/ui/features/modals/offline_reward_modal_host_test.dart`.
  - [ ] 6.5 Run `flutter test test/architecture`.
  - [ ] 6.6 Run `flutter analyze`.
  - [ ] 6.7 Run full `flutter test` if time permits.

## Dev Notes

### Implementation Scope

This story creates the app shell only. The shell should feel production-shaped, but non-map tab content is intentionally placeholder-level until later stories supply real screens.

The intended successful boot shape is:

```dart
MaterialApp(
  theme: _theme,
  home: const OfflineRewardModalHost(
    child: _SaveRepositoryBootstrap(
      child: _GameScreen(), // wraps GameLoop + AppScaffold + temporary support long-press
    ),
  ),
)
```

Inside `_GameScreen`, the child should become `const GameLoop(child: AppScaffold())` or equivalent. Keep the temporary support long-press wrapper from current `app.dart`.

### Current Codebase Observations

- `lib/ui/app_scaffold.dart` does not exist yet.
- `lib/app.dart` currently reaches `OfflineRewardModalHost(child: _SaveRepositoryBootstrap(child: _GameScreen()))` after all boot gates pass.
- `_GameScreen` currently wraps `GameLoop(child: MapScreen())` and owns a temporary 5-second long-press path to `SupportScreen`.
- `GameLoop` in `lib/ui/features/map/game_loop.dart` owns the single `Ticker`, stops on pause/inactive/hidden/detached, runs offline catch-up before restarting on resume, and absorbs pointer input during resume catch-up.
- `MapScreen` stores pan/zoom in `_MapViewState._viewTransform` and builds `WorldMapPainter` with that transform.
- `geoProvider` in `lib/providers/geo_providers.dart` is the only production loader for `assets/geo/countries.geojson.json`; its comment already anticipates `IndexedStack`.
- Existing map widget tests use provider overrides from `test/helpers/map_screen_test_providers.dart`; reuse these patterns for shell tests.
- Story 7.1 token files are in progress in this workspace. Use the current token files if they exist and do not overwrite them.

### Previous Story Intelligence

- Story 7.1 explicitly excluded bottom navigation, global HUD, modal queue, settings, Upgrades, Leaders, and Stats. This story may now introduce bottom navigation and placeholder tab roots, but it must not pull in the later feature work.
- Story 7.1 established the expectation that UI colors/spacing/typography come from `appTheme()`, `ThemeExtension`s, `ColorScheme`, `textTheme`, and `Spacing.*`.
- Story 6.5 found that offline reward modal subscription order matters. In `app.dart`, keep `ref.watch(offlineRewardModalControllerProvider.notifier)` before `offlineCatchupBootProvider`.
- Story 6.6 recently changed save recovery and corrupt database flows. Do not alter `SaveRecoveryScreen`, `SaveRecoveryActions`, database bootstrap, or backup quarantine behavior for this shell story.

### Architecture Compliance

- Navigation decision is already made: `BottomNavigationBar` plus `IndexedStack`, with Navigator 1.0 for future pushes. Do not add `go_router`, `auto_route`, or a per-tab router.
- `AppScaffold` belongs in `lib/ui/app_scaffold.dart`.
- UI widgets can import providers and UI helpers, but must not import Drift database classes or repositories directly.
- `lib/game/**` remains untouched. No Flutter imports, no new game commands/events, no reducer work.
- Do not add packages or bump versions.
- Do not create a second ticker, animation controller, or game loop for tab switching.
- Keep Material icon usage through `uses-material-design: true`; do not add bitmap nav assets.
- All placeholder UI must be portrait/mobile-first and must avoid cards-inside-cards or marketing-style landing content.

### Library / Framework Requirements

- Flutter `BottomNavigationBar` is appropriate for selecting between a small number of top-level views and is commonly placed in `Scaffold.bottomNavigationBar`. The docs describe it for "three to five" views, matching this story's five tabs. Source: https://api.flutter.dev/flutter/material/BottomNavigationBar-class.html
- Flutter docs note `BottomNavigationBar` defaults to shifting behavior when there are four or more items. Set `type: BottomNavigationBarType.fixed` explicitly so the five-tab shell remains stable and token-styled. Source: https://api.flutter.dev/flutter/material/BottomNavigationBar-class.html
- Flutter docs say `NavigationBar` is preferred for new Material 3 apps, but this project architecture explicitly selected `BottomNavigationBar + IndexedStack`; follow architecture, do not migrate this story to `NavigationBar`. Source: `_bmad-output/game-architecture/architectural-decisions.md` and https://api.flutter.dev/flutter/material/BottomNavigationBar-class.html
- `IndexedStack` shows one child at the selected index while keeping the child list in the tree; this is the required mechanism for preserving Map tab state. Source: https://api.flutter.dev/flutter/widgets/IndexedStack-class.html
- `AutomaticKeepAliveClientMixin` is for lazily built lists/slivers and is not a substitute for the shell-level `IndexedStack` requirement. Source: https://api.flutter.dev/flutter/widgets/AutomaticKeepAliveClientMixin-mixin.html

### File Structure Requirements

Create:

| File | Purpose |
| --- | --- |
| `lib/ui/app_scaffold.dart` | Bottom navigation plus `IndexedStack` shell |
| `lib/ui/features/upgrades/upgrades_screen.dart` | Placeholder root for future Story 7.7 implementation |
| `lib/ui/features/leaders/leaders_screen.dart` | Placeholder root for future Story 7.8 implementation |
| `lib/ui/features/achievements/achievements_screen.dart` | Placeholder root for Achievements tab |
| `lib/ui/features/minigames/minigames_screen.dart` | Required "Coming Soon" placeholder |
| `test/ui/app_scaffold_test.dart` | Shell navigation, IndexedStack, map state preservation tests |

Modify:

| File | Purpose |
| --- | --- |
| `lib/app.dart` | Swap final successful boot child from direct `MapScreen` to `AppScaffold` under existing `GameLoop`/support wrapper |
| Existing map/widget tests if needed | Only adjust imports/pump wrappers if shell integration requires it |

Do not modify:

| File area | Reason |
| --- | --- |
| `lib/game/**` | No simulation changes in this story |
| `lib/data/**` | No persistence or migration work in this story |
| `lib/providers/geo_providers.dart` | GeoJSON loading path already exists |
| `lib/providers/modal_providers.dart` | Generic modal queue is Story 7.4; offline-only queue stays as-is |

### Testing Requirements

Use widget tests with Riverpod overrides rather than real database/content boot. Follow existing map test patterns:

```dart
ProviderScope(
  overrides: [
    geoProvider.overrideWith((ref) async => fakeCountries),
    mapWidgetTestGameWorldOverride(),
  ],
  child: MaterialApp(theme: appTheme(), home: const AppScaffold()),
)
```

For the map-state test:

1. Pump `AppScaffold`.
2. Wait for the fake `geoProvider`.
3. Drag or pinch on the Map tab.
4. Capture `WorldMapPainter.viewTransform`.
5. Tap Upgrades, then tap Map.
6. Assert the new `WorldMapPainter.viewTransform` equals the captured transform.

For the no-reparse test, use an override that increments a local counter when `geoProvider` resolves and assert it stays at `1` after repeated tab switches. This complements, but does not replace, the transform preservation test.

### Out of Scope

- Real global HUD and currency badges.
- `CurrencyBadge` and animated counters.
- Stats screen push from HUD.
- Settings modal and settings persistence.
- Generic priority modal queue.
- Upgrades list/card/bulk purchase UI.
- Leaders accordion UI.
- Achievement list/detail UI beyond a placeholder.
- Tutorial-aware map auto-focus.
- Continent progress bars.
- Any new game command, event, reducer, content JSON, Drift table, or migration.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` - Story 7.2]
- [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` - FR28, FR30, NFR18, NFR21, NFR22]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` - Navigation, Theme & Design Tokens]
- [Source: `_bmad-output/game-architecture/project-structure.md` - `lib/ui/app_scaffold.dart` and UI shell mapping]
- [Source: `_bmad-output/project-context.md` - Technology stack, architectural boundaries, performance rules]
- [Source: `_bmad-output/implementation-artifacts/7-1-theme-tokens-and-design-system-foundation.md` - previous story scope and token guidance]
- [Source: `lib/app.dart` - current boot, modal host, support long-press, and game loop wiring]
- [Source: `lib/ui/features/map/map_screen.dart` - current map transform state and painter wiring]
- [Source: `lib/providers/geo_providers.dart` - GeoJSON loading path]
- [Source: Flutter BottomNavigationBar API - https://api.flutter.dev/flutter/material/BottomNavigationBar-class.html]
- [Source: Flutter IndexedStack API - https://api.flutter.dev/flutter/widgets/IndexedStack-class.html]
- [Source: Flutter AutomaticKeepAliveClientMixin API - https://api.flutter.dev/flutter/widgets/AutomaticKeepAliveClientMixin-mixin.html]

## Dev Agent Record

### Agent Model Used

TBD by dev agent.

### Debug Log References

### Completion Notes List

### File List

## Story Completion Status

Ultimate context engine analysis completed - comprehensive developer guide created.
