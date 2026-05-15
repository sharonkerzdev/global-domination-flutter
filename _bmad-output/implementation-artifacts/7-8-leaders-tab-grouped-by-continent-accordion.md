# Story 7.8: Leaders Tab — Grouped-by-Continent Accordion

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Story 7.8 depends on the shell, leader simulation, and Upgrades-tab DTO pattern already present in the current worktree:

- `lib/ui/app_scaffold.dart` mounts `LeadersScreen` as tab index 2 in the `IndexedStack`. Replace the placeholder `LeadersScreen`; do not add a second leaders route, tab, nested `MaterialApp`, or per-tab navigator.
- `lib/ui/features/leaders/leaders_screen.dart` currently contains only the placeholder (`Scaffold` + centered "Placeholder — leaders UI arrives in a later story."). This story owns expanding it into the real Leaders tab. Drop the nested `Scaffold`; `AppScaffold` already provides shell + HUD.
- `HireLeader(countryId)` and `UpgradeLeader(countryId)` already exist in `lib/game/game_command.dart` and are handled by `GameWorld` via `applyHireLeader` / `applyUpgradeLeader` in `lib/game/features/leaders/leaders_reducer.dart`.
- `applyHireLeader` enforces unlocked country, `ipLevel >= BalanceConfig.leaderHireMinIpLevel` (10), `leaderTier == LeaderTier.none`, positive `baseInfluence`, and affordability via `IncomeCalculator.leaderHireCost(def)`.
- `applyUpgradeLeader` enforces unlocked country, `leaderTier != LeaderTier.none`, `leaderTier != LeaderTier.tier3`, positive `baseInfluence`, and affordability via `IncomeCalculator.leaderUpgradeCost(def, fromTier)` where `fromTier` is `tier1` or `tier2`.
- `LeaderTier` enum is `{ none, tier1, tier2, tier3 }`. The "4 tiers, 3 upgradeable steps" decision is locked at this enum; multipliers come from `BalanceConfig.leaderMultiplier(tier)` reading the `{none:1.0, tier1:1.5, tier2:2.0, tier3:3.0}` table.
- `IncomeCalculator.leaderHireCost(def)` = `def.baseInfluence × BalanceConfig.leaderHireBaseInfluenceScale (500)`.
- `IncomeCalculator.leaderUpgradeCost(def, fromTier)` = `def.baseInfluence × {tier1→tier2: 750, tier2→tier3: 1000}`.
- `nextUnlockInContinentProvider` / `nextUnlockOverallProvider` are NOT relevant to Leaders. Do not import them. Leaders tab shows only unlocked continents and their unlocked countries; locked countries are not listed as leader rows.
- Story 7.7 added the canonical pattern for Tab DTO providers: `lib/providers/upgrades_providers.dart` exposes `Provider<AsyncValue<UpgradesTabModel>>` with `ContinentUpgradeSection` and `CountryUpgradeRow` immutable DTOs. Leaders should mirror this pattern (DTO + provider) so the widget remains a thin renderer.
- Story 7.7 added `countryDisplayName(CountryId)` in `lib/providers/upgrades_providers.dart` (splits on `_`/`-`, capitalizes words). Reuse it via import; do not duplicate the helper. If 7.7's helper is renamed/moved before this story lands, follow the new location.
- `CountryDef` has no `name` field. Display names derive from `CountryId.value` via the shared helper.
- `ContinentDef.name` is the friendly continent name; use it for accordion header text.
- `CurrencyBadge` exists in `lib/ui/widgets/currency_badge.dart`. Reuse it for hire/upgrade Influence costs where layout allows; otherwise use `Influence.format()` directly.
- `GameWorldNotifier.apply(GameCommand)` currently returns `void`. Do not assume `Result` propagation to UI. If exposing command failures becomes necessary, treat it as a tiny tested seam and update all call sites; default for this story is direct dispatch with disabled-when-ineligible buttons.
- Story 7.7 is `review` (not yet `done`) at story-creation time. Treat Upgrades providers/screen as concurrent/landed locally; do not revert or "clean up" Story 7.7 files outside this story's lines.
- Sprint status currently shows `M lib/ui/features/upgrades/upgrades_screen.dart` and `?? lib/providers/upgrades_providers.dart` plus `?? test/providers/upgrades_providers_test.dart` / `?? test/ui/features/upgrades/` as uncommitted Story 7.7 artifacts. Preserve them.

Before coding, verify with `git status --short` and inspect the current versions of `leaders_screen.dart`, `app_scaffold.dart`, `leaders_reducer.dart`, `income_calculator.dart`, `balance.dart`, `leader_tier.dart`, and `upgrades_providers.dart` (for the DTO pattern + display-name helper).

## Story

As a player,
I want a Leaders tab that groups unlocked countries by continent in expandable accordion cards, showing leader status per country (not-eligible / hire available / hired / upgrade available / max tier),
so that I can manage automation across the whole game from one screen without navigating the map or the Upgrades tab.

## Acceptance Criteria

1. Given the player opens the Leaders tab, then it replaces the placeholder screen with a scrollable, token-styled tab body mounted inside the existing `AppScaffold` tab at index 2.

2. Given continents are loaded from `ContentRegistry`, then the tab shows one accordion section for each continent where `GameState.unlockedContinents[continentId] == true`; locked continents are not rendered as sections.

3. Given an unlocked continent has no unlocked countries yet, then the accordion section still renders with an empty / informational state instead of a country list, and the header counters reflect `0 / 0`.

4. Given an accordion continent header renders, then it shows the continent display name (`ContinentDef.name`), an `X / Y Leaders hired` counter where X is the count of unlocked countries in that continent with `leaderTier != LeaderTier.none` and Y is the count of unlocked countries in that continent, and a gold/affordable visual highlight if AT LEAST ONE eligible row in that continent has an affordable next action (Hire or Upgrade).

5. Given the player expands a continent accordion, then the rows for that continent become visible; collapsing the accordion hides them. Expanded/collapsed state is UI state only, defaults to expanded on first build, and is not persisted to `GameState`, Drift, content JSON, or any repository.

6. Given an accordion is expanded, then each unlocked country in that continent renders as a `_CountryLeaderRow` showing country display name (via the shared `countryDisplayName` helper), current IP level, current leader tier label, and a single contextual action.

7. Given a row's contextual action label and behavior derive from `(country.unlocked, country.ipLevel, country.leaderTier, affordability)` exactly per this state table:
    - `ipLevel < BalanceConfig.leaderHireMinIpLevel (10)` AND `leaderTier == none` → label `"Reach IP 10 first"`, button disabled, no command dispatched.
    - `ipLevel >= 10` AND `leaderTier == none` → label `"Hire ({cost})"` where cost is `IncomeCalculator.leaderHireCost(def).format()`. Enabled iff `state.totalInfluence >= cost`; tap dispatches `HireLeader(countryId)`.
    - `leaderTier == tier1` → label `"Upgrade to Tier 2 ({cost})"` where cost is `IncomeCalculator.leaderUpgradeCost(def, LeaderTier.tier1).format()`. Enabled iff affordable; tap dispatches `UpgradeLeader(countryId)`.
    - `leaderTier == tier2` → label `"Upgrade to Tier 3 ({cost})"`, cost via `leaderUpgradeCost(def, LeaderTier.tier2)`. Enabled iff affordable; tap dispatches `UpgradeLeader(countryId)`.
    - `leaderTier == tier3` → label `"Max tier reached"`, button disabled, no command dispatched.

