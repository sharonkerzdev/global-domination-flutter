import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/geo_providers.dart';
import 'package:global_domination/providers/map_focus_providers.dart';
import 'package:global_domination/ui/features/map/auto_focus_target.dart';
import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/map_screen.dart';
import 'package:global_domination/ui/features/map/world_map_painter.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

import '../../../helpers/map_screen_test_providers.dart';

CountryPath _fakeCountry(String id, String continent, Rect bbox) {
  return CountryPath(
    id: CountryId(id),
    continent: ContinentId(continent),
    rings: [
      [
        Offset(bbox.left, bbox.top),
        Offset(bbox.right, bbox.top),
        Offset(bbox.right, bbox.bottom),
        Offset(bbox.left, bbox.bottom),
      ],
    ],
    bbox: bbox,
    path: Path()..addRect(bbox),
  );
}

final _egypt = _fakeCountry(
  'egypt',
  'africa',
  const Rect.fromLTWH(0.55, 0.40, 0.06, 0.06),
);
final _libya = _fakeCountry(
  'libya',
  'africa',
  const Rect.fromLTWH(0.50, 0.42, 0.08, 0.08),
);
final _china = _fakeCountry(
  'china',
  'asia',
  const Rect.fromLTWH(0.72, 0.32, 0.10, 0.10),
);

final _allFakes = [_egypt, _libya, _china];

GameState _seedAllUnlocked() {
  return GameState(
    countries: {
      const CountryId('egypt'): CountryState(
        id: const CountryId('egypt'),
        unlocked: true,
        ipLevel: 1,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      ),
      const CountryId('libya'): CountryState(
        id: const CountryId('libya'),
        unlocked: false,
        ipLevel: 0,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      ),
      const CountryId('china'): CountryState(
        id: const CountryId('china'),
        unlocked: true,
        ipLevel: 1,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      ),
    },
  );
}

GameState _seedChinaFirstInStateOrder() {
  return GameState(
    countries: {
      const CountryId('china'): CountryState(
        id: const CountryId('china'),
        unlocked: true,
        ipLevel: 1,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      ),
      const CountryId('egypt'): CountryState(
        id: const CountryId('egypt'),
        unlocked: true,
        ipLevel: 1,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      ),
      const CountryId('libya'): CountryState(
        id: const CountryId('libya'),
        unlocked: false,
        ipLevel: 0,
        leaderTier: LeaderTier.none,
        bankedInfluence: Influence.zero,
      ),
    },
  );
}

WorldMapPainter _painter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  return paints.firstWhere((w) => w.painter is WorldMapPainter).painter!
      as WorldMapPainter;
}

bool _matricesNearlyEqual(Matrix4 a, Matrix4 b, [double eps = 1e-6]) {
  for (var i = 0; i < 16; i++) {
    if ((a.storage[i] - b.storage[i]).abs() > eps) return false;
  }
  return true;
}

class _FixedRecentNotifier extends RecentlyUnlockedCountryNotifier {
  _FixedRecentNotifier(CountryId? initial) : super(const Stream.empty()) {
    state = initial;
  }
}

Widget _pump({
  required Stream<GameEvent> events,
  bool tutorialCompleted = true,
  List<CountryPath>? countries,
  GameState? initial,
}) {
  return ProviderScope(
    overrides: [
      geoProvider.overrideWith((ref) async => countries ?? _allFakes),
      mapWidgetTestContentOverride(countries ?? _allFakes),
      mapWidgetTestGameWorldOverride(initial ?? _seedAllUnlocked()),
      gameWorldEventsProvider.overrideWith((ref) => events),
      tutorialCompletedProvider.overrideWith((ref) => tutorialCompleted),
    ],
    child: MaterialApp(
      theme: appTheme(),
      home: const Scaffold(body: MapScreen()),
    ),
  );
}

