import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/theme/spacing.dart';

/// Pure Matrix4 builder for continent-fit auto-focus on the world map.
Matrix4 computeContinentFitTransform({
  required CountryPath targetCountry,
  required List<CountryPath> allCountries,
  required Size canvasSize,
  double paddingLogical = Spacing.lg,
  double minZoom = 1.0,
  double maxZoom = 15.0,
}) {
  if (!canvasSize.width.isFinite ||
      !canvasSize.height.isFinite ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0) {
    return Matrix4.identity();
  }

  final usableW = canvasSize.width - 2 * paddingLogical;
  final usableH = canvasSize.height - 2 * paddingLogical;
  if (usableW <= 0 || usableH <= 0) {
    return Matrix4.identity();
  }

  final continent = targetCountry.continent;
  Rect? unionBbox;
  for (final c in allCountries) {
    if (c.continent != continent) continue;
    final b = c.bbox;
    if (unionBbox == null) {
      unionBbox = b;
    } else {
      unionBbox = Rect.fromLTRB(
        math.min(unionBbox.left, b.left),
        math.min(unionBbox.top, b.top),
        math.max(unionBbox.right, b.right),
        math.max(unionBbox.bottom, b.bottom),
      );
    }
  }
  if (unionBbox == null) return Matrix4.identity();

  final bboxW = unionBbox.width * canvasSize.width;
  final bboxH = unionBbox.height * canvasSize.height;
  if (bboxW <= 0 || bboxH <= 0 || !bboxW.isFinite || !bboxH.isFinite) {
    return Matrix4.identity();
  }

  var zoom = math.min(usableW / bboxW, usableH / bboxH);
  if (!zoom.isFinite) return Matrix4.identity();
  if (zoom < minZoom) zoom = minZoom;
  if (zoom > maxZoom) zoom = maxZoom;

  final centerX = (unionBbox.left + unionBbox.width / 2) * canvasSize.width;
  final centerY = (unionBbox.top + unionBbox.height / 2) * canvasSize.height;

  final canvasCenterX = canvasSize.width / 2;
  final canvasCenterY = canvasSize.height / 2;

  return Matrix4.translationValues(canvasCenterX, canvasCenterY, 0)
      .multiplied(Matrix4.diagonal3Values(zoom, zoom, 1))
      .multiplied(Matrix4.translationValues(-centerX, -centerY, 0));
}