8. Given a row's action is enabled and the player taps it, then `ref.read(gameWorldProvider.notifier).apply(<command>)` is called exactly once and the row re-renders from the resulting state.

9. Given a row's action is disabled, then taps do nothing — no command is dispatched and no exception is thrown.

10. Given a country approaches a hire or upgrade IP threshold, then the row shows a subtle "approaching threshold" visual hint (token-only outline/border, no animation, no custom colors outside theme tokens). Thresholds: `ipLevel ∈ [8, 9]` while `leaderTier == none` (approaching hire eligibility at 10); `ipLevel ∈ [46, 47]` while `leaderTier == tier1` (approaching tier-2 typical breakpoint at 48 per epic doc); `ipLevel ∈ [96, 97]` while `leaderTier == tier2` (approaching tier-3 typical breakpoint at 98 per epic doc). These IP windows are visual-only and DO NOT change command eligibility — eligibility is governed exclusively by the reducer rules in AC #7. Full milestone glow polish belongs to Epic 8.

11. Given any state change (Influence increases via tick or collect, an IP upgrade lands from the Upgrades tab, an unlock happens, a Hire/Upgrade succeeds), then the Leaders tab updates reactively without manual refresh.

12. Given Leaders tab reads state, then providers/selectors keep rebuilds narrow enough for up to 79 countries × 7 continents. Prefer one derived `LeadersTabModel` provider over per-row deep watches; widgets should consume the immutable DTO list rather than reading `gameWorldProvider` directly per row.

13. Given a continent is unlocked with no unlocked countries yet, then the header counter reads `0 / 0`, the affordable highlight is not applied, and the empty body renders an informational state ("No countries unlocked here yet." or equivalent) without crashes.

14. Given all countries in all unlocked continents reach `LeaderTier.tier3` (full automation), then every row shows "Max tier reached" disabled, every header counter reads `Y / Y`, no affordable highlight is applied, and the tab does not crash.

15. Given `CountryDef` currently has no friendly `name` field, then display names are derived consistently from `CountryId.value` via the existing `countryDisplayName(CountryId)` helper imported from `lib/providers/upgrades_providers.dart`. Do not add a content model field, rewrite assets, or duplicate the helper in this story.

16. Given action buttons render, then they use Material buttons (`FilledButton.tonal` or equivalent), have readable `Semantics` labels (e.g. `"Hire leader for Egypt"`, `"Upgrade Egypt leader to tier 2"`, `"Max tier reached"` with `button: true, enabled: false`), and meet 44/48dp-class mobile touch targets via `minimumSize: Size(48, 48)` + `MaterialTapTargetSize.padded`.

17. Given the tab is viewed on narrow mobile widths or larger text scale, then accordion headers, row content (long country names, formatted big numbers, tier labels), and action buttons wrap or constrain cleanly without overflow. Costs in button labels may use `FittedBox` only for compact numeric chips.

18. Given Leaders UI uses colors, spacing, icons, typography, surfaces, dividers, card styling, and approaching-threshold highlights, then it uses `Theme.of(context).colorScheme`, `textTheme`, existing `ThemeExtension`s (`HudPalette`, `MilestoneColors`, `CountryColors` only as relevant), Material icons (`Icons.groups`, `Icons.upgrade`, `Icons.lock`, `Icons.check_circle`, etc.), and `Spacing.*`. Do not add raw `Color(...)`, `Colors.*`, emoji icons, bitmap assets, or one-off typography. The "affordable" header highlight and the "approaching threshold" row hint must be expressed in theme tokens only.

19. Given implementation is complete, then `flutter analyze`, Leaders provider tests, Leaders widget tests, AppScaffold tab integration tests if touched, UI token guardrails, no-duplicate-income-math guardrails, and game boundary tests pass.

20. Given Leaders tab state, then UI dispatches commands only through `gameWorldProvider.notifier.apply(...)`. UI/providers never import `lib/data/**` Drift, repositories, mappers, or schema; never mutate `GameState`; never introduce new game events/commands/reducers; never duplicate leader cost or income math.

## Tasks / Subtasks

