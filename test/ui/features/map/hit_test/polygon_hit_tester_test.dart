import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/ui/features/map/hit_test/polygon_hit_tester.dart';

import '../../../../helpers/country_path_builder.dart';

void main() {
  // Simple square: (0.1,0.1)→(0.3,0.1)→(0.3,0.3)→(0.1,0.3)
  final squareRing = [
    const Offset(0.1, 0.1),
    const Offset(0.3, 0.1),
    const Offset(0.3, 0.3),
    const Offset(0.1, 0.3),
  ];

  group('PolygonHitTester', () {
    test('hit inside a simple square polygon returns the country id', () {
      final country = makeCountryPath(id: 'alpha', rings: [squareRing]);
      final tester = PolygonHitTester([country]);

      expect(tester.hitTest(const Offset(0.2, 0.2)), const CountryId('alpha'));
    });

    test('miss on ocean (outside all polygons) returns null', () {
      final country = makeCountryPath(id: 'alpha', rings: [squareRing]);
      final tester = PolygonHitTester([country]);

      expect(tester.hitTest(const Offset(0.5, 0.5)), isNull);
    });

    test('bbox rejection — country far from tap returns null quickly', () {
      // Square at bottom-right; tap at top-left is bbox-rejected
      final farRing = [
        const Offset(0.8, 0.8),
        const Offset(0.9, 0.8),
        const Offset(0.9, 0.9),
        const Offset(0.8, 0.9),
      ];
      final country = makeCountryPath(id: 'far', rings: [farRing]);
      final tester = PolygonHitTester([country]);

      expect(tester.hitTest(const Offset(0.1, 0.1)), isNull);
    });

    test('first-match-wins on overlapping polygons (AC #3)', () {
      // Two overlapping squares — overlap in (0.2,0.2)→(0.3,0.3)
      final ring1 = [
        const Offset(0.1, 0.1),
        const Offset(0.3, 0.1),
        const Offset(0.3, 0.3),
        const Offset(0.1, 0.3),
      ];
      final ring2 = [
        const Offset(0.2, 0.2),
        const Offset(0.4, 0.2),
        const Offset(0.4, 0.4),
        const Offset(0.2, 0.4),
      ];
      final first = makeCountryPath(id: 'first', rings: [ring1]);
      final second = makeCountryPath(id: 'second', rings: [ring2]);
      final tester = PolygonHitTester([first, second]);

      // Tap in the overlap zone — first in list wins
      expect(
        tester.hitTest(const Offset(0.25, 0.25)),
        const CountryId('first'),
      );
    });

    test('multi-ring polygon — tap inside hole returns null', () {
      // Outer ring: (0.1,0.1)→(0.5,0.1)→(0.5,0.5)→(0.1,0.5)
      // Inner ring (hole): (0.2,0.2)→(0.4,0.2)→(0.4,0.4)→(0.2,0.4)
      final outerRing = [
        const Offset(0.1, 0.1),
        const Offset(0.5, 0.1),
        const Offset(0.5, 0.5),
        const Offset(0.1, 0.5),
      ];
      final holeRing = [
        const Offset(0.2, 0.2),
        const Offset(0.4, 0.2),
        const Offset(0.4, 0.4),
        const Offset(0.2, 0.4),
      ];
      final country = makeCountryPath(
        id: 'donut',
        rings: [outerRing, holeRing],
      );
      final tester = PolygonHitTester([country]);

      // Inside hole → null (even-odd: outer ring toggles inside=true, hole toggles back to false)
      expect(tester.hitTest(const Offset(0.3, 0.3)), isNull);

      // Between outer and inner ring → returns country
      expect(
        tester.hitTest(const Offset(0.15, 0.15)),
        const CountryId('donut'),
      );
    });

    test('point clearly inside near an edge returns country id', () {
      // Ray-casting on exact edges/vertices is undefined by algorithm (Flutter
      // does not guarantee edge inclusion). Instead verify a point nudged just
      // inside the edge is reliably treated as inside — the behavior players
      // experience. We test all four edges to catch asymmetric bugs.
      final country = makeCountryPath(id: 'alpha', rings: [squareRing]);
      final tester = PolygonHitTester([country]);
      const eps = 1e-6;

      expect(
        tester.hitTest(const Offset(0.1 + eps, 0.2)),
        const CountryId('alpha'),
        reason: 'just inside left edge',
      );
      expect(
        tester.hitTest(const Offset(0.3 - eps, 0.2)),
        const CountryId('alpha'),
        reason: 'just inside right edge',
      );
      expect(
        tester.hitTest(const Offset(0.2, 0.1 + eps)),
        const CountryId('alpha'),
        reason: 'just inside top edge',
      );
      expect(
        tester.hitTest(const Offset(0.2, 0.3 - eps)),
        const CountryId('alpha'),
        reason: 'just inside bottom edge',
      );
    });

    test('empty country list always returns null', () {
      final tester = PolygonHitTester([]);
      expect(tester.hitTest(const Offset(0.2, 0.2)), isNull);
    });
  });
}
