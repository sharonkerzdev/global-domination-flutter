import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:global_domination/ui/widgets/currency_badge.dart';

void main() {
  group('CurrencyBadge', () {
    testWidgets('Influence: icon, formatted value, semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: Center(
              child: CurrencyBadge.influence(
                value: Influence(Decimal.parse('1234')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.public), findsOneWidget);
      expect(find.text('1.23K'), findsOneWidget);
      expect(find.bySemanticsLabel('Influence 1.23K'), findsOneWidget);
    });

    testWidgets('Intel: memory icon and semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: Center(
              child: CurrencyBadge.intel(value: Intel(Decimal.parse('45'))),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.memory), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.bySemanticsLabel('Intel 45'), findsOneWidget);
    });

    testWidgets('large Influence value formats without exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: Center(
              child: CurrencyBadge.influence(
                value: Influence(Decimal.parse('1e38')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CurrencyBadge), findsOneWidget);
    });
  });
}
