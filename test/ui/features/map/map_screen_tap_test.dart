import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/geo_providers.dart';
import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/map_screen.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Spy notifier — records applied commands
// ---------------------------------------------------------------------------

final _emptyContent = const ContentRegistry(
  countries: {},
  continents: {},
  leaders: [],
  achievements: [],
  missions: [],
  globalUpgrades: [],
  dailyRewards: [],
);

class _SpyGameWorldNotifier extends GameWorldNotifier {
  _SpyGameWorldNotifier()
    : super(
        GameWorld(
          content: _emptyContent,
          clock: const SystemClock(),
          rng: SeededRng(0),
          initialState: GameState(),
        ),
      );

  final List<GameCommand> applied = [];

  @override
  void apply(GameCommand cmd) {
    applied.add(cmd);
  }

  @override
  void tick(Duration dt) {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Large square filling most of [0,1]²: easy to tap in center
CountryPath _bigCountry(String id) {
  final rings = [
    [
      const Offset(0.1, 0.1),
      const Offset(0.9, 0.1),
      const Offset(0.9, 0.9),
      const Offset(0.1, 0.9),
    ],
  ];
  const bbox = Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);
  final path = Path()..fillType = PathFillType.evenOdd;
  path.addPolygon(rings[0], true);
  return CountryPath(
    id: CountryId(id),
    continent: const ContinentId('africa'),
    rings: rings,
    bbox: bbox,
    path: path,
  );
}

// Small square in top-left corner; tap in bottom-right is ocean
CountryPath _smallCountry(String id) {
  final rings = [
    [
      const Offset(0.0, 0.0),
      const Offset(0.05, 0.0),
      const Offset(0.05, 0.05),
      const Offset(0.0, 0.05),
    ],
  ];
  const bbox = Rect.fromLTRB(0.0, 0.0, 0.05, 0.05);
  final path = Path()..fillType = PathFillType.evenOdd;
  path.addPolygon(rings[0], true);
  return CountryPath(
    id: CountryId(id),
    continent: const ContinentId('africa'),
    rings: rings,
    bbox: bbox,
    path: path,
  );
}

Widget _buildApp({
  required List<CountryPath> countries,
  required _SpyGameWorldNotifier spy,
}) {
  return ProviderScope(
    overrides: [
      geoProvider.overrideWith((ref) async => countries),
      contentRegistryProvider.overrideWith((ref) async => _emptyContent),
      gameWorldProvider.overrideWith((ref) => spy),
    ],
    child: MaterialApp(theme: appTheme(), home: const MapScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MapScreen tap — dispatch', () {
    testWidgets('tap on a country dispatches TapCountry with correct id', (
      tester,
    ) async {
      final spy = _SpyGameWorldNotifier();
      await tester.pumpWidget(
        _buildApp(countries: [_bigCountry('eg')], spy: spy),
      );
      await tester.pump(); // resolve FutureProvider

      // Tap at the center of the widget — the big country covers 10%–90% of
      // normalized space so center maps inside it regardless of canvas size.
      await tester.tapAt(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump();

      expect(spy.applied, hasLength(1));
      expect(spy.applied.first, isA<TapCountry>());
      expect(
        (spy.applied.first as TapCountry).countryId,
        const CountryId('eg'),
      );
    });

    testWidgets('tap on ocean dispatches nothing', (tester) async {
      final spy = _SpyGameWorldNotifier();
      await tester.pumpWidget(
        _buildApp(countries: [_smallCountry('eg')], spy: spy),
      );
      await tester.pump();

      // The small country is in the top-left (0–5% of normalized space).
      // Tap at the bottom-right corner of the widget → ocean.
      final rect = tester.getRect(find.byType(GestureDetector));
      await tester.tapAt(Offset(rect.right - 10, rect.bottom - 10));
      await tester.pump();

      expect(spy.applied, isEmpty);
    });

    testWidgets('tap works correctly after pan', (tester) async {
      final spy = _SpyGameWorldNotifier();
      await tester.pumpWidget(
        _buildApp(countries: [_bigCountry('eg')], spy: spy),
      );
      await tester.pump();

      // Pan slightly right
      await tester.drag(find.byType(GestureDetector), const Offset(20, 0));
      await tester.pump();

      // After pan, center of widget still maps inside the big country
      // (it covers 10%–90% so a 20px pan on a typical 800px canvas = ~2.5%
      // shift, well within the polygon bounds).
      await tester.tapAt(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump();

      expect(spy.applied, hasLength(1));
      expect(spy.applied.first, isA<TapCountry>());
    });

    testWidgets('tap works correctly after zoom (AC #1 any pan/zoom)', (
      tester,
    ) async {
      final spy = _SpyGameWorldNotifier();
      // Use a small country centered at (0.5, 0.5) — only reachable if the
      // inverse transform is computed correctly post-zoom.
      final center = CountryPath(
        id: const CountryId('mid'),
        continent: const ContinentId('africa'),
        rings: [
          [
            const Offset(0.45, 0.45),
            const Offset(0.55, 0.45),
            const Offset(0.55, 0.55),
            const Offset(0.45, 0.55),
          ],
        ],
        bbox: const Rect.fromLTRB(0.45, 0.45, 0.55, 0.55),
        path: Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(const Rect.fromLTRB(0.45, 0.45, 0.55, 0.55)),
      );
      await tester.pumpWidget(_buildApp(countries: [center], spy: spy));
      await tester.pump();

      // Pinch-zoom-in centered on the widget midpoint. Zooming around the
      // center leaves the midpoint fixed in screen space, so a tap at the
      // midpoint still maps to normalized (0.5, 0.5) — inside the polygon.
      final widgetCenter = tester.getCenter(find.byType(GestureDetector));
      final g1 = await tester.startGesture(widgetCenter - const Offset(20, 0));
      final g2 = await tester.startGesture(widgetCenter + const Offset(20, 0));
      await g1.moveBy(const Offset(-40, 0));
      await g2.moveBy(const Offset(40, 0));
      await g1.up();
      await g2.up();
      await tester.pump();

      await tester.tapAt(widgetCenter);
      await tester.pump();

      expect(spy.applied, hasLength(1));
      expect(spy.applied.first, isA<TapCountry>());
      expect(
        (spy.applied.first as TapCountry).countryId,
        const CountryId('mid'),
      );
    });
  });
}
