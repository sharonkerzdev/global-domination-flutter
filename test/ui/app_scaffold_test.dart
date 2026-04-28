import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/providers/geo_providers.dart';

import '../helpers/map_screen_test_providers.dart';
import 'package:global_domination/ui/app_scaffold.dart';
import 'package:global_domination/ui/features/hud/global_hud.dart';
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

Widget _pumpAppScaffold() {
  return ProviderScope(
    overrides: [
      geoProvider.overrideWith((ref) async => _fakeCountries),
      mapWidgetTestGameWorldOverride(),
    ],
    child: MaterialApp(theme: appTheme(), home: const AppScaffold()),
  );
}

WorldMapPainter _mapPainter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  return paints.firstWhere((w) => w.painter is WorldMapPainter).painter!
      as WorldMapPainter;
}

Finder _mapGestureDetector() {
  return find.descendant(
    of: find.byType(MapScreen),
    matching: find.byType(GestureDetector),
  );
}

bool _matricesNearlyEqual(Matrix4 a, Matrix4 b) {
  for (var i = 0; i < 16; i++) {
    if ((a.storage[i] - b.storage[i]).abs() > 1e-9) {
      return false;
    }
  }
  return true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AppScaffold', () {
    testWidgets('bottom nav has five fixed items in Map → Minigames order', (
      tester,
    ) async {
      await tester.pumpWidget(_pumpAppScaffold());
      await tester.pump();

      final bar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bar.type, BottomNavigationBarType.fixed);
      expect(bar.items, hasLength(5));

      final labels = bar.items.map((e) => e.label).toList();
      expect(labels, [
        'Map',
        'Upgrades',
        'Leaders',
        'Achievements',
        'Minigames',
      ]);

      for (final item in bar.items) {
        expect(item.icon, isA<Icon>());
      }
    });

    testWidgets('IndexedStack index tracks taps; initial tab is Map', (
      tester,
    ) async {
      await tester.pumpWidget(_pumpAppScaffold());
      await tester.pump();

      IndexedStack stack() => tester.widget(find.byType(IndexedStack));

      expect(stack().index, 0);

      await tester.tap(find.text('Upgrades'));
      await tester.pump();
      expect(stack().index, 1);

      await tester.tap(find.text('Leaders'));
      await tester.pump();
      expect(stack().index, 2);

      await tester.tap(find.text('Achievements'));
      await tester.pump();
      expect(stack().index, 3);

      await tester.tap(find.text('Minigames'));
      await tester.pump();
      expect(stack().index, 4);

      await tester.tap(find.text('Map'));
      await tester.pump();
      expect(stack().index, 0);
    });

    testWidgets('Minigames tab shows Coming Soon', (tester) async {
      await tester.pumpWidget(_pumpAppScaffold());
      await tester.pump();

      await tester.tap(find.text('Minigames'));
      await tester.pump();

      expect(find.text('Coming Soon'), findsOneWidget);
    });

    testWidgets('map viewTransform survives tab switch after pan', (
      tester,
    ) async {
      await tester.pumpWidget(_pumpAppScaffold());
      await tester.pump();

      await tester.drag(_mapGestureDetector(), const Offset(50, 30));
      await tester.pump();

      final afterPan = _mapPainter(tester).viewTransform;
      expect(_matricesNearlyEqual(afterPan, Matrix4.identity()), isFalse);

      await tester.tap(find.text('Upgrades'));
      await tester.pump();

      await tester.tap(find.text('Map'));
      await tester.pump();

      final afterReturn = _mapPainter(tester).viewTransform;
      expect(_matricesNearlyEqual(afterReturn, afterPan), isTrue);
    });

    testWidgets('geoProvider async body runs once across tab switches', (
      tester,
    ) async {
      var loads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            geoProvider.overrideWith((ref) async {
              loads++;
              return _fakeCountries;
            }),
            mapWidgetTestGameWorldOverride(),
          ],
          child: MaterialApp(theme: appTheme(), home: const AppScaffold()),
        ),
      );
      await tester.pump();

      expect(loads, 1);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Upgrades'));
        await tester.pump();
        await tester.tap(find.text('Map'));
        await tester.pump();
      }

      expect(loads, 1);
    });

    testWidgets('GlobalHud is mounted once and stays visible on every tab', (
      tester,
    ) async {
      await tester.pumpWidget(_pumpAppScaffold());
      await tester.pump();

      expect(find.byType(GlobalHud), findsOneWidget);

      for (final label in [
        'Upgrades',
        'Leaders',
        'Achievements',
        'Minigames',
        'Map',
      ]) {
        await tester.tap(find.text(label));
        await tester.pump();
        expect(find.byType(GlobalHud), findsOneWidget);
      }
    });

    testWidgets('Map tab no longer shows temporary Influence pill', (
      tester,
    ) async {
      await tester.pumpWidget(_pumpAppScaffold());
      await tester.pump();

      expect(
        find.byKey(const ValueKey('temporaryInfluencePill')),
        findsNothing,
      );
    });
  });

  group('AppScaffold architecture', () {
    test(
      'app_scaffold.dart does not import package:global_domination/data/',
      () {
        final file = File('lib/ui/app_scaffold.dart');
        expect(file.existsSync(), isTrue);
        final violations = <String>[];
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//')) continue;
          if (line.contains(r"package:global_domination/data/")) {
            violations.add('${i + 1}: $line');
          }
        }
        expect(violations, isEmpty, reason: violations.join('\n'));
      },
    );
  });
}
