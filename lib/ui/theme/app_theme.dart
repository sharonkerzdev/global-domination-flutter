import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:global_domination/ui/theme/country_colors.dart';

ThemeData appTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    textTheme: GoogleFonts.fredokaTextTheme(base.textTheme),
    extensions: const [CountryColors.defaults],
  );
}
