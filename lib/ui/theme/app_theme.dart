import 'package:flutter/material.dart';

import 'package:global_domination/ui/theme/country_colors.dart';
import 'package:global_domination/ui/theme/hud_palette.dart';
import 'package:global_domination/ui/theme/milestone_colors.dart';
import 'package:global_domination/ui/theme/typography.dart';

/// Single light theme for v1 (no dark mode).
ThemeData appTheme() {
  const hud = HudPalette.defaults;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: hud.influenceAccent,
    brightness: Brightness.light,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

  return base.copyWith(
    textTheme: appTextTheme(base.textTheme),
    extensions: const [
      CountryColors.defaults,
      HudPalette.defaults,
      MilestoneColors.defaults,
    ],
  );
}
