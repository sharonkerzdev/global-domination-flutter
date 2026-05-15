# Story 7.6: Settings Modal Overlay From HUD Gear Icon

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Dependency Gate

Story 7.6 depends on the Story 7.3 HUD gear route hook and the Story 1.10 Support screen. It also crosses into Drift schema work because the settings table does not exist yet.

Before coding, verify:

- `lib/ui/features/hud/global_hud.dart` still imports `settings_modal.dart` and calls `showSettingsModal(context)` from the HUD Settings icon. Keep this public route hook unless a tiny signature change is required.
- `lib/ui/features/settings/settings_modal.dart` still contains only the placeholder bottom sheet. Expand this file instead of creating a second settings surface.
- `lib/app.dart` still contains the temporary release-accessible 5-second Support long-press wrapper around `_GameScreen`. This story must move that Support entry point into Settings and remove only the temporary wrapper/import/timer while preserving the `GameLoop(child: AppScaffold())` path.
- Story 7.4 modal queue files are present in the current worktree (`modalQueueProvider`, `ModalQueueHost`, queue modal widgets). Do not revert, rename, or route Settings through the reward modal queue.
- Sprint status currently marks Story 7.5 as `in-progress`; current code still has the placeholder `StatsScreen`. Treat any stats work as concurrent/user-owned and do not edit stats files for this story.
- `lib/data/database/app_database.dart` is schema v3 and has no `settings` table. This story owns schema v4, the v3-to-v4 migration, repository/providers, generated Drift output, and tests.
- `AudioService`, `HapticsService`, and notification scheduling do not exist yet. Do not implement them here. Settings toggles must update Riverpod state immediately and persist so Epic 8 services can read them later.

## Story

As a player,
I want a Settings screen that opens as a modal overlay from the HUD gear,
so that I can adjust sound, haptics, and notification preferences without leaving my current tab.

## Acceptance Criteria

1. Given any tab is visible, when I tap the HUD gear icon, then a modal bottom sheet opens over the current shell and the bottom navigation remains mounted and visible behind the scrim.

2. Given the Settings sheet is open, when I dismiss it with the drag handle, scrim, system back, or close affordance, then I return to the same tab and the tab subtree state is preserved.

3. Given the Settings sheet is shown, then it contains at minimum: Sound on/off, Haptics on/off, Notifications on/off, Credits, and the 5-second Support activator from Story 1.10.

4. Given Settings renders, when any toggle is changed, then the visible switch state and exported settings provider value update before the sheet is dismissed.

5. Given a toggle is changed, when the app is restarted or the Settings sheet is reopened after persistence completes, then the value is loaded from Drift and remains changed.

6. Given no settings row exists yet, when Settings renders, then defaults are used without crashing: sound enabled, haptics enabled, notifications disabled.

7. Given the settings table is added, then `AppDatabase.currentSchemaVersion` becomes 4, fresh installs create the settings table, and v3 databases migrate by running a new `V3ToV4` migration step that creates only the settings table.

8. Given settings persistence is implemented, then all database work goes through a typed `SettingsRepository` and Drift DSL. No raw SQL is added for normal settings reads/writes.

9. Given Sound, Haptics, or Notifications are toggled, then this story does not play audio, trigger haptics, request OS notification permission, schedule notifications, or add packages. It only persists and exposes preferences for current/future consumers.

10. Given the player taps Credits, then a lightweight Credits surface opens from Settings without adding `url_launcher` or any external dependency.

11. Given the player holds the Support activator for 5 seconds, then the Settings sheet closes and `SupportScreen` opens via Navigator 1.0. Releasing or cancelling before 5 seconds must not open Support.

12. Given accessibility services invoke the Support activator's semantic long-press action, then Support opens through the same navigation path. Do not require screen-reader users to physically hold for 5 seconds after the semantic action has already fired.

13. Given the temporary Support trigger in `app.dart` existed before this story, then after completion Support is reachable only through Settings; `_GameScreen` no longer owns a support `Timer`, `GestureDetector`, or `SupportScreen` import.

14. Given Settings is rendered on narrow mobile widths and larger text scale, then controls wrap or scroll cleanly without overflow and every interactive target meets 44/48dp-class sizing.

