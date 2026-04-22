import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/ui/theme/country_colors.dart';

void main() {
  group('CountryColors.defaults', () {
    test('has non-null values for all scalar fields', () {
      final d = CountryColors.defaults;
      expect(d.ocean, isNotNull);
      expect(d.border, isNotNull);
      expect(d.locked, isNotNull);
      expect(d.unlocked, isNotNull);
      expect(d.readyToCollect, isNotNull);
      expect(d.automated, isNotNull);
    });

    test('has entries for all 7 continents', () {
      final fills = CountryColors.defaults.continentFills;
      const expected = [
        'africa',
        'europe',
        'middle_east',
        'asia',
        'south_america',
        'north_america',
        'oceania',
      ];
      for (final continent in expected) {
        expect(
          fills.containsKey(continent),
          isTrue,
          reason: 'Missing continent fill: $continent',
        );
        expect(fills[continent], isNotNull);
      }
    });
  });

  group('CountryColors.copyWith', () {
    test('returns new instance with only the changed field', () {
      const newColor = Color(0xFFFF0000);
      final result = CountryColors.defaults.copyWith(ocean: newColor);
      expect(result.ocean, newColor);
      expect(result.border, CountryColors.defaults.border);
      expect(result.locked, CountryColors.defaults.locked);
      expect(result.unlocked, CountryColors.defaults.unlocked);
      expect(result.readyToCollect, CountryColors.defaults.readyToCollect);
      expect(result.automated, CountryColors.defaults.automated);
      expect(result.continentFills, CountryColors.defaults.continentFills);
    });

    test('does not mutate the original', () {
      final original = CountryColors.defaults;
      final _ = original.copyWith(ocean: const Color(0xFFFF0000));
      expect(original.ocean, CountryColors.defaults.ocean);
    });
  });

  group('CountryColors.lerp', () {
    test('returns self when other is null', () {
      final result = CountryColors.defaults.lerp(null, 0.5);
      expect(result, CountryColors.defaults);
    });

    test('interpolates ocean color at t=0 returns this', () {
      const a = CountryColors.defaults;
      final b = a.copyWith(ocean: const Color(0xFFFF0000));
      final result = a.lerp(b, 0.0);
      expect(result.ocean, a.ocean);
    });

    test('interpolates ocean color at t=1 returns other', () {
      const a = CountryColors.defaults;
      final b = a.copyWith(ocean: const Color(0xFFFF0000));
      final result = a.lerp(b, 1.0);
      expect(result.ocean, b.ocean);
    });

    test('interpolates scalar color fields between two instances', () {
      const a = CountryColors(
        ocean: Color(0xFF000000),
        border: Color(0xFF000000),
        locked: Color(0xFF000000),
        unlocked: Color(0xFF000000),
        readyToCollect: Color(0xFF000000),
        automated: Color(0xFF000000),
        continentFills: {
          'africa': Color(0xFF000000),
          'europe': Color(0xFF000000),
          'middle_east': Color(0xFF000000),
          'asia': Color(0xFF000000),
          'south_america': Color(0xFF000000),
          'north_america': Color(0xFF000000),
          'oceania': Color(0xFF000000),
        },
      );
      const b = CountryColors(
        ocean: Color(0xFFFFFFFF),
        border: Color(0xFFFFFFFF),
        locked: Color(0xFFFFFFFF),
        unlocked: Color(0xFFFFFFFF),
        readyToCollect: Color(0xFFFFFFFF),
        automated: Color(0xFFFFFFFF),
        continentFills: {
          'africa': Color(0xFFFFFFFF),
          'europe': Color(0xFFFFFFFF),
          'middle_east': Color(0xFFFFFFFF),
          'asia': Color(0xFFFFFFFF),
          'south_america': Color(0xFFFFFFFF),
          'north_america': Color(0xFFFFFFFF),
          'oceania': Color(0xFFFFFFFF),
        },
      );

      final mid = a.lerp(b, 0.5);
      // At t=0.5 between black and white, each channel is ~128
      final r = mid.ocean.r;
      expect(r, closeTo(128 / 255, 0.01));
    });
  });

  group('CountryColors equality', () {
    test('two defaults instances are equal', () {
      expect(CountryColors.defaults, CountryColors.defaults);
    });

    test('copyWith changed field breaks equality', () {
      final modified = CountryColors.defaults.copyWith(
        ocean: const Color(0xFFFF0000),
      );
      expect(CountryColors.defaults == modified, isFalse);
    });
  });
}
