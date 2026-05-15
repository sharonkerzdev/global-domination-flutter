import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/ui/features/map/auto_focus_target.dart';
import 'package:global_domination/ui/features/map/country_path.dart';

CountryPath _fake(String id, String continent, Rect bbox) {
  return CountryPath(
    id: CountryId(id),
    continent: ContinentId(continent),
    rings: const [],
    bbox: bbox,
    path: Path()..addRect(bbox),
  );
}

bool _matricesNearlyEqual(Matrix4 a, Matrix4 b, [double eps = 1e-6]) {
  for (var i = 0; i < 16; i++) {
    if ((a.storage[i] - b.storage[i]).abs() > eps) return false;
  }
  return true;
}

Offset _project(Matrix4 m, Offset canvasNormalized, Size canvasSize) {
  final scaled = Vector3(
    canvasNormalized.dx * canvasSize.width,
    canvasNormalized.dy * canvasSize.height,
    0,
  );
  final v = m.transform3(scaled);
  return Offset(v.x, v.y);
}

void main() {
  group('computeContinentFitTransform', () {
    const canvas = Size(1000, 600);

    test('single-country continent centers bbox at clamped zoom', () {
      final target = _fake(
        'a',
        'africa',
        const Rect.fromLTWH(0.4, 0.4, 0.05, 0.05),
      );
      final m = computeContinentFitTransform(
        targetCountry: target,
        allCountries: [target],
        canvasSize: canvas,
      );

      final projectedCenter = _project(m, const Offset(0.425, 0.425), canvas);
      expect((projectedCenter.dx - canvas.width / 2).abs(), lessThan(1e-3));
      expect((projectedCenter.dy - canvas.height / 2).abs(), lessThan(1e-3));
      // Zoom must be > 1 because a 0.05-normalized country is much smaller than canvas.
      expect(m.getMaxScaleOnAxis(), greaterThan(1.0));
    });

    test('multi-country continent uses union bbox', () {
      final a = _fake('a', 'asia', const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1));
      final b = _fake('b', 'asia', const Rect.fromLTWH(0.5, 0.4, 0.2, 0.2));
      final m = computeContinentFitTransform(
        targetCountry: a,
        allCountries: [a, b],
        canvasSize: canvas,
      );

      // Union bbox: (0.1, 0.1) to (0.7, 0.6). Center = (0.4, 0.35).
      final projectedCenter = _project(m, const Offset(0.4, 0.35), canvas);
      expect((projectedCenter.dx - canvas.width / 2).abs(), lessThan(1e-3));
      expect((projectedCenter.dy - canvas.height / 2).abs(), lessThan(1e-3));
    });

    test('ignores countries outside the target continent', () {
      final target = _fake(
        'a',
        'asia',
        const Rect.fromLTWH(0.4, 0.4, 0.05, 0.05),
      );
      final other = _fake(
        'b',
        'europe',
        const Rect.fromLTWH(0.0, 0.0, 0.9, 0.9),
      );
      final m = computeContinentFitTransform(
        targetCountry: target,
        allCountries: [target, other],
        canvasSize: canvas,
      );
      final onlyTarget = computeContinentFitTransform(
        targetCountry: target,
        allCountries: [target],
        canvasSize: canvas,
      );
      expect(_matricesNearlyEqual(m, onlyTarget), isTrue);
    });

    test('degenerate canvas (zero) returns identity', () {
      final target = _fake(
        'a',
        'africa',
        const Rect.fromLTWH(0.4, 0.4, 0.05, 0.05),
      );
      final m = computeContinentFitTransform(
        targetCountry: target,
        allCountries: [target],
        canvasSize: Size.zero,
      );
      expect(_matricesNearlyEqual(m, Matrix4.identity()), isTrue);
    });

    test('NaN canvas width returns identity', () {
      final target = _fake(
        'a',
        'africa',
        const Rect.fromLTWH(0.4, 0.4, 0.05, 0.05),
      );
      final m = computeContinentFitTransform(
        targetCountry: target,
        allCountries: [target],
        canvasSize: Size(double.nan, 600),
      );
      expect(_matricesNearlyEqual(m, Matrix4.identity()), isTrue);
    });

    test('continent has no matching countries returns identity', () {
      final target = _fake(
        'a',
        'antarctica',
        const Rect.fromLTWH(0.4, 0.4, 0.05, 0.05),
      );
      final other = _fake(
        'b',
        'europe',
        const Rect.fromLTWH(0.0, 0.0, 0.9, 0.9),
      );
      final m = computeContinentFitTransform(
        targetCountry: target,
        allCountries: [other],
        canvasSize: canvas,
      );
      expect(_matricesNearlyEqual(m, Matrix4.identity()), isTrue);
    });

    test('zoom clamps to maxZoom for very small bboxes', () {
      final target = _fake(
        'a',
        'africa',
        const Rect.fromLTWH(0.5, 0.5, 0.001, 0.001),
      );
      final m = computeContinentFitTransform(
        targetCountry: target,
        allCountries: [target],
        canvasSize: canvas,
        maxZoom: 15.0,
      );
      expect(m.getMaxScaleOnAxis(), closeTo(15.0, 1e-6));
    });

    test('zoom clamps to minZoom for very large bboxes', () {
      // Wider/taller-than-canvas normalized bbox (>1.0) ensures the natural-fit
      // zoom math would go below 1.0 and the clamp kicks in.
      final target = _fake(
        'a',
        'africa',
        const Rect.fromLTWH(0.0, 0.0, 2.0, 2.0),
      );
      final m = computeContinentFitTransform(
        targetCountry: target,
        allCountries: [target],
        canvasSize: canvas,
        minZoom: 1.0,
      );
      expect(m.getMaxScaleOnAxis(), closeTo(1.0, 1e-6));
    });

    test('usable canvas <= 0 (padding swallows canvas) returns identity', () {
      final target = _fake(
        'a',
        'africa',
        const Rect.fromLTWH(0.4, 0.4, 0.05, 0.05),
      );
      final m = computeContinentFitTransform(
        targetCountry: target,
        allCountries: [target],
        canvasSize: const Size(40, 40),
        paddingLogical: 24,
      );
      expect(_matricesNearlyEqual(m, Matrix4.identity()), isTrue);
    });
  });
}