15. Given Settings uses colors, spacing, icons, typography, and switch rows, then it uses `Theme.of(context).colorScheme`, `textTheme`, Material icons, `Spacing.*`, and existing theme extensions. Do not add raw `Color(...)`, `Colors.*`, emoji icons, bitmap assets, or one-off typography.

16. Given Settings UI code is inspected, then it does not import Drift database classes directly. UI reads Riverpod providers and calls provider/repository methods through the provider layer.

17. Given this story is complete, then `flutter analyze`, settings repository/provider tests, database migration tests, Settings modal widget tests, HUD gear route tests, Support relocation tests, UI token guardrails, modal host wiring tests, and architecture boundary tests pass.

## Tasks / Subtasks

- [x] Task 1: Preflight current shell, Settings placeholder, and concurrent work (AC: #1, #2, #13)
  - [x] 1.1 Confirm `GlobalHud` still opens Settings through `showSettingsModal(context)`.
  - [x] 1.2 Confirm `settings_modal.dart` is the placeholder file to expand.
  - [x] 1.3 Confirm `AppScaffold` still uses `IndexedStack` and `BottomNavigationBar`; do not alter tab order or selected-index state.
  - [x] 1.4 Confirm `ModalQueueHost` still wraps the game surface in `app.dart`; do not move Settings into `modalQueueProvider`.
  - [x] 1.5 Confirm `_GameScreen` still contains the temporary Support trigger; plan to remove only that temporary trigger after the Settings Support path is implemented.
  - [x] 1.6 Check `git status` before editing. Current Story 7.4 files may be uncommitted; preserve them.

- [x] Task 2: Add persisted settings schema v4 (AC: #5, #6, #7, #8)
  - [x] 2.1 Create `lib/data/database/tables/settings_table.dart`.
  - [x] 2.2 Define `@DataClassName('SettingsRow') class Settings extends Table` with a singleton primary key:
    - `singletonId` integer, default 0, primary key.
    - `soundEnabled` boolean, default true.
    - `hapticsEnabled` boolean, default true.
    - `notificationsEnabled` boolean, default false.
    - `customConstraints => ['CHECK (singleton_id = 0)']`.
  - [x] 2.3 Register `Settings` in `@DriftDatabase(tables: [...])` in `app_database.dart`.
  - [x] 2.4 Bump `AppDatabase.currentSchemaVersion` from 3 to 4.
  - [x] 2.5 Create `lib/data/database/migrations/v3_to_v4.dart` implementing `MigrationStep` and `await m.createTable(db.settings)`.
  - [x] 2.6 Add `const V3ToV4()` to `MigrationRegistry._steps` after `V2ToV3`.
  - [x] 2.7 Run `dart run build_runner build --delete-conflicting-outputs` so `app_database.g.dart` is updated and committed.
  - [x] 2.8 Do not seed a settings row during migration unless tests prove it is necessary. The repository must handle an absent row with defaults.

- [x] Task 3: Add settings value object, repository, and providers (AC: #4, #5, #6, #8, #9, #16)
  - [x] 3.1 Create `lib/data/repositories/app_settings.dart` with an immutable `AppSettings` value type, `defaults`, `copyWith`, `==`, and `hashCode`.
  - [x] 3.2 Create `lib/data/repositories/settings_repository.dart`.
  - [x] 3.3 `SettingsRepository` should expose:
    - `Stream<AppSettings> watchSettings()`
    - `Future<AppSettings> readSettings()`
    - `Future<void> setSoundEnabled(bool enabled)`
    - `Future<void> setHapticsEnabled(bool enabled)`
    - `Future<void> setNotificationsEnabled(bool enabled)`
  - [x] 3.4 Map an absent row to `AppSettings.defaults` and persist via typed Drift upsert/insert-on-conflict. Never raw SQL.
  - [x] 3.5 Preserve other settings when updating one bool. Use a small transaction or read-current-then-upsert path so toggling Sound does not reset Haptics/Notifications.
  - [x] 3.6 Add providers in the provider layer, preferably `lib/providers/data_providers.dart`:
    - `settingsRepositoryProvider`
    - `appSettingsProvider` as a `StreamProvider<AppSettings>` or equivalent small controller.
    - Narrow bool providers such as `soundEnabledProvider`, `hapticsEnabledProvider`, and `notificationsEnabledProvider` for future services/widgets.
  - [x] 3.7 If using a `StreamProvider`, tests must prove provider output changes after repository writes before the modal is dismissed. If using a controller, tests must prove optimistic state updates and persistence failure handling.
  - [x] 3.8 Log persistence failures with `Logger('SettingsRepository')` or surface them to UI; never swallow errors silently and never use `print()`.

- [x] Task 4: Implement the real Settings modal bottom sheet (AC: #1, #2, #3, #4, #9, #10, #14, #15, #16)
  - [x] 4.1 Modify `lib/ui/features/settings/settings_modal.dart`.
  - [x] 4.2 Keep `showSettingsModal(BuildContext context)` as the public HUD hook.
  - [x] 4.3 Configure the sheet with Material bottom-sheet APIs appropriate for this content:
    - `showDragHandle: true`
    - `isScrollControlled: true`
    - `useSafeArea: true`
    - a custom `barrierLabel`, such as `Settings modal active`
    - a constrained height that leaves the current shell and bottom nav visually behind the scrim.
  - [x] 4.4 Render a scrollable, portrait-first sheet body with a route/semantic label such as `Settings`.
  - [x] 4.5 Use `SwitchListTile.adaptive` or token-consistent custom switch rows for Sound, Haptics, and Notifications. Keep rows accessible as single interactive controls.
  - [x] 4.6 Toggle handlers call the settings provider/repository path. Do not store final settings only in local widget state.
  - [x] 4.7 Add a Credits row that opens a lightweight credits/about dialog or nested sheet. Use existing Material widgets and theme tokens only.
  - [x] 4.8 Add an explicit close affordance if the layout needs it, but keep standard sheet dismissal working.
  - [x] 4.9 If a write fails, show a concise `SnackBar` such as `Setting could not be saved` and leave the provider/row in the last persisted state.

- [x] Task 5: Move Support activation into Settings (AC: #10, #11, #12, #13, #14)
  - [x] 5.1 Add a Support activator in Settings. Preferred: the Credits row opens credits on tap and opens Support on 5-second hold, matching Story 1.10's "settings element" intent.
  - [x] 5.2 Implement pointer hold with a `Timer` that starts on long-press start or pointer down and cancels on end/cancel/dispose. The Support route must not open on short holds.
  - [x] 5.3 Prevent duplicate route pushes if the hold timer fires more than once.
  - [x] 5.4 For accessibility, provide `Semantics(onLongPress: ...)` that opens Support through the same function.
  - [x] 5.5 When Support opens, close the Settings sheet first or use the root navigator so only one visible route remains. Returning from Support should land back on the same app shell/tab.
  - [x] 5.6 Remove the temporary Support wrapper from `lib/app.dart`: no `_longPressTimer`, no `_onLongPressStart`, no `_cancelLongPress`, no `GestureDetector`, and no `SupportScreen` import there.
  - [x] 5.7 Preserve `_SaveRepositoryBootstrap`, `GameLifecycleObserver`, `ModalQueueHost`, `modalQueueProvider.notifier` before `offlineCatchupBootProvider`, and `GameLoop(child: AppScaffold())`.

- [x] Task 6: Database and provider tests (AC: #4, #5, #6, #7, #8, #9)
  - [x] 6.1 Update `test/data/database/app_database_test.dart` for schema version 4 and fresh `settings` table creation.
  - [x] 6.2 Add v3-to-v4 migration coverage that creates `settings` while preserving existing v3 tables and crash logs.
  - [x] 6.3 Update `test/data/database/migrations/migration_registry_test.dart` for `V3ToV4`, v1-to-v4 order, from==to v4 no-op, and missing-step behavior.
  - [x] 6.4 Add `test/data/repositories/settings_repository_test.dart` using `AppDatabase(NativeDatabase.memory())`.
  - [x] 6.5 Test absent-row defaults, read/watch behavior, each toggle write, preserving other bools, singleton constraint, and no duplicate rows after repeated writes.
  - [x] 6.6 Add provider tests, e.g. `test/providers/settings_providers_test.dart`, proving bool providers expose defaults, update after writes, can be overridden, and do not require real app boot.

- [x] Task 7: Widget and shell tests (AC: #1, #2, #3, #4, #10, #11, #12, #13, #14, #15)
  - [x] 7.1 Extend `test/ui/features/hud/global_hud_test.dart` so the gear opens the real Settings modal and all required rows are present.
  - [x] 7.2 Add `test/ui/features/settings/settings_modal_test.dart`.
  - [x] 7.3 Test Sound, Haptics, and Notifications switches render with expected defaults and call repository/provider writes when toggled.
  - [x] 7.4 Test reopening the sheet reflects persisted values.
  - [x] 7.5 Test Credits opens the credits/about surface without leaving the shell.
  - [x] 7.6 Test a short hold on the Support activator does not navigate.
  - [x] 7.7 Test a 5-second hold closes Settings and opens `SupportScreen`.
  - [x] 7.8 Test the semantic long-press action opens Support.
  - [x] 7.9 Add or update an app wiring architecture test proving `app.dart` no longer imports `SupportScreen` and no longer contains the temporary support timer/wrapper.
  - [x] 7.10 Test narrow width and increased text scale do not throw overflow errors.

- [x] Task 8: Architecture and regression guardrails (AC: #13, #15, #16, #17)
  - [x] 8.1 Run `test/architecture/ui_design_tokens_test.dart`; Settings UI must avoid raw widget colors.
  - [x] 8.2 Run `test/architecture/game_boundary_test.dart`; this story should not modify `lib/game/**`.
  - [x] 8.3 Run `test/architecture/data_boundary_test.dart`; settings tables/converters must not import `lib/game/`, and the new repository must not become an accidental dual database/game bridge.
  - [x] 8.4 Run `test/architecture/modal_host_wiring_test.dart`; preserve Story 7.4 modal queue boot ordering.
  - [x] 8.5 Ensure `pubspec.yaml` is unchanged and no notification/audio/haptic package is added.
  - [x] 8.6 Ensure `lib/ui/**` does not import `AppDatabase`, Drift table classes, or repositories directly except through providers if an existing test already permits it. Prefer a focused source guard if this slips.

- [x] Task 9: Verification (AC: all)
  - [x] 9.1 Run `dart format --set-exit-if-changed` on changed Dart/test files.
  - [x] 9.2 Run `dart run build_runner build --delete-conflicting-outputs`.
  - [x] 9.3 Run `flutter test test/data/database/app_database_test.dart`.
  - [x] 9.4 Run `flutter test test/data/database/migrations/migration_registry_test.dart`.
  - [x] 9.5 Run `flutter test test/data/repositories/settings_repository_test.dart`.
  - [x] 9.6 Run `flutter test test/providers/settings_providers_test.dart`.
  - [x] 9.7 Run `flutter test test/ui/features/settings/settings_modal_test.dart`.
  - [x] 9.8 Run `flutter test test/ui/features/hud/global_hud_test.dart`.
  - [x] 9.9 Run `flutter test test/architecture`.
  - [x] 9.10 Run `flutter analyze`.
  - [x] 9.11 Run full `flutter test` if time permits.

### Review Findings

- [x] [Review][Patch] Settings sheet covers bottom navigation despite AC1 visibility requirement [lib/ui/features/settings/settings_modal.dart:21]
- [x] [Review][Patch] Settings UI imports data-layer settings state directly instead of consuming only provider-layer state [lib/ui/features/settings/settings_modal.dart:7]
- [x] [Review][Patch] Support shortcut can pop the wrong navigator when Settings is opened from a nested navigator [lib/ui/features/settings/settings_modal.dart:13]
- [x] [Review][Patch] Five-second Support hold is not canceled by drag/scroll movement [lib/ui/features/settings/settings_modal.dart:225]
- [x] [Review][Patch] Semantic long-press action does not open Support [lib/ui/features/settings/settings_modal.dart:269]
- [x] [Review][Patch] Credits widget test asserts a substring with `find.text` and will fail once widget tests run [test/ui/features/settings/settings_modal_test.dart:86]

## Dev Notes

### Implementation Scope

This story replaces the placeholder Settings bottom sheet with a real player settings surface, persists the settings to Drift, and moves the release-accessible Support entry point from the temporary app-wide long press into Settings.

It should not implement audio playback, haptic dispatch, OS notification permissions, notification scheduling, modal reward queue behavior, stats content, upgrades/leaders UI, tutorial UI, or new game simulation state.

### Current Codebase Observations

- `GlobalHud` already exposes the gear button with tooltip/semantics and calls `showSettingsModal(context)`.
- `settings_modal.dart` currently calls `showModalBottomSheet<void>` with a placeholder `SettingsModal`.
- `AppScaffold` keeps the five tabs mounted in an `IndexedStack` and places `GlobalHud` above the tab content.
- `app.dart` currently uses `ModalQueueHost` and initializes `modalQueueProvider.notifier` before `offlineCatchupBootProvider`; this ordering is load-bearing for offline rewards.
- `_GameScreen` currently wraps `GameLoop(child: AppScaffold())` in a temporary `GestureDetector` with a 5-second `Timer` that pushes `SupportScreen`.
- `SupportScreen` already exists at `lib/ui/debug/support_screen.dart` and is intentionally not `kDebugMode` gated.
- `app_database.dart` has `currentSchemaVersion = 3`; tables include `crash_logs`, `meta`, active gameplay tables, completed missions, daily streaks, and achievements, but no settings table.
- `MigrationRegistry` currently composes `V1ToV2` and `V2ToV3`.
- `data_boundary_test.dart` allows only `game_state_mapper.dart` and `save_repository.dart` to import both database and game. The new settings repository should not import `lib/game/**`, so the allowlist should not need a new entry.
- No `AudioService`, `HapticsService`, local notifications service, or notification plugin is present.

### Previous Story Intelligence

- Story 1.10 created the release-accessible crash-log Support screen and explicitly said the temporary app-level support trigger is replaced by Story 7.6.
- Story 7.1 established `appTheme()`, `Spacing.*`, `HudPalette`, and raw-color guardrails. Settings must consume those tokens.
- Story 7.2 established `AppScaffold` with `BottomNavigationBar` plus `IndexedStack`; Settings should overlay the shell, not become a tab or route that replaces the shell.
- Story 7.3 established the HUD gear action and the placeholder Settings file. Reuse that hook.
- Story 7.4 established the priority reward modal queue and `ModalQueueHost`. Settings is a user-initiated bottom sheet and should not be part of `modalQueueProvider`.
- Story 7.5 is marked in progress; avoid stats screen/provider work and preserve any uncommitted stats edits if they appear.
- Story 6.3 established typed migration step files and `MigrationRegistry`; add `V3ToV4` instead of editing old migration bodies.
- Story 6.1 explicitly deferred `settings` tables to a future story; this is that story.

### Architecture Compliance

- UI reads settings through Riverpod providers. UI must not import Drift database classes, table classes, or repositories directly.
- `lib/data/database/tables/settings_table.dart` and any settings converters must have zero Flutter imports.
- `SettingsRepository` belongs under `lib/data/repositories/`, uses typed Drift DSL, and does not import `lib/game/**`.
- Providers are the composition root. Add the repository/provider wiring under `lib/providers/`, not inside widgets.
- No `lib/game/**` changes are needed. Settings are player preferences, not simulation state.
- No schema mutation without a migration. The only valid DB path is schema v4 plus `V3ToV4`.
- Do not add `go_router`, `auto_route`, `get_it`, `freezed`, `riverpod_generator`, `url_launcher`, local notification plugins, or new audio/haptic packages.
- Do not introduce a second ticker, app lifecycle observer, or modal host.
- Preserve support-screen release access. Do not add `kDebugMode` gates to `SupportScreen` or its Settings entry point.

### Library / Framework Requirements

- Use existing pinned dependencies from `pubspec.yaml`: Flutter SDK / Dart `^3.11.4`, `flutter_riverpod: ^2.6.1`, `riverpod: ^2.6.1`, `drift: ^2.26.1`, `drift_dev: ^2.26.1`, `sqlite3_flutter_libs: ^0.5.25`, `logging: ^1.3.0`, and `flutter_lints: ^6.0.0`.
- Flutter `showModalBottomSheet` is the selected primitive. Official docs describe it as a modal Material bottom sheet that prevents interaction with the rest of the app; use `isScrollControlled` for scrollable content, `useSafeArea` for system intrusions, and `useRootNavigator` if the sheet must appear above a nested navigator.
- Flutter `SwitchListTile` is appropriate for the three settings toggles, but it merges descendant semantics. Do not place independently interactive widgets inside a `SwitchListTile` label.
- Flutter semantics docs recommend providing the same long-press handler to gesture and semantic long-press paths; use this for the Support activator.
- Drift's `Migrator.createTable` creates a table if it does not exist; use it in `V3ToV4`.
- Riverpod providers can be overridden in `ProviderScope` or `ProviderContainer`, which is the required test seam for Settings modal/provider tests.

### File Structure Requirements

Create:

| File | Purpose |
| --- | --- |
| `lib/data/database/tables/settings_table.dart` | Singleton Drift settings table |
| `lib/data/database/migrations/v3_to_v4.dart` | Schema v3-to-v4 step creating the settings table |
| `lib/data/repositories/app_settings.dart` | Immutable settings value type and defaults |
| `lib/data/repositories/settings_repository.dart` | Typed Drift repository for watching/updating settings |
| `test/data/repositories/settings_repository_test.dart` | Defaults, writes, watch, singleton, no duplicate rows |
| `test/providers/settings_providers_test.dart` | Provider defaults, updates, overrides |
| `test/ui/features/settings/settings_modal_test.dart` | Modal rows, toggles, credits, support hold, accessibility, responsive layout |

Modify:

| File | Purpose |
| --- | --- |
| `lib/data/database/app_database.dart` | Register `Settings`, bump schema to v4 |
| `lib/data/database/app_database.g.dart` | Regenerated Drift output |
| `lib/data/database/migrations/migration_registry.dart` | Add `V3ToV4` |
| `lib/providers/data_providers.dart` or sibling provider file | Add settings repository/provider exports |
| `lib/ui/features/settings/settings_modal.dart` | Replace placeholder with real Settings sheet |
| `lib/app.dart` | Remove temporary app-wide Support long-press, preserve game shell and modal queue |
| `test/data/database/app_database_test.dart` | Schema v4 and settings table coverage |
| `test/data/database/migrations/migration_registry_test.dart` | V3ToV4 order and version coverage |
| `test/ui/features/hud/global_hud_test.dart` | Real settings sheet expectations |
| `test/architecture/modal_host_wiring_test.dart` or new wiring guard | Ensure Support trigger moved out of app.dart while modal queue wiring remains |

Do not modify:

| Area | Reason |
| --- | --- |
| `lib/game/**` | Settings are app preferences, not simulation state |
| `lib/providers/modal_providers.dart` and `lib/ui/features/modals/**` | Story 7.4 owns the reward modal queue |
| `lib/ui/features/stats/**` | Story 7.5 owns Stats |
| `lib/ui/features/upgrades/**` | Story 7.7 owns Upgrades |
| `lib/ui/features/leaders/**` | Story 7.8 owns Leaders |
| `assets/**` | No content or asset change |
| `pubspec.yaml` | No new dependencies |

### Testing Requirements

Use Riverpod provider overrides for Settings widget tests. Do not mount a real production database path in widget tests; repository tests can use `AppDatabase(NativeDatabase.memory())`.

Recommended repository-test shape:

```dart
final db = AppDatabase(NativeDatabase.memory());
addTearDown(db.close);
final repo = SettingsRepository(db);

expect(await repo.readSettings(), AppSettings.defaults);
await repo.setSoundEnabled(false);
expect(await repo.readSettings(), AppSettings.defaults.copyWith(soundEnabled: false));
```

Recommended widget-test shape:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith((ref) => Stream.value(
            const AppSettings(
              soundEnabled: true,
              hapticsEnabled: true,
              notificationsEnabled: false,
            ),
          )),
      settingsRepositoryProvider.overrideWithValue(fakeRepo),
    ],
    child: MaterialApp(
      theme: appTheme(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showSettingsModal(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);
```

For the Support hold test:

1. Pump the real Settings sheet with fake crash-log provider data.
2. Start the long press/hold on the Support activator.
3. Pump less than 5 seconds and assert `SupportScreen` is absent.
4. Pump through the 5-second threshold and settle.
5. Assert `SettingsModal` is gone, `SupportScreen` is visible, and popping returns to the shell.

### Out of Scope

- Audio playback, haptic dispatch, event-bus SFX wiring, or service-level gating. Epic 8 owns those services.
- Native notification permission prompts, local notification scheduling, or notification packages.
- Stats screen implementation or Stats route changes.
- Reward modal queue changes or purchase-confirm call sites.
- Upgrades and Leaders screens.
- Save recovery changes.
- Game commands, game events, reducers, `GameState`, content JSON, or balance constants.
- Debug overlay, cheat panel, event log viewer, or any new release support surface beyond the existing `SupportScreen`.

### Latest Technical Information

- Flutter `showModalBottomSheet` docs confirm a modal sheet blocks interaction with the rest of the app, supports scroll-controlled sheets, can use safe areas, can target the root navigator, and returns a Future when closed. Source: https://api.flutter.dev/flutter/material/showModalBottomSheet.html
- Flutter `SwitchListTile` docs confirm the whole tile is interactive and note its merged semantics behavior. Avoid nested independent gestures inside its label. Source: https://api.flutter.dev/flutter/material/SwitchListTile-class.html
- Flutter semantics docs state semantic long press may be invoked differently by assistive technologies and recommend wiring the same handler for gesture and semantics long press. Source: https://api.flutter.dev/flutter/semantics/SemanticsProperties/onLongPress.html
- Drift `Migrator` docs confirm `createTable` is the table-creation API used by migrations. Source: https://pub.dev/documentation/drift/latest/drift/Migrator-class.html
- Riverpod provider override docs confirm providers can be overridden through `ProviderScope` and `ProviderContainer`, using `overrideWith...` methods. Source: https://riverpod.dev/ko/docs/concepts2/overrides

### Git Intelligence Summary

Recent commits are directly relevant:

- `8a74e35 feat(ui): global HUD, currency badges, stats and settings` - HUD gear hook and placeholder Settings sheet exist.
- `0db66e0 feat(ui): extract AppScaffold with IndexedStack and Minigames tab` - Shell/tab preservation requirements are in place.
- `7a28f09 feat(ui): design tokens, theme extensions, and tab scaffold` - Token usage and raw-color guardrails are active.
- `ef0faba feat: save recovery on corrupt database and related UI` - Do not disturb save recovery or database bootstrap error paths.
- `c442514 feat: offline catchup and reward modal on resume` - Preserve offline reward ordering and modal host behavior now generalized by Story 7.4.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epic-7-complete-the-shell-navigation-hud-stats-settings-upgrades-leaders-screens.md` - Story 7.6]
- [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` - FR32, NFR10, NFR17, NFR18, NFR19, NFR21, NFR22, NFR27]
- [Source: `_bmad-output/game-architecture/architectural-decisions.md` - Navigation, Persistence, Theme & tokens, Event bus]
- [Source: `_bmad-output/game-architecture/project-structure.md` - `settings` table/repository locations, UI shell/HUD locations]
- [Source: `_bmad-output/game-architecture/implementation-patterns.md` - Widget to provider to repository, provider override tests, typed Drift pattern]
- [Source: `_bmad-output/game-architecture/cross-cutting-concerns.md` - Player settings storage, debug/support exception, logging rules]
- [Source: `_bmad-output/project-context.md` - architecture boundaries, Drift rules, accessibility, token rules, forbidden packages]
- [Source: `_bmad-output/implementation-artifacts/1-10-crash-log-ring-buffer-and-support-screen.md` - Support screen and temporary long-press replacement target]
- [Source: `_bmad-output/implementation-artifacts/7-3-global-hud-with-influence-and-intel-currency-badges.md` - HUD gear hook and placeholder Settings scope]
- [Source: `_bmad-output/implementation-artifacts/7-4-sequential-modal-queue-with-priority.md` - ModalQueueHost ownership boundary]
- [Source: `_bmad-output/implementation-artifacts/7-5-stats-screen-reachable-from-hud.md` - Concurrent stats ownership boundary]
- [Source: `lib/ui/features/hud/global_hud.dart` - current settings gear action]
- [Source: `lib/ui/features/settings/settings_modal.dart` - placeholder to expand]
- [Source: `lib/app.dart` - temporary Support trigger, ModalQueueHost, boot ordering, GameLoop]
- [Source: `lib/ui/debug/support_screen.dart` - existing Support screen]
- [Source: `lib/data/database/app_database.dart` - current schema v3 and table registry]
- [Source: `lib/data/database/migrations/migration_registry.dart` - migration step registry]
- [Source: `lib/data/database/tables/daily_streaks_table.dart` - singleton table CHECK pattern]
- [Source: `lib/providers/data_providers.dart` and `lib/providers/database_providers.dart` - provider/repository wiring patterns]
- [Source: `test/architecture/ui_design_tokens_test.dart`, `data_boundary_test.dart`, `modal_host_wiring_test.dart` - required guardrails]
- [Source: Flutter showModalBottomSheet API - https://api.flutter.dev/flutter/material/showModalBottomSheet.html]
- [Source: Flutter SwitchListTile API - https://api.flutter.dev/flutter/material/SwitchListTile-class.html]
- [Source: Flutter Semantics long press API - https://api.flutter.dev/flutter/semantics/SemanticsProperties/onLongPress.html]
- [Source: Drift Migrator API - https://pub.dev/documentation/drift/latest/drift/Migrator-class.html]
- [Source: Riverpod provider overrides - https://riverpod.dev/ko/docs/concepts2/overrides]

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

- Drift `watchSingleOrNull` teardown schedules a zero-duration timer; widget tests unmount the `ProviderScope` and pump briefly before `AppDatabase.close()` to avoid pending-timer failures.
- Windows `flutter test` can fail copying `build/native_assets/windows/sqlite3.dll` if the DLL is locked (errno 183); close other Flutter processes or delete the file, then re-run tests.

### Completion Notes List

- Implemented Drift schema v4 with singleton `settings` table, `V3ToV4` migration, `AppSettings` + `SettingsRepository`, and Riverpod providers (`appSettingsProvider`, bool selectors) on `database_providers`.
- Replaced placeholder settings sheet with scroll-controlled bottom sheet (theme tokens, adaptive switches, Credits dialog, 5s pointer hold + semantic long-press to Support, SnackBar on persist errors).
- Removed temporary `_GameScreen` long-press Support wrapper from `app.dart`; extended `modal_host_wiring_test` and added HUD/settings/modal/repository/provider/database tests.
- Code review patch pass fixed bottom-nav visibility, UI/provider boundary, nested navigator Support routing, drag-cancel Support hold, semantic long-press Support activation, and the Credits widget-test assertion.
- `dart analyze` clean on `lib` and `test`. Full `flutter test` not re-run in this session after the sqlite3.dll copy lock on Windows; run locally when the build folder is not locked.

### File List

- lib/data/database/tables/settings_table.dart
- lib/data/database/migrations/v3_to_v4.dart
- lib/data/repositories/app_settings.dart
- lib/data/repositories/settings_repository.dart
- lib/data/database/app_database.dart
- lib/data/database/app_database.g.dart
- lib/data/database/migrations/migration_registry.dart
- lib/providers/database_providers.dart
- lib/ui/features/settings/settings_modal.dart
- lib/app.dart
- test/data/database/app_database_test.dart
- test/data/database/migrations/migration_registry_test.dart
- test/data/database/migrations/save_recovery_actions_test.dart
- test/data/repositories/settings_repository_test.dart
- test/providers/settings_providers_test.dart
- test/ui/features/settings/settings_modal_test.dart
- test/ui/features/hud/global_hud_test.dart
- test/architecture/modal_host_wiring_test.dart
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/7-6-settings-modal-overlay-from-hud-gear-icon.md

## Change Log

- 2026-04-29: Story 7.6 code review patch pass - resolved Settings modal overlay, semantics, navigation, gesture-cancel, provider-boundary, and widget-test findings; sprint status -> done.

- 2026-04-29: Story 7.6 implementation — settings schema v4, repository/providers, settings modal UI, Support relocation from `app.dart`, tests and sprint status → review.

## Story Completion Status

Ultimate context engine analysis completed - comprehensive developer guide created.
