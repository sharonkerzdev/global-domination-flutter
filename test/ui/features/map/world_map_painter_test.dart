import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';

import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/geo_providers.dart';

import '../../../helpers/map_screen_test_providers.dart';
import 'package:global_domination/ui/features/map/country_paints.dart';
import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/country_visual_state.dart';
import 'package:global_domination/ui/features/map/map_screen.dart';
import 'package:global_domination/ui/features/map/world_map_painter.dart';
import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:global_domination/ui/theme/country_colors.dart';

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

WorldMapPainter _painter({
  List<CountryPath>? countries,
  Matrix4? viewTransform,
  Map<CountryId, CountryVisualState>? countryStates,
  CountryColors? colors,
}) {
  return WorldMapPainter(
    countries: countries ?? [],
    viewTransform: viewTransform ?? Matrix4.identity(),
    countryStates: countryStates ?? const {},
    paints: CountryPaints(colors ?? CountryColors.defaults),
  );
}

// ---------------------------------------------------------------------------
// shouldRepaint tests
// ---------------------------------------------------------------------------

void main() {
  group('WorldMapPainter.shouldRepaint', () {
    test('returns false when all parameters are identical', () {
      final countries = [_fakeCountry('eg', 'africa')];
      final transform = Matrix4.identity();
      final states = {CountryId('eg'): CountryVisualState.unlocked};

      final a = _painter(
        countries: countries,
        viewTransform: transform,
        countryStates: states,
      );
      final b = _painter(
        countries: countries,
        viewTransform: transform,
        countryStates: states,
      );

      expect(a.shouldRepaint(b), isFalse);
    });

    test('returns true when viewTransform differs', () {
      final a = _painter(viewTransform: Matrix4.identity());
      final b = _painter(viewTransform: Matrix4.translationValues(1, 0, 0));
      expect(a.shouldRepaint(b), isTrue);
    });

    test('returns true when countryStates map differs (different value)', () {
      final countries = <CountryPath>[];
      final transform = Matrix4.identity();
      final id = CountryId('eg');
      final a = _painter(
        countries: countries,
        viewTransform: transform,
        countryStates: {id: CountryVisualState.locked},
      );
      final b = _painter(
        countries: countries,
        viewTransform: transform,
        countryStates: {id: CountryVisualState.unlocked},
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test(
      'returns false when same countryStates map instance is passed (identity check)',
      () {
        final countries = <CountryPath>[];
        final states = {CountryId('eg'): CountryVisualState.unlocked};
        final a = _painter(countries: countries, countryStates: states);
        final b = _painter(countries: countries, countryStates: states);
        expect(a.shouldRepaint(b), isFalse);
      },
    );

    test(
      'returns true when countries list instance differs and contents differ',
      () {
        final a = _painter(countries: [_fakeCountry('eg', 'africa')]);
        final b = _painter(countries: [_fakeCountry('de', 'europe')]);
        expect(a.shouldRepaint(b), isTrue);
      },
    );

    test('returns false when countries list is the same instance', () {
      final countries = [_fakeCountry('eg', 'africa')];
      final a = _painter(countries: countries);
      final b = _painter(countries: countries);
      expect(a.shouldRepaint(b), isFalse);
    });

    test('returns true when colors differ', () {
      final countries = <CountryPath>[];
      final states = <CountryId, CountryVisualState>{};
      final transform = Matrix4.identity();
      final a = _painter(
        countries: countries,
        viewTransform: transform,
        countryStates: states,
        colors: CountryColors.defaults,
      );
      final b = _painter(
        countries: countries,
        viewTransform: transform,
        countryStates: states,
        colors: CountryColors.defaults.copyWith(ocean: const Color(0xFFFF0000)),
      );
      expect(a.shouldRepaint(b), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // MapScreen widget tests
  // ---------------------------------------------------------------------------

  group('MapScreen widget', () {
    final fakeCountries = [
      _fakeCountry('eg', 'africa'),
      _fakeCountry('de', 'europe'),
      _fakeCountry('cn', 'asia'),
    ];

    testWidgets('shows CircularProgressIndicator when geoProvider is loading', (
      tester,
    ) async {
      final completer = Completer<List<CountryPath>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith((ref) => completer.future),
            mapWidgetTestContentOverride(fakeCountries),
            mapWidgetTestGameWorldOverride(),
          ],
          child: MaterialApp(theme: appTheme(), home: const MapScreen()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'renders CustomPaint with WorldMapPainter when geoProvider resolves',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              geoProvider.overrideWith((ref) async => fakeCountries),
              mapWidgetTestContentOverride(fakeCountries),
              mapWidgetTestGameWorldOverride(),
            ],
            child: MaterialApp(theme: appTheme(), home: const MapScreen()),
          ),
        );

        await tester.pump(); // trigger future

        expect(find.byType(CustomPaint), findsWidgets);
        final customPaint = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .firstWhere((w) => w.painter is WorldMapPainter);
        expect(customPaint.painter, isA<WorldMapPainter>());
      },
    );

    testWidgets('reuses the same WorldMapPainter across rebuilds', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith((ref) async => fakeCountries),
            mapWidgetTestContentOverride(fakeCountries),
            mapWidgetTestGameWorldOverride(),
          ],
          child: MaterialApp(theme: appTheme(), home: const MapScreen()),
        ),
      );
      await tester.pump();

      final first = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere((w) => w.painter is WorldMapPainter)
          .painter;

      await tester.pump(const Duration(milliseconds: 16));

      final second = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .firstWhere((w) => w.painter is WorldMapPainter)
          .painter;

      expect(identical(first, second), isTrue);
    });

    testWidgets('shows error message when geoProvider fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith(
              (ref) => Future<List<CountryPath>>.error('boom'),
            ),
            mapWidgetTestContentOverride(fakeCountries),
            mapWidgetTestGameWorldOverride(),
          ],
          child: MaterialApp(theme: appTheme(), home: const MapScreen()),
        ),
      );

      await tester.pump(); // resolve future

      expect(find.textContaining('Map load error'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets(
      'MapScreen does not render legacy Influence pill at huge totals',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(160, 320));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              geoProvider.overrideWith((ref) async => fakeCountries),
              mapWidgetTestContentOverride(fakeCountries),
              mapWidgetTestGameWorldOverride(
                GameState(totalInfluence: Influence(Decimal.parse('1e38'))),
              ),
            ],
            child: MaterialApp(theme: appTheme(), home: const MapScreen()),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('temporaryInfluencePill')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