- [x] Task 1: Preflight current shell, placeholder, and concurrent Story 7.7 work (AC: #1, #2, #15)
  - [x] 1.1 Run `git status --short` and note existing user-owned/uncommitted Story 7.7 files (`upgrades_providers.dart`, upgrades tests). Preserve them; do not revert or "clean up" outside this story's lines.
  - [x] 1.2 Confirm `AppScaffold` still renders tabs in Map / Upgrades / Leaders / Achievements / Minigames order with `IndexedStack` and `LeadersScreen` at index 2.
  - [x] 1.3 Confirm `LeadersScreen` is still the placeholder in `lib/ui/features/leaders/leaders_screen.dart`; expand this file rather than adding another route.
  - [x] 1.4 Confirm `lib/providers/upgrades_providers.dart` still exports `countryDisplayName(CountryId)` and the `CountryUpgradeRow` DTO style. Note its exact import path for reuse.
  - [x] 1.5 Confirm `HireLeader`, `UpgradeLeader`, `LeaderTier`, `BalanceConfig.leaderHireMinIpLevel`, `IncomeCalculator.leaderHireCost`, and `IncomeCalculator.leaderUpgradeCost` signatures match this story's expectations.
  - [x] 1.6 Confirm no settings/stats/modal-queue files need editing here.

- [x] Task 2: Add Leaders tab provider models (AC: #2, #3, #4, #6, #7, #10, #11, #12, #14, #15)
  - [x] 2.1 Create `lib/providers/leaders_providers.dart`. Keep derived Leaders models UI-independent (no Flutter imports beyond `flutter_riverpod`).
  - [x] 2.2 Add immutable DTOs (mirroring 7.7's pattern):
    - `enum LeaderRowAction { reachIp10First, hire, upgradeToTier2, upgradeToTier3, maxTier }`
    - `enum ApproachingThreshold { none, hire, tier2, tier3 }`
    - `CountryLeaderRow { countryId, displayName, ipLevel, currentTier, action, actionCost (Influence?), canAfford (bool), approaching }`
    - `ContinentLeadersSection { continentId, continentName, rows, hiredCount, totalCount, hasAffordableAction }`
    - `LeadersTabModel { sections }` with `bool get isEmpty`.
  - [x] 2.3 Build `_buildLeadersTabModel(GameState, ContentRegistry)`:
    - Sort continents by `unlockThreshold` asc, then `id.value` (mirror 7.7's deterministic ordering).
    - Filter to `state.unlockedContinents[continent.id] == true`.
    - Within each continent, iterate `content.countries.values` in content order, filtered to `def.continent == continent.id` and `state.countries[def.id]?.unlocked == true`.
    - For each row derive `action` per AC #7 state table, `actionCost` via `IncomeCalculator.leaderHireCost(def)` or `IncomeCalculator.leaderUpgradeCost(def, fromTier)`, `canAfford = state.totalInfluence >= actionCost` (false when cost is null), and `approaching` per AC #10 IP windows.
    - Section `hiredCount` = count of rows with `currentTier != LeaderTier.none`; `totalCount` = rows length; `hasAffordableAction` = any row with `action ∈ {hire, upgradeToTier2, upgradeToTier3}` and `canAfford == true`.
  - [x] 2.4 Expose `leadersTabModelProvider = Provider<AsyncValue<LeadersTabModel>>` that watches `contentRegistryProvider` and `gameWorldProvider` and returns `contentAsync.whenData((c) => _buildLeadersTabModel(ref.watch(gameWorldProvider), c))`.
  - [x] 2.5 Reuse `countryDisplayName` from `lib/providers/upgrades_providers.dart` via import. Do NOT redefine.
  - [x] 2.6 Do not duplicate `BalanceConfig.leaderMultiplier(tier)` formatting math in the provider — the row's tier label is a pure presentation concern handled in the widget layer.

- [x] Task 3: Replace placeholder with real Leaders tab UI (AC: #1, #2, #4, #5, #6, #16, #17, #18)
  - [x] 3.1 Modify `lib/ui/features/leaders/leaders_screen.dart`. Remove the nested `Scaffold`; `AppScaffold` already provides shell + HUD.
  - [x] 3.2 Use `ConsumerWidget` for the root and switch on `ref.watch(leadersTabModelProvider)` (`loading` / `error` / `data`).
  - [x] 3.3 On `isEmpty` (no unlocked continents), render a `_EmptyState` centered message ("No continents unlocked yet.") using tokens.
  - [x] 3.4 On `data` non-empty, render a single vertical scrollable. `ListView.builder` or a `CustomScrollView` with slivers is preferred for scaling.
  - [x] 3.5 For each `ContinentLeadersSection`, render an `ExpansionTile` (Material accordion) as the section. Header content: continent name (`titleMedium`), counter chip `${section.hiredCount} / ${section.totalCount} Leaders hired` (`labelSmall` + `surfaceContainer`-style backdrop), and an affordable-highlight indicator (e.g. a small dot/border using `colorScheme.tertiary` or `MilestoneColors`) when `section.hasAffordableAction == true`.
  - [x] 3.6 `ExpansionTile.initiallyExpanded: true` for first build; let the framework manage per-tile open/close state. Do not persist expansion state anywhere.
  - [x] 3.7 Inside each expanded tile, render `section.rows` as `_CountryLeaderRow` widgets in a `Column` (rows are bounded by `totalCount`; no need for `ListView` inside the tile).
  - [x] 3.8 If `section.rows` is empty, render an informational row ("No countries unlocked here yet.") inside the tile.
  - [x] 3.9 `_CountryLeaderRow` layout (Card or `ListTile`-like row, no nested Card-in-Card):
    - Leading: small `Icons.groups` colored by `scheme.primary`.
    - Title: country display name (`titleSmall`).
    - Subtitle line 1: `IP {ipLevel}` + tier label (e.g., "Tier 1 Leader", "No leader", "Tier 3 (MAX)").
    - Trailing: action button using `FilledButton.tonal` with the AC #7 label, disabled when ineligible, with `minimumSize: Size(48, 48)` + `MaterialTapTargetSize.padded`, wrapped in `Semantics(button: true, enabled: ..., label: ...)`.
    - When `row.approaching != ApproachingThreshold.none`, decorate the row container with a subtle token border (e.g. `border: Border.all(color: scheme.tertiary.withOpacity(0.5))` or `MilestoneColors.approachingThreshold` if such a token exists; otherwise `scheme.tertiary` with low alpha). No animation.
  - [x] 3.10 Use `Icons.upgrade`, `Icons.lock`, `Icons.check_circle`, and `Icons.groups` where helpful; no emoji or new assets.
  - [x] 3.11 Make long country names + large cost numbers resilient via `Flexible`, ellipsis, and stable row constraints. Allow the trailing action button to wrap to a new row only if the row exceeds available width (`Wrap` or two-line layout).

- [x] Task 4: Per-row action dispatch wiring (AC: #7, #8, #9, #16)
  - [x] 4.1 Map `LeaderRowAction` to the dispatched command:
    - `reachIp10First`, `maxTier` → `onPressed: null`, button disabled.
    - `hire` → `onPressed: canAfford ? () => ref.read(gameWorldProvider.notifier).apply(HireLeader(countryId: row.countryId)) : null`.
    - `upgradeToTier2`, `upgradeToTier3` → `onPressed: canAfford ? () => ref.read(gameWorldProvider.notifier).apply(UpgradeLeader(countryId: row.countryId)) : null`.
  - [x] 4.2 Do not route Hire/Upgrade through the modal queue or a purchase-confirm modal in this story (Story 7.4 made that queue available for future flows but is explicitly out of scope here).
  - [x] 4.3 Do not assume `GameWorldNotifier.apply` returns a `Result`; it currently returns `void`. If exposing command failures becomes necessary, treat it as a tiny tested refactor and update all affected call sites (Upgrades tab included).
  - [x] 4.4 `Semantics` labels for buttons: explicit per-action ("Hire leader for {name}", "Upgrade {name} leader to tier 2", "Upgrade {name} leader to tier 3", "Reach IP 10 first to hire leader", "Max tier reached"); always pass `button: true` and `enabled: ...` accurately.

- [x] Task 5: Preserve architecture boundaries and state ownership (AC: #11, #18, #20)
  - [x] 5.1 UI dispatches commands only through `gameWorldProvider.notifier.apply(...)`; UI never mutates `GameState`.
  - [x] 5.2 UI and providers do not import Drift database classes, table classes, or repositories. Verify with a focused architecture test if needed (see Task 8).
  - [x] 5.3 No `lib/game/**` changes are required. Do not add new commands, events, reducers, or balance constants. Existing `HireLeader` / `UpgradeLeader` / `LeaderTier` / `BalanceConfig.leaderHireMinIpLevel` / `IncomeCalculator.leaderHireCost` / `IncomeCalculator.leaderUpgradeCost` already cover all behavior.
  - [x] 5.4 No `lib/data/**` changes, schema migrations, generated Drift files, save repository edits, or persistence write changes belong to this story. Story 6.2 already persists `LeaderHired` / `LeaderUpgraded` via the exhaustive event switch.
  - [x] 5.5 No package additions, router additions, custom map libraries, global event bus changes, service calls, haptics, audio, or animations.
  - [x] 5.6 Keep `AppScaffold`, `GlobalHud`, `ModalQueueHost`, stats, settings, upgrades tab, and `GameLoop` wiring intact.
  - [x] 5.7 Do not duplicate `IncomeCalculator.leaderHireCost` or `leaderUpgradeCost` math anywhere. All cost reads route through these helpers.

- [x] Task 6: Provider tests (AC: #2, #3, #4, #6, #7, #10, #11, #12, #13, #14, #15)
  - [x] 6.1 Add `test/providers/leaders_providers_test.dart` modeled on `test/providers/upgrades_providers_test.dart` (same fixture pattern: `_twoContinent()`, `_unlocked`, `_locked`, `ProviderContainer` with `contentRegistryProvider` + `gameWorldProvider` overrides, spy notifier).
  - [x] 6.2 Test: locked continents are not included as sections.
  - [x] 6.3 Test: unlocked continent with no unlocked countries still produces a section with `hiredCount: 0`, `totalCount: 0`, empty `rows`, `hasAffordableAction: false`.
  - [x] 6.4 Test: unlocked country rows grouped by continent in content order; locked countries do not appear as rows.
  - [x] 6.5 Test the AC #7 state table exhaustively for each `(ipLevel, leaderTier)` permutation that matters:
    - `(ipLevel=9, none)` → `action = reachIp10First`, button disabled.
    - `(ipLevel=10, none)` affordable → `action = hire`, `canAfford = true`, cost equals `IncomeCalculator.leaderHireCost(def)`.
    - `(ipLevel=10, none)` unaffordable → `action = hire`, `canAfford = false`.
    - `(ipLevel=20, tier1)` affordable → `action = upgradeToTier2`, cost equals `IncomeCalculator.leaderUpgradeCost(def, LeaderTier.tier1)`.
    - `(ipLevel=20, tier2)` unaffordable → `action = upgradeToTier3`, cost equals `leaderUpgradeCost(def, LeaderTier.tier2)`, `canAfford = false`.
    - `(ipLevel=20, tier3)` → `action = maxTier`, button disabled, `actionCost == null` (or sentinel meaning "no cost").
  - [x] 6.6 Test approaching-threshold windows from AC #10:
    - `(ipLevel=8, none)` → `approaching = hire`; `(ipLevel=9, none)` → `approaching = hire`; `(ipLevel=10, none)` → `approaching = none`.
    - `(ipLevel=46, tier1)` → `approaching = tier2`; `(ipLevel=47, tier1)` → `approaching = tier2`; `(ipLevel=48, tier1)` → `approaching = none`.
    - `(ipLevel=96, tier2)` → `approaching = tier3`; `(ipLevel=97, tier2)` → `approaching = tier3`; `(ipLevel=98, tier2)` → `approaching = none`.
    - `(ipLevel=10, tier1)` → `approaching = none` (already eligible for upgrade slot, not the hire window).
    - `(ipLevel=9, tier1)` → `approaching = none` (hire window does not apply when leader already hired).
  - [x] 6.7 Test `hiredCount` / `totalCount` math: mix of `none`/`tier1`/`tier2`/`tier3` rows produces the correct counters; locked countries do not contribute to either.
  - [x] 6.8 Test `hasAffordableAction = true` when at least one row in section is affordable hire OR affordable upgrade; `false` otherwise (all `reachIp10First` / `maxTier` / unaffordable).
  - [x] 6.9 Test section ordering by `unlockThreshold` asc then `id` asc (mirror 7.7's section-ordering test).
  - [x] 6.10 Test display-name formatting reuses `countryDisplayName` from the upgrades providers (smoke test on `underscore_separated`, `hyphen-separated`, single word).
  - [x] 6.11 Test missing country state map entry → country treated as locked → not present as a row.
  - [x] 6.12 Test all-tier3 world: every section has `hiredCount == totalCount`, every row `action == maxTier`, `hasAffordableAction: false`.

- [x] Task 7: Widget and shell tests (AC: #1, #4, #5, #6, #7, #8, #9, #10, #13, #14, #16, #17, #18)
  - [x] 7.1 Add `test/ui/features/leaders/leaders_screen_test.dart` modeled on `test/ui/features/upgrades/upgrades_screen_test.dart`.
  - [x] 7.2 Pump `LeadersScreen` inside a `ProviderScope` with `contentRegistryProvider` + `gameWorldProvider` overrides; do not boot real Drift or production filesystem paths.
  - [x] 7.3 Test section headers render continent name + `X / Y Leaders hired` counter and that locked continents are absent.
  - [x] 7.4 Test expansion: tile renders collapsed/expanded; initial state is expanded; tapping the header toggles the tile (rows visible → hidden → visible).
  - [x] 7.5 Test Hire button dispatches `HireLeader(countryId)` exactly once when enabled.
  - [x] 7.6 Test Upgrade-to-tier-2 button dispatches `UpgradeLeader(countryId)` exactly once when enabled.
  - [x] 7.7 Test Upgrade-to-tier-3 button dispatches `UpgradeLeader(countryId)` exactly once when enabled.
  - [x] 7.8 Test disabled states do not dispatch: `reachIp10First`, unaffordable hire, unaffordable upgrade, `maxTier` — all `onPressed == null`, tapping is a no-op.
  - [x] 7.9 Test approaching-threshold visual hint shows for `(8/9 + none)`, `(46/47 + tier1)`, `(96/97 + tier2)` and is absent for the surrounding values — assert a token-tagged finder (e.g., a custom `Key` on the row container, or `find.byWidgetPredicate` matching the threshold-decorated container).
  - [x] 7.10 Test `Semantics` labels for each action variant (e.g., `find.bySemanticsLabel(RegExp(r'Hire leader for'))`).
  - [x] 7.11 Test large numbers (`Influence(Decimal.parse('1e38'))` as `state.totalInfluence`) and very large costs render through existing formatters without overflow.
  - [x] 7.12 Test narrow widths and increased text scale (`MediaQueryData(textScaler: TextScaler.linear(1.5))`) do not throw overflow.
  - [x] 7.13 Test empty-section case: continent unlocked but no unlocked countries → header `0 / 0` + informational row body.
  - [x] 7.14 Test all-tier3 world: every header shows `Y / Y`, every row button shows "Max tier reached" disabled.
  - [x] 7.15 If `test/ui/app_scaffold_test.dart` needs updates, assert Leaders tab still at index 2 and HUD/bottom nav remain mounted.

- [x] Task 8: Architecture and regression guardrails (AC: #18, #20, #19)
  - [x] 8.1 Run `test/architecture/ui_design_tokens_test.dart`; Leaders UI must avoid raw widget color literals (`Color(...)` / `Colors.*`) and use tokens / `Theme.of(context).colorScheme` / `Spacing.*`.
  - [x] 8.2 Run `test/architecture/no_duplicate_income_math_test.dart`; Leaders must not introduce any `def.baseInfluence *` math outside `IncomeCalculator`.
  - [x] 8.3 Run `test/architecture/game_boundary_test.dart`; no Flutter imports under `lib/game/**` (this story does not touch `lib/game/**`, but confirm).
  - [x] 8.4 Add a focused source guard if needed to ensure `leaders_screen.dart` and `leaders_providers.dart` do not import Drift / database / repository / `lib/data/**` classes directly.
  - [x] 8.5 Ensure `pubspec.yaml` is unchanged.

- [x] Task 9: Verification (AC: all)
  - [x] 9.1 Run `dart format --set-exit-if-changed` on changed Dart/test files.
  - [x] 9.2 Run `flutter test test/providers/leaders_providers_test.dart`.
  - [x] 9.3 Run `flutter test test/ui/features/leaders/leaders_screen_test.dart`.
  - [x] 9.4 Run `flutter test test/ui/app_scaffold_test.dart` if touched.
  - [x] 9.5 Run `flutter test test/architecture`.
  - [x] 9.6 Run `flutter analyze`.
  - [x] 9.7 Run full `flutter test` if time permits; expect no regressions over the Story 7.7 baseline (~941 tests).

## Dev Notes

### Implementation Scope

This story turns the Leaders bottom tab into the primary management screen for hiring and upgrading per-country Leaders. It is a UI/provider story over existing simulation commands and reducers from Story 3.3 (Leader Hire & Tier System).

It should not implement upgrades (Story 7.7 owns that), stats, settings, modal queue changes, content population, persistence, migrations, map autofocus, progress bars, tutorial, SFX, haptics, or animations.

### Current Codebase Observations

- `lib/ui/features/leaders/leaders_screen.dart` is a placeholder `StatelessWidget` with a nested `Scaffold` showing "Placeholder — leaders UI arrives in a later story." Drop the nested `Scaffold` — `AppScaffold` already wraps everything.
- `lib/ui/app_scaffold.dart` already imports `LeadersScreen` and places it third (index 2) in the `IndexedStack` between `UpgradesScreen` (1) and `AchievementsScreen` (3).
- `lib/providers/feature_providers.dart` exposes `totalInfluenceProvider` / `totalIntelProvider` / `nextUnlockInContinentProvider` / `nextUnlockOverallProvider` / `dailyRewardAvailableProvider`. Leaders does NOT need the unlock selectors; do not import them.
- `lib/providers/upgrades_providers.dart` (Story 7.7) is the canonical reference for how to shape a tab DTO provider:
  - Immutable DTOs at top with `@immutable`.
  - `_buildXTabModel(GameState, ContentRegistry)` pure helper.
  - `Provider<AsyncValue<XTabModel>>` watching `contentRegistryProvider` + `gameWorldProvider`.
  - `countryDisplayName(CountryId)` helper.
- `lib/game/game_command.dart` has `HireLeader({required CountryId countryId})` and `UpgradeLeader({required CountryId countryId})` ready.
- `lib/game/features/leaders/leaders_reducer.dart` exposes `applyHireLeader` / `applyUpgradeLeader` with full validation (locked country, negative IP, min-IP gate, already-hired, max-tier, non-positive baseInfluence, insufficient funds).
- `lib/game/config/balance.dart` provides `leaderHireMinIpLevel = 10`, `leaderHireBaseInfluenceScale = 500`, `leaderUpgradeT1T2BaseInfluenceScale = 750`, `leaderUpgradeT2T3BaseInfluenceScale = 1000`, and `leaderMultiplier(tier)` lookup table. Do NOT hardcode these in widgets/providers; reuse the helpers.
- `lib/game/features/economy/income_calculator.dart` exposes `leaderHireCost(def)` and `leaderUpgradeCost(def, fromTier)` returning `Influence`. These are the ONLY allowed cost sources for the Leaders tab.
- `lib/game/features/leaders/leader_tier.dart`: `enum LeaderTier { none, tier1, tier2, tier3 }`. Four enum values, three upgradeable steps (hire none→tier1, upgrade tier1→tier2, upgrade tier2→tier3). AC #7 maps each value to exactly one action label.
- `lib/game/content/country_def.dart` has no `name` field. Continue using `countryDisplayName(CountryId)` from `upgrades_providers.dart`. `lib/game/content/continent_def.dart` has `name` — use it for accordion headers.
- `lib/game/game_event.dart` already includes `LeaderHired(at, countryId, cost, newTier)` and `LeaderUpgraded(at, countryId, cost, newTier)`. Story 6.2 persists these. No new events.
- `GameWorldNotifier.apply(GameCommand)` returns `void` and snaps `state = _world.state` after the command. Reactive Riverpod watches handle UI updates.
- `assets/data/countries.json` is still placeholder-sized in this phase. Tests should use fixtures (mirror `test/providers/upgrades_providers_test.dart` `_twoContinent()`) rather than the future 79-country production count.
- The "approaching threshold" IP windows in AC #10 (8-9, 46-47, 96-97) are visual-only hints. The actual eligibility for Hire is IP ≥ 10 (`BalanceConfig.leaderHireMinIpLevel`); the actual eligibility for Upgrade is `leaderTier == tier1 or tier2` — IP level is NOT a gate for the Upgrade action in the current reducer. The tier-2/tier-3 IP windows are guidance from the epic doc (Story 7.8 acceptance text) for visual polish only and DO NOT change command eligibility.

### Previous Story Intelligence

- Story 7.1 established `appTheme()`, `Spacing.*`, `HudPalette`, `CountryColors`, `MilestoneColors`, and raw-color guardrails. Leaders must consume tokens.
- Story 7.2 established the bottom navigation shell with `IndexedStack`; Leaders should stay a tab body and preserve map state. Do not introduce a nested `Scaffold`.
- Story 7.3 established `GlobalHud`, `CurrencyBadge`, total currency providers, and minimal placeholders. Reuse `CurrencyBadge` for cost rendering where it fits; `Influence.format()` is the fallback.
- Story 7.4 established the generic modal queue. This story does not need queue changes and should not route Hire/Upgrade through purchase confirmation.
- Story 7.5 established `stats_providers.dart` and `MultiplierStackHelpers`. Leaders may rely on `IncomeCalculator.leaderHireCost` / `leaderUpgradeCost` (the only cost sources) and must preserve no-duplicate-income-math guardrails. Tier multiplier display (e.g., "Tier 1 (×1.5)") should read from `BalanceConfig.leaderMultiplier(tier)` if shown; do not hardcode the table.
- Story 7.6 is `done`. Settings work has landed. This story does not edit settings files.
- Story 7.7 (currently `review`) established the Tab DTO + Provider pattern (`UpgradesTabModel`, `_buildUpgradesTabModel`, `Provider<AsyncValue<UpgradesTabModel>>`), reused `countryDisplayName`, and the SegmentedButton/FilledButton patterns. Leaders should mirror this pattern. If 7.7 is updated during patch-pass before this story lands, follow the latest version.
- Story 3.3 created `HireLeader`, `UpgradeLeader`, `LeaderTier`, the leader cost helpers, and reducer behavior. Story 4.1 created `UnlockCountry`. Story 6.2 persists upgrade/unlock/leader events.

### Architecture Compliance

- UI reads Riverpod providers and dispatches commands. UI never mutates `GameState` directly.
- Providers are the composition root. Leaders-derived DTOs belong in `lib/providers/`, not inside widgets if they mix content, game state, and calculator calls.
- `lib/game/**` remains pure Dart. No Flutter imports, no widget helpers, no service calls.
- `lib/data/**` remains untouched. No Drift, repository, mapper, schema, migration, or generated-file work.
- All game quantities remain `Influence`, `Intel`, or `Decimal` through existing value objects/helpers. Do not convert to `double` for costs or affordability.
- Leader cost display routes through `IncomeCalculator.leaderHireCost(def)` and `IncomeCalculator.leaderUpgradeCost(def, fromTier)`. The `IncomeCalculator.compute(...)` per-second rate is NOT required by AC; do not show it here unless future polish stories request it. If it must be shown, route through `IncomeCalculator.compute(...)` — never inline.
- Balance constants come from `BalanceConfig`; content values come from `ContentRegistry`. Do not hardcode `leaderHireMinIpLevel`, hire scale, upgrade scales, leader multipliers, or country counts in widgets.
- Navigation remains `BottomNavigationBar` + `IndexedStack`; no router package or extra navigator.
- No new explicit ticker or animation controller. Epic 8 owns polish animation budgets.

### Library / Framework Requirements

- Use the pinned project dependencies from `pubspec.yaml`: Flutter/Dart SDK, `flutter_riverpod: ^2.6.1`, `riverpod: ^2.6.1`, `decimal: ^3.0.2`, `collection: ^1.19.1`, `flutter_lints: ^6.0.0`. Do not bump packages.
- Use manual Riverpod providers; the project does not use `riverpod_generator`.
- Flutter `ExpansionTile` is the appropriate Material widget for the accordion. Per the Flutter docs it manages its own open/close state, supports `initiallyExpanded`, `title`/`subtitle`/`leading`/`trailing` slots, and `children` rendered only when expanded. Do not roll a custom accordion. Source: https://api.flutter.dev/flutter/material/ExpansionTile-class.html
- Use `ListView.builder` or slivers if section count grows; for ≤ 7 continents a `Column` inside a `SingleChildScrollView` or `ListView` is acceptable. If `ListView.builder`, provide `itemCount`.
- Use Riverpod `select` for narrow watches where the model can remain immutable and the complexity is justified; for this story, prefer a single `LeadersTabModel` watch over per-row deep watches.
- If a later implementation exposes command failures to the UI, use `ScaffoldMessenger` for transient user errors. Do not add a bespoke error overlay in this story.

### File Structure Requirements

Create:

| File | Purpose |
| --- | --- |
| `lib/providers/leaders_providers.dart` | Leaders tab section/row DTOs and derived provider |
| `test/providers/leaders_providers_test.dart` | Section filtering, row derivation, action mapping per state table, approaching-threshold windows, counters, affordability highlight |
| `test/ui/features/leaders/leaders_screen_test.dart` | Rendering, accordion expand/collapse, Hire/Upgrade dispatch, disabled states, threshold hint, responsive/a11y |

Modify:

| File | Purpose |
| --- | --- |
| `lib/ui/features/leaders/leaders_screen.dart` | Replace placeholder with real Leaders tab |
| `test/ui/app_scaffold_test.dart` | Only if needed to keep tab integration assertions current |
| `test/architecture/*` | Only if adding a focused source guard is needed |

Do not modify:

| Area | Reason |
| --- | --- |
| `lib/game/**` | Existing commands/reducers/calculators already support this UI |
| `lib/data/**` | No persistence/schema work |
| `lib/providers/upgrades_providers.dart` | Story 7.7 owns it; only import `countryDisplayName` |
| `lib/providers/modal_providers.dart` and `lib/ui/features/modals/**` | Story 7.4 owns modal queue |
| `lib/ui/features/stats/**` and `lib/providers/stats_providers.dart` | Story 7.5 owns Stats |
| `lib/ui/features/settings/**` | Story 7.6 owns Settings |
| `lib/ui/features/upgrades/**` | Story 7.7 owns Upgrades |
| `assets/**` | No content population or display-name asset changes |
| `pubspec.yaml` | No new dependency |

### Testing Requirements

Provider tests should use `ProviderContainer` with `contentRegistryProvider` and `gameWorldProvider` overrides. Widget tests should use `ProviderScope` overrides and avoid real Drift.

Recommended provider-test shape (mirror Story 7.7):

```dart
final content = _twoContinent();
final notifier = _SpyNotifier(
  content: content,
  initialState: GameState(
    countries: {
      CountryId('egypt'): CountryState(
        id: CountryId('egypt'),
        unlocked: true,
        ipLevel: 10,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      ),
      // …
    },
    unlockedContinents: {ContinentId('africa'): true},
    totalInfluence: Influence(Decimal.parse('1000000')),
  ),
);
final container = ProviderContainer(
  overrides: [
    contentRegistryProvider.overrideWith((_) async => content),
    gameWorldProvider.overrideWith((_) => notifier),
  ],
);
addTearDown(container.dispose);
await container.read(contentRegistryProvider.future);
final model = container.read(leadersTabModelProvider).value!;
```

Recommended widget-test shape:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      contentRegistryProvider.overrideWith((_) async => content),
      gameWorldProvider.overrideWith((_) => spyNotifier),
    ],
    child: MaterialApp(
      theme: appTheme(),
      home: const LeadersScreen(),
    ),
  ),
);
await tester.pump();
```

Use a spy `GameWorldNotifier` (mirror `_SpyNotifier` from `test/providers/upgrades_providers_test.dart`) for command-dispatch tests. For state-transition tests, a real `GameWorldNotifier` with fixture content is acceptable if it stays deterministic and does not touch Drift.

### Out of Scope

- Upgrades tab, IP upgrade UI, bulk buy controls, or unlock teaser behavior (Story 7.7).
- Global upgrades, research trees, diplomatic influence, prestige, or any new automation system.
- Purchase confirmation modal wiring for Hire/Upgrade.
- Settings modal implementation or settings persistence.
- Stats route/provider changes.
- Modal queue behavior, modal host ordering, daily/achievement/offline modal changes.
- Content JSON expansion to all 79 countries, new country display-name fields, or asset edits.
- Drift schema, migrations, save repository changes, or generated Drift files.
- Game command/event/reducer changes. The Leaders reducer is feature-complete from Story 3.3; do not modify it.
- New `BalanceConfig` constants. The 8/9, 46/47, 96/97 "approaching threshold" windows are local UI constants in the provider/widget; if the tier-2 (48) / tier-3 (98) IP breakpoints become enforced eligibility gates in the future, that is an Epic 10 retune, not Story 7.8.
- Map default launch/autofocus, tutorial behavior, continent progress bars, milestone tick indicators (Story 7.10).
- SFX, haptics, flying numbers, pulses, celebrations, or animation polish (Epic 8).
- Per-country leader-name display (would require asset content + `LeaderDef` wiring; current `LeaderDef` is content-only and not assigned per country).

### Latest Technical Information

- Flutter `ExpansionTile` is the Material accordion widget; expanded children render only when open, `initiallyExpanded` controls the first build state, and the widget manages internal animation. Source: https://api.flutter.dev/flutter/material/ExpansionTile-class.html
- Flutter `ListView.builder` creates children on demand and benefits from a non-null `itemCount` for scroll extent estimation. Source: https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html
- Riverpod `select` lets consumers/providers listen to selected immutable properties instead of rebuilding on every state-object change. Use it where it materially reduces churn (e.g., when one row would otherwise watch `totalInfluence` directly instead of consuming the DTO). Source: https://riverpod.dev/docs/how_to/select
- Flutter `Semantics` `enabled` flag is essential for accessibility scanners to surface disabled controls correctly; pair it with the `button: true` flag and a descriptive `label`. Source: https://api.flutter.dev/flutter/widgets/Semantics-class.html

### Git Intelligence Summary

Recent commits are directly relevant:

- `a6bbe42 feat(ui): priority modal queue, stats screen, and settings overlay` — Stories 7.4/7.5/7.6 wiring; do not touch their files.
- `8a74e35 feat(ui): global HUD, currency badges, stats and settings` — HUD/CurrencyBadge lineage; reuse `CurrencyBadge` for cost rendering where it fits.
- `0db66e0 feat(ui): extract AppScaffold with IndexedStack and Minigames tab` — tab order and `IndexedStack` are established; Leaders is index 2.
- `7a28f09 feat(ui): design tokens, theme extensions, and tab scaffold` — token guardrails active; use `Spacing.*` and `Theme.of(context)` only.
- `ef0faba feat: save recovery on corrupt database and related UI` — do not disturb boot/recovery paths.
- `c442514 feat: offline catchup and reward modal on resume` — do not disturb offline/modal ordering.
- `6f06a51 feat: achievements with permanent multipliers (5-5-27)` — `IncomeCalculator` stack is locked; do not duplicate.

Uncommitted in the working tree at story-creation time:

- `M lib/ui/features/upgrades/upgrades_screen.dart`, `?? lib/providers/upgrades_providers.dart`, `?? test/providers/upgrades_providers_test.dart`, `?? test/ui/features/upgrades/` — Story 7.7 artifacts (in review). Preserve them. The Leaders story relies on `upgrades_providers.dart` for `countryDisplayName`.
- `M _bmad-output/implementation-artifacts/7-7-…md` and `M _bmad-output/implementation-artifacts/sprint-status.yaml` — Story 7.7 review notes / sprint state. Do not revert.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` — Story 7.8]
- [Source: `_bmad-output/planning-artifacts/epics/epic-3-power-up-upgrades-leaders-and-automation.md` — Story 3.3 Leader Hire and Tier System]
- [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` — FR (leader hire/upgrade), NFR (accessibility, performance, responsiveness)]
- [Source: `_bmad-output/planning-artifacts/gdd.md` — Core loop, Leaders, Automation, Controls and Input]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` — Riverpod, Navigation, Big Numbers, Multiplier Stack]
- [Source: `_bmad-output/game-architecture/project-structure.md` — `lib/ui/features/leaders/`, `lib/providers/`, architectural boundaries]
- [Source: `_bmad-output/game-architecture/implementation-patterns.md` — Widget → Provider → Notifier → GameWorld and typed test patterns]
- [Source: `_bmad-output/project-context.md` — architecture boundaries, token rules, value objects, forbidden packages, accessibility]
- [Source: `_bmad-output/implementation-artifacts/7-1-theme-tokens-and-design-system-foundation.md` — tokens, Spacing, ThemeExtension]
- [Source: `_bmad-output/implementation-artifacts/7-2-app-scaffold-with-5-tab-bottom-navigation-and-indexedstack.md` — IndexedStack tab order]
- [Source: `_bmad-output/implementation-artifacts/7-3-global-hud-with-influence-and-intel-currency-badges.md` — CurrencyBadge, HUD]
- [Source: `_bmad-output/implementation-artifacts/7-4-sequential-modal-queue-with-priority.md` — modal queue ownership boundary]
- [Source: `_bmad-output/implementation-artifacts/7-5-stats-screen-reachable-from-hud.md` — multiplier helper guardrails]
- [Source: `_bmad-output/implementation-artifacts/7-6-settings-modal-overlay-from-hud-gear-icon.md` — settings ownership boundary]
- [Source: `_bmad-output/implementation-artifacts/7-7-upgrades-tab-unlocked-countries-next-unlock-teaser-per-continent.md` — Tab DTO + Provider pattern, `countryDisplayName` helper, Upgrades-specific guardrails]
- [Source: `lib/ui/features/leaders/leaders_screen.dart` — placeholder to replace]
- [Source: `lib/ui/app_scaffold.dart` — tab order and `IndexedStack` integration]
- [Source: `lib/providers/upgrades_providers.dart` — DTO/provider pattern + `countryDisplayName(CountryId)` to import]
- [Source: `lib/providers/feature_providers.dart` — currency providers (HUD already covers; not needed in Leaders body)]
- [Source: `lib/providers/game_providers.dart` — `gameWorldProvider`, `GameWorldNotifier.apply`]
- [Source: `lib/providers/app_providers.dart` — `contentRegistryProvider`]
- [Source: `lib/game/game_command.dart` — `HireLeader`, `UpgradeLeader` commands]
- [Source: `lib/game/game_event.dart` — `LeaderHired`, `LeaderUpgraded` events]
- [Source: `lib/game/features/leaders/leaders_reducer.dart` — hire/upgrade validation; do not change]
- [Source: `lib/game/features/leaders/leader_tier.dart` — `LeaderTier` enum]
- [Source: `lib/game/features/economy/income_calculator.dart` — `leaderHireCost`, `leaderUpgradeCost`]
- [Source: `lib/game/config/balance.dart` — `leaderHireMinIpLevel`, hire/upgrade scales, `leaderMultiplier(tier)`]
- [Source: `lib/game/content/country_def.dart` and `continent_def.dart` — available content fields; `CountryDef` has no `name`]
- [Source: `lib/ui/widgets/currency_badge.dart` — reusable currency display]
- [Source: `test/helpers/game_state_builder.dart` and `test/helpers/test_content_registry.dart` — fixture patterns]
- [Source: `test/providers/upgrades_providers_test.dart` — `_twoContinent`, `_SpyNotifier`, `_container`, fixture patterns to mirror]
- [Source: `test/ui/features/upgrades/upgrades_screen_test.dart` — widget-test pump pattern]
- [Source: `test/architecture/ui_design_tokens_test.dart`, `no_duplicate_income_math_test.dart`, `game_boundary_test.dart` — guardrails]
- [Source: Flutter ExpansionTile API — https://api.flutter.dev/flutter/material/ExpansionTile-class.html]
- [Source: Flutter ListView.builder API — https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html]
- [Source: Riverpod select guide — https://riverpod.dev/docs/how_to/select]
- [Source: Flutter Semantics API — https://api.flutter.dev/flutter/widgets/Semantics-class.html]

### Project Context Rules

Extracted from `_bmad-output/project-context.md` (authoritative source: `_bmad-output/game-architecture.md`):

- **Pinned versions only.** Flutter 3.41.6 / Dart `^3.11.4`, `flutter_riverpod ^2.6.1`, `decimal ^3.0.2`, `collection ^1.19.1`, `flutter_lints ^6.0.0`. Do not bump or add packages. No `freezed`, no `go_router`/`auto_route`, no `get_it`, no analytics SDKs.
- **`lib/game/` has zero Flutter imports** and never imports from `lib/data/`. This story does not touch `lib/game/**` at all.
- **UI never touches Drift directly.** UI → Riverpod provider → repository (none here) → DB (none here). Leaders is pure UI + derived provider.
- **UI never mutates `GameState` directly.** UI dispatches `HireLeader` / `UpgradeLeader` via `ref.read(gameWorldProvider.notifier).apply(cmd)`.
- **Services subscribe to events; they never emit `GameEvent`s.** This story does not introduce service calls.
- **Only `lib/providers/` imports `game/` + `data/` + `services/` together.** `leaders_providers.dart` lives there.
- **One `Ticker` only — owned by `GameLoop`.** Do not introduce animation controllers, custom tickers, or `Implicitly*` animations beyond what `ExpansionTile` provides internally. Epic 8 owns polish animation budgets.
- **Multiplier stack is locked in `IncomeCalculator`.** Leader cost helpers (`leaderHireCost`, `leaderUpgradeCost`) live there. Do not duplicate; the architecture test grep will fail on `def.baseInfluence *` outside the calculator.
- **Big numbers** flow through `Influence` / `Intel` value objects. Costs returned by `IncomeCalculator` are already `Influence`. Format via `Influence.format()`.
- **Riverpod `select` aggressively.** Prefer one `LeadersTabModel` watch per screen over per-row deep watches.
- **Sealed switch exhaustiveness.** This story does not add new commands or events, so no consumer-switch updates needed.
- **Accessibility is not optional.** Every action button wraps in `Semantics(button: true, enabled: ..., label: ...)`. Touch targets ≥ 48dp via `minimumSize: Size(48, 48)` + `MaterialTapTargetSize.padded`.
- **Tokens only — no raw colors.** `Theme.of(context).colorScheme`, `Spacing.*`, theme extensions only. Architecture test `test/architecture/ui_design_tokens_test.dart` enforces this against `lib/ui/`.
- **Naming.** `snake_case.dart` files (`leaders_providers.dart`, `leaders_screen.dart`, `leaders_screen_test.dart`, `leaders_providers_test.dart`), `PascalCase` classes (`LeadersScreen`, `LeadersTabModel`, `ContinentLeadersSection`, `CountryLeaderRow`), `camelCase` providers (`leadersTabModelProvider`).
- **No `print`.** Use `Logger('LeadersTab')` if logging becomes necessary (not expected for this story).

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Claude Code)

### Debug Log References

- `flutter analyze` clean.
- `flutter test test/providers/leaders_providers_test.dart` — 28/28 passed.
- `flutter test test/ui/features/leaders/leaders_screen_test.dart` — 19/19 passed.
- `flutter test test/ui/app_scaffold_test.dart` — 9/9 passed (Leaders still at index 2; HUD/bottom nav unchanged).
- `flutter test test/architecture` — 16/16 passed (token guardrails, no-duplicate-income-math, game boundary, data boundary all green).
- `flutter test` (full suite) — 990/990 passed (943 baseline + 47 new Leaders tests).
- `dart format` applied to all four new/modified files.

### Completion Notes List

- Added `lib/providers/leaders_providers.dart` mirroring the Story 7.7 Tab DTO + Provider pattern. DTOs: `LeaderRowAction`, `ApproachingThreshold`, `CountryLeaderRow`, `ContinentLeadersSection`, `LeadersTabModel`. The provider uses a narrow `_LeadersStateSlice` projection over `gameWorldProvider.select` so the tab does not rebuild on `bankedInfluence` ticks or other unrelated state slots (AC #11, #12). `countryDisplayName` is imported from `upgrades_providers.dart` (AC #15).
- Action / cost mapping in the provider follows AC #7 exactly via a single switch over `(leaderTier, ipLevel)`. Costs route through `IncomeCalculator.leaderHireCost` / `leaderUpgradeCost`; no `def.baseInfluence *` math exists outside the calculator (architecture guardrail green).
- Approaching-threshold logic (AC #10) is implemented as three private IP windows (`8-9 + none`, `46-47 + tier1`, `96-97 + tier2`) and is visual-only — it never gates command eligibility.
- Replaced the placeholder `lib/ui/features/leaders/leaders_screen.dart` with a `ConsumerWidget` rendering one `ExpansionTile` per `ContinentLeadersSection` (AC #1, #4, #5). The previous nested `Scaffold` was dropped; `AppScaffold` still provides the shell + HUD (AC #1). Sections render `_CountryLeaderRowWidget` rows via `Column` inside the tile, with an `_EmptySectionRow` when no countries are unlocked (AC #3, #13).
- Affordable highlight is a small `colorScheme.tertiary` dot in the header (`Key('leaders.affordable_dot')`) lit when `section.hasAffordableAction == true` (AC #4). The approaching-threshold hint is a token-only border (`scheme.tertiary` at 0.5 alpha) keyed via `Key('leaders.row.<id>.approaching')` (AC #10, #18).
- Action buttons are `FilledButton.tonal` with `minimumSize: Size(48, 48)` and `MaterialTapTargetSize.padded`; each is wrapped in `Semantics(button: true, enabled: ..., label: ...)` with explicit per-action labels: "Hire leader for {name}", "Upgrade {name} leader to tier 2", "Upgrade {name} leader to tier 3", "Reach IP 10 first to hire leader", "Max tier reached" (AC #16, #18).
- Tap handlers map `LeaderRowAction → ref.read(gameWorldProvider.notifier).apply(<command>)`. Disabled actions have `onPressed == null`, so tapping is a guaranteed no-op (AC #8, #9). Verified by spy-notifier widget tests for hire-unaffordable, reachIp10First, max-tier, and the three disabled paths.
- Provider tests cover: locked-continent filter, empty-continent section shape, missing-state→locked, full state-table permutations including affordable / unaffordable / max-tier, all approaching-threshold edges including the boundary "off" cases, counter math, affordability highlight rollup, section ordering by `unlockThreshold` then `id`, display-name reuse, the all-tier3 terminal state, and a reactivity test asserting the tab is insensitive to `bankedInfluence` mutations.
- Widget tests cover: rendering, locked-continent absent, empty state, empty section informational row, expansion toggle, hire dispatch, hire unaffordable no-op, reach-IP-10 no-op, upgrade-to-tier-2/3 dispatch, max-tier no-op, approaching-key present/absent, affordable dot present/absent, narrow-width / 1e38 / textScaler 1.5 overflow safety, and the all-tier3 world.
- No game / data / pubspec changes. No `lib/data/**` imports from the new UI/provider. `AppScaffold` and other tab files left untouched.

### File List

- Created: `lib/providers/leaders_providers.dart`
- Created: `test/providers/leaders_providers_test.dart`
- Created: `test/ui/features/leaders/leaders_screen_test.dart`
- Modified: `lib/ui/features/leaders/leaders_screen.dart` (replaced placeholder with real Leaders accordion UI)
- Modified: `_bmad-output/implementation-artifacts/7-8-leaders-tab-grouped-by-continent-accordion.md` (status, dev agent record, file list, change log)
- Modified: `_bmad-output/implementation-artifacts/sprint-status.yaml` (status transition ready-for-dev → in-progress → review)

## Change Log

- Story 7.8 context created: ready-for-dev (Date: 2026-05-15)
- Story 7.8 implementation complete → review (Date: 2026-05-15): leaders provider + accordion UI landed; 47 new tests; full flutter test 990/990 green; analyze + dart format clean; no game/data/pubspec changes.
- Story 7.8 code review passed → done (Date: 2026-05-15): clean review; flutter analyze, targeted Leaders/AppScaffold/architecture tests, and full flutter test green.

## Story Completion Status

done
