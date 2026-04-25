import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/features/goldens/active_golden.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/geo_providers.dart';
import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/map_screen.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Copy of map_screen_tap_test helpers: big polygon + spy notifier
// ---------------------------------------------------------------------------

final _emptyContent = const ContentRegistry(
  countries: {},
  continents: {},
  leaders: [],
  achievements: [],
  missions: [],
  globalUpgrades: [],
);

class _SpyGameWorldNotifier extends GameWorldNotifier {
  _SpyGameWorldNotifier(GameState s)
    : super(
        GameWorld(
          content: _emptyContent,
          clock: const SystemClock(),
          rng: SeededRng(0),
          initialState: s,
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

void main() {
  group('MapScreen golden tap routing', () {
    testWidgets('active golden on country → ClaimGolden, not TapCountry', (
      tester,
    ) async {
      const cid = 'eg';
      const goldenId = 'g1';
      final exp = DateTime.utc(2099, 1, 1, 20);
      final s = GameState(
        activeGoldens: {
          goldenId: ActiveGolden(
            id: goldenId,
            countryId: const CountryId(cid),
            multiplier: 50,
            expiresAt: exp,
          ),
        },
      );
      final spy = _SpyGameWorldNotifier(s);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith((ref) async => [_bigCountry(cid)]),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(theme: appTheme(), home: const MapScreen()),
        ),
      );
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump();

      expect(spy.applied, hasLength(1));
      expect(spy.applied.first, isA<ClaimGolden>());
      expect((spy.applied.first as ClaimGolden).goldenId, equals(goldenId));
    });

    testWidgets('no active golden → TapCountry', (tester) async {
      const cid = 'eg';
      final spy = _SpyGameWorldNotifier(GameState());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith((ref) async => [_bigCountry(cid)]),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(theme: appTheme(), home: const MapScreen()),
        ),
      );
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump();
      expect(spy.applied.single, isA<TapCountry>());
    });

    testWidgets('expired golden still routes to ClaimGolden', (tester) async {
      const cid = 'eg';
      const goldenId = 'g1';
      final s = GameState(
        activeGoldens: {
          goldenId: ActiveGolden(
            id: goldenId,
            countryId: const CountryId(cid),
            multiplier: 50,
            expiresAt: DateTime.utc(2000, 1, 1),
          ),
        },
      );
      final spy = _SpyGameWorldNotifier(s);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith((ref) async => [_bigCountry(cid)]),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(theme: appTheme(), home: const MapScreen()),
        ),
      );
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump();
      expect(spy.applied.single, isA<ClaimGolden>());
      expect((spy.applied.single as ClaimGolden).goldenId, equals(goldenId));
    });

    testWidgets('earliest-expiry golden is claimed when multiple match', (
      tester,
    ) async {
      const cid = 'eg';
      final s = GameState(
        activeGoldens: {
          'later': ActiveGolden(
            id: 'later',
            countryId: const CountryId(cid),
            multiplier: 20,
            expiresAt: DateTime.utc(2099, 1, 1, 20, 0, 10),
          ),
          'earlier': ActiveGolden(
            id: 'earlier',
            countryId: const CountryId(cid),
            multiplier: 10,
            expiresAt: DateTime.utc(2099, 1, 1, 20, 0, 5),
          ),
        },
      );
      final spy = _SpyGameWorldNotifier(s);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith((ref) async => [_bigCountry(cid)]),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(theme: appTheme(), home: const MapScreen()),
        ),
      );
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump();
      expect(spy.applied.single, isA<ClaimGolden>());
      expect((spy.applied.single as ClaimGolden).goldenId, equals('earlier'));
    });

    testWidgets('equal-expiry tie-break picks smallest golden id', (
      tester,
    ) async {
      const cid = 'eg';
      final t = DateTime.utc(2099, 1, 1, 20, 0, 5);
      final s = GameState(
        activeGoldens: {
          'z-id': ActiveGolden(
            id: 'z-id',
            countryId: const CountryId(cid),
            multiplier: 20,
            expiresAt: t,
          ),
          'a-id': ActiveGolden(
            id: 'a-id',
            countryId: const CountryId(cid),
            multiplier: 10,
            expiresAt: t,
          ),
        },
      );
      final spy = _SpyGameWorldNotifier(s);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith((ref) async => [_bigCountry(cid)]),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(theme: appTheme(), home: const MapScreen()),
        ),
      );
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump();
      expect(spy.applied.single, isA<ClaimGolden>());
      expect((spy.applied.single as ClaimGolden).goldenId, equals('a-id'));
    });
  });
}
