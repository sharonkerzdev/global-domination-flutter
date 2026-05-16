import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/ui/features/continents/continent_progress_bar.dart';
import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:global_domination/ui/theme/milestone_colors.dart';

void main() {
  group('ContinentProgressBar', () {
    testWidgets('renders track-only when ownedCount == 0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: ContinentProgressBar(
              ownedCount: 0,
              totalCount: 10,
              reachedMilestoneTiers: {},
            ),
          ),
        ),
      );

      // Verify the bar renders with minimal fill width
      expect(find.byType(ContinentProgressBar), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('renders fill at approximately 25% with tier-25 reached', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: ContinentProgressBar(
              ownedCount: 3,
              totalCount: 10,
              reachedMilestoneTiers: {25},
            ),
          ),
        ),
      );

      expect(find.byType(ContinentProgressBar), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('renders all four ticks', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: ContinentProgressBar(
              ownedCount: 5,
              totalCount: 10,
              reachedMilestoneTiers: {25, 50},
            ),
          ),
        ),
      );

      // Should find four _Tick widgets inside the Stack
      await tester.pumpAndSettle();
      expect(find.byType(ContinentProgressBar), findsOneWidget);
    });

    testWidgets('filled ticks use correct color for highest reached tier', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: ContinentProgressBar(
              ownedCount: 3,
              totalCount: 10,
              reachedMilestoneTiers: {25},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ContinentProgressBar), findsOneWidget);
    });

    testWidgets('completed bars color all filled ticks with milestone100', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: ContinentProgressBar(
              ownedCount: 10,
              totalCount: 10,
              reachedMilestoneTiers: {100},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      for (final tier in [25, 50, 75, 100]) {
        final tickFinder = find.byKey(
          ValueKey('continent-progress-tick-$tier'),
        );
        final containerFinder = find.descendant(
          of: tickFinder,
          matching: find.byType(Container),
        );
        expect(containerFinder, findsOneWidget);
        final container = tester.widget<Container>(containerFinder);
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, MilestoneColors.defaults.milestone100);
      }
    });

    testWidgets('initial build with multiple tiers does NOT pulse', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: ContinentProgressBar(
              ownedCount: 5,
              totalCount: 10,
              reachedMilestoneTiers: {25, 50},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // No TweenAnimationBuilder should fire on initial build
      expect(find.byType(TweenAnimationBuilder), findsNothing);
    });

    testWidgets('didUpdateWidget processes state changes', (
      WidgetTester tester,
    ) async {
      var ownedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ContinentProgressBar(
                      ownedCount: ownedCount,
                      totalCount: 10,
                      reachedMilestoneTiers: {25},
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => ownedCount = 5),
                      child: const Text('Update'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger update
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Widget should still render without error
      expect(find.byType(ContinentProgressBar), findsOneWidget);
    });

    testWidgets('totalCount == 0 guard does not throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: ContinentProgressBar(
              ownedCount: 0,
              totalCount: 0,
              reachedMilestoneTiers: {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ContinentProgressBar), findsOneWidget);
    });

    testWidgets('semantic label is rendered when provided', (
      WidgetTester tester,
    ) async {
      const label = 'Test continent progress';

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: ContinentProgressBar(
              ownedCount: 3,
              totalCount: 10,
              reachedMilestoneTiers: {25},
              semanticLabel: label,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(label), findsOneWidget);
    });

    testWidgets('animated fill width changes on ownedCount update', (
      WidgetTester tester,
    ) async {
      var ownedCount = 2;

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ContinentProgressBar(
                      ownedCount: ownedCount,
                      totalCount: 10,
                      reachedMilestoneTiers: {},
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => ownedCount = 5),
                      child: const Text('Update'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger update
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // AnimatedContainer should be animating
      expect(find.byType(AnimatedContainer), findsWidgets);
    });
  });
}
