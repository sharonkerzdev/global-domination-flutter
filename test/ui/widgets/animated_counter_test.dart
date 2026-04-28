import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:global_domination/ui/widgets/animated_counter.dart';

void main() {
  testWidgets('AnimatedCounter uses ~400ms AnimatedSwitcher duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: const Scaffold(body: AnimatedCounter(formattedValue: '1.23K')),
      ),
    );
    await tester.pump();

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, const Duration(milliseconds: 400));
  });

  testWidgets('AnimatedCounter settles on new formatted value', (tester) async {
    Widget buildCounter(String v) {
      return MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: Center(
            child: AnimatedCounter(
              formattedValue: v,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildCounter('10'));
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);

    await tester.pumpWidget(buildCounter('20'));
    await tester.pumpAndSettle();
    expect(find.text('20'), findsOneWidget);
    expect(find.text('10'), findsNothing);
  });
}
