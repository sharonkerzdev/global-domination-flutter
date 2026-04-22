# Story 1.3: Enforce "No Flutter in `lib/game/`" Boundary

Status: done

## Story

As an architect,
I want a mechanized check that fails CI if any file under `lib/game/` imports `package:flutter/*`,
so that the headless-simulation invariant cannot silently drift.

## Acceptance Criteria

1. **Given** the project CI pipeline **When** any file under `lib/game/**/*.dart` contains a line matching `import 'package:flutter/` or `import "package:flutter/` **Then** the CI step fails with a clear error naming the offending file and line **And** the check is implemented either as a `custom_lint` rule or a CI grep script, whichever is simpler.

2. **Given** a developer tries to add `import 'package:flutter/material.dart';` to a new file in `lib/game/` **When** they run `flutter analyze` or push to CI **Then** the build fails before tests run.

## Tasks / Subtasks

- [x] Task 1: Create boundary enforcement test (AC: #1, #2)
  - [x] 1.1 Create `test/architecture/game_boundary_test.dart` — a pure Dart test that recursively scans all `*.dart` files under `lib/game/` for forbidden imports (`package:flutter/`, `dart:ui`)
  - [x] 1.2 The test must report the exact file path and offending line on failure
  - [x] 1.3 The test must pass when `lib/game/` does not yet exist (no files = no violations)
  - [x] 1.4 Also check for `dart:ui` imports (architecture says "zero Flutter imports, no `dart:ui`")
- [x] Task 2: Also check `lib/game/` → `lib/data/` forbidden reverse dependency (AC: #1)
  - [x] 2.1 In the same test file, add a test that scans `lib/game/**/*.dart` for `import '...data/` or `import 'package:global_domination/data/` patterns
  - [x] 2.2 Report exact file and line on failure
- [x] Task 3: Validate the test catches violations (AC: #2)
  - [x] 3.1 Temporarily create a file `lib/game/test_violation.dart` with `import 'package:flutter/material.dart';`
  - [x] 3.2 Run the boundary test and confirm it fails with a clear error message naming the file
  - [x] 3.3 Delete the temporary violation file
  - [x] 3.4 Re-run and confirm the test passes
- [x] Task 4: Document CI grep command (AC: #1)
  - [x] 4.1 Add a comment at the top of the test file documenting the equivalent CI grep one-liner: `grep -rn "import 'package:flutter/" lib/game/ && exit 1 || exit 0`
  - [x] 4.2 This serves as the reference for when CI pipeline is wired (future story)
- [x] Task 5: Run all existing tests to confirm no regressions
  - [x] 5.1 Run `flutter test` — all existing tests (from Stories 1.1 and 1.2) must still pass
  - [x] 5.2 Run `flutter analyze --fatal-infos` — zero issues

## Dev Notes

### Implementation Approach: Test-Based Enforcement

The architecture says "either as a `custom_lint` rule or a CI grep script, whichever is simpler." A **Dart test** is the simplest approach that provides:
- Runs in `flutter test` (which is part of CI pipeline per project-context.md)
- Reports exact file and line number on failure
- No additional packages needed (no `custom_lint` dependency)
- Works locally during development, not just in CI

`custom_lint` was considered but rejected for v1: it requires adding `custom_lint` + `analyzer_plugin` packages, writing analyzer plugin code, and managing plugin lifecycle. A test achieves the same enforcement with zero new dependencies.

### What to Scan For

The test must detect these forbidden patterns in any `*.dart` file under `lib/game/`:

1. **`import 'package:flutter/...`** or **`import "package:flutter/...`** — any Flutter SDK import
2. **`import 'dart:ui'`** — `dart:ui` is Flutter-specific, not available in pure Dart
3. **`import '...data/...`** or **`import 'package:global_domination/data/...`** — reverse dependency from game → data is forbidden

### Architecture Compliance

- **NFR8:** `lib/game/` contains zero Flutter imports — this story mechanizes that enforcement [Source: epics.md#NFR8]
- **NFR9:** `lib/game/` never imports `lib/data/` — bonus check to enforce this boundary too [Source: epics.md#NFR9]
- **Boundary rule #1:** "No Flutter imports in `lib/game/`. Enforced via `custom_lint` rule or CI grep. Breakage is a test failure, not a style suggestion." [Source: game-architecture.md#Architectural Boundaries]
- **CI expectations:** "Grep check: fail CI if `package:flutter/` appears anywhere under `lib/game/**`" [Source: project-context.md#Pre-commit / CI expectations]
- `dart:ui` is also forbidden per project-context.md: "No `package:flutter/*`, no `dart:ui`. Pure Dart only."

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `test/architecture/game_boundary_test.dart` | Boundary enforcement test |
| NO CHANGES | `lib/` | No production code changes |
| NO CHANGES | `pubspec.yaml` | No new dependencies |

### Technical Requirements

- **Test location:** `test/architecture/` — a new directory for architecture enforcement tests, separate from feature tests. This mirrors the pattern of architecture tests being cross-cutting, not tied to a specific feature.
- **Use `dart:io` for file scanning:** The test reads the filesystem directly using `dart:io` (`Directory`, `File`). This is fine in test code — the prohibition on `dart:io` is only for `lib/game/` sim code.
- **Regex patterns:** Use `RegExp` to match import lines. Must handle both single-quote and double-quote import styles. Must NOT false-positive on comments or strings containing the word "flutter".
- **Handle missing `lib/game/`:** The directory doesn't exist yet (first `lib/game/` files come in Story 1.5+). The test must pass trivially when the directory is absent — no violations if no files exist.
- **`flutter_test` is fine here:** This is a test under `test/architecture/`, not `test/game/`. Architecture tests can use `flutter_test`.

### Testing Standards

- This test IS the deliverable — there's no separate "test the test" except the manual violation check in Task 3.
- The test must be deterministic: scan filesystem, pattern match, report. No flakiness vectors.
- Future `lib/game/` stories will automatically be covered by this test existing in the suite.

### Anti-Patterns to Avoid

- Do NOT add `custom_lint` as a dependency — unnecessary complexity for v1.
- Do NOT scan only specific subdirectories of `lib/game/` — scan ALL `*.dart` files recursively.
- Do NOT use `Process.run('grep', ...)` in the test — use Dart's `dart:io` directly for portability.
- Do NOT ignore `part` files or generated files under `lib/game/` — there should be none (no code generation in the game layer), but if somehow present, they must also comply.
- Do NOT add a catch-all that silently passes if scanning fails — errors in the test itself should surface.
- Do NOT put this test under `test/game/` — architecture tests are cross-cutting and belong in `test/architecture/`. Also, `test/game/` tests must use `package:test/test.dart` (not `flutter_test`), and this test needs `dart:io` which works better with `flutter_test`.

### Previous Story Intelligence

**From Story 1.2 (Configure Lint and Analysis Options):**
- `analysis_options.yaml` is configured and verified — `flutter analyze --fatal-infos` passes clean
- All 11 existing tests pass (7 CrashReporter unit + 4 widget tests)
- No production code changes were made in Story 1.2 — it was pure validation
- The lint config includes `avoid_print: error` which is already enforced

**From Story 1.1 (Wire Global Safety Net):**
- Files exist: `lib/main.dart`, `lib/services/crash_reporter.dart`, `lib/ui/fallback_error_widget.dart`
- Tests exist: `test/services/crash_reporter_test.dart`, `test/ui/main_test.dart`
- `logging: ^1.3.0` added to pubspec
- `lib/game/` directory does NOT yet exist — first game-layer files come in Story 1.5

### Git Intelligence

Recent commits are all project setup — no feature code beyond Story 1.1's uncommitted work:
- `9c804f9` — planning artifacts and settings
- `6992c42` — MCP servers config
- `8d84ab1` — BMAD setup, Flutter deps
- `91edb72` — Initial Flutter scaffold

### Project Structure Notes

- New directory `test/architecture/` follows the pattern of separating cross-cutting tests from feature tests
- Aligns with the existing test structure: `test/services/`, `test/ui/` mirror `lib/services/`, `lib/ui/`
- `test/architecture/` is not mirroring a `lib/` directory — it's a test-only cross-cutting concern

### References

- [Source: epics.md#Story 1.3] — Acceptance criteria and user story
- [Source: game-architecture.md#Architectural Boundaries] — "No Flutter imports in `lib/game/`. Enforced via `custom_lint` rule or CI grep."
- [Source: project-context.md#Critical Implementation Rules] — "`lib/game/` has ZERO Flutter imports. No `package:flutter/*`, no `dart:ui`."
- [Source: project-context.md#Pre-commit / CI expectations] — "Grep check: fail CI if `package:flutter/` appears anywhere under `lib/game/**`"
- [Source: project-context.md#Code Organization Rules] — Dependency graph showing `game/` as an island of purity
- [Source: 1-2-configure-lint-and-analysis-options.md] — Previous story context, 11 passing tests

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no errors.

### Completion Notes List

- Created `test/architecture/game_boundary_test.dart` with 4 tests enforcing architectural boundaries
- Test 1: Scans `lib/game/**/*.dart` for forbidden `package:flutter/` imports (both quote styles)
- Test 2: Scans for forbidden `dart:ui` imports
- Test 3: Scans for forbidden reverse dependency on `lib/data/` (relative and package imports)
- Test 4: Verifies graceful handling when `lib/game/` directory doesn't exist
- All tests skip commented lines to avoid false positives
- Violation validation: created temporary `lib/game/test_violation.dart` with Flutter import, confirmed test failure with clear file:line error, deleted file, confirmed pass
- CI grep one-liners documented at top of test file for future CI pipeline wiring
- Full regression suite: 15/15 tests pass (11 existing + 4 new)
- `flutter analyze --fatal-infos`: zero issues
- No production code changes, no new dependencies

### Change Log

- 2026-04-21: Implemented Story 1.3 — created boundary enforcement tests in `test/architecture/game_boundary_test.dart`
- 2026-04-21: Code review passed — 0 High, 0 Medium findings. All ACs verified implemented, 15/15 tests pass, analyzer clean. Status → done.

### File List

| Action | File |
|--------|------|
| CREATE | `test/architecture/game_boundary_test.dart` |
