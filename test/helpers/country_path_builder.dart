import 'dart:ui';

import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/ui/features/map/country_path.dart';

CountryPath makeCountryPath({
  required String id,
  required List<List<Offset>> rings,
}) {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;
  for (final ring in rings) {
    for (final p in ring) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
  }
  final bbox = Rect.fromLTRB(minX, minY, maxX, maxY);
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final ring in rings) {
    if (ring.isEmpty) continue;
    path.moveTo(ring.first.dx, ring.first.dy);
    for (final p in ring.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
  }
  return CountryPath(
    id: CountryId(id),
    continent: const ContinentId('test'),
    rings: rings,
    bbox: bbox,
    path: path,
  );
}
