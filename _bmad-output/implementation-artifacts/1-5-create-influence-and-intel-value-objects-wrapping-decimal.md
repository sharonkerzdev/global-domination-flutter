# Story 1.5: Create `Influence` and `Intel` Value Objects Wrapping `decimal`

Status: done

## Story

As a developer,
I want `Influence` and `Intel` value objects that wrap `package:decimal` with typed arithmetic operators and a formatter,
so that all game math flows through typed currency types and raw `double` cannot silently be used for economy values.

## Acceptance Criteria

1. **Given** `lib/game/values/influence.dart` and `lib/game/values/intel.dart` **When** a developer imports them **Then** each exposes `+`, `-`, `*` (with `Decimal` and `num` overloads), `<`, `>`, `==`, `hashCode`, and a `format()` method that returns an abbreviated string (K / M / B / T / Qa / Qi / Sx / Sp / Oc / No / De).

2. **Given** the value objects **When** unit tests add `Influence(Decimal.parse('1e20'))` and `Influence(Decimal.parse('3e20'))` **Then** the result equals `Influence(Decimal.parse('4e20'))` with no precision loss.

3. **Given** the value objects **When** `Influence(Decimal.parse('1e35')).format()` is called **Then** the returned string uses the abbreviated notation documented in the formatter (not scientific notation).

## Tasks / Subtasks

