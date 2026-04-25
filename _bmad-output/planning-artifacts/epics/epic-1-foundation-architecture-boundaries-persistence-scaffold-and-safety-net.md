# Epic 1: Foundation — Architecture Boundaries, Persistence Scaffold, and Safety Net

**Goal:** Deliver a Flutter app that boots safely, enforces the headless-simulation boundary, loads game content, persists settings, handles errors gracefully, and proves the two Epic-1 risk spikes (big-number precision at 1e38+, canvas performance on low-end Android). After this epic the app boots to a placeholder screen on safe foundations.

### Story 1.1: Wire Global Safety Net and Portrait Lock in `main.dart`

As a developer,
I want global error handlers, portrait orientation lock, and a Riverpod `ProviderScope` configured in `main.dart`,
So that uncaught errors are captured instead of crashing the app silently and orientation is guaranteed from first frame.

**Acceptance Criteria:**

**Given** the app is launched
**When** an uncaught error occurs in a Flutter widget, platform error, or zoned code
**Then** `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded` all route the error to a `CrashReporter` singleton
**And** the app does not crash to a blank white screen — it displays a fallback screen with a "Restart" CTA.

**Given** the app launches on any supported device
**When** the first frame renders
**Then** `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` has been awaited before `runApp()`
**And** the device cannot rotate the app to landscape.

**Given** the `main.dart` entry point
**When** the app starts
**Then** `runApp()` is wrapped in a `ProviderScope` so Riverpod providers are available throughout the widget tree.

### Story 1.2: Configure Lint and Analysis Options

As a developer,
I want `analysis_options.yaml` configured with the project's lint rules,
So that architectural violations and style inconsistencies are caught at analyze time, not review time.

**Acceptance Criteria:**

**Given** `analysis_options.yaml` at the project root
**When** `flutter analyze --fatal-infos` runs
**Then** the analyzer uses `package:flutter_lints/flutter.yaml` as a base
**And** `avoid_print: error`, `unnecessary_null_comparison: error`, `unrelated_type_equality_checks: error` are enforced as errors
**And** `always_declare_return_types`, `prefer_final_fields`, `prefer_final_locals`, `require_trailing_commas`, `unawaited_futures` are enabled as lints
**And** generated files (`**/*.g.dart`, `**/*.freezed.dart`, `build/**`) are excluded.

**Given** a developer adds `print('debug')` anywhere under `lib/`
**When** `flutter analyze` runs
**Then** the analyze step fails.

### Story 1.3: Enforce "No Flutter in `lib/game/`" Boundary

As an architect,
I want a mechanized check that fails CI if any file under `lib/game/` imports `package:flutter/*`,
So that the headless-simulation invariant cannot silently drift.

**Acceptance Criteria:**

**Given** the project CI pipeline
**When** any file under `lib/game/**/*.dart` contains a line matching `import 'package:flutter/` or `import "package:flutter/`
**Then** the CI step fails with a clear error naming the offending file and line
**And** the check is implemented either as a `custom_lint` rule or a CI grep script, whichever is simpler.

**Given** a developer tries to add `import 'package:flutter/material.dart';` to a new file in `lib/game/`
**When** they run `flutter analyze` or push to CI
**Then** the build fails before tests run.

### Story 1.4: Scaffold Drift Database and Apply Migrations

As a developer,
I want Drift configured with a minimal `AppDatabase` (empty or near-empty table list), code generation running via `build_runner`, and a `MigrationStrategy` wired,
So that future stories can add tables incrementally without re-scaffolding persistence.

**Acceptance Criteria:**

**Given** the project has `drift: ^2.26.1` and `sqlite3_flutter_libs: ^0.5.25` in `pubspec.yaml`
**When** a developer runs `dart run build_runner build --delete-conflicting-outputs`
**Then** `*.g.dart` files generate cleanly under `lib/data/database/`
**And** no errors or warnings are produced.

**Given** `build.yaml` at the project root
**When** Drift generates code
**Then** it uses `store_date_time_values_as_text: true` and `named_parameters: true`.

