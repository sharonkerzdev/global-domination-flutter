import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:global_domination/ui/theme/country_colors.dart';
import 'package:global_domination/ui/theme/hud_palette.dart';
import 'package:global_domination/ui/theme/milestone_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('appTheme', () {
    test('registers CountryColors, HudPalette, and MilestoneColors', () async {
      final theme = appTheme();
      await GoogleFonts.pendingFonts();

      expect(theme.extension<CountryColors>(), isNotNull);
      expect(theme.extension<HudPalette>(), isNotNull);
      expect(theme.extension<MilestoneColors>(), isNotNull);
    });

    testWidgets('textTheme uses Fredoka-derived styles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: appTheme(), home: const SizedBox()),
      );
      await GoogleFonts.pendingFonts();
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.byType(SizedBox)));
      final headline = theme.textTheme.headlineMedium;
      expect(headline, isNotNull);
      expect(headline!.fontFamily, contains('Fredoka'));
    });
  });
}
