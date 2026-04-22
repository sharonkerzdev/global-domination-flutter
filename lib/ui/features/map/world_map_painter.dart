import 'package:flutter/rendering.dart';

import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/country_paints.dart';
import 'package:global_domination/ui/features/map/country_visual_state.dart';

class WorldMapPainter extends CustomPainter {
  const WorldMapPainter({
    required this.countries,
    required this.viewTransform,
    required this.countryStates,
    required this.paints,
  });

  final List<CountryPath> countries;
  final Matrix4 viewTransform;
  final Map<CountryId, CountryVisualState> countryStates;
  final CountryPaints paints;

  Paint _statePaint(CountryVisualState state) {
    switch (state) {
      case CountryVisualState.locked:
        return paints.lockedPaint;
      case CountryVisualState.unlocked:
        return paints.unlockedPaint;
      case CountryVisualState.readyToCollect:
        return paints.readyToCollectPaint;
      case CountryVisualState.automated:
        return paints.automatedPaint;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Layer 1: ocean background (drawn before transform — covers full screen)
    canvas.drawRect(Offset.zero & size, paints.oceanPaint);

    canvas.save();
    canvas.transform(viewTransform.storage);
    canvas.scale(size.width, size.height);

    // Layer 2: continent background fills
    for (final country in countries) {
      final continentPaint =
          paints.continentFillPaints[country.continent.value];
      assert(
        continentPaint != null,
        'No continent fill registered for ${country.continent.value}',
      );
      if (continentPaint != null) {
        canvas.drawPath(country.path, continentPaint);
      }
    }

    // Layer 3: country state fills
    for (final country in countries) {
      final state = countryStates[country.id] ?? CountryVisualState.locked;
      canvas.drawPath(country.path, _statePaint(state));
    }

    // Layer 4: country borders
    for (final country in countries) {
      canvas.drawPath(country.path, paints.borderPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(WorldMapPainter oldDelegate) {
    if (!identical(countries, oldDelegate.countries)) return true;
    if (viewTransform != oldDelegate.viewTransform) return true;
    if (!identical(countryStates, oldDelegate.countryStates)) {
      if (countryStates.length != oldDelegate.countryStates.length) return true;
      for (final key in countryStates.keys) {
        if (countryStates[key] != oldDelegate.countryStates[key]) return true;
      }
    }
    if (paints.colors != oldDelegate.paints.colors) return true;
    return false;
  }
}