void main() {
  group('MapScreen auto-focus', () {
    testWidgets(
      'AC #4 fallback: no event → focuses on first-content-order unlocked country',
      (tester) async {
        final bus = StreamController<GameEvent>.broadcast(sync: true);
        addTearDown(bus.close);

        await tester.pumpWidget(_pump(events: bus.stream));
        await tester.pumpAndSettle();

        final t = _painter(tester).viewTransform;
        expect(_matricesNearlyEqual(t, Matrix4.identity()), isFalse);
        // Egypt is content-order-first unlocked; its continent (africa) center is
        // around (0.55, 0.45). After auto-focus that maps to canvas center.
        expect(t.getMaxScaleOnAxis(), greaterThan(1.0));
      },
    );

    testWidgets(
      'AC #4 fallback uses content order when GameState map order differs',
      (tester) async {
        final bus = StreamController<GameEvent>.broadcast(sync: true);
        addTearDown(bus.close);

        await tester.pumpWidget(
          _pump(events: bus.stream, initial: _seedChinaFirstInStateOrder()),
        );
        await tester.pumpAndSettle();

        final expectedAfrica = computeContinentFitTransform(
          targetCountry: _egypt,
          allCountries: _allFakes,
          canvasSize: tester.getSize(find.byType(GestureDetector)),
        );
        final expectedAsia = computeContinentFitTransform(
          targetCountry: _china,
          allCountries: _allFakes,
          canvasSize: tester.getSize(find.byType(GestureDetector)),
        );
        final t = _painter(tester).viewTransform;

        expect(_matricesNearlyEqual(t, expectedAfrica), isTrue);
        expect(_matricesNearlyEqual(t, expectedAsia), isFalse);
      },
    );

    testWidgets('AC #3 + #7: recently-unlocked China drives focus to asia', (
      tester,
    ) async {
      late final StreamController<GameEvent> bus;
      bus = StreamController<GameEvent>.broadcast(
        sync: true,
        onListen: () {
          bus.add(
            CountryUnlocked(
              DateTime.utc(2026, 1, 1),
              countryId: const CountryId('china'),
              continent: const ContinentId('asia'),
              cost: Influence.zero,
            ),
          );
        },
      );
      addTearDown(bus.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith((ref) async => _allFakes),
            mapWidgetTestContentOverride(_allFakes),
            mapWidgetTestGameWorldOverride(_seedAllUnlocked()),
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            tutorialCompletedProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const Scaffold(body: MapScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tAsia = _painter(tester).viewTransform;
      final expected = computeContinentFitTransform(
        targetCountry: _china,
        allCountries: _allFakes,
        canvasSize: tester.getSize(find.byType(GestureDetector)),
      );
      expect(_matricesNearlyEqual(tAsia, expected), isTrue);
    });

    testWidgets(
      'Recently-unlocked-overridden China matrix differs from fallback',
      (tester) async {
        final bus1 = StreamController<GameEvent>.broadcast(sync: true);
        addTearDown(bus1.close);
        final bus2 = StreamController<GameEvent>.broadcast(sync: true);
        addTearDown(bus2.close);

        Future<Matrix4> renderWith({CountryId? fixed}) async {
          final overrides = <Override>[
            geoProvider.overrideWith((ref) async => _allFakes),
            mapWidgetTestContentOverride(_allFakes),
            mapWidgetTestGameWorldOverride(_seedAllUnlocked()),
            gameWorldEventsProvider.overrideWith(
              (ref) => fixed == null ? bus1.stream : bus2.stream,
            ),
            tutorialCompletedProvider.overrideWith((ref) => true),
            if (fixed != null)
              recentlyUnlockedCountryProvider.overrideWith(
                (ref) => _FixedRecentNotifier(fixed),
              ),
          ];
          await tester.pumpWidget(
            ProviderScope(
              overrides: overrides,
              child: MaterialApp(
                theme: appTheme(),
                home: const Scaffold(body: MapScreen()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          return _painter(tester).viewTransform;
        }

        final tAfrica = await renderWith();
        // Tear down current widget so the next pumpWidget creates a fresh
        // ProviderScope (different override count).
        await tester.pumpWidget(const SizedBox.shrink());
        final tAsia = await renderWith(fixed: const CountryId('china'));

        expect(_matricesNearlyEqual(tAfrica, tAsia), isFalse);
      },
    );

    testWidgets('AC #5: tutorialCompleted=false suppresses auto-focus', (
      tester,
    ) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);

      await tester.pumpWidget(
        _pump(events: bus.stream, tutorialCompleted: false),
      );
      await tester.pumpAndSettle();

      final t = _painter(tester).viewTransform;
      expect(_matricesNearlyEqual(t, Matrix4.identity()), isTrue);
    });

    testWidgets(
      'AC #6: after auto-focus, a later CountryUnlocked does not re-trigger',
      (tester) async {
        final bus = StreamController<GameEvent>.broadcast(sync: true);
        addTearDown(bus.close);

        await tester.pumpWidget(_pump(events: bus.stream));
        await tester.pumpAndSettle();
        final tInitial = _painter(tester).viewTransform;
        expect(_matricesNearlyEqual(tInitial, Matrix4.identity()), isFalse);

        bus.add(
          CountryUnlocked(
            DateTime.utc(2026, 1, 1),
            countryId: const CountryId('china'),
            continent: const ContinentId('asia'),
            cost: Influence.zero,
          ),
        );
        await tester.pumpAndSettle();

        final tAfter = _painter(tester).viewTransform;
        expect(_matricesNearlyEqual(tAfter, tInitial), isTrue);
      },
    );

    testWidgets('AC #10: manual pan after auto-focus is respected', (
      tester,
    ) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);

      await tester.pumpWidget(_pump(events: bus.stream));
      await tester.pumpAndSettle();
      final tFocus = _painter(tester).viewTransform;
      expect(_matricesNearlyEqual(tFocus, Matrix4.identity()), isFalse);

      await tester.drag(
        find.descendant(
          of: find.byType(MapScreen),
          matching: find.byType(GestureDetector),
        ),
        const Offset(50, 30),
      );
      await tester.pumpAndSettle();

      final tDragged = _painter(tester).viewTransform;
      expect(_matricesNearlyEqual(tDragged, tFocus), isFalse);
    });

    testWidgets('AC #9: recently-unlocked country not in geo list falls back', (
      tester,
    ) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);

      await tester.pumpWidget(_pump(events: bus.stream));
      bus.add(
        CountryUnlocked(
          DateTime.utc(2026, 1, 1),
          countryId: const CountryId('atlantis'),
          continent: const ContinentId('atlantis'),
          cost: Influence.zero,
        ),
      );
      await tester.pumpAndSettle();

      final t = _painter(tester).viewTransform;
      // Fallback to Egypt → focus did apply (transform != identity).
      expect(_matricesNearlyEqual(t, Matrix4.identity()), isFalse);
    });
  });
}
