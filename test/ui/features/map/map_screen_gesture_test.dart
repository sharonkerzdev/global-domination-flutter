import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/providers/geo_providers.dart';
import 'package:global_domination/ui/features/map/country_paints.dart';
import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/map_screen.dart';
import 'package:global_domination/ui/features/map/world_map_painter.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CountryPath _fakeCountry(String id, String continent) {
  final path = Path()..addRect(const Rect.fromLTWH(0, 0, 0.1, 0.1));
  return CountryPath(
    id: CountryId(id),
    continent: ContinentId(continent),
    rings: const [
      [Offset(0, 0), Offset(0.1, 0), Offset(0.1, 0.1), Offset(0, 0.1)],
    ],
    bbox: const Rect.fromLTWH(0, 0, 0.1, 0.1),
    path: path,
  );
}

final _fakeCountries = [
  _fakeCountry('eg', 'africa'),
  _fakeCountry('de', 'europe'),
  _fakeCountry('cn', 'asia'),
];

Widget _buildApp(List<CountryPath> countries) {
  return ProviderScope(
    overrides: [geoProvider.overrideWith((ref) async => countries)],
    child: MaterialApp(theme: appTheme(), home: const MapScreen()),
  );
}

WorldMapPainter _getPainter(WidgetTester tester) {
  final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  return customPaints.firstWhere((w) => w.painter is WorldMapPainter).painter!
      as WorldMapPainter;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MapScreen gesture — initial state', () {
    testWidgets('painter has identity viewTransform before any gesture', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_fakeCountries));
      await tester.pump();

      final painter = _getPainter(tester);
      expect(painter.viewTransform, equals(Matrix4.identity()));
    });
  });

  group('MapScreen gesture — pan', () {
    testWidgets('drag gesture changes viewTransform to non-identity', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_fakeCountries));
      await tester.pump();

      await tester.drag(find.byType(GestureDetector), const Offset(50, 30));
      await tester.pump();

      final painter = _getPainter(tester);
      expect(painter.viewTransform, isNot(equals(Matrix4.identity())));
    });
  });

  group('MapScreen gesture — allocation safety', () {
    testWidgets('paint palette is reused across gesture frames', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_fakeCountries));
      await tester.pump();

      final CountryPaints paintsBefore = _getPainter(tester).paints;

      await tester.drag(find.byType(GestureDetector), const Offset(50, 30));
      await tester.pump();

      final CountryPaints paintsAfter = _getPainter(tester).paints;
      // Identity (not just equality): confirms no Paint reallocation on the
      // gesture hot path — story anti-pattern forbids per-frame allocations.
      expect(identical(paintsBefore, paintsAfter), isTrue);
    });

    testWidgets(
      'viewTransform is stable after gesture ends (AC #4: no redundant frames)',
      (tester) async {
        await tester.pumpWidget(_buildApp(_fakeCountries));
        await tester.pump();

        await tester.drag(find.byType(GestureDetector), const Offset(50, 30));
        await tester.pump();

        final Matrix4 transformAfterGesture = _getPainter(tester).viewTransform;

        // Pump several additional frames with no input — the painter's
        // transform must not change, proving no post-gesture animation or
        // redundant setState is firing.
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        final Matrix4 transformAfterPumps = _getPainter(tester).viewTransform;
        expect(transformAfterPumps, equals(transformAfterGesture));
      },
    );
  });

  group('MapScreen gesture — zoom clamp', () {
    testWidgets('zoom scale stays within [1.0, 15.0] after pinch-out', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_fakeCountries));
      await tester.pump();

      final center = tester.getCenter(find.byType(GestureDetector));

      // Simulate multiple aggressive pinch-out gestures
      for (int i = 0; i < 25; i++) {
        final gesture1 = await tester.startGesture(center - const Offset(5, 0));
        final gesture2 = await tester.startGesture(center + const Offset(5, 0));
        await gesture1.moveTo(center - Offset(5 + (i + 1) * 20.0, 0));
        await gesture2.moveTo(center + Offset(5 + (i + 1) * 20.0, 0));
        await tester.pump();
        await gesture1.up();
        await gesture2.up();
        await tester.pump();
      }

      final painter = _getPainter(tester);
      final scale = painter.viewTransform.getMaxScaleOnAxis();
      expect(scale, lessThanOrEqualTo(15.0));
      expect(scale, greaterThanOrEqualTo(1.0));
    });

    testWidgets('zoom scale stays >= 1.0 after extreme pinch-in', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(_fakeCountries));
      await tester.pump();

      final center = tester.getCenter(find.byType(GestureDetector));

      // Simulate multiple aggressive pinch-in gestures
      for (int i = 0; i < 10; i++) {
        final startOffset = 100.0 + i * 5;
        final gesture1 = await tester.startGesture(
          center - Offset(startOffset, 0),
        );
        final gesture2 = await tester.startGesture(
          center + Offset(startOffset, 0),
        );
        await gesture1.moveTo(center - const Offset(5, 0));
        await gesture2.moveTo(center + const Offset(5, 0));
        await tester.pump();
        await gesture1.up();
        await gesture2.up();
        await tester.pump();
      }

      final painter = _getPainter(tester);
      final scale = painter.viewTransform.getMaxScaleOnAxis();
      expect(scale, greaterThanOrEqualTo(1.0));
    });
  });
}
