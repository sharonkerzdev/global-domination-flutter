import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';

void main() {
  // ── Precision property tests (AC #1) ──────────────────────────────────

  group('precision — single multiplier stack', () {
    test('1e38 × 3.0 × 1.75 × 2.0 × 100 equals exactly 1.05e41', () {
      final base = Decimal.parse('1e38');
      final result =
          base *
          Decimal.parse('3.0') *
          Decimal.parse('1.75') *
          Decimal.parse('2.0') *
          Decimal.parse('100');

      final expected = Decimal.parse('1.05e41');
      expect(result, equals(expected));
    });
  });

  group('precision — compounding across iterations', () {
    test(
      'full multiplier stack compounded 100 times matches independent calc',
      () {
        // stack = 3.0 × 1.75 × 2.0 × 100 = 1050
        final stack =
            Decimal.parse('3.0') *
            Decimal.parse('1.75') *
            Decimal.parse('2.0') *
            Decimal.parse('100');

        // Iterative: base × stack, repeated 100 times
        var iterative = Decimal.parse('1e38');
        for (var i = 0; i < 100; i++) {
          iterative = iterative * stack;
        }

        // Independent: 1e38 × 1050^100
        var stackPow100 = Decimal.one;
        for (var i = 0; i < 100; i++) {
          stackPow100 = stackPow100 * stack;
        }
        final independent = Decimal.parse('1e38') * stackPow100;

        expect(iterative, equals(independent));
      },
    );
  });

  group('precision — full multiplier stack order per architecture', () {
    test('architecture-specified multiplier order at extreme values', () {
      // Multiplier stack order from architecture:
      // base × (1 + ipLevel × IP_MULT_PER_LEVEL) × leaderMult
      //   × continentBonus × (1 + Σachievements) × globalUpgrades
      //   × goldenMult × boostMult
      // Each factor at its maximum documented range per game-architecture.md.
      final base = Decimal.parse('1e38');

      // ipLevel = ipMaxLevel (200) per GameConstants; IP_MULT_PER_LEVEL
      // not yet pinned in design — assume 0.05/level. ipFactor = 1 + 200*0.05 = 11.
      final ipFactor =
          Decimal.one + (Decimal.parse('200') * Decimal.parse('0.05'));
      final leaderMult = Decimal.parse('3.0'); // tier 3 max
      final continentBonus = Decimal.parse('2.75'); // 1.0…2.75 max
      // 27 achievements × 0.1 each → Σ = 2.7, so factor = 1 + 2.7 = 3.7
      final achievementFactor = Decimal.one + Decimal.parse('2.7');
      final globalUpgrades = Decimal.parse('1.5');
      final goldenMult = Decimal.parse('100'); // 10…100 max
      final boostMult = Decimal.parse('2.0');

      final result =
          base *
          ipFactor *
          leaderMult *
          continentBonus *
          achievementFactor *
          globalUpgrades *
          goldenMult *
          boostMult;

      // Independent expected value: computed via pure BigInt integer math
      // so it does NOT reuse the Decimal multiplication operator / order
      // under test. Each factor is expressed as an integer at a chosen
      // scale; we then reason about the final decimal placement by hand.
      //
      // Factors rewritten as integers (with their scale) × 1e38 base:
      //   ipFactor           11       (scale 1e0)
      //   leaderMult         3        (scale 1e0)
      //   continentBonus     275      (scale 1e2)
      //   achievementFactor  37       (scale 1e1)
      //   globalUpgrades     15       (scale 1e1)
      //   goldenMult         100      (scale 1e0)
      //   boostMult          2        (scale 1e0)
      // Total scale divisor = 1e2 × 1e1 × 1e1 = 1e4
      // So expected = (11*3*275*37*15*100*2) × 10^38 / 10^4
      //             = factorsProduct × 10^34
      final factorsProduct =
          BigInt.from(11) *
          BigInt.from(3) *
          BigInt.from(275) *
          BigInt.from(37) *
          BigInt.from(15) *
          BigInt.from(100) *
          BigInt.from(2);
      // factorsProduct = 1_007_325_000 (verified by hand:
      // 11×3=33 → ×275=9075 → ×37=335_775 → ×15=5_036_625
      // → ×100=503_662_500 → ×2=1_007_325_000).
      expect(factorsProduct, equals(BigInt.from(1007325000)));
      final expectedBigInt = factorsProduct * BigInt.from(10).pow(34);
      final expectedDecimal = Decimal.fromBigInt(expectedBigInt);

      expect(result, equals(expectedDecimal));

      // Sanity: result must grow since every factor is > 1
      expect(result > base, isTrue);
    });
  });

  group('precision — addition at 1e38 scale', () {
    test('1e38 + 1e20 preserves both magnitudes', () {
      final large = Influence(Decimal.parse('1e38'));
      final small = Influence(Decimal.parse('1e20'));
      final sum = large + small;

      // Subtracting back should yield exact original values
      expect(sum - small, equals(large));
      expect(sum - large, equals(small));

      // The sum should be strictly greater than either operand
      expect(sum > large, isTrue);
      expect(sum > small, isTrue);
    });
  });

  group('precision — subtraction near zero at 1e38 scale', () {
    test('1e38 - 9.99999999e37 yields exact difference', () {
      final a = Influence(Decimal.parse('1e38'));
      final b = Influence(Decimal.parse('9.99999999e37'));
      final diff = a - b;

      // 1e38 - 9.99999999e37 = 1e38 - 0.999999999e38 = 0.000000001e38 = 1e29
      final expected = Influence(Decimal.parse('1e29'));
      expect(diff, equals(expected));
    });
  });

  group('precision — division for display formatting', () {
    test('1.05e41 / 1e33 yields correct De-tier value', () {
      final value = Decimal.parse('1.05e41');
      final deTier = Decimal.parse('1e33');
      final divided = (value / deTier).toDecimal(scaleOnInfinitePrecision: 10);

      // 1.05e41 / 1e33 = 1.05e8 = 105000000
      final expected = Decimal.parse('105000000');
      expect(divided, equals(expected));
    });
  });

  group('precision — repeated small multiplications drift check', () {
    test(
      'multiplying by 1.001 1000 times matches 1.001^1000 independently',
      () {
        final base = Influence(Decimal.parse('1e38'));
        final factor = Decimal.parse('1.001');

        // Iterative multiplication
        var iterative = base;
        for (var i = 0; i < 1000; i++) {
          iterative = iterative * factor;
        }

        // Independent: compute 1.001^1000 then multiply by base
        var factorPow1000 = Decimal.one;
        for (var i = 0; i < 1000; i++) {
          factorPow1000 = factorPow1000 * factor;
        }
        final independent = base * factorPow1000;

        expect(iterative, equals(independent));
      },
    );
  });

  // ── Micro-benchmark (AC #2) — reference only, no assertions ──────────

  group('micro-benchmark (reference only)', () {
    const warmupIterations = 1000;
    const timedIterations = 10000;

    test('benchmark: multiplication at 1e38 scale (bounded operand size)', () {
      // Multiply then divide to keep the operand at ~1e38 throughout, so the
      // measured per-op cost reflects hot-path (fixed-magnitude) behavior —
      // not an ever-growing-operand worst case.
      final base = Decimal.parse('1e38');
      final mul = Decimal.parse('3.0');
      final div = Decimal.parse('3.0');

      // Warmup
      var warm = base;
      for (var i = 0; i < warmupIterations; i++) {
        warm = warm * mul;
        warm = (warm / div).toDecimal(scaleOnInfinitePrecision: 0);
      }

      final sw = Stopwatch()..start();
      var result = base;
      for (var i = 0; i < timedIterations; i++) {
        result = result * mul;
        result = (result / div).toDecimal(scaleOnInfinitePrecision: 0);
      }
      sw.stop();
      // 2 ops per loop (one multiply, one divide). Report multiply cost as
      // total / (2 × iterations) — a conservative approximation.
      final perOpMicros = sw.elapsedMicroseconds / (2 * timedIterations);
      // ignore: avoid_print
      print('Multiplication per-op cost: ${perOpMicros.toStringAsFixed(2)}µs');
      // Reference only — no assertion on timing.
      // If > 10µs, flag for "Cache per-country rates" follow-up.

      expect(result, isNotNull);
    });

    test('benchmark: addition at 1e38 scale', () {
      final base = Decimal.parse('1e38');
      final addend = Decimal.parse('1e20');

      // Warmup
      var warm = base;
      for (var i = 0; i < warmupIterations; i++) {
        warm = warm + addend;
      }

      final sw = Stopwatch()..start();
      var result = base;
      for (var i = 0; i < timedIterations; i++) {
        result = result + addend;
      }
      sw.stop();
      final perOpMicros = sw.elapsedMicroseconds / timedIterations;
      // ignore: avoid_print
      print('Addition per-op cost: ${perOpMicros.toStringAsFixed(2)}µs');

      expect(result, isNotNull);
    });

    test('benchmark: full multiplier-stack composition (8 mults)', () {
      final ipFactor =
          Decimal.one + (Decimal.parse('200') * Decimal.parse('0.05'));
      final leaderMult = Decimal.parse('3.0');
      final continentBonus = Decimal.parse('2.75');
      final achievementFactor = Decimal.one + Decimal.parse('2.7');
      final globalUpgrades = Decimal.parse('1.5');
      final goldenMult = Decimal.parse('100');
      final boostMult = Decimal.parse('2.0');
      const multsPerComposition = 8;

      Decimal applyStack(Decimal base) =>
          base *
          ipFactor *
          leaderMult *
          continentBonus *
          achievementFactor *
          globalUpgrades *
          goldenMult *
          boostMult;

      // Warmup — reset inside loop so operand size stays bounded.
      for (var i = 0; i < warmupIterations; i++) {
        applyStack(Decimal.parse('1e38'));
      }

      final sw = Stopwatch()..start();
      Decimal result = Decimal.zero;
      for (var i = 0; i < timedIterations; i++) {
        // Reset per iteration — the base is a fresh 1e38 each time, matching
        // the tick-path pattern of computing rate from current state.
        result = applyStack(Decimal.parse('1e38'));
      }
      sw.stop();
      final perCompositionMicros = sw.elapsedMicroseconds / timedIterations;
      final perMultMicros = perCompositionMicros / multsPerComposition;
      // ignore: avoid_print
      print(
        'Full stack composition: '
        '${perCompositionMicros.toStringAsFixed(2)}µs per composition, '
        '${perMultMicros.toStringAsFixed(2)}µs per mult (8/composition)',
      );

      expect(result, isNotNull);
    });

    // Benchmark results (recorded 2026-04-21, Windows 11, with warmup and
    // bounded operand size):
    //   Multiplication per-op: ~1µs
    //   Addition per-op: ~0.2µs
    //   Full stack composition: ~5µs / composition, ~0.6µs / mult
    // All well under the 10µs per-op threshold — no "Cache per-country rates"
    // follow-up needed.
  });

  // ── Value object validation at extreme scale (AC #1) ──────────────────

  group('Influence wrapper precision at 1e38', () {
    test('Influence arithmetic preserves Decimal precision', () {
      final a = Influence(Decimal.parse('1e38'));
      final factor = Decimal.parse('1050');
      final result = a * factor;

      expect(result, equals(Influence(Decimal.parse('1.05e41'))));
    });

    test('Influence addition at 1e38 through wrapper', () {
      final a = Influence(Decimal.parse('1e38'));
      final b = Influence(Decimal.parse('5e37'));
      final result = a + b;

      expect(result, equals(Influence(Decimal.parse('1.5e38'))));
    });

    test('Influence subtraction at 1e38 through wrapper', () {
      final a = Influence(Decimal.parse('1e38'));
      final b = Influence(Decimal.parse('3e37'));
      final result = a - b;

      expect(result, equals(Influence(Decimal.parse('7e37'))));
    });

    test('Influence multiplyByNum at extreme scale', () {
      final a = Influence(Decimal.parse('1e38'));
      final result = a.multiplyByNum(3);

      expect(result, equals(Influence(Decimal.parse('3e38'))));
    });
  });

  group('Intel wrapper precision at 1e18', () {
    test('Intel arithmetic at max realistic scale', () {
      final a = Intel(Decimal.parse('1e18'));
      final b = Intel(Decimal.parse('5e17'));
      final sum = a + b;

      expect(sum, equals(Intel(Decimal.parse('1.5e18'))));
    });

    test('Intel multiplication preserves precision', () {
      final a = Intel(Decimal.parse('1e18'));
      final factor = Decimal.parse('2.5');
      final result = a * factor;

      expect(result, equals(Intel(Decimal.parse('2.5e18'))));
    });

    test('Intel subtraction at large scale', () {
      final a = Intel(Decimal.parse('1e18'));
      final b = Intel(Decimal.parse('9.99e17'));
      final diff = a - b;

      expect(diff, equals(Intel(Decimal.parse('1e15'))));
    });
  });

  group('Influence.format() at 1e38+', () {
    test('1e38 formats as 100000De', () {
      final a = Influence(Decimal.parse('1e38'));
      expect(a.format(), equals('100000De'));
    });

    test('1.05e41 formats correctly', () {
      final a = Influence(Decimal.parse('1.05e41'));
      // 1.05e41 / 1e33 = 1.05e8 = 105000000
      expect(a.format(), equals('105000000De'));
    });

    test('5e35 formats as 500De', () {
      final a = Influence(Decimal.parse('5e35'));
      expect(a.format(), equals('500De'));
    });
  });

  group('cross-type safety', () {
    test('Influence and Intel are distinct types at compile time', () {
      // This test documents compile-time type safety.
      // The following would NOT compile (uncomment to verify):
      //   Influence a = Influence(Decimal.parse('100'));
      //   Intel b = Intel(Decimal.parse('50'));
      //   var c = a + b;  // Compile error: Intel is not Influence
      //   var d = a * b;  // Compile error: Intel is not Decimal
      //
      // At runtime, we verify they are not equal even with same value:
      final influenceVal = Influence(Decimal.parse('100'));
      final intelVal = Intel(Decimal.parse('100'));

      // Different types — runtime equality check confirms they're distinct
      // ignore: unrelated_type_equality_checks
      expect(influenceVal == intelVal, isFalse);
    });
  });
}
