# Story 1.2: Configure Lint and Analysis Options

Status: done

## Story

As a developer,
I want `analysis_options.yaml` configured with the project's lint rules,
so that architectural violations and style inconsistencies are caught at analyze time, not review time.

## Acceptance Criteria

1. **Given** `analysis_options.yaml` at the project root **When** `flutter analyze --fatal-infos` runs **Then** the analyzer uses `package:flutter_lints/flutter.yaml` as a base **And** `avoid_print: error`, `unnecessary_null_comparison: error`, `unrelated_type_equality_checks: error` are enforced as errors **And** `always_declare_return_types`, `prefer_final_fields`, `prefer_final_locals`, `require_trailing_commas`, `unawaited_futures` are enabled as lints **And** generated files (`**/*.g.dart`, `**/*.freezed.dart`, `build/**`) are excluded.

2. **Given** a developer adds `print('debug')` anywhere under `lib/` **When** `flutter analyze` runs **Then** the analyze step fails.

## Tasks / Subtasks

- [x] Task 1: Verify `analysis_options.yaml` matches architecture spec (AC: #1)
  - [x] 1.1 Confirm `include: package:flutter_lints/flutter.yaml` is present
  - [x] 1.2 Confirm `analyzer.errors` section has `avoid_print: error`, `unnecessary_null_comparison: error`, `unrelated_type_equality_checks: error`
  - [x] 1.3 Confirm `analyzer.exclude` has `lib/**/*.g.dart`, `lib/**/*.freezed.dart`, `build/**`
  - [x] 1.4 Confirm `linter.rules` has `always_declare_return_types`, `prefer_final_fields`, `prefer_final_locals`, `require_trailing_commas`, `unawaited_futures`
  - [x] 1.5 Apply any missing rules if the file is incomplete — N/A, file already complete
- [x] Task 2: Run `flutter analyze --fatal-infos` and fix all issues (AC: #1)
  - [x] 2.1 Execute `flutter analyze --fatal-infos` from project root
  - [x] 2.2 Fix any violations found in existing `lib/` code (from Story 1.1 work) — zero issues found
  - [x] 2.3 Re-run until clean — zero issues
- [x] Task 3: Validate `avoid_print` enforcement (AC: #2)
  - [x] 3.1 Temporarily add `print('test')` to a file under `lib/` (e.g. `lib/main.dart`)
  - [x] 3.2 Run `flutter analyze` and confirm it reports an error (not warning/info)
  - [x] 3.3 Remove the temporary `print()` statement
- [x] Task 4: Run `dart format --set-exit-if-changed .` (implicit quality gate)
  - [x] 4.1 Fix any formatting issues found — zero changes needed
  - [x] 4.2 Re-run until clean
- [x] Task 5: Run existing tests to confirm no regressions
  - [x] 5.1 Run `flutter test` — all 11 tests from Story 1.1 still pass

## Dev Notes

### Current State of `analysis_options.yaml`

The file **already exists and matches the architecture spec**. Story 1.1 modified it:
- Replaced the default Flutter template comments with the project's lint config
- Removed deprecated `avoid_returning_null_for_future` (removed in Dart 3.3.0)

The current content is:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    avoid_print: error
    unnecessary_null_comparison: error
    unrelated_type_equality_checks: error
  exclude:
    - lib/**/*.g.dart
    - lib/**/*.freezed.dart
    - build/**

linter:
  rules:
    - always_declare_return_types
    - prefer_final_fields
    - prefer_final_locals
    - require_trailing_commas
    - unawaited_futures
```

**This means the primary work is VALIDATION, not creation.** The file content is already correct. The dev agent must:
1. Verify the content matches the spec exactly (it does)
2. Run `flutter analyze --fatal-infos` and ensure zero issues
3. Prove `avoid_print` is enforced as an error (not just a warning)
4. Ensure formatting is clean

### Architecture Compliance

- The lint configuration comes directly from the architecture document. [Source: project-context.md#Lint config]
- `avoid_print: error` is critical — `print()` is a project-wide ban. All logging goes through `Logger('Tag')` from `package:logging`. [Source: project-context.md#Logging]
- `unawaited_futures` catches fire-and-forget `Future`s that silently drop errors — important for Drift persistence and `SystemChrome` calls.
- `require_trailing_commas` enforces consistent formatting that makes diffs cleaner and `dart format` output stable.
- `always_declare_return_types` prevents implicit `dynamic` returns — critical for type safety in the headless sim (`lib/game/`).
- Generated file exclusions prevent Drift-generated `*.g.dart` files from producing lint noise.

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| VERIFY | `analysis_options.yaml` | Confirm lint rules match architecture spec |
| NO NEW FILES | — | This story creates no new files |

### Technical Requirements

- **`flutter_lints` vs `flutter_lints`:** The project uses `flutter_lints: ^6.0.0` (in `pubspec.yaml` under `dev_dependencies`). The `include: package:flutter_lints/flutter.yaml` resolves to this package. Do NOT switch to `package:lints/recommended.yaml` — `flutter_lints` includes Flutter-specific rules on top of core Dart lints.
- **`--fatal-infos` flag:** This flag makes `flutter analyze` exit with non-zero status on info-level diagnostics too, not just warnings/errors. This is the strictest mode and matches CI expectations.
- **No `avoid_returning_null_for_future`:** This rule was removed in Dart 3.3.0. Story 1.1 already cleaned it up. Do NOT re-add it.
- **`analysis_options.yaml` changes are NOT committed yet** — they are part of the uncommitted working tree from Story 1.1's implementation. This story validates them.

### Library/Framework Requirements

- `flutter_lints: ^6.0.0` — already in `pubspec.yaml` dev_dependencies. No changes needed.
- No new packages required for this story.

### Testing Standards

- This story has no new test files to create. The validation is done via `flutter analyze` and manual `print()` insertion test.
- Existing tests (11 tests from Story 1.1) must still pass after any changes.

### Anti-Patterns to Avoid

- Do NOT add rules beyond what the architecture specifies. The lint set is intentionally curated — over-linting causes noise and lint-ignore proliferation.
- Do NOT use `// ignore:` or `// ignore_for_file:` to suppress legitimate violations. Fix the code instead.
- Do NOT switch from `flutter_lints` to `lints` or any other lint package.
- Do NOT add `pedantic` or `effective_dart` (deprecated packages).
- Do NOT remove the `build/**` exclusion — even though there's no `build/` directory yet, it prevents future generated output from triggering lint errors.

### Previous Story Intelligence

**From Story 1.1 (Wire Global Safety Net and Portrait Lock):**

- `analysis_options.yaml` was already modified: removed deprecated `avoid_returning_null_for_future` rule
- `flutter analyze` ran clean after Story 1.1 implementation (0 issues)
- `dart format --set-exit-if-changed .` — all files formatted
- `logging: ^1.3.0` was added to `pubspec.yaml` (needed explicit entry despite being a first-party package)
- Files created/modified: `lib/services/crash_reporter.dart`, `lib/ui/fallback_error_widget.dart`, `lib/main.dart`, test files under `test/services/` and `test/ui/`
- All 11 tests passing (7 CrashReporter unit + 4 widget tests)

**Key learning:** The `avoid_returning_null_for_future` lint was listed in the original architecture but was removed in Dart 3.3.0. The project context file was updated to note this. Do not re-add it.

### Git Intelligence

Recent commits are project setup only (no code changes beyond Story 1.1's uncommitted work):
- `9c804f9` — planning artifacts and settings
- `6992c42` — MCP servers config
- `8d84ab1` — BMAD setup, Flutter deps
- `91edb72` — Initial Flutter scaffold

Story 1.1's implementation is in the working tree but not yet committed.

### Project Structure Notes

- No new files created — this is a verification/validation story
- `analysis_options.yaml` is at project root (correct location)
- No conflicts with existing code

### References

- [Source: epics.md#Story 1.2] — Full acceptance criteria and user story
- [Source: project-context.md#Lint config] — Exact lint configuration from architecture
- [Source: project-context.md#Logging] — `print()` ban, `Logger` requirement
- [Source: project-context.md#Pre-commit / CI expectations] — `flutter analyze` with zero warnings
- [Source: 1-1 story file#Completion Notes] — `analysis_options.yaml` already modified, deprecated rule removed

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean validation run, no issues encountered.

### Completion Notes List

- `analysis_options.yaml` verified against architecture spec — all rules present and correct
- `flutter analyze --fatal-infos` passed with zero issues on first run
- `avoid_print` enforcement validated: inserting `print('test')` in `lib/main.dart` produced `error - Don't invoke 'print' in production code` — confirmed error severity, not warning/info
- `dart format --set-exit-if-changed .` — 5 files checked, 0 changes needed
- All 11 existing tests pass (7 CrashReporter unit + 4 widget tests)
- No code changes were required — this was a pure validation story
- Both acceptance criteria satisfied: AC#1 (lint config matches spec, analyze clean) and AC#2 (print() triggers analyze failure)

### Change Log

- 2026-04-21: Story validated — all tasks complete, no file modifications needed beyond story/sprint status updates

### File List

No files created, modified, or deleted. This was a verification-only story. The `analysis_options.yaml` was already correctly configured by Story 1.1.
