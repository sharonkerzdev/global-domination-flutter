# Story 1.1: Wire Global Safety Net and Portrait Lock in `main.dart`

Status: done

## Story

As a developer,
I want global error handlers, portrait orientation lock, and a Riverpod `ProviderScope` configured in `main.dart`,
so that uncaught errors are captured instead of crashing the app silently and orientation is guaranteed from first frame.

## Acceptance Criteria

1. **Given** the app is launched **When** an uncaught error occurs in a Flutter widget, platform error, or zoned code **Then** `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded` all route the error to a `CrashReporter` singleton **And** the app does not crash to a blank white screen — it displays a fallback error screen with a "Restart" CTA.

2. **Given** the app launches on any supported device **When** the first frame renders **Then** `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` has been awaited before `runApp()` **And** the device cannot rotate the app to landscape.

3. **Given** the `main.dart` entry point **When** the app starts **Then** `runApp()` is wrapped in a `ProviderScope` so Riverpod providers are available throughout the widget tree.

## Tasks / Subtasks

- [x] Task 1: Create `CrashReporter` singleton (AC: #1)
  - [x] 1.1 Create `lib/services/crash_reporter.dart` with a `CrashReporter` class
  - [x] 1.2 Implement `reportFlutterError(FlutterErrorDetails)` method
  - [x] 1.3 Implement `reportPlatformError(Object error, StackTrace stack)` method
  - [x] 1.4 Implement `reportZonedError(Object error, StackTrace stack)` method
  - [x] 1.5 Use `package:logging` (`Logger('CrashReporter')`) — NEVER `print()`
  - [x] 1.6 Keep the implementation minimal — log the error. The ring buffer and Support screen come in Story 1.10
- [x] Task 2: Set `ErrorWidget.builder` for release fallback (AC: #1)
  - [x] 2.1 In `main()`, set `ErrorWidget.builder` to return a simple fallback widget (red/dark screen with "Something went wrong" text and a "Restart" button that calls `SystemNavigator.pop()` or restarts the app root)
  - [x] 2.2 The fallback must NOT use any provider or game state — it is a static, self-contained widget
- [x] Task 3: Wire all three global error handlers to `CrashReporter` (AC: #1)
  - [x] 3.1 `FlutterError.onError` → `CrashReporter.instance.reportFlutterError(details)`
  - [x] 3.2 `PlatformDispatcher.instance.onError` → `CrashReporter.instance.reportPlatformError(error, stack)` and return `true`
  - [x] 3.3 `runZonedGuarded` error callback → `CrashReporter.instance.reportZonedError(error, stack)`
- [x] Task 4: Add portrait orientation lock (AC: #2)
  - [x] 4.1 Call `WidgetsFlutterBinding.ensureInitialized()` first
  - [x] 4.2 `await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` BEFORE `runApp()`
  - [x] 4.3 Import `package:flutter/services.dart` for `SystemChrome` and `DeviceOrientation`
- [x] Task 5: Ensure `ProviderScope` wraps app (AC: #3)
  - [x] 5.1 Confirm `runApp(const ProviderScope(child: ...))` pattern (already partially in place)
- [x] Task 6: Write tests
  - [x] 6.1 Unit test for `CrashReporter` — verify it does not throw when receiving errors (flutter_test used since `FlutterErrorDetails` needed)
  - [x] 6.2 Widget test: verify `ErrorWidget.builder` returns the fallback widget, not the default red error box
  - [x] 6.3 Widget test: verify the app starts inside a `ProviderScope`

## Dev Notes

### Current State of `main.dart`

The file already exists at `lib/main.dart` with:
- `runZonedGuarded` wrapping the app
- `FlutterError.onError` and `PlatformDispatcher.instance.onError` stubs (handlers are empty — just `presentError` / `return true`)
- `ProviderScope` wrapping `runApp`
- A `_Placeholder` widget as the root

**What needs to change:** The empty handler bodies must route to `CrashReporter`. Portrait lock and `ErrorWidget.builder` must be added. The `_Placeholder` widget stays as-is — it will be replaced in later stories.

### Architecture Compliance

- `CrashReporter` lives in `lib/services/crash_reporter.dart` per the project structure. [Source: project-context.md#Code Organization Rules]
- `lib/main.dart` is the ONLY file that contains boot-time global setup. Do NOT spread init logic across multiple files. [Source: project-context.md#File content discipline]
- Use `Logger('CrashReporter')` from `package:logging` — NEVER `print()`. `avoid_print` is elevated to `error` in `analysis_options.yaml`. [Source: project-context.md#Logging]
- `CrashReporter` is a service. Services subscribe to events but never emit `GameEvent`s. At this stage, `CrashReporter` is standalone — it will subscribe to the event stream in a later epic. [Source: project-context.md#Engine-Specific Rules]

### File Structure

Files to create or modify:

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/services/crash_reporter.dart` | Singleton crash reporter that logs errors via `package:logging` |
| MODIFY | `lib/main.dart` | Wire handlers to CrashReporter, add portrait lock, add ErrorWidget.builder |
| CREATE | `test/services/crash_reporter_test.dart` | Unit tests for CrashReporter |
| CREATE | `test/ui/main_test.dart` | Widget tests for error fallback and ProviderScope |

### Technical Requirements

- **Portrait lock call order matters:** `WidgetsFlutterBinding.ensureInitialized()` MUST be called before `SystemChrome.setPreferredOrientations()`. The `await` on `setPreferredOrientations` MUST complete before `runApp()`.
- **`ErrorWidget.builder` assignment:** Must happen after binding init, before `runApp()`. It replaces the default red error screen in debug and the grey screen in release.
- **CrashReporter singleton pattern:** Use a simple `static final instance = CrashReporter._()` private constructor pattern. Do NOT use `get_it` (forbidden package).
- **Fallback error widget:** Must be a plain `MaterialApp` + `Scaffold` with no dependencies on providers, game state, or theming. It is the last-resort screen when everything else is broken.
- **`return true` in `PlatformDispatcher.instance.onError`:** Returning `true` signals that the error has been handled and prevents the framework from reporting it to the default error handler.

### Library/Framework Requirements

- `package:flutter/services.dart` — for `SystemChrome`, `DeviceOrientation`, `SystemNavigator`
- `package:flutter/material.dart` — already imported
- `package:flutter_riverpod/flutter_riverpod.dart` — already imported
- `package:logging/logging.dart` — add to imports in `crash_reporter.dart`. **Note:** `logging` is a Dart core package (ships with the SDK), does NOT need to be added to `pubspec.yaml`.
- Do NOT add any crash reporting SDK (Crashlytics, Sentry) — deferred to Epic 13. [Source: project-context.md#Forbidden packages]

### Testing Standards

- `CrashReporter` tests: Use `package:test/test.dart` if possible (it's a service, not a widget). However, if `FlutterErrorDetails` is needed in tests, use `package:flutter_test/flutter_test.dart`.
- Widget tests for error fallback: Use `package:flutter_test/flutter_test.dart` with `ProviderScope(overrides: [])`.
- Tests go under `test/services/` and `test/ui/` mirroring the `lib/` structure.
- Do NOT create tests under `test/game/` — this story has no `lib/game/` code.

### Anti-Patterns to Avoid

- Do NOT `print()` anywhere — use `Logger`.
- Do NOT create a second `main()` or spread boot logic into `app.dart` yet — all init stays in `main.dart` for this story.
- Do NOT add error analytics or network reporting — offline-only for v1.
- Do NOT use `FlutterError.presentError` as the primary handler — it only works in debug mode. Route to `CrashReporter` which uses `Logger`.
- Do NOT use `runApp()` inside a try/catch — `runZonedGuarded` is the correct pattern.
- The fallback error widget MUST NOT use `const` constructor if it takes dynamic error info — but for simplicity, a static message is fine for v1.

### Project Structure Notes

- Alignment with unified project structure confirmed: `lib/services/crash_reporter.dart` is the correct location.
- No conflicts with existing code — only `lib/main.dart` exists currently.
- This is the FIRST story in the project — no previous patterns to follow yet. Patterns established here (logging setup, singleton services, test structure) will be referenced by all subsequent stories.

### References

- [Source: epics.md#Story 1.1] — Full acceptance criteria and user story
- [Source: project-context.md#Critical Implementation Rules] — Global handlers in `main.dart`, Logger usage, service patterns
- [Source: project-context.md#Code Organization Rules] — `lib/main.dart` contains boot-time global setup ONLY
- [Source: project-context.md#Testing Rules] — Test file placement and import conventions
- [Source: project-context.md#Anti-patterns] — No `print()`, no crash SDK for v1
- [Source: game-architecture.md#Executive Summary] — Portrait-locked, iOS 16+ / Android API 21+
- [Source: pubspec.yaml] — Current dependency list (no additions needed for this story)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- `flutter analyze` — 0 issues after fixing deprecated `avoid_returning_null_for_future` lint rule (removed in Dart 3.3.0)
- `flutter test` — 10/10 tests pass (7 CrashReporter unit tests, 3 widget tests)
- `dart format --set-exit-if-changed .` — all files formatted
- Note: `logging` package needed explicit `pubspec.yaml` entry despite story note saying it ships with SDK — it's a first-party package but still requires a dependency declaration

### Completion Notes List

- Created `CrashReporter` singleton at `lib/services/crash_reporter.dart` using `static final instance = CrashReporter._()` pattern with `Logger('CrashReporter')` for all error reporting
- Wired all three global error handlers in `main.dart`: `FlutterError.onError`, `PlatformDispatcher.instance.onError` (returns `true`), and `runZonedGuarded` error callback — all route to `CrashReporter`
- Added `ErrorWidget.builder` assignment producing a dark-background `_FallbackErrorWidget` with "Something went wrong" text and "Restart" button (`SystemNavigator.pop()`) — fully self-contained with zero provider dependencies
- Portrait lock: `WidgetsFlutterBinding.ensureInitialized()` → `await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` → `runApp()` — correct call order enforced
- `ProviderScope` wrapping confirmed (was already in place)
- Added `logging: ^1.3.0` to `pubspec.yaml` (was transitive, promoted to direct)
- Removed deprecated `avoid_returning_null_for_future` lint rule from `analysis_options.yaml`
- 7 unit tests for `CrashReporter` (singleton identity, no-throw on all three error types, Logger integration)
- 3 widget tests (fallback widget renders correctly, fallback has no provider dependencies, app starts inside ProviderScope)

### File List

- `lib/services/crash_reporter.dart` (CREATED) — CrashReporter singleton service
- `lib/ui/fallback_error_widget.dart` (CREATED) — Public `FallbackErrorWidget` used by `ErrorWidget.builder`
- `lib/main.dart` (MODIFIED) — Wired error handlers, added portrait lock, wired `ErrorWidget.builder` to `FallbackErrorWidget`
- `test/services/crash_reporter_test.dart` (CREATED) — 7 unit tests for CrashReporter
- `test/ui/main_test.dart` (CREATED) — 4 widget tests covering `FallbackErrorWidget` and ProviderScope boot
- `test/widget_test.dart` (DELETED) — Default scaffold test removed (replaced by `test/ui/main_test.dart`)
- `pubspec.yaml` (MODIFIED) — Added `logging: ^1.3.0` direct dependency
- `analysis_options.yaml` (MODIFIED) — Removed deprecated `avoid_returning_null_for_future` lint rule (removed in Dart 3.3.0)
- `_bmad-output/project-context.md` (MODIFIED) — Noted `avoid_returning_null_for_future` was removed in Dart 3.3.0 so future stories don't re-add it

## Change Log

- 2026-04-21: Implemented Story 1.1 — Global safety net (CrashReporter + error handlers + fallback widget), portrait lock, ProviderScope confirmed. 10 tests added, all passing. Added `logging` dependency, fixed deprecated lint rule.
- 2026-04-21: Code review fixes — Extracted `FallbackErrorWidget` to `lib/ui/fallback_error_widget.dart` (was private in `main.dart`, untestable); widget tests now exercise the real widget. Cleaned up duplicated log context in `CrashReporter`. Updated File List to include previously undocumented `test/widget_test.dart` deletion and `pubspec.yaml` / `analysis_options.yaml` modifications. Patched `project-context.md` to reflect Dart 3.3.0 removing `avoid_returning_null_for_future`. `flutter analyze` clean; 11/11 tests pass. Status → done.
