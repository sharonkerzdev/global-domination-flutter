import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// HUD files must not introduce explicit tickers (Epic 8 owns animation budget).
void main() {
  const paths = <String>[
    'lib/ui/features/hud/global_hud.dart',
    'lib/ui/widgets/currency_badge.dart',
    'lib/ui/widgets/animated_counter.dart',
  ];

  final forbidden = RegExp(
    r'AnimationController|createTicker|SingleTickerProviderStateMixin|TickerProviderStateMixin',
  );

  for (final relative in paths) {
    test('$relative has no explicit ticker APIs', () {
      final file = File(relative);
      expect(file.existsSync(), isTrue);
      final hits = <String>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (forbidden.hasMatch(code)) {
          hits.add('${i + 1}: $code');
        }
      }
      expect(hits, isEmpty, reason: hits.join('\n'));
    });
  }
}