**Given** the app launches for the first time on a fresh install
**When** `AppDatabase` initializes
**Then** the database opens at schema version 1 with zero rows in zero custom tables (only Drift's internal metadata is present)
**And** no migration runs.

**Given** a schema version bump (e.g. v1 → v2) is introduced in a later story
**When** the app launches against a v1 database
**Then** a backup file `schema_backup_v1.sqlite` is written to app documents before the migration executes
**And** the migration runs via Drift's typed `MigrationStrategy`.

### Story 1.5: Create `Influence` and `Intel` Value Objects Wrapping `decimal`

As a developer,
I want `Influence` and `Intel` value objects that wrap `package:decimal` with typed arithmetic operators and a formatter,
So that all game math flows through typed currency types and raw `double` cannot silently be used for economy values.

**Acceptance Criteria:**

**Given** `lib/game/values/influence.dart` and `lib/game/values/intel.dart`
**When** a developer imports them
**Then** each exposes `+`, `-`, `*` (with `Decimal` and `num` overloads), `<`, `>`, `==`, `hashCode`, and a `format()` method that returns an abbreviated string (K / M / B / T / Qa / Qi / Sx / Sp / Oc / No / De).

**Given** the value objects
**When** unit tests add `Influence(Decimal.parse('1e20'))` and `Influence(Decimal.parse('3e20'))`
**Then** the result equals `Influence(Decimal.parse('4e20'))` with no precision loss.

**Given** the value objects
**When** `Influence(Decimal.parse('1e35')).format()` is called
**Then** the returned string uses the abbreviated notation documented in the formatter (not scientific notation).

### Story 1.6: Big-Number Precision Spike (Property Tests at 1e38+)

As an architect,
I want property tests that validate `decimal` arithmetic at 1e38 with the full compounded multiplier stack,
So that we confirm before building more that no silent rounding occurs and per-op cost is acceptable on the tick hot path.

**Acceptance Criteria:**

**Given** a property-test suite under `test/game/values/influence_precision_test.dart`
**When** it runs `Decimal` operations representing `1e38 × 3.0 × 1.75 × 2.0 × 100` compounded across many iterations
**Then** the result exactly matches the expected symbolic value (computed separately) with zero rounding error.

**Given** a per-op micro-benchmark in the same test file (documented as a reference, not asserted)
**When** it runs 10,000 multiplications
**Then** the measured per-op cost is recorded in a comment or small JSON report for team review
**And** if the per-op cost is above a documented threshold (e.g. 10µs), a follow-up story "Cache per-country rates" is added to the Epic 10 (Tune) backlog.

### Story 1.7: `ContentRegistry` Loads from Assets at Boot

As a developer,
I want a `ContentRegistry` that loads `countries.json`, `continents.json`, `leaders.json`, `achievements.json`, `missions.json`, and `global_upgrades.json` from `assets/data/` once at boot and exposes immutable typed collections,
So that reducers and UI read from one in-memory source of truth and never call `rootBundle` themselves.

**Acceptance Criteria:**

**Given** minimal placeholder JSON files exist at `assets/data/*.json` (even if most are empty arrays for now)
**When** `ContentRegistry.loadFromAssets()` is awaited
**Then** it returns an immutable `ContentRegistry` with `Map<CountryId, CountryDef>`, `Map<ContinentId, ContinentDef>`, and lists for achievements/missions/leaders/global upgrades.

**Given** a `contentRegistryProvider` defined in `lib/providers/app_providers.dart` as a `FutureProvider<ContentRegistry>`
**When** any widget calls `ref.watch(contentRegistryProvider)`
**Then** it resolves to the same registry instance across the app lifetime (no duplicate loads).

**Given** a malformed JSON file in `assets/data/`
**When** the app boots
**Then** `ContentRegistry.loadFromAssets()` surfaces a `BootError` and the `GlobalDominationApp` displays a `BootErrorScreen` with reinstall guidance.

### Story 1.8: Define `GameError` Sealed Hierarchy and `Result<T, GameError>`

As a developer,
I want a `GameError` sealed class hierarchy (`UserError` / `InternalError` variants) and a `Result<T, E>` sealed type,
So that recoverable game-logic failures flow through typed returns rather than exceptions.

**Acceptance Criteria:**

**Given** `lib/game/values/result.dart` and `lib/game/game_error.dart`
**When** a reducer returns `Result.failure(GameError.userInsufficientFunds(required: cost))`
**Then** the caller can pattern-match on `Success` / `Failure` exhaustively.

**Given** the `GameError` hierarchy
**When** it is exhaustively pattern-matched
**Then** `UserError` variants include at minimum `insufficientFunds`, `locked`, `invalidTarget`
**And** `InternalError` variants include at minimum `missingCountry`, `invariantBroken`, `persistenceFailure`, `migrationFailure`.

**Given** unit tests
**When** they construct each variant
**Then** equality, `hashCode`, and `toString` behave per Dart conventions and are covered.

### Story 1.9: Skeleton `GameWorld` With `tick` and `applyCommand` (No-Op)

As a developer,
I want a `GameWorld` class in `lib/game/game_world.dart` with `tick(Duration dt)`, `applyCommand(GameCommand)`, `GameState get state`, and `Stream<GameEvent> get events`, initially returning no-ops or empty state,
So that subsequent epics have a stable aggregator to attach reducers and events to.

**Acceptance Criteria:**

**Given** `GameWorld` is instantiated with an injected `Clock` and a `ContentRegistry`
**When** `tick(Duration.zero)` is called
**Then** it returns without error and `state` is unchanged.

**Given** `GameWorld`
**When** `applyCommand(cmd)` is called for any `GameCommand` variant defined so far (initially an empty sealed hierarchy or a single `Noop`)
**Then** it returns `Result.success(null)` and emits no event — a placeholder ready to be extended.

**Given** the `events` stream
**When** a subscriber attaches before any event emission
**Then** the stream is a broadcast stream that survives multiple subscribers.

**Given** `GameWorld`
**When** imported
**Then** it has zero `package:flutter/*` imports (enforced by Story 1.3).

### Story 1.10: Crash Log Ring Buffer and Support Screen

As a player,
I want a hidden "Support" screen (reachable via a 5-second long-press on a settings element in release) that shows the last 100 crash/warning entries,
So that if the app misbehaves I can share the recent error log without needing developer tools.

**Acceptance Criteria:**

**Given** a `crash_logs` Drift table with bounded `N=100` entries
**When** `CrashReporter.report()` is called (from any of the three global handlers)
**Then** a new row is inserted with timestamp, level, tag, message, and stack trace
**And** if the row count exceeds 100, the oldest is deleted.

**Given** a "Support" screen reachable via a 5-second long-press on a settings element in release (wiring placeholder — actual Settings screen ships in Epic 7)
**When** opened
**Then** it displays the last 100 entries, newest first, with a "Copy All" button.

**Given** `kDebugMode` is `false`
**When** the long-press is triggered
**Then** the Support screen opens (this path remains in release, unlike debug-only cheats).

### Story 1.11: Canvas Performance Spike on Low-End Android

As an architect,
I want a throwaway spike screen that parses `countries.geojson.json`, renders all 79 country polygons with a naive `CustomPainter`, and supports pan + zoom,
So that we measure frame rate on a low-end Android API 21 device before committing to the renderer design in Epic 2.

**Acceptance Criteria:**

**Given** a debug-only spike screen (`kDebugMode`-gated, reachable via a dev flag)
**When** opened on a low-end Android API 21 device (via `flutter run --profile`)
**Then** 79 polygons render and pan/zoom sustains at least 45fps average over 30 seconds with stretch-goal 60fps.

**Given** the spike measurements
**When** the story is closed
**Then** a written note is added to the architecture document or this epic file recording the measured fps and any optimization needed (e.g. "cache Path to Picture") before Epic 2.1 proceeds.

**Given** the spike is a throwaway
**When** Epic 2 begins
**Then** the spike file is deleted or clearly marked for deletion so it does not linger as dead code.

---