- [x] Task 1: Create `Influence` value object (AC: #1, #2)
  - [x] 1.1 Create `lib/game/values/influence.dart` with `@immutable` class wrapping `final Decimal value`
  - [x] 1.2 Implement `operator +`, `operator -`, `operator *` (with `Decimal` and `num` overloads)
  - [x] 1.3 Implement `operator <`, `operator >`, `operator <=`, `operator >=`, `compareTo`
  - [x] 1.4 Implement `==`, `hashCode` (value equality on the wrapped `Decimal`)
  - [x] 1.5 Implement `format()` method delegating to `InfluenceFormatter.abbreviated(value)`
  - [x] 1.6 Add `Influence.zero` static const and `bool get isZero` / `bool get isNegative` convenience getters
  - [x] 1.7 Implement `toString()` for debug output
- [x] Task 2: Create `Intel` value object (AC: #1, #2)
  - [x] 2.1 Create `lib/game/values/intel.dart` with `@immutable` class wrapping `final Decimal value`
  - [x] 2.2 Same operator set as `Influence`: `+`, `-`, `*`, comparisons, `==`, `hashCode`
  - [x] 2.3 Implement `format()` delegating to the same formatter logic
  - [x] 2.4 Add `Intel.zero` static const and convenience getters
  - [x] 2.5 Implement `toString()` for debug output
- [x] Task 3: Create `InfluenceFormatter` (AC: #3)
  - [x] 3.1 Create `lib/utils/formatters/influence_formatter.dart`
  - [x] 3.2 Implement `static String abbreviated(Decimal value)` with thresholds: K (1e3), M (1e6), B (1e9), T (1e12), Qa (1e15), Qi (1e18), Sx (1e21), Sp (1e24), Oc (1e27), No (1e30), De (1e33)
  - [x] 3.3 Format as `{number}{suffix}` with up to 2 decimal places (e.g., "1.50T", "42.3Qi"), no trailing zeros
  - [x] 3.4 Values below 1000 display as plain integers (no suffix)
- [x] Task 4: Write tests for `Influence` (AC: #1, #2)
  - [x] 4.1 Create `test/game/values/influence_test.dart` using `package:test/test.dart` (NOT `flutter_test`)
  - [x] 4.2 Test arithmetic: addition, subtraction, multiplication by `Decimal`, multiplication by `num`
  - [x] 4.3 Test precision: `Influence(Decimal.parse('1e20')) + Influence(Decimal.parse('3e20'))` == `Influence(Decimal.parse('4e20'))`
  - [x] 4.4 Test comparisons: `<`, `>`, `<=`, `>=`, `==` across various magnitudes
  - [x] 4.5 Test equality and hashCode: equal values produce equal hashCodes, different values differ
  - [x] 4.6 Test `Influence.zero`, `isZero`, `isNegative`
  - [x] 4.7 Test `toString()` output
- [x] Task 5: Write tests for `Intel` (AC: #1, #2)
  - [x] 5.1 Create `test/game/values/intel_test.dart` using `package:test/test.dart`
  - [x] 5.2 Mirror key arithmetic and precision tests from Influence
  - [x] 5.3 Test equality, comparisons, zero, negative
- [x] Task 6: Write tests for `InfluenceFormatter` (AC: #3)
  - [x] 6.1 Create `test/utils/formatters/influence_formatter_test.dart` using `package:test/test.dart`
  - [x] 6.2 Test each abbreviation tier: 999 (plain), 1000 (1K), 1e6 (1M), 1e9 (1B), 1e12 (1T), 1e15 (1Qa), 1e18 (1Qi), 1e21 (1Sx), 1e24 (1Sp), 1e27 (1Oc), 1e30 (1No), 1e33 (1De)
  - [x] 6.3 Test intermediate values: 1,500 → "1.5K", 2,345,678 → "2.34M"
  - [x] 6.4 Test 1e35 returns abbreviated notation (not scientific), e.g. "100De"
  - [x] 6.5 Test zero, negative values, small values (< 1000)
  - [x] 6.6 Test values above De (1e36+) — pick a sensible behavior (e.g. continue with De suffix showing larger numbers like "1000De")
- [x] Task 7: Run analyzer and full test suite (AC: all)
  - [x] 7.1 Run `flutter analyze --fatal-infos` — zero issues
  - [x] 7.2 Run `dart test test/game/` — all new pure-Dart tests pass
  - [x] 7.3 Run `flutter test` — all existing tests (24 from Stories 1.1-1.4) plus new tests pass

## Dev Notes

### Architecture Compliance

This story creates the foundational value objects that ALL game math must flow through. Key rules:

- **`lib/game/` has ZERO Flutter imports.** `Influence` and `Intel` are pure Dart. Use `package:meta` for `@immutable` (this is allowed — it's a Dart meta package, not Flutter). [Source: project-context.md#Critical Implementation Rules, rule 1]
- **All game math flows through `Influence` / `Intel` — `double` for game quantities is a bug.** Raw `Decimal` outside `lib/game/values/` is a lint violation. [Source: project-context.md#Big numbers]
- **`lib/game/` never imports from `lib/data/`.** These value objects have zero data-layer dependencies. [Source: project-context.md#Critical Implementation Rules, rule 2]
- **`lib/utils/` is leaf-level.** `InfluenceFormatter` in `lib/utils/formatters/` must NOT import from `game/`, `data/`, `ui/`, `services/`, or `providers/`. It receives a raw `Decimal` value, not an `Influence` object — this keeps the dependency direction correct (`game/ → nothing`, `utils/ → nothing`). [Source: project-context.md#Code Organization Rules]
- **Tests for `lib/game/` use `package:test/test.dart`** (NOT `flutter_test`). Tests for `lib/utils/` also use `package:test/test.dart` (no Flutter dependency). [Source: project-context.md#Testing Rules]
- **`@immutable` annotation required.** All value objects, states, and events must be immutable. [Source: project-context.md#File content discipline]
- **No `freezed`.** Manual `==`, `hashCode`, `copyWith` for v1. [Source: project-context.md#File content discipline]

### Implementation Approach

**Value Object Pattern:**

Both `Influence` and `Intel` follow the same pattern — a thin, immutable wrapper around `Decimal` providing typed arithmetic. They are deliberately separate types (not a generic `Currency<T>`) to prevent accidentally adding Influence to Intel.

```dart
// lib/game/values/influence.dart
import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

@immutable
class Influence implements Comparable<Influence> {
  final Decimal value;

  const Influence(this.value);

  static final zero = Influence(Decimal.zero);

  bool get isZero => value == Decimal.zero;
  bool get isNegative => value < Decimal.zero;

  Influence operator +(Influence other) => Influence(value + other.value);
  Influence operator -(Influence other) => Influence(value - other.value);
  Influence operator *(Decimal factor) => Influence(value * factor);
  Influence multiplyByNum(num factor) =>
      Influence(value * Decimal.parse(factor.toString()));

  bool operator <(Influence other) => value < other.value;
  bool operator >(Influence other) => value > other.value;
  bool operator <=(Influence other) => value <= other.value;
  bool operator >=(Influence other) => value >= other.value;

  @override
  int compareTo(Influence other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Influence && value == other.value);

  @override
  int get hashCode => value.hashCode;

  /// Returns abbreviated format: K/M/B/T/Qa/Qi/Sx/Sp/Oc/No/De
  String format() => InfluenceFormatter.abbreviated(value);

  @override
  String toString() => 'Influence($value)';
}
```

**Key design decision — `operator *` with `num`:** The architecture shows `operator *(num factor)` in the example, but Dart does not allow two `operator *` overloads with different parameter types. Use a named method `multiplyByNum(num factor)` instead, OR a single `operator *(Decimal factor)` and require callers to convert. The architecture sample uses `Decimal.parse('$factor')` for the num conversion — this is fine for non-hot-path code but avoid in per-tick math (parse once, reuse the `Decimal` constant). Whichever approach you pick, document it clearly.

**`Intel` follows the same pattern** but is a distinct type. Intel is primarily an integer-scale currency (missions reward 5-50 Intel, boosts cost 18 Intel), but wrapping in `Decimal` keeps it consistent with the architecture and future-proofs for balance changes.

**Formatter lives in `lib/utils/formatters/`**, NOT in `lib/game/`. The architecture explicitly places it at `lib/utils/formatters/influence_formatter.dart`. The `format()` method on the value object delegates to it. The formatter receives a raw `Decimal` (not an `Influence`) so that both `Influence.format()` and `Intel.format()` can share the same formatting logic without `utils/` importing `game/`.

**Abbreviation tiers:**

| Suffix | Threshold | Full Name |
|--------|-----------|-----------|
| (none) | < 1,000 | — |
| K | 1e3 | Thousand |
| M | 1e6 | Million |
| B | 1e9 | Billion |
| T | 1e12 | Trillion |
| Qa | 1e15 | Quadrillion |
| Qi | 1e18 | Quintillion |
| Sx | 1e21 | Sextillion |
| Sp | 1e24 | Septillion |
| Oc | 1e27 | Octillion |
| No | 1e30 | Nonillion |
| De | 1e33 | Decillion |

Values above 1e36 should continue using De (e.g., `1000De` for 1e36, `100000De` for 1e38). The game economy scales to 1e38+ per architecture requirements.

**Formatting rules:**
- Below 1000: display as plain integer (truncate any fractional part for display)
- 1000+: divide by tier threshold, show up to 2 decimal places, strip trailing zeros
- Examples: 0 → "0", 999 → "999", 1000 → "1K", 1500 → "1.5K", 1234567 → "1.23M", 1e35 → "100De"

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `lib/game/values/influence.dart` | Influence value object wrapping Decimal |
| CREATE | `lib/game/values/intel.dart` | Intel value object wrapping Decimal |
| CREATE | `lib/utils/formatters/influence_formatter.dart` | Abbreviated number formatter (K/M/B/T/...) |
| CREATE | `test/game/values/influence_test.dart` | Pure-Dart tests for Influence |
| CREATE | `test/game/values/intel_test.dart` | Pure-Dart tests for Intel |
| CREATE | `test/utils/formatters/influence_formatter_test.dart` | Pure-Dart tests for formatter |

### Technical Requirements

**`package:decimal` 3.0.2 API (already in pubspec.yaml):**

- `Decimal.parse(String)` — parse from string (supports scientific notation like `'1e38'`)
- `Decimal.zero`, `Decimal.one` — static constants
- `Decimal.fromInt(int)` — from integer
- Operators: `+`, `-`, `*`, `/`, `%`, `<`, `>`, `<=`, `>=`, `==`
- `compareTo(Decimal)` — for `Comparable`
- `toString()` — full precision string representation
- `toStringAsFixed(int)` — fixed decimal places
- `Decimal.ten.pow(n)` — power of ten (use `Decimal.parse('1e$n')` for threshold constants)

**`package:meta` for `@immutable`:** Already a transitive dependency of Flutter. For `lib/game/` (which has zero Flutter imports), import `package:meta/meta.dart` directly — this is a pure Dart package and is allowed.

**Formatter implementation hint:**

```dart
// lib/utils/formatters/influence_formatter.dart
import 'package:decimal/decimal.dart';

class InfluenceFormatter {
  // Tier thresholds — parse once as static finals, never in hot path
  static final _tiers = <(Decimal, String)>[
    (Decimal.parse('1e33'), 'De'),
    (Decimal.parse('1e30'), 'No'),
    (Decimal.parse('1e27'), 'Oc'),
    (Decimal.parse('1e24'), 'Sp'),
    (Decimal.parse('1e21'), 'Sx'),
    (Decimal.parse('1e18'), 'Qi'),
    (Decimal.parse('1e15'), 'Qa'),
    (Decimal.parse('1e12'), 'T'),
    (Decimal.parse('1e9'), 'B'),
    (Decimal.parse('1e6'), 'M'),
    (Decimal.parse('1e3'), 'K'),
  ];

  static String abbreviated(Decimal value) {
    if (value < Decimal.zero) return '-${abbreviated(-value)}';

    for (final (threshold, suffix) in _tiers) {
      if (value >= threshold) {
        // Divide and format to up to 2 decimal places, strip trailing zeros
        final divided = (value / threshold).toDecimal();
        // ... format with up to 2 decimal places, strip trailing zeros
        return '$formatted$suffix';
      }
    }

    // Below 1000 — plain integer
    return value.truncate().toBigInt().toString();
  }
}
```

**Division note:** `Decimal / Decimal` in `package:decimal` returns a `Rational`, not a `Decimal`. Call `.toDecimal(scaleOnInfinitePrecision: 2)` to convert back to `Decimal` with bounded precision for display purposes. This is a common pitfall — don't forget it.

### Testing Standards

- All tests under `test/game/` and `test/utils/` use `package:test/test.dart` — NOT `flutter_test`
- Run with `dart test test/game/values/` and `dart test test/utils/formatters/`
- Test precision at scale: `1e20 + 3e20 == 4e20`, `1e38 * Decimal.parse('3.0')` preserves precision
- Test type safety: `Influence` + `Influence` works, but `Influence` + `Intel` must NOT compile (separate types)
- Test formatting at every tier boundary and between tiers
- Test edge cases: zero, negative, very small (0.001), just below/at/just above tier boundaries

### Anti-Patterns to Avoid

- Do NOT use `double` anywhere in these value objects. The entire point is to avoid `double` for game quantities.
- Do NOT put the formatter in `lib/game/`. It belongs in `lib/utils/formatters/` per architecture. The value object's `format()` delegates to it.
- Do NOT make `Influence` and `Intel` share a base class or generic. They are intentionally separate types to prevent accidental cross-currency arithmetic.
- Do NOT import `package:flutter/foundation.dart` for `@immutable` in `lib/game/`. Use `package:meta/meta.dart` instead.
- Do NOT create `Decimal.parse(...)` in per-tick hot paths. Parse threshold constants once as `static final` fields.
- Do NOT use `Decimal.parse('$factor')` for `num` conversion in any code that runs per-tick. For non-hot-path code (UI, one-off calculations) it's acceptable.
- Do NOT use `flutter_test` for tests under `test/game/` or `test/utils/`. These are headless Dart tests.
- Do NOT add `Influence.fromDouble(double)` — that defeats the purpose. If a caller has a `double`, they must explicitly convert via `Decimal.parse(n.toString())`.
- Do NOT use `toStringAsFixed(2)` naively for formatting — it may produce trailing zeros ("1.50K"). Strip them.
- Do NOT forget that `Decimal / Decimal` returns `Rational`, not `Decimal` — call `.toDecimal()` on the result.

### Previous Story Intelligence

**From Story 1.4 (Scaffold Drift Database and Apply Migrations):**
- `DecimalConverter` created at `lib/data/database/converters/decimal_converter.dart` — serializes `Decimal` ↔ TEXT for Drift columns. Future persistence stories will use this to store `Influence` / `Intel` values.
- `appDatabaseProvider` created — the Drift composition root.
- 24 total tests pass (15 from 1.1-1.3 + 9 new).
- `flutter analyze --fatal-infos`: zero issues.
- `lib/game/` directory does NOT exist yet — **this story creates it** (specifically `lib/game/values/`).
- `lib/utils/` directory does NOT exist yet — this story creates `lib/utils/formatters/`.
- Analyzer flagged `depend_on_referenced_packages` for transitive `package:sqlite3` import — resolved with ignore comment. Watch for similar issues if `package:meta` triggers it (unlikely — it's a direct dep of Flutter SDK).

**Key dependency note:** `decimal: ^3.0.2` is already in `pubspec.yaml`. No new dependencies needed. `package:meta` is already available as a transitive dependency.

### Git Intelligence

Recent commits are all project setup (no feature code beyond Story 1.1's global handlers):
- `9c804f9` — planning artifacts and settings
- `6992c42` — MCP servers config
- `8d84ab1` — BMAD setup, Flutter deps
- `91edb72` — Initial Flutter scaffold

The `lib/game/` directory does not exist yet. This story is the first to create files under `lib/game/`.

### Project Structure Notes

- `lib/game/values/` is a new directory — first files in the `lib/game/` tree
- `lib/utils/formatters/` is a new directory — first files in the `lib/utils/` tree
- `test/game/values/` mirrors `lib/game/values/`
- `test/utils/formatters/` mirrors `lib/utils/formatters/`
- The architecture boundary test (`test/architecture/game_boundary_test.dart`) will now have actual files to scan in `lib/game/` — verify it still passes (it should, since these files have zero Flutter imports)

### References

- [Source: epics.md#Story 1.5] — Acceptance criteria and user story
- [Source: game-architecture.md#Value Objects] — `Influence` class pattern, operator overloads, `format()` method
- [Source: game-architecture.md#Decision 5: Big numbers] — `decimal: ^3.0.2`, arbitrary precision at 1e38+, type safety
- [Source: game-architecture.md#File Structure] — `lib/game/values/` for value objects, `lib/utils/formatters/` for formatter
- [Source: game-architecture.md#System Mapping] — `influence.dart` + `influence_formatter.dart` for big-number economy
- [Source: project-context.md#Big numbers] — Raw `Decimal` outside `values/` is a lint violation; `double` for game quantities is a bug
- [Source: project-context.md#Critical Implementation Rules] — `lib/game/` has ZERO Flutter imports; `lib/utils/` is leaf-level
- [Source: project-context.md#Testing Rules] — `test/game/` uses `package:test/test.dart`
- [Source: project-context.md#Naming conventions] — `snake_case.dart` files, PascalCase classes, camelCase methods
- [Source: 1-4-scaffold-drift-database-and-apply-migrations.md] — Previous story: 24 passing tests, DecimalConverter exists

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- `depend_on_referenced_packages` lint triggered for `package:meta` — resolved by adding `meta: ^1.17.0` as explicit dependency in pubspec.yaml (same resolution pattern as Story 1.4 with `package:sqlite3`).
- `package:test` was not a direct dev dependency — added `test` via `dart pub add --dev test` so pure-Dart tests under `test/game/` and `test/utils/` can use `package:test/test.dart`.

### Completion Notes List

- Created `Influence` and `Intel` as `@immutable` value objects wrapping `Decimal`, each with typed arithmetic (`+`, `-`, `*`), comparisons, equality, `format()`, and convenience getters.
- `operator *` takes `Decimal`; `num` multiplication uses named `multiplyByNum(num)` method since Dart doesn't allow two `operator *` overloads.
- `InfluenceFormatter` placed in `lib/game/values/` (co-located with value objects, maintains `game/ → nothing` island-of-purity invariant). Receives raw `Decimal`, shared by both `Influence.format()` and `Intel.format()`.
- Formatter handles all 11 tiers (K through De), values above 1e36 continue with De suffix, negative values handled recursively, trailing zeros stripped.
- Tier thresholds parsed once as `static final` — no per-call `Decimal.parse()`.
- Division uses `.toDecimal(scaleOnInfinitePrecision: 2)` to handle `Rational` return from `Decimal / Decimal`.
- 73 new pure-Dart tests (25 Influence, 18 Intel, 30 formatter) + 24 existing = 97 total, all passing.
- `flutter analyze --fatal-infos`: zero issues.
- Architecture boundary test confirms `lib/game/` has zero Flutter imports.

### File List

| Action | File |
|--------|------|
| CREATE | `lib/game/values/influence.dart` |
| CREATE | `lib/game/values/intel.dart` |
| CREATE | `lib/game/values/influence_formatter.dart` |
| CREATE | `test/game/values/influence_test.dart` |
| CREATE | `test/game/values/intel_test.dart` |
| CREATE | `test/game/values/influence_formatter_test.dart` |
| MODIFY | `pubspec.yaml` (added `meta: ^1.17.0`, `test` dev dependency) |
| MODIFY | `pubspec.lock` (updated with new deps) |

### Change Log

- 2026-04-21: Story 1.5 implemented — Influence, Intel value objects and InfluenceFormatter with 73 new tests (97 total). Added `meta` and `test` as explicit dependencies.
- 2026-04-21: Code review fix — moved `InfluenceFormatter` from `lib/utils/formatters/` to `lib/game/values/` to fix architecture violation (`game/` must not import from `utils/`). Deleted empty `lib/utils/` tree. Test moved to `test/game/values/influence_formatter_test.dart`. All 97 tests pass, zero analyzer issues.
