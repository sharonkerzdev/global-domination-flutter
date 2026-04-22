# Story 1.8: Define `GameError` Sealed Hierarchy and `Result<T, GameError>`

Status: done

## Story

As a developer,
I want a `GameError` sealed class hierarchy (`UserError` / `InternalError` variants) and a `Result<T, E>` sealed type,
So that recoverable game-logic failures flow through typed returns rather than exceptions.

## Acceptance Criteria

1. **Given** `lib/game/values/result.dart` and `lib/game/game_error.dart` **When** a reducer returns `Result.failure(GameError.userInsufficientFunds(required: cost))` **Then** the caller can pattern-match on `Success` / `Failure` exhaustively.

2. **Given** the `GameError` hierarchy **When** it is exhaustively pattern-matched **Then** `UserError` variants include at minimum `insufficientFunds`, `locked`, `invalidTarget` **And** `InternalError` variants include at minimum `missingCountry`, `invariantBroken`, `persistenceFailure`, `migrationFailure`.

3. **Given** unit tests **When** they construct each variant **Then** equality, `hashCode`, and `toString` behave per Dart conventions and are covered.

## Tasks / Subtasks

- [x] Task 1: Create `Result<T, E>` sealed type (AC: #1)
  - [x] 1.1 Create `lib/game/values/result.dart` — sealed class `Result<T, E>` with two variants: `Success<T, E>({T value})` and `Failure<T, E>({E error})`
  - [x] 1.2 Implement `==`, `hashCode`, `toString` on both variants
  - [x] 1.3 Add convenience getters: `bool get isSuccess`, `bool get isFailure`, `T? get valueOrNull`, `E? get errorOrNull`
  - [x] 1.4 Add `T getOrElse(T Function(E) orElse)` and `Result<U, E> map<U>(U Function(T) f)` for ergonomic chaining

- [x] Task 2: Create `GameError` sealed hierarchy (AC: #2)
  - [x] 2.1 Create `lib/game/game_error.dart` — sealed class `GameError` with two sealed subtypes: `UserError` and `InternalError`
  - [x] 2.2 Define `UserError` variants as `final class` subtypes:
    - `InsufficientFunds({required Influence required})` — player lacks funds for a purchase
    - `Locked({required String reason})` — action blocked (e.g. `'ip_below_10'`, `'max_level'`, `'leader_already_hired'`, `'continent_locked'`, `'boost_already_active'`)
    - `InvalidTarget({required String detail})` — action targets something invalid
  - [x] 2.3 Define `InternalError` variants as `final class` subtypes:
    - `MissingCountry({required CountryId id})` — country ID not found in state
    - `InvariantBroken({required String message})` — programmer-error invariant violation
    - `PersistenceFailure({required String cause})` — database operation failed
    - `MigrationFailure({required int fromVersion, required int toVersion, required String cause})` — schema migration failed
  - [x] 2.4 Implement `==`, `hashCode`, `toString` on all variant classes
  - [x] 2.5 Add named constructors on `GameError` for ergonomic creation: `GameError.userInsufficientFunds(...)`, `GameError.userLocked(...)`, `GameError.userInvalidTarget(...)`, `GameError.internalMissingCountry(...)`, `GameError.internalInvariantBroken(...)`, `GameError.internalPersistenceFailure(...)`, `GameError.internalMigrationFailure(...)`

- [x] Task 3: Write tests for `Result<T, E>` (AC: #1, #3)
  - [x] 3.1 Create `test/game/values/result_test.dart` using `package:test/test.dart`:
    - Test: `Result.success(42)` is `Success`, `isSuccess == true`, `isFailure == false`, `valueOrNull == 42`, `errorOrNull == null`
    - Test: `Result.failure('err')` is `Failure`, `isFailure == true`, `isSuccess == false`, `errorOrNull == 'err'`, `valueOrNull == null`
    - Test: exhaustive pattern match on `Success` / `Failure`
    - Test: `==` and `hashCode` — two `Success` with same value are equal; `Success` != `Failure`
    - Test: `toString` includes variant name and payload
    - Test: `map` transforms `Success` value, passes through `Failure`
    - Test: `getOrElse` returns value on success, calls fallback on failure

- [x] Task 4: Write tests for `GameError` hierarchy (AC: #2, #3)
  - [x] 4.1 Create `test/game/game_error_test.dart` using `package:test/test.dart`:
    - Test: each `UserError` variant constructs and exposes fields correctly
    - Test: each `InternalError` variant constructs and exposes fields correctly
    - Test: exhaustive pattern match on `GameError` → `UserError` → variants and `InternalError` → variants
    - Test: `==` and `hashCode` — same variant with same fields are equal; different fields are not equal; different variants are not equal
    - Test: `toString` for each variant includes variant name and field values
    - Test: named constructors (`GameError.userInsufficientFunds(...)`, etc.) produce correct variant types
    - Test: `Result<T, GameError>` composes correctly — `Result.failure(GameError.userLocked(reason: 'test'))` is pattern-matchable

- [x] Task 5: Run analyzer and full test suite (AC: all)
  - [x] 5.1 Run `flutter analyze --fatal-infos` — zero issues
  - [x] 5.2 Run `dart test test/game/` — all pure-Dart tests pass (including existing 122)
  - [x] 5.3 Verify `lib/game/game_error.dart` and `lib/game/values/result.dart` have ZERO Flutter imports

## Dev Notes

### Architecture Compliance

**Both files live in `lib/game/` — ZERO Flutter imports. Pure Dart only.**

File locations per architecture [Source: game-architecture.md#File Structure, lines 553-563]:
- `lib/game/game_error.dart` — sealed error hierarchy (top-level game file)
- `lib/game/values/result.dart` — generic Result type (values directory, alongside `influence.dart`, `intel.dart`, `country_id.dart`)

The architecture specifies `Result<T, GameError>` as the standard return type for all reducers [Source: game-architecture.md#Error Handling, lines 336-384]. Every reducer in future epics (3, 4, 5, 6) will return `Result<(GameState, GameEvent), GameError>`. Story 1.9 (`GameWorld.applyCommand`) will be the first consumer — it returns `Result<void, GameError>`.

### Implementation Approach

**`Result<T, E>` — generic sealed type:**

```dart
sealed class Result<T, E> {
  const Result();

  factory Result.success(T value) = Success<T, E>;
  factory Result.failure(E error) = Failure<T, E>;

  bool get isSuccess;
  bool get isFailure;
  T? get valueOrNull;
  E? get errorOrNull;
}

final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
  // ... ==, hashCode, toString
}

final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
  // ... ==, hashCode, toString
}
```

Key decisions:
- `Result` is **generic over both `T` and `E`** — not hardcoded to `GameError`. This allows reuse (e.g. `Result<void, GameError>`, `Result<CountryState, GameError>`, `Result<(GameState, GameEvent), GameError>`).
- `const` constructors on both variants for compile-time constant results.
- Factory constructors on the sealed base enable `Result.success(...)` and `Result.failure(...)` without importing variant classes.
- `map` and `getOrElse` enable ergonomic chaining without forcing pattern match at every call site.

**`GameError` — two-level sealed hierarchy:**

```dart
sealed class GameError {
  const GameError();

  // Named constructors for ergonomic creation
  factory GameError.userInsufficientFunds({required Influence required}) =
      InsufficientFunds;
  factory GameError.userLocked({required String reason}) = Locked;
  factory GameError.userInvalidTarget({required String detail}) = InvalidTarget;
  factory GameError.internalMissingCountry({required CountryId id}) =
      MissingCountry;
  factory GameError.internalInvariantBroken({required String message}) =
      InvariantBroken;
  factory GameError.internalPersistenceFailure({required String cause}) =
      PersistenceFailure;
  factory GameError.internalMigrationFailure({
    required int fromVersion,
    required int toVersion,
    required String cause,
  }) = MigrationFailure;
}

sealed class UserError extends GameError {
  const UserError();
}

final class InsufficientFunds extends UserError {
  final Influence required;
  const InsufficientFunds({required this.required});
  // ... ==, hashCode, toString
}

final class Locked extends UserError {
  final String reason;
  const Locked({required this.reason});
  // ... ==, hashCode, toString
}

final class InvalidTarget extends UserError {
  final String detail;
  const InvalidTarget({required this.detail});
  // ... ==, hashCode, toString
}

sealed class InternalError extends GameError {
  const InternalError();
}

final class MissingCountry extends InternalError {
  final CountryId id;
  const MissingCountry({required this.id});
  // ... ==, hashCode, toString
}

final class InvariantBroken extends InternalError {
  final String message;
  const InvariantBroken({required this.message});
  // ... ==, hashCode, toString
}

final class PersistenceFailure extends InternalError {
  final String cause;
  const PersistenceFailure({required this.cause});
  // ... ==, hashCode, toString
}

final class MigrationFailure extends InternalError {
  final int fromVersion;
  final int toVersion;
  final String cause;
  const MigrationFailure({
    required this.fromVersion,
    required this.toVersion,
    required this.cause,
  });
  // ... ==, hashCode, toString
}
```

Key decisions:
- `UserError` and `InternalError` are **sealed subtypes** (not `final`) — this enables two-level exhaustive switching: first `UserError` vs `InternalError`, then individual variants within each.
- `InsufficientFunds.required` uses the `Influence` value type (from `lib/game/values/influence.dart`) — not raw `Decimal` or `double`. This keeps the error hierarchy consistent with the value-object discipline. [Source: project-context.md#Big numbers]
- `MissingCountry.id` uses `CountryId` (from `lib/game/values/country_id.dart`) — typed, not raw `String`.
- Named constructors on `GameError` base class (e.g. `GameError.userInsufficientFunds(...)`) redirect to the concrete variant. This matches the architecture examples exactly [Source: game-architecture.md#Error Handling, lines 365-368].
- All variant classes are `final class` — no further subclassing.
- Manual `==`, `hashCode`, `toString` per project convention (no `freezed`). [Source: project-context.md#File content discipline]

**Exhaustive switch pattern (architecture intent):**

```dart
final result = reducer.purchaseIP(state, cmd, now: now);
switch (result) {
  case Success(:final value):
    // apply state + emit event
  case Failure(error: UserError error):
    // surface to UI (ErrorRouter)
  case Failure(error: InternalError error):
    // log silently
}
```

The two-level hierarchy allows coarse-grained switching (UserError vs InternalError) and fine-grained switching (individual variants). Both are compiler-enforced exhaustive.

### Relationship to `ContentLoadException`

Story 1.7 created `ContentLoadException` at `lib/game/content/content_load_exception.dart`. This is a **boot-time-only** exception, NOT part of `GameError`. `ContentLoadException` fires before `GameWorld` exists — it's caught at the boot gate level and shows `BootErrorScreen`. `GameError` is for in-game recoverable errors during normal operation. Do NOT merge them. [Source: 1-7 story, Task 5 note]

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/game/values/result.dart` | Generic `Result<T, E>` sealed type |
| CREATE | `lib/game/game_error.dart` | `GameError` sealed hierarchy (UserError / InternalError) |
| CREATE | `test/game/values/result_test.dart` | Result type tests |
| CREATE | `test/game/game_error_test.dart` | GameError hierarchy tests |

### Testing Standards

- **Both test files** use `package:test/test.dart` only (NOT `flutter_test`). Both source files are pure Dart under `lib/game/`.
- Test every variant: construction, field access, `==`, `hashCode`, `toString`.
- Test exhaustive pattern matching compiles and resolves correctly.
- Test composition: `Result<SomeType, GameError>` with various `GameError` variants.
- Test named constructor factories on `GameError` produce correct concrete types.

### Anti-Patterns to Avoid

- Do NOT use `Exception` or `Error` as the base class for `GameError` — it is a sealed data class, not a throwable. Errors flow through `Result`, not `throw/catch`.
- Do NOT add Flutter imports to either file — both live in `lib/game/`.
- Do NOT use `freezed` or `json_serializable` — manual `==`/`hashCode`/`toString`. [Source: project-context.md#File content discipline]
- Do NOT use `double` for the `InsufficientFunds.required` field — use `Influence`. [Source: project-context.md#Big numbers]
- Do NOT use raw `String` for `MissingCountry.id` — use `CountryId`.
- Do NOT add a catch-all `case _ =>` in test exhaustive-match tests — the point is to prove the compiler enforces exhaustiveness.
- Do NOT create `GameError` variants for boot-time failures — `ContentLoadException` already covers that. `GameError` is for in-game recoverable errors only.
- Do NOT extend `GameError` with non-sealed subclasses — `UserError` and `InternalError` are `sealed`, all concrete variants are `final class`.
- Do NOT add `package:logging` imports or any logging to these files — they are pure data types with no side effects.

### Previous Story Intelligence

**From Story 1.7 (ContentRegistry):**
- `ContentLoadException` is boot-time only — separate from `GameError`. Story 1.7 explicitly notes this: "This is a boot-time-only exception, NOT part of the `GameError` hierarchy (Story 1.8)".
- Pattern for `@immutable` + `const` constructor + manual `==`/`hashCode`/`toString` is well-established in `*Def` classes.
- 149 total tests passing, zero analyzer issues.

**From Story 1.5 (Influence/Intel Value Objects):**
- `Influence` value object at `lib/game/values/influence.dart` — wraps `Decimal`, implements `==`, `hashCode`, `toString`, `Comparable`. `InsufficientFunds` uses this type for its `required` field.
- `Intel` value object at `lib/game/values/intel.dart` — same pattern.
- Import: `import 'package:global_domination/game/values/influence.dart';`

**From Story 1.5 (CountryId/ContinentId):**
- `CountryId` at `lib/game/values/country_id.dart` — typed wrapper around `String`. `MissingCountry` uses this type for its `id` field.
- Import: `import 'package:global_domination/game/values/country_id.dart';`

**From Story 1.3 (Architecture Boundary):**
- `test/architecture/game_boundary_test.dart` enforces no Flutter imports in `lib/game/`. New files will be automatically covered.

**Key patterns established:**
- File naming: `snake_case.dart`, one public class per file (sealed hierarchies are the stated exception — `game_error.dart` holds the full hierarchy)
- Test naming: `{source_name}_test.dart` mirroring lib path
- All `lib/game/` tests use `package:test/test.dart`
- `@immutable` on value/data classes, `const` constructors

### Project Structure Notes

- `lib/game/game_error.dart` is a new top-level file in `lib/game/` — matches architecture file tree [Source: game-architecture.md#File Structure, line 555]
- `lib/game/values/result.dart` goes alongside existing `influence.dart`, `intel.dart`, `country_id.dart`, `continent_id.dart` [Source: game-architecture.md#File Structure, line 563]
- Sealed hierarchies are explicitly noted as the exception to "one public class per file" [Source: game-architecture.md#Naming Conventions, line 706]

### References

- [Source: epics.md#Story 1.8] — Acceptance criteria, user story statement
- [Source: epics.md#NFR16] — "Recoverable game errors use `Result<T, GameError>` sealed hierarchy — no exceptions for control flow"
- [Source: game-architecture.md#Error Handling, lines 336-384] — Full `GameError` hierarchy definition, `Result` usage examples, error handling rules
- [Source: game-architecture.md#File Structure, lines 550-563] — `game_error.dart` and `result.dart` file locations
- [Source: game-architecture.md#Reducers, lines 776-806] — Reducer return type `Result<(GameState, GameEvent), GameError>`, usage examples
- [Source: game-architecture.md#Naming Conventions, line 706] — Sealed hierarchies exception to one-class-per-file
- [Source: project-context.md#Result / error handling] — `Result<T, GameError>` rules, `UserError` vs `InternalError` distinction
- [Source: project-context.md#Big numbers] — Always use `Influence`/`Intel` value objects, never raw `Decimal` or `double`
- [Source: project-context.md#File content discipline] — No `freezed`, manual `copyWith`/`==`/`hashCode`

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Implemented `Result<T, E>` sealed type with `Success`/`Failure` variants, `const` factory constructors, `map`, `getOrElse`, convenience getters, and manual `==`/`hashCode`/`toString`
- Implemented `GameError` two-level sealed hierarchy: `UserError` (InsufficientFunds, Locked, InvalidTarget) and `InternalError` (MissingCountry, InvariantBroken, PersistenceFailure, MigrationFailure) with `const` factory named constructors on the base class
- `InsufficientFunds.required` uses `Influence` value type; `MissingCountry.id` uses `CountryId` — no raw primitives
- 14 Result tests + 42 GameError tests = 56 new tests; 178 total passing (zero regressions)
- `flutter analyze --fatal-infos` — zero issues
- Both source files verified to have ZERO Flutter imports (pure Dart)

### Change Log

- 2026-04-21: Implemented all tasks (1-5) — Result sealed type, GameError hierarchy, comprehensive tests, analyzer clean

### File List

- `lib/game/values/result.dart` (CREATE) — Generic `Result<T, E>` sealed type
- `lib/game/game_error.dart` (CREATE) — `GameError` sealed hierarchy (UserError / InternalError)
- `test/game/values/result_test.dart` (CREATE) — 14 tests for Result type
- `test/game/game_error_test.dart` (CREATE) — 42 tests for GameError hierarchy
