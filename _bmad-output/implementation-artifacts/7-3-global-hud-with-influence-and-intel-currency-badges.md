# Story 7.3: Global HUD With Influence and Intel Currency Badges

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Story 7.3 depends on the Story 7.2 shell. At story creation time, `lib/ui/app_scaffold.dart` is not present in `lib/`, while the Story 7.2 file is already created as ready-for-dev. Do not build a competing shell in this story. Start this story only after Story 7.2 has landed, or integrate into the current `AppScaffold` if it already exists when implementation begins.

Before coding, verify:

- `lib/ui/app_scaffold.dart` exists and owns the bottom navigation plus `IndexedStack`.
- `AppScaffold` still renders five tabs in Map, Upgrades, Leaders, Achievements, Minigames order.
- `AppScaffold` still keeps the Map tab alive with `IndexedStack`; do not change it to a `switch`, `PageView`, per-tab `Navigator`, or lazy tab rebuild.
- `lib/ui/theme/app_theme.dart`, `spacing.dart`, `hud_palette.dart`, `milestone_colors.dart`, and `country_colors.dart` may contain in-progress Story 7.1 edits; consume the current token files instead of replacing them.
- `lib/app.dart` still watches `offlineRewardModalControllerProvider.notifier` before `offlineCatchupBootProvider`.
- `OfflineRewardModalHost` remains outside the game shell and still displays offline rewards before other post-resume UI.
- `_GameScreen` still wraps the shell in the existing `GameLoop`; do not create another app-level ticker.
- The temporary release-accessible Support long-press path from `lib/app.dart` remains until Story 7.6 replaces it with the real settings/support path.

If Story 7.2 has not landed, stop and complete Story 7.2 first. This story should not be implemented against direct `GameLoop(child: MapScreen())` wiring.

## Story

As a player,
I want a top-bar HUD visible on all tabs showing my Influence and Intel totals with icons,
so that I always know my resources without switching screens.

## Acceptance Criteria

1. Given the booted game shell is visible on any tab, when `AppScaffold` renders, then a global top HUD appears above the selected tab content and below the safe-area top inset.

2. Given the global HUD renders, when inspected, then it shows exactly these primary elements in one stable top bar: an Influence currency badge, an Intel currency badge, a stats icon button, and a settings gear icon button.

3. Given the player switches between Map, Upgrades, Leaders, Achievements, and Minigames tabs, when each tab is selected, then the same global HUD remains visible and is not duplicated inside individual tab screens.

4. Given the Map tab renders after this story, when the global HUD is present, then the old temporary centered `MapScreen` Influence pill is removed so Influence is not shown twice.

5. Given Influence changes, when `totalInfluenceProvider` emits, then only HUD consumers that depend on `totalInfluence` rebuild and the Influence badge updates to the new `Influence.format()` value.

6. Given Intel changes, when `totalIntelProvider` emits, then only HUD consumers that depend on `totalIntel` rebuild and the Intel badge updates to the new `Intel.format()` value.

7. Given a HUD currency value changes, when the displayed value updates, then the badge uses an `AnimatedCounter` presentation that visually transitions from the previous formatted value to the new formatted value over approximately 400ms.

8. Given values may reach late-game scale, when `AnimatedCounter` handles large values such as `1e38`, then it does not convert game currency to `double` for economy meaning and never feeds interpolated display values back into game state, persistence, or reducers.

9. Given a `CurrencyBadge` is used for Influence or Intel, when rendered in the HUD, then icon, accent color, foreground/background, border radius, typography, spacing, and formatting all come from `appTheme()` tokens, `HudPalette`, `Spacing.*`, `textTheme`, and the existing `Influence` / `Intel` formatters.

10. Given future upgrade cards, reward modals, and mission rows need currency display, when they reuse `CurrencyBadge`, then they can render Influence and Intel consistently without duplicating icon, color, spacing, or formatter logic.

11. Given the player taps the stats icon, when the tap completes, then a Navigator 1.0 route is pushed on top of the current shell. This story may provide only a lightweight Stats placeholder surface; the real reactive Stats screen contents remain Story 7.5.

12. Given the player taps the settings gear, when the tap completes, then a modal surface opens over the current shell. This story may provide only a lightweight Settings placeholder surface; real settings toggles, persistence, credits, and Support long-press integration remain Story 7.6.

