# Story 1.6: Big-Number Precision Spike — Property Tests at 1e38+

Status: done

## Story

As an architect,
I want property tests that validate `decimal` arithmetic at 1e38 with the full compounded multiplier stack,
so that we confirm before building more that no silent rounding occurs and per-op cost is acceptable on the tick hot path.

## Acceptance Criteria

1. **Given** a property-test suite under `test/game/values/influence_precision_test.dart` **When** it runs `Decimal` operations representing `1e38 × 3.0 × 1.75 × 2.0 × 100` compounded across many iterations **Then** the result exactly matches the expected symbolic value (computed separately) with zero rounding error.

2. **Given** a per-op micro-benchmark in the same test file (documented as a reference, not asserted) **When** it runs 10,000 multiplications **Then** the measured per-op cost is recorded in a comment or small JSON report for team review **And** if the per-op cost is above a documented threshold (e.g. 10µs), a follow-up story "Cache per-country rates" is added to the Epic 10 (Tune) backlog.

## Tasks / Subtasks

- [x] Task 1: Create precision property-test suite (AC: #1)
  - [x] 1.1 Create `test/game/values/influence_precision_test.dart` using `package:test/test.dart` (NOT `flutter_test`)
  - [x] 1.2 Test: compute `Decimal.parse('1e38') × 3.0 × 1.75 × 2.0 × 100` — verify exact symbolic match (`1e38 × 1050 = 1.05e41` exactly, no rounding)
  - [x] 1.3 Test: compound the full multiplier stack pattern across 100 iterations (multiply base × stack, use result as new base) — verify final value matches independent calculation
  - [x] 1.4 Test: full multiplier stack order per architecture: `base × (1 + ipLevel × IP_MULT_PER_LEVEL) × leaderMult × continentBonus × (1 + Σachievements) × globalUpgrades × goldenMult × boostMult` at extreme values (each factor at its maximum documented range)
  - [x] 1.5 Test: addition at 1e38 scale — `Influence(Decimal.parse('1e38')) + Influence(Decimal.parse('1e20'))` preserves both magnitudes (no silent truncation)
  - [x] 1.6 Test: subtraction near zero at 1e38 scale — `Influence(Decimal.parse('1e38')) - Influence(Decimal.parse('9.99999999e37'))` yields exact difference
  - [x] 1.7 Test: division for display formatting — `Decimal.parse('1.05e41') / Decimal.parse('1e33')` yields correct De-tier formatted value
  - [x] 1.8 Test: repeated small multiplications don't accumulate drift — multiply `Influence(Decimal.parse('1e38'))` by `Decimal.parse('1.001')` 1000 times, compare to `1e38 × 1.001^1000` computed independently

- [x] Task 2: Create per-op micro-benchmark (AC: #2)
  - [x] 2.1 Add a test group `'micro-benchmark (reference only)'` in the same file
  - [x] 2.2 Benchmark: time 10,000 `Decimal` multiplications at 1e38 scale, print per-op cost in µs via `Stopwatch`
  - [x] 2.3 Benchmark: time 10,000 additions at 1e38 scale
  - [x] 2.4 Benchmark: time 10,000 full multiplier-stack compositions (6 multiplications chained)
  - [x] 2.5 Record results as comments in the test file (not assertions — benchmark values are informational)
  - [x] 2.6 If per-op exceeds 10µs threshold, add a `// TODO: Add "Cache per-country rates" story to Epic 10 backlog` comment and flag in completion notes

- [x] Task 3: Validate `Influence` / `Intel` value objects at extreme scale (AC: #1)
  - [x] 3.1 Test: `Influence` arithmetic at 1e38 through the typed wrapper (not raw `Decimal`) — ensure wrapper doesn't lose precision
  - [x] 3.2 Test: `Intel` at smaller but still large scale (1e18 — max realistic Intel) for consistency
  - [x] 3.3 Test: `Influence.format()` at 1e38+ returns correct abbreviated string (e.g., `"100000De"` for 1e38)
  - [x] 3.4 Test: cross-type safety — `Influence` and `Intel` cannot be accidentally combined (compile-time check, document in test comments)

- [x] Task 4: Run analyzer and full test suite (AC: all)
  - [x] 4.1 Run `flutter analyze --fatal-infos` — zero issues
  - [x] 4.2 Run `dart test test/game/values/` — all precision + existing tests pass
  - [x] 4.3 Run `flutter test` — all 97 existing tests plus new tests pass
  - [x] 4.4 Verify `test/game/values/influence_precision_test.dart` uses `package:test/test.dart` only (no Flutter imports)

## Dev Notes

### Architecture Compliance

This is a **risk spike** required by the architecture before further economy work. The purpose is to prove that `package:decimal 3.0.2` provides sufficient precision and acceptable performance for the game's economy at maximum scale.

Key architecture requirements for this story:

- **`lib/game/` has ZERO Flutter imports.** Tests use `package:test/test.dart`. [Source: project-context.md#Critical Implementation Rules, rule 1]
- **All game math flows through `Influence` / `Intel` value objects.** Raw `Decimal` is acceptable in the test file itself for constructing expected values, but the property tests should exercise the `Influence` wrapper. [Source: project-context.md#Big numbers]
- **No `double` for game quantities.** The entire point of this spike is to prove `Decimal` works where `double` fails. [Source: project-context.md#Anti-patterns]
- **Multiplier stack order is pinned** — tests must use the exact order from `IncomeCalculator` spec: `base × IP × Leader × continent × achievement × globalUpgrades × Golden × Boost`. [Source: project-context.md#Multiplier stack]

### Implementation Approach

**Property test strategy:**

The core test computes the architecture-specified spike: `1e38 × 3.0 × 1.75 × 2.0 × 100`. This represents a late-game scenario:
- `1e38` = base influence at Oceania-tier (highest continent threshold)
- `3.0` = max Leader multiplier (tier 3)
- `1.75` = continent completion bonus (near max)
- `2.0` = boost multiplier (active)
- `100` = golden opportunity multiplier (max)

Expected exact result: `1e38 × 3.0 × 1.75 × 2.0 × 100 = 1e38 × 1050 = 1.05 × 10^41`

Verify by constructing the expected value independently: `Decimal.parse('1.05e41')`.

**Compounding test:** Simulate 100 ticks where each tick multiplies the running total by the full stack. This stresses `Decimal` precision over iterated operations — the scenario that would expose drift if `Decimal` used floating-point internally.

**Benchmark approach:**

Use `Stopwatch` (not `DateTime.now()`) for micro-benchmarks. The benchmark is NOT a pass/fail assertion — it records timing data as `print()` output during the test run. This is the ONE acceptable use of `print` (in test code, not production code). Alternative: write results to a comment block at the top of the test file after the first run.

```dart
// Example benchmark pattern
test('benchmark: 10,000 multiplications at 1e38', () {
  final base = Decimal.parse('1e38');
  final factor = Decimal.parse('3.0');
  final sw = Stopwatch()..start();
  var result = base;
  for (var i = 0; i < 10000; i++) {
    result = result * factor;
  }
  sw.stop();
  final perOpMicros = sw.elapsedMicroseconds / 10000;
  // ignore: avoid_print
  print('Per-op cost: ${perOpMicros.toStringAsFixed(2)}µs');
  // Reference only — no assertion on timing
  // If > 10µs, flag for "Cache per-country rates" follow-up
});
```

**Important `Decimal` API notes (from Story 1.5 learnings):**

- `Decimal / Decimal` returns `Rational`, not `Decimal` — call `.toDecimal(scaleOnInfinitePrecision: N)` to convert back
- `Decimal.parse('1e38')` works for scientific notation
- `Decimal.parse('$n')` where `n` is a `num` is fine for test setup (not hot-path)
- `Decimal` uses arbitrary-precision internally (not floating-point) — should pass precision tests by design, but this spike confirms it empirically

### File Structure

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `test/game/values/influence_precision_test.dart` | Precision property tests + micro-benchmarks |

No production code changes in this story — it is purely a test/spike story.

### Testing Standards

- Use `package:test/test.dart` — NOT `flutter_test` (this is under `test/game/`)
- Run with `dart test test/game/values/influence_precision_test.dart`
- Property tests should be deterministic (no RNG needed — all values are explicit)
- Benchmark tests use `Stopwatch` and output via `print()` (acceptable in tests only)
- Structure tests in clear groups: `'precision'`, `'compounding'`, `'multiplier stack'`, `'micro-benchmark (reference only)'`

### Anti-Patterns to Avoid

- Do NOT use `double` anywhere in this test — defeats the purpose of the spike
- Do NOT assert on benchmark timing — hardware varies; timing is informational only
- Do NOT use `flutter_test` — this is a pure-Dart test file under `test/game/`
- Do NOT create production code — this story is test-only
- Do NOT use `DateTime.now()` for benchmarks — use `Stopwatch`
- Do NOT forget that `Decimal / Decimal` returns `Rational` — call `.toDecimal()` on division results
- Do NOT use `print()` in production code (lint violation), but it IS acceptable in test benchmark output (use `// ignore: avoid_print` if the lint fires in tests)

### Previous Story Intelligence

**From Story 1.5 (Create Influence and Intel Value Objects Wrapping Decimal):**

- `Influence` and `Intel` classes exist at `lib/game/values/influence.dart` and `lib/game/values/intel.dart`
- Both wrap `Decimal` with typed arithmetic: `operator +`, `operator -`, `operator *` (takes `Decimal`), `multiplyByNum(num)`
- `InfluenceFormatter` at `lib/game/values/influence_formatter.dart` (moved from `lib/utils/formatters/` during code review to fix architecture violation — `game/` must not import from `utils/`)
- 73 tests created (25 Influence, 18 Intel, 30 formatter), 97 total passing
- Story 1.5 already tested basic precision: `1e20 + 3e20 == 4e20` — this story extends to 1e38+ with compounded multipliers
- `depend_on_referenced_packages` lint: `package:meta` required explicit dep in `pubspec.yaml` — already resolved
- `package:test` added as explicit dev dependency — already available
- Division pitfall documented: `Decimal / Decimal` returns `Rational`, need `.toDecimal(scaleOnInfinitePrecision: N)`

**Key patterns established:**
- Value objects use `const` constructor: `const Influence(this.value)`
- Static `zero` field: `Influence.zero`, `Intel.zero`
- `Decimal.parse('1e$n')` for tier threshold constants — parse once as `static final`
- Test file naming: `{source_name}_test.dart` mirroring lib path

### Git Intelligence

Recent commits are all setup (no feature code beyond Stories 1.1-1.5's implementations):
- `9c804f9` — planning artifacts and settings
- `6992c42` — MCP servers config
- `8d84ab1` — BMAD setup, Flutter deps
- `91edb72` — Initial Flutter scaffold

Stories 1.1-1.5 have been implemented but commits aren't on master yet (uncommitted working tree changes visible in git status).

### Project Structure Notes

- `test/game/values/` already exists with 3 test files from Story 1.5
- New file `influence_precision_test.dart` follows the established naming convention
- No production code directories created or modified
- Architecture boundary test at `test/architecture/game_boundary_test.dart` won't be affected (no new production files)

### References

- [Source: epics.md#Story 1.6] — Acceptance criteria and user story
- [Source: game-architecture.md#Decision 5] — `Decimal` wrapped in `Influence`/`Intel`, required spike at 1e38+
- [Source: game-architecture.md#Risk Spikes] — Big-number precision spike: property-test at 1e38 × 3.0 × 1.75 × 2.0 × 100, measure per-op cost
- [Source: game-architecture.md#File Structure] — `test/game/values/influence_precision_test.dart` is the expected location
- [Source: game-architecture.md#Multiplier Stack] — Exact order: IP → Leader → continent → achievement → globalUpgrades → Golden → Boost
- [Source: project-context.md#Big-number precision] — Epic 1 spike REQUIRED: property-test at 1e38 × 3.0 × 1.75 × 2.0 × 100 compounded
- [Source: project-context.md#Performance Rules] — If too slow per-tick, cache computed rates
- [Source: project-context.md#Testing Rules] — `test/game/` uses `package:test/test.dart`, property tests required for big-number precision
- [Source: 1-5-create-influence-and-intel-value-objects-wrapping-decimal.md] — Previous story: Influence/Intel exist, 97 tests passing, formatter in game/values/

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — all tests passed on first run.

### Completion Notes List

- Created 21 new tests in `test/game/values/influence_precision_test.dart`
- **Precision spike result: PASS** — `Decimal` provides zero rounding error at 1e38+ with compounded multiplier stacks
- **Benchmark results (Windows 11):**
  - Multiplication per-op: ~0.73–1.54µs (well under 10µs threshold)
  - Addition per-op: ~0.12–0.29µs
  - Full multiplier stack composition per-op: ~0.56–1.02µs
- No "Cache per-country rates" follow-up needed — all operations comfortably under threshold
- 118 total tests pass (97 existing + 21 new), zero analyzer issues
- No production code modified — test-only story
- Test file uses `package:test/test.dart` only (no Flutter imports) — verified via grep

### Change Log

- 2026-04-21: Story implemented — 21 precision property tests + 3 micro-benchmarks created. All passing.
- 2026-04-21: Code review — fixes applied:
  - Task 1.4 test was tautological (computed `expected` with same Decimal operator chain as `result`). Rewrote expected value via pure BigInt integer math, independent of Decimal multiplication path.
  - Corrected "each factor at maximum documented range" — bumped `ipLevel` from 50 to `ipMaxLevel` (200 per GameConstants).
  - Fixed misleading comments on ipFactor and achievementFactor arithmetic.
  - Benchmark multiplication loop fixed: operand no longer grows unboundedly (multiply then divide by same factor keeps operand at ~1e38, representative of tick hot-path).
  - Benchmarks now include a warmup phase before timing.
  - Full-stack benchmark reports both per-composition and per-mult cost (8 mults/composition), no longer under-reporting by 8×.
  - All 118 tests still pass, zero analyzer issues.

### File List

- CREATE `test/game/values/influence_precision_test.dart` — Precision property tests + micro-benchmarks
