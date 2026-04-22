import 'package:flutter/rendering.dart';

import 'package:global_domination/ui/theme/country_colors.dart';

/// Pre-allocated [Paint] objects derived from a [CountryColors] theme.
///
/// Exists so `WorldMapPainter` instances can be rebuilt every gesture frame
/// (the view transform changes) without re-allocating `Paint` objects inside
/// the painter constructor. The palette is cached in `_MapViewState` keyed on
/// the [CountryColors] identity and only rebuilt when the theme changes.
class CountryPaints {
  CountryPaints(this.colors)
    : oceanPaint = Paint()..color = colors.ocean,
      borderPaint = Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.001,
      lockedPaint = Paint()
        ..color = colors.locked
        ..style = PaintingStyle.fill,
      unlockedPaint = Paint()
        ..color = colors.unlocked
        ..style = PaintingStyle.fill,
      readyToCollectPaint = Paint()
        ..color = colors.readyToCollect
        ..style = PaintingStyle.fill,
      automatedPaint = Paint()
        ..color = colors.automated
        ..style = PaintingStyle.fill,
      continentFillPaints = {
        for (final entry in colors.continentFills.entries)
          entry.key: Paint()
            ..color = entry.value
            ..style = PaintingStyle.fill,
      };

  final CountryColors colors;
  final Paint oceanPaint;
  final Paint borderPaint;
  final Paint lockedPaint;
  final Paint unlockedPaint;
  final Paint readyToCollectPaint;
  final Paint automatedPaint;
  final Map<String, Paint> continentFillPaints;
}