13. Given stats/settings placeholder surfaces are added in this story, when rendered, then they contain only minimal shell wiring needed for the HUD actions. Do not implement full stats metrics, sound/haptics settings, Drift settings persistence, or the Story 7.4 modal queue.

14. Given the HUD contains icon buttons, when inspected by accessibility tooling, then both buttons have readable tooltips and `Semantics` labels, and each hit target meets the 44/48dp mobile minimum.

15. Given currency badges are interactive-looking but not tappable, when screen readers traverse the HUD, then each badge has a readable semantic label such as `Influence 1.2K` or `Intel 45`.

16. Given the game loop exists, when this HUD lands, then `GameLoop` remains the only explicit owner of `Ticker` / `SingleTickerProviderStateMixin` / `TickerProviderStateMixin` in runtime gameplay code. Do not add an app-level animation controller for the HUD.

17. Given this story is complete, when verification runs, then `flutter analyze`, HUD widget tests, provider selector tests, app scaffold integration tests, map widget tests, offline reward modal host tests, and architecture tests pass.

## Tasks / Subtasks

- [ ] Task 1: Add fine-grained currency providers (AC: #5, #6)
  - [ ] 1.1 Add `totalInfluenceProvider` and `totalIntelProvider` as Riverpod `Provider`s, preferably in `lib/providers/feature_providers.dart` unless that file has been reorganized by prior work.
  - [ ] 1.2 Implement both with `ref.watch(gameWorldProvider.select((state) => state.totalInfluence))` and `ref.watch(gameWorldProvider.select((state) => state.totalIntel))`.
  - [ ] 1.3 Return typed `Influence` and `Intel` values, not `Decimal`, `num`, `double`, or preformatted strings.
  - [ ] 1.4 Do not change `GameState`, `GameWorld`, `GameEvent`, Drift schema, save repository behavior, or persistence cadence.
  - [ ] 1.5 Add provider tests proving each provider emits only the selected currency and can be overridden in widget tests.

- [ ] Task 2: Create reusable currency display widgets (AC: #7, #8, #9, #10, #15, #16)
  - [ ] 2.1 Add `lib/ui/widgets/currency_badge.dart`.
  - [ ] 2.2 Expose clear Influence and Intel usage paths, such as `CurrencyBadge.influence(value: ...)` and `CurrencyBadge.intel(value: ...)`, or an equivalent small typed API.
  - [ ] 2.3 Use existing value-object formatters: `Influence.format()` and `Intel.format()`. Do not add a second formatter.
  - [ ] 2.4 Use Material icons only. Suggested defaults: `Icons.public` for Influence and `Icons.memory` for Intel. Do not use emoji or bitmap assets.
  - [ ] 2.5 Pull colors and shape from `HudPalette`; extend `HudPalette` only if needed, and preserve existing Story 7.1 token fields.
  - [ ] 2.6 Use `Spacing.*` and `Theme.of(context).textTheme` for layout and typography.
  - [ ] 2.7 Add a semantics label that includes currency name and formatted value.
  - [ ] 2.8 Add `lib/ui/widgets/animated_counter.dart` or an equivalent local widget used by `CurrencyBadge`.
  - [ ] 2.9 Keep animation implementation compatible with the single explicit ticker rule: do not add `AnimationController`, `Ticker`, `SingleTickerProviderStateMixin`, or `TickerProviderStateMixin` to runtime HUD code. Prefer a small implicit display transition or a widget that can later be moved onto the shared Epic 8 ticker budget.
  - [ ] 2.10 If interpolating numeric display, keep interpolation display-only, use value-object / `Decimal` math where currency magnitude matters, and test a `1e38` value so no `double` overflow or precision crash appears.

- [ ] Task 3: Add the global HUD widget (AC: #1, #2, #3, #5, #6, #11, #12, #14)
  - [ ] 3.1 Add `lib/ui/features/hud/global_hud.dart`.
  - [ ] 3.2 Implement `GlobalHud` as a `ConsumerWidget` or small widget tree that watches `totalInfluenceProvider` and `totalIntelProvider`.
  - [ ] 3.3 Keep provider watches narrow; do not watch the entire `GameState` in the HUD.
  - [ ] 3.4 Layout must be portrait/mobile-first and stable at narrow widths. Use compact badges, icon buttons, `SafeArea`, and responsive constraints so values and icons do not overlap.
  - [ ] 3.5 The top bar should be a shell element, not a floating card inside another card. Use a full-width top bar or unframed layout consistent with the app shell.
  - [ ] 3.6 Add stats and settings icon buttons with tooltips and semantic labels.
  - [ ] 3.7 Wire stats with `Navigator.of(context).push(...)` using Navigator 1.0. Do not add `go_router`, `auto_route`, or per-tab routers.
  - [ ] 3.8 Wire settings with `showModalBottomSheet` or `showDialog`, using current Material theme tokens. Do not integrate with Story 7.4's future modal queue.

- [ ] Task 4: Integrate HUD into AppScaffold (AC: #1, #3, #4, #11, #12, #16)
  - [ ] 4.1 Modify `lib/ui/app_scaffold.dart` from Story 7.2 so the root scaffold body contains the global HUD once above the tab `IndexedStack`.
  - [ ] 4.2 Preserve the existing `BottomNavigationBar`, selected index state, tab order, placeholder screens, and `IndexedStack(index: selectedIndex, children: ...)`.
  - [ ] 4.3 Keep the Map tab child as the existing `MapScreen`; do not rewrite map gestures, painter, hit-testing, GeoJSON loading, or provider wiring.
  - [ ] 4.4 Remove the temporary Influence pill from `lib/ui/features/map/map_screen.dart` after the global HUD is mounted.
  - [ ] 4.5 Do not add another `MaterialApp`, `ProviderScope`, database bootstrap, content bootstrap, modal host, or ticker inside `GlobalHud` or `AppScaffold`.
  - [ ] 4.6 Keep the temporary Support long-press wrapper in `lib/app.dart` unchanged until Story 7.6.

- [ ] Task 5: Add minimal placeholder action surfaces only if absent (AC: #11, #12, #13)
  - [ ] 5.1 If no Stats surface exists, add a lightweight placeholder at `lib/ui/features/stats/stats_screen.dart` so the HUD route can push a real widget path that Story 7.5 will expand.
  - [ ] 5.2 The placeholder may show only a themed app bar/title or similarly minimal surface. Avoid explanatory "coming soon" feature-description copy. Do not compute total countries, continents, achievements, or multipliers in this story.
  - [ ] 5.3 If no Settings surface exists, add a lightweight modal widget at `lib/ui/features/settings/settings_modal.dart` or `lib/ui/features/settings/settings_sheet.dart` so the HUD gear opens a modal path that Story 7.6 will expand.
  - [ ] 5.4 The placeholder must not add explanatory settings copy, settings toggles, settings repository calls, Drift tables, sound/haptics side effects, credits links, or Support screen long-press integration.
  - [ ] 5.5 Keep these placeholders easy to replace without changing the HUD public action wiring.

- [ ] Task 6: Widget, provider, and architecture tests (AC: #3, #4, #5, #6, #7, #8, #10, #11, #12, #14, #15, #16, #17)
  - [ ] 6.1 Add `test/providers/feature_providers_test.dart` coverage for `totalInfluenceProvider` and `totalIntelProvider`, or extend the existing file if present.
  - [ ] 6.2 Add `test/ui/widgets/currency_badge_test.dart` for Influence and Intel labels, icons, formatted values, semantics, token usage, and large values.
  - [ ] 6.3 Add `test/ui/widgets/animated_counter_test.dart` or cover the counter through `CurrencyBadge` tests, including a value-change transition around 400ms.
  - [ ] 6.4 Add `test/ui/features/hud/global_hud_test.dart` for both badges, stats/settings buttons, semantics labels, and action wiring.
  - [ ] 6.5 Extend `test/ui/app_scaffold_test.dart` from Story 7.2 to prove the HUD remains visible on every tab and is only mounted once.
  - [ ] 6.6 Extend or add a map test proving the old temporary `MapScreen` Influence pill no longer appears once rendered under `AppScaffold`.
  - [ ] 6.7 Add a guardrail test that HUD runtime files do not contain `AnimationController`, `createTicker`, `SingleTickerProviderStateMixin`, or `TickerProviderStateMixin`.
  - [ ] 6.8 Re-run the UI design-token architecture test from Story 7.1 so new HUD/settings/stats files do not introduce raw widget colors.

- [ ] Task 7: Verification (AC: all)
  - [ ] 7.1 Run `dart format --set-exit-if-changed` on changed Dart files.
  - [ ] 7.2 Run `flutter test test/providers/feature_providers_test.dart`.
  - [ ] 7.3 Run `flutter test test/ui/widgets/currency_badge_test.dart` and any `animated_counter` widget tests.
  - [ ] 7.4 Run `flutter test test/ui/features/hud`.
  - [ ] 7.5 Run `flutter test test/ui/app_scaffold_test.dart`.
  - [ ] 7.6 Run `flutter test test/ui/features/map`.
  - [ ] 7.7 Run `flutter test test/ui/features/modals/offline_reward_modal_host_test.dart`.
  - [ ] 7.8 Run `flutter test test/architecture`.
  - [ ] 7.9 Run `flutter analyze`.
  - [ ] 7.10 Run full `flutter test` if time permits.

## Dev Notes

### Implementation Scope

This story creates the app-wide resource HUD and reusable currency badge primitives. It should make the app feel like a coherent shell without implementing the full Stats, Settings, modal queue, Upgrades, Leaders, or Achievements feature screens.

The intended post-7.2 structure is:

```dart
class AppScaffold extends StatefulWidget { ... }

// Build shape, not exact code:
Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        const GlobalHud(),
        Expanded(
          child: IndexedStack(
            index: selectedIndex,
            children: const [
              MapScreen(),
              UpgradesScreen(),
              LeadersScreen(),
              AchievementsScreen(),
              MinigamesScreen(),
            ],
          ),
        ),
      ],
    ),
  ),
  bottomNavigationBar: BottomNavigationBar(...),
)
```

If Story 7.2 uses a slightly different shell layout, adapt to it while preserving the same requirements: HUD once, above tab content, bottom nav persistent, `IndexedStack` preserved.

### Current Codebase Observations

- `lib/ui/app_scaffold.dart` is absent at story creation time; Story 7.2 owns creating it.
- `lib/app.dart` currently reaches `OfflineRewardModalHost(child: _SaveRepositoryBootstrap(child: _GameScreen()))` after boot gates.
- `_GameScreen` currently wraps direct map content with `GameLoop(child: MapScreen())` and owns a temporary 5-second Support long-press path.
- `lib/ui/features/map/map_screen.dart` currently contains a temporary centered Influence pill using `HudPalette` and `Spacing`. This must be removed when the global HUD lands.
- `lib/ui/theme/hud_palette.dart`, `spacing.dart`, and `milestone_colors.dart` exist as Story 7.1 in-progress/untracked files in this workspace. Treat them as current local work and extend carefully if needed.
- `lib/providers/feature_providers.dart` currently contains derived providers for next unlock and daily reward availability, but no `totalInfluenceProvider` or `totalIntelProvider`.
- `lib/game/values/influence.dart` and `lib/game/values/intel.dart` both expose `format()` through the existing `InfluenceFormatter.abbreviated(...)`.
- No `lib/ui/features/hud/`, `lib/ui/features/stats/`, or `lib/ui/features/settings/` production files are present at story creation time.
- Existing map widget tests use `ProviderScope` overrides from `test/helpers/map_screen_test_providers.dart`; reuse that pattern instead of booting real content or Drift in HUD/shell tests.

### Previous Story Intelligence

- Story 7.1 established the token system expectation: `appTheme()`, `ThemeExtension`s, `HudPalette`, `MilestoneColors`, `CountryColors`, and `Spacing.*` are the sources for UI colors/spacing/typography. Do not introduce raw widget color literals outside theme files.
- Story 7.2 is the immediate dependency and owns bottom navigation, placeholder tab roots, and `IndexedStack` map preservation. This story should only modify that shell to add the HUD.
- Story 2.6 explicitly deferred HUD reactive update behavior to Epic 7 / Story 7.3. The sim state update is already synchronous; this story supplies the provider and UI surface.
- Story 6.5 found that offline reward modal subscription order matters. Keep `ref.watch(offlineRewardModalControllerProvider.notifier)` before `offlineCatchupBootProvider`.
- Story 6.6 completed save recovery and corrupt database handling. Do not alter `SaveRecoveryScreen`, recovery actions, backup quarantine, or database bootstrap flow.
- Recent commits (`ef0faba`, `c442514`, `3c7ec27`, `6886d6f`) center on save recovery, offline catch-up, reward modal, and persistence. This HUD story must not disturb those flows.

### Architecture Compliance

- Navigation remains `BottomNavigationBar` plus `IndexedStack`; stats push uses Navigator 1.0. Do not add `go_router` or `auto_route`.
- UI widgets may import Riverpod providers and game value objects, but must not import Drift database classes or repositories directly.
- `lib/game/**` remains untouched. No Flutter imports, commands, events, reducers, or state fields are needed for this story.
- `lib/data/**` remains untouched. No schema changes, migrations, tables, repositories, or save writes are needed.
- HUD providers belong in `lib/providers/` as Riverpod selectors. Providers are the composition root.
- Currency display uses `Influence` / `Intel` value objects and existing formatter behavior. Do not use raw `Decimal` or `double` for game quantities in widgets.
- Do not duplicate income math or derive totals by summing country state. The authoritative totals are `GameState.totalInfluence` and `GameState.totalIntel`.
- Do not create a second explicit runtime ticker. The HUD animation must avoid manual animation controllers and remain small enough to revisit in Epic 8 Story 8.5's shared animation budget.
- Every interactive HUD widget must have readable `Semantics`, tooltip, and minimum touch target behavior.

### Library / Framework Requirements

- Use existing pinned dependencies from `pubspec.yaml`: Flutter SDK / Dart SDK, `flutter_riverpod: ^2.6.1`, `decimal: ^3.0.2`, and `google_fonts: ^6.2.1`. Do not bump packages.
- Use `Provider` / `Provider.family` style only; this project does not use `riverpod_generator`.
- Use Material `IconButton`, `Tooltip`, `Semantics`, `SafeArea`, and Navigator 1.0 APIs already available from Flutter.
- Use Material Icons through `uses-material-design: true`; no new assets are required.
- No web research or dependency upgrade is required for this story because implementation relies on pinned project dependencies and stable Flutter SDK widgets.

### File Structure Requirements

Create:

| File | Purpose |
| --- | --- |
| `lib/ui/features/hud/global_hud.dart` | App-wide HUD watching narrow currency providers and exposing stats/settings actions |
| `lib/ui/widgets/currency_badge.dart` | Reusable Influence/Intel badge with tokenized icon, color, formatter, semantics |
| `lib/ui/widgets/animated_counter.dart` | Small display-only value transition used by currency badges |
| `lib/ui/features/stats/stats_screen.dart` | Minimal placeholder route only if absent; Story 7.5 expands it |
| `lib/ui/features/settings/settings_modal.dart` or `settings_sheet.dart` | Minimal placeholder modal only if absent; Story 7.6 expands it |
| `test/ui/features/hud/global_hud_test.dart` | HUD rendering, semantics, and action wiring |
| `test/ui/widgets/currency_badge_test.dart` | Badge formatting, icons, semantics, token use, large-value behavior |
| `test/ui/widgets/animated_counter_test.dart` | Counter transition behavior if not covered through badge tests |

Modify:

| File | Purpose |
| --- | --- |
| `lib/providers/feature_providers.dart` | Add `totalInfluenceProvider` and `totalIntelProvider` selectors |
| `lib/ui/app_scaffold.dart` | Mount `GlobalHud` once above the tab `IndexedStack` |
| `lib/ui/features/map/map_screen.dart` | Remove temporary centered Influence pill |
| `lib/ui/theme/hud_palette.dart` | Extend only if the HUD needs missing tokens; preserve existing fields |
| `test/providers/feature_providers_test.dart` | Add selector tests for total currency providers |
| `test/ui/app_scaffold_test.dart` | Assert HUD remains visible across tabs and mounted once |

Do not modify:

| File area | Reason |
| --- | --- |
| `lib/game/**` | No simulation changes in this story |
| `lib/data/**` | No persistence or migration work in this story |
| `lib/providers/modal_providers.dart` | Story 7.4 owns the generic priority modal queue |
| `lib/providers/geo_providers.dart` | GeoJSON loading path already exists |
| `lib/ui/features/map/game_loop.dart` | Single ticker and resume catch-up behavior already exist |
| `lib/app.dart` | Avoid unless Story 7.2 integration requires a tiny import/child update; preserve boot order and support long-press |

### Testing Requirements

Use widget tests with provider overrides. Do not mount real Drift or real content boot for HUD tests.

Recommended HUD test shape:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      totalInfluenceProvider.overrideWithValue(
        Influence(Decimal.parse('1234')),
      ),
      totalIntelProvider.overrideWithValue(
        Intel(Decimal.parse('45')),
      ),
    ],
    child: MaterialApp(
      theme: appTheme(),
      home: const Scaffold(body: GlobalHud()),
    ),
  ),
);

expect(find.textContaining('1.23K'), findsOneWidget);
expect(find.bySemanticsLabel('Influence 1.23K'), findsOneWidget);
expect(find.byTooltip('Stats'), findsOneWidget);
expect(find.byTooltip('Settings'), findsOneWidget);
```

For selector tests, use a `ProviderContainer` with a fake `GameWorldNotifier` or provider override that can change only one total at a time. Assert `totalInfluenceProvider` and `totalIntelProvider` read the typed values expected.

For shell integration, extend Story 7.2 tests:

1. Pump `AppScaffold` with fake map and game providers.
2. Assert exactly one `GlobalHud`.
3. Switch through every bottom tab.
4. Assert `GlobalHud` still exists exactly once after each switch.
5. Assert the old MapScreen text prefix `Influence:` is no longer rendered as a separate centered map pill under the shell.

### Out of Scope

- Implementing the full Stats screen metrics and active multiplier breakdown (Story 7.5).
- Implementing real Settings toggles, persistence, credits, or Support long-press integration (Story 7.6).
- Generic sequential modal queue with priority (Story 7.4).
- Upgrades tab country cards, next-unlock teaser UI, buy/unlock buttons (Story 7.7).
- Leaders tab grouped accordion and hire/upgrade actions (Story 7.8).
- Map cold-launch auto-focus and tutorial-aware behavior (Story 7.9).
- Continent progress bars and milestone tick indicators (Story 7.10).
- Flying numbers, country pulses, celebration animations, or shared animation ticker architecture (Epic 8).
- New game commands, events, reducers, content JSON, Drift tables, migrations, or save repository writes.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` - Story 7.3]
- [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` - FR29, FR32, FR43, NFR18, NFR21, NFR22]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` - Navigation, Theme & tokens, Big Numbers]
- [Source: `_bmad-output/game-architecture/project-structure.md` - UI shell + HUD + nav locations]
- [Source: `_bmad-output/game-architecture/implementation-patterns.md` - Widget to Provider to Notifier to GameWorld and widget test patterns]
- [Source: `_bmad-output/project-context.md` - Riverpod selectors, single ticker, value-object, accessibility, and token rules]
- [Source: `_bmad-output/implementation-artifacts/7-1-theme-tokens-and-design-system-foundation.md` - token foundation and previous scope exclusions]
- [Source: `_bmad-output/implementation-artifacts/7-2-app-scaffold-with-5-tab-bottom-navigation-and-indexedstack.md` - shell dependency and AppScaffold expectations]
- [Source: `lib/app.dart` - current boot, modal host, game loop, and support long-press wiring]
- [Source: `lib/providers/game_providers.dart` - `gameWorldProvider` and `GameState` source]
- [Source: `lib/providers/feature_providers.dart` - existing derived provider location]
- [Source: `lib/game/game_state.dart` - `totalInfluence` and `totalIntel` fields]
- [Source: `lib/game/values/influence.dart` and `lib/game/values/intel.dart` - existing `format()` APIs]
- [Source: `lib/game/values/influence_formatter.dart` - abbreviated formatter suffixes]
- [Source: `lib/ui/features/map/map_screen.dart` - temporary Influence pill to remove]
- [Source: `lib/ui/theme/hud_palette.dart` and `lib/ui/theme/spacing.dart` - existing HUD tokens]
- [Source: `test/helpers/map_screen_test_providers.dart` - widget test provider override pattern]

## Dev Agent Record

### Agent Model Used

TBD by dev agent.

### Debug Log References

### Completion Notes List

### File List

## Story Completion Status

Ultimate context engine analysis completed - comprehensive developer guide created.
