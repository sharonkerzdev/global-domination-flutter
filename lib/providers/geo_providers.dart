import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/geojson_parser.dart';

/// Loads and parses `assets/geo/countries.geojson.json` once at startup.
///
/// Riverpod's [FutureProvider] caches the result — all [ref.watch] calls share
/// the same [List<CountryPath>]. The map tab is kept alive in an [IndexedStack]
/// so parsing never repeats on tab switch.
final geoProvider = FutureProvider<List<CountryPath>>((ref) async {
  final jsonString = await rootBundle.loadString(
    'assets/geo/countries.geojson.json',
  );
  return parseGeoJson(jsonString);
});
