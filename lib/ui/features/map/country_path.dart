import 'dart:ui';

import 'package:meta/meta.dart';

import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';

@immutable
class CountryPath {
  const CountryPath({
    required this.id,
    required this.continent,
    required this.rings,
    required this.bbox,
    required this.path,
  });

  final CountryId id;
  final ContinentId continent;

  /// Raw projected [0,1]² ring vertices — stored separately from [path] because
  /// [Path] does not expose its vertices. Used by Story 2.4 hit-testing.
  final List<List<Offset>> rings;

  final Rect bbox;
  final Path path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CountryPath && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CountryPath(${id.value})';
}
