import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/ui/debug/spike_geojson_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SpikeCountryPath> countries;

  setUpAll(() async {
    final jsonString = await rootBundle.loadString(
      'assets/geo/countries.geojson.json',
    );
    countries = parseSpikeGeoJson(jsonString);
  });

  test('parses exactly 79 countries from GeoJSON', () {
    expect(countries.length, 79);
  });

  test('every country has a non-empty name', () {
    for (final country in countries) {
      expect(
        country.name.isNotEmpty,
        isTrue,
        reason: 'Country at index ${countries.indexOf(country)} has empty name',
      );
    }
  });

  test('every country has a non-empty Path with valid bounds', () {
    for (final country in countries) {
      final bounds = country.path.getBounds();
      expect(
        bounds.width > 0 || bounds.height > 0,
        isTrue,
        reason: '${country.name} has zero-area path bounds',
      );
    }
  });

  test('every country has a valid bbox', () {
    for (final country in countries) {
      expect(
        country.bbox.width >= 0 && country.bbox.height >= 0,
        isTrue,
        reason: '${country.name} has invalid bbox',
      );
    }
  });

  test('all projected coordinates fall within [0,1]² space', () {
    for (final country in countries) {
      final bounds = country.path.getBounds();
      expect(
        bounds.left >= -0.01 && bounds.right <= 1.01,
        isTrue,
        reason:
            '${country.name} x out of range: '
            'left=${bounds.left}, right=${bounds.right}',
      );
      expect(
        bounds.top >= -0.01 && bounds.bottom <= 1.01,
        isTrue,
        reason:
            '${country.name} y out of range: '
            'top=${bounds.top}, bottom=${bounds.bottom}',
      );
    }
  });
}
