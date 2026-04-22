import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/repositories/crash_log_entry.dart';
import 'package:global_domination/providers/data_providers.dart';
import 'package:global_domination/ui/debug/support_screen.dart';

List<CrashLogEntry> _fakeEntries(int count) {
  return List.generate(
    count,
    (i) => CrashLogEntry(
      timestamp: DateTime(2026, 1, 1, i),
      level: CrashLogLevel.severe,
      tag: 'Tag$i',
      message: 'Message $i',
      stackTrace: i.isEven ? '#0 stack$i' : null,
    ),
  );
}

Widget _wrap(List<CrashLogEntry> entries) {
  return ProviderScope(
    overrides: [crashLogsProvider.overrideWith((ref) async => entries)],
    child: const MaterialApp(home: SupportScreen()),
  );
}

void main() {
  group('SupportScreen', () {
    testWidgets('empty state renders "No crash logs recorded."', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([]));
      await tester.pumpAndSettle();

      expect(find.text('No crash logs recorded.'), findsOneWidget);
    });

    testWidgets('with 3 entries renders 3 cards', (tester) async {
      final entries = _fakeEntries(3);
      await tester.pumpWidget(_wrap(entries));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets('expanding a card reveals stack trace', (tester) async {
      final entries = [
        CrashLogEntry(
          timestamp: DateTime(2026, 1, 1),
          level: CrashLogLevel.severe,
          tag: 'TestTag',
          message: 'A message',
          stackTrace: '#0 someMethod (file.dart:42)',
        ),
      ];
      await tester.pumpWidget(_wrap(entries));
      await tester.pumpAndSettle();

      // Tap to expand the ExpansionTile
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();

      expect(find.text('#0 someMethod (file.dart:42)'), findsOneWidget);
    });

    testWidgets('copy button calls Clipboard.setData', (tester) async {
      final entries = _fakeEntries(2);
      String? clipboardText;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(_wrap(entries));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();

      expect(clipboardText, isNotNull);
      expect(clipboardText, contains('Message 0'));
      expect(clipboardText, contains('Message 1'));
    });

    testWidgets('copy button shows snackbar with entry count', (tester) async {
      final entries = _fakeEntries(3);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );

      await tester.pumpWidget(_wrap(entries));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();

      expect(find.text('Copied 3 entries to clipboard'), findsOneWidget);
    });

    testWidgets('copy button is disabled (null onPressed) when list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([]));
      await tester.pumpAndSettle();

      final copyButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(copyButton.onPressed, isNull);
    });

    testWidgets('semantics label present on crash log cards', (tester) async {
      final entries = _fakeEntries(1);
      await tester.pumpWidget(_wrap(entries));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(Card).first);
      expect(semantics.label, contains('Crash log'));
    });

    testWidgets('copy button has semantics label', (tester) async {
      final entries = _fakeEntries(1);
      await tester.pumpWidget(_wrap(entries));
      await tester.pumpAndSettle();

      // The Semantics wrapper around IconButton provides the label
      expect(
        find.bySemanticsLabel(
          RegExp(r'(Copy|clipboard)', caseSensitive: false),
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
