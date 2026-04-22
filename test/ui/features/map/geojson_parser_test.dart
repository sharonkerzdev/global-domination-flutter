import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/ui/features/map/geojson_parser.dart';
import 'package:global_domination/ui/features/map/country_path.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<CountryPath> countries;

  setUpAll(() async {
    final jsonString = await rootBundle.loadString(
      'assets/geo/countries.geojson.json',
    );
    countries = parseGeoJson(jsonString);
  });

  test('parses exactly 79 entries from real GeoJSON asset', () {
    expect(countries.length, 79);
  });

  test('every CountryPath has a non-empty CountryId', () {
    for (final country in countries) {
      expect(
        country.id.value.isNotEmpty,
        isTrue,
        reason:
            'CountryPath at index ${countries.indexOf(country)} has empty id',
      );
    }
  });

  test('every CountryPath has a non-empty ContinentId', () {
    for (final country in countries) {
      expect(
        country.continent.value.isNotEmpty,
        isTrue,
        reason: '${country.id.value} has empty continent',
      );
    }
  });

  test('every CountryPath has a non-empty path with valid bbox', () {
    for (final country in countries) {
      final bounds = country.path.getBounds();
      expect(
        bounds.width > 0 || bounds.height > 0,
        isTrue,
        reason: '${country.id.value} has zero-area path',
      );
      expect(
        country.bbox.width >= 0 && country.bbox.height >= 0,
        isTrue,
        reason: '${country.id.value} has invalid bbox',
      );
    }
  });

  test('all projected ring vertices fall within [0,1]² range', () {
    for (final country in countries) {
      for (final ring in country.rings) {
        for (final vertex in ring) {
          expect(
            vertex.dx >= -0.001 && vertex.dx <= 1.001,
            isTrue,
            reason:
                '${country.id.value} has vertex.dx=${vertex.dx} outside [0,1]',
          );
          expect(
            vertex.dy >= -0.001 && vertex.dy <= 1.001,
            isTrue,
            reason:
                '${country.id.value} has vertex.dy=${vertex.dy} outside [0,1]',
          );
        }
      }
    }
  });

  test('bbox exactly encloses all ring vertices for Egypt (Polygon)', () {
    final egypt = countries.firstWhere((c) => c.id.value == 'egypt');
    _assertBboxEnclosesAllRings(egypt);
  });

  test(
    'bbox exactly encloses all ring vertices for Indonesia (MultiPolygon)',
    () {
      final indonesia = countries.firstWhere((c) => c.id.value == 'indonesia');
      _assertBboxEnclosesAllRings(indonesia);
    },
  );

  test(
    'bbox exactly encloses all ring vertices for Philippines (MultiPolygon)',
    () {
      final philippines = countries.firstWhere(
        (c) => c.id.value == 'philippines',
      );
      _assertBboxEnclosesAllRings(philippines);
    },
  );

  test('CountryPath equality is by id only', () {
    final a = countries.first;
    final b = CountryPath(
      id: a.id,
      continent: a.continent,
      rings: const [],
      bbox: a.bbox,
      path: a.path,
    );
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('CountryPaths with different ids are not equal', () {
    final a = countries[0];
    final b = countries[1];
    expect(a, isNot(equals(b)));
  });

  test('toString returns CountryPath(id)', () {
    final egypt = countries.firstWhere((c) => c.id.value == 'egypt');
    expect(egypt.toString(), 'CountryPath(egypt)');
  });

  test('no duplicate CountryIds in parsed result', () {
    final ids = countries.map((c) => c.id.value).toList();
    final uniqueIds = ids.toSet();
    expect(
      ids.length,
      equals(uniqueIds.length),
      reason: 'Duplicate CountryIds found',
    );
  });

  test('known game countries have correct ids', () {
    final ids = countries.map((c) => c.id.value).toSet();
    expect(ids, contains('egypt'));
    expect(ids, contains('nigeria'));
    expect(ids, contains('south_africa'));
  });

  test('Path uses evenOdd fillType so GeoJSON holes render as holes', () {
    // Italy, South Africa, and UAE have MultiPolygon pieces with hole rings
    // in the asset — evenOdd is required to render those holes correctly.
    for (final country in countries) {
      expect(
        country.path.fillType,
        PathFillType.evenOdd,
        reason: '${country.id.value} has fillType=${country.path.fillType}',
      );
    }
  });

  test(
    'countries with multi-ring polygons have extra rings (hole detection)',
    () {
      // Sanity check — the three countries known to carry hole rings in the
      // asset should have multiple rings; if this ever regresses the asset has
      // changed shape and the evenOdd assumption above needs revisiting.
      final multiRingCountries = countries
          .where((c) => c.rings.length > 1)
          .toList();
      final ids = multiRingCountries.map((c) => c.id.value).toSet();
      expect(ids, contains('italy'));
      expect(ids, contains('south_africa'));
      expect(ids, contains('uae'));
    },
  );
}

void _assertBboxEnclosesAllRings(CountryPath country) {
  for (final ring in country.rings) {
    for (final vertex in ring) {
      expect(
        vertex.dx >= country.bbox.left - 0.0001 &&
            vertex.dx <= country.bbox.right + 0.0001,
        isTrue,
        reason:
            '${country.id.value} vertex.dx=${vertex.dx} outside bbox '
            'left=${country.bbox.left} right=${country.bbox.right}',
      );
      expect(
        vertex.dy >= country.bbox.top - 0.0001 &&
            vertex.dy <= country.bbox.bottom + 0.0001,
        isTrue,
        reason:
            '${country.id.value} vertex.dy=${vertex.dy} outside bbox '
            'top=${country.bbox.top} bottom=${country.bbox.bottom}',
      );
    }
  }
}
