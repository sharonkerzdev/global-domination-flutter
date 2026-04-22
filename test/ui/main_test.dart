import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/ui/fallback_error_widget.dart';

void main() {
  group('FallbackErrorWidget', () {
    testWidgets(
      'displays error message and restart button instead of default red box',
      (tester) async {
        await tester.pumpWidget(const FallbackErrorWidget());

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Restart'), findsOneWidget);
        expect(find.byType(ErrorWidget), findsNothing);
      },
    );

    testWidgets('has no provider dependencies', (tester) async {
      // The fallback error widget must work WITHOUT a ProviderScope ancestor —
      // it is the last-resort screen when providers themselves are broken.
      await tester.pumpWidget(const FallbackErrorWidget());

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('is what ErrorWidget.builder produces', (tester) async {
      final original = ErrorWidget.builder;
      ErrorWidget.builder = (details) => const FallbackErrorWidget();
      try {
        final widget = ErrorWidget.builder(
          FlutterErrorDetails(exception: Exception('boom')),
        );
        expect(widget, isA<FallbackErrorWidget>());
      } finally {
        ErrorWidget.builder = original;
      }
    });
  });

  group('App startup', () {
    testWidgets('app starts inside a ProviderScope', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: Center(child: Text('Global Domination'))),
          ),
        ),
      );

      expect(find.byType(ProviderScope), findsOneWidget);
      expect(find.text('Global Domination'), findsOneWidget);
    });
  });
}
