import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/ui/features/map/flying_number.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap({
  required String amount,
  Offset offset = const Offset(100, 200),
  bool reduceMotion = false,
  VoidCallback? onEnd,
}) {
  return MaterialApp(
    theme: appTheme(),
    home: Scaffold(
      body: Stack(
        children: [
          FlyingNumber(
            key: UniqueKey(),
            amount: amount,
            screenOffset: offset,
            reduceMotion: reduceMotion,
            onEnd: onEnd ?? () {},
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FlyingNumber — rendering', () {
    testWidgets('renders text with the given amount', (tester) async {
      await tester.pumpWidget(_wrap(amount: '42'));
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('renders correctly with formatted large number', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(amount: '1.2K'));
      expect(find.text('1.2K'), findsOneWidget);
    });

    testWidgets('positioned near the given screen offset at t=0', (
      tester,
    ) async {
      const offset = Offset(50, 150);
      await tester.pumpWidget(_wrap(amount: '10', offset: offset));

      final textTopLeft = tester.getTopLeft(find.text('10'));
      expect(textTopLeft.dx, closeTo(offset.dx, 1.0));
      expect(textTopLeft.dy, closeTo(offset.dy, 1.0));
    });

    testWidgets('clamps edge taps so scaled text stays readable', (
      tester,
    ) async {
      const bounds = Size(200, 120);
      const amount = '123456789';
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: bounds,
              textScaler: TextScaler.linear(2.5),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.fromSize(
                  size: bounds,
                  child: Stack(
                    children: [
                      FlyingNumber(
                        amount: amount,
                        screenOffset: const Offset(190, 5),
                        reduceMotion: false,
                        onEnd: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      Rect rect = tester.getRect(find.text(amount));
      expect(rect.left, greaterThanOrEqualTo(0.0));
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.right, lessThanOrEqualTo(bounds.width));
      expect(rect.bottom, lessThanOrEqualTo(bounds.height));

      await tester.pump(const Duration(milliseconds: 500));

      rect = tester.getRect(find.text(amount));
      expect(rect.left, greaterThanOrEqualTo(0.0));
      expect(rect.top, greaterThanOrEqualTo(0.0));
      expect(rect.right, lessThanOrEqualTo(bounds.width));
      expect(rect.bottom, lessThanOrEqualTo(bounds.height));
    });
  });

  group('FlyingNumber — animation', () {
    testWidgets('Opacity starts at 1.0 and falls to ~0 after animation', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(amount: '99'));

      // At t=0 opacity should be near 1.0
      final opacityAtStart = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('99'), matching: find.byType(Opacity))
            .first,
      );
      expect(opacityAtStart.opacity, closeTo(1.0, 0.05));

      // After the full 1-second animation, opacity should be near 0
      await tester.pump(const Duration(milliseconds: 1000));
      // Pump one extra frame to let the final value settle
      await tester.pump(const Duration(milliseconds: 16));

      final opacityAtEnd = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('99'), matching: find.byType(Opacity))
            .first,
      );
      expect(opacityAtEnd.opacity, closeTo(0.0, 0.05));
    });

    testWidgets('Y position moves upward during animation', (tester) async {
      const offset = Offset(100, 300);
      await tester.pumpWidget(_wrap(amount: '5', offset: offset));

      final topAtStart = tester.getTopLeft(find.text('5')).dy;

      // Advance halfway through
      await tester.pump(const Duration(milliseconds: 500));

      final topAtMid = tester.getTopLeft(find.text('5')).dy;

      // Y should have decreased (moved upward)
      expect(topAtMid, lessThan(topAtStart));
    });

    testWidgets('onEnd is called after animation completes', (tester) async {
      var endCalled = false;
      await tester.pumpWidget(
        _wrap(amount: '7', onEnd: () => endCalled = true),
      );

      expect(endCalled, isFalse);

      // Run through the full 1-second animation
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 16));

      expect(endCalled, isTrue);
    });

    testWidgets('multiple flying numbers coexist independently', (
      tester,
    ) async {
      var ended1 = false;
      var ended2 = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: Stack(
              children: [
                FlyingNumber(
                  key: const ValueKey('a'),
                  amount: '10',
                  screenOffset: const Offset(50, 100),
                  reduceMotion: false,
                  onEnd: () => ended1 = true,
                ),
                FlyingNumber(
                  key: const ValueKey('b'),
                  amount: '20',
                  screenOffset: const Offset(150, 200),
                  reduceMotion: false,
                  onEnd: () => ended2 = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 16));

      expect(ended1, isTrue);
      expect(ended2, isTrue);
    });
  });

  group('FlyingNumber — reduce-motion mode', () {
    testWidgets(
      'shows text statically without Opacity/translate when reduceMotion=true',
      (tester) async {
        await tester.pumpWidget(_wrap(amount: '50', reduceMotion: true));

        expect(find.text('50'), findsOneWidget);
        // No TweenAnimationBuilder wrapping means no Opacity widget
        expect(find.byType(Opacity), findsNothing);

        // Let the pending 500ms timer fire so the test ends cleanly
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 16));
      },
    );

    testWidgets('onEnd is called after 500ms when reduceMotion=true', (
      tester,
    ) async {
      var endCalled = false;
      await tester.pumpWidget(
        _wrap(amount: '50', reduceMotion: true, onEnd: () => endCalled = true),
      );

      expect(endCalled, isFalse);
      await tester.pump(const Duration(milliseconds: 500));
      // The Future.delayed fires; pump to let microtasks run
      await tester.pump(const Duration(milliseconds: 16));

      expect(endCalled, isTrue);
    });
  });
}
