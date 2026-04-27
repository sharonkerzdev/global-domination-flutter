import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Raw [Color] constructors and [Colors] swatches belong in `lib/ui/theme/` only.
///
/// This guardrail enforces color literals only. Spacing and typography literals in
/// widgets should still use [Spacing] and [ThemeData.textTheme]; prefer extending
/// this suite if literals slip past review.
void main() {
  test('lib/ui production widgets do not use raw Color(...) or Colors.*', () async {
    final uiRoot = Directory(p.join('lib', 'ui'));
    expect(uiRoot.existsSync(), isTrue);

    final violations = <String>[];
    final colorCtor = RegExp(r'\bColor\s*\(');
    final colorsSwatch = RegExp(r'\bColors\.');

    await for (final entity in uiRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = p.normalize(entity.path).replaceAll(r'\', '/');
      if (_allowlisted(relative)) continue;

      final lines = await entity.readAsLines();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (colorCtor.hasMatch(code) || colorsSwatch.hasMatch(code)) {
          violations.add('$relative:${i + 1}: $code');
        }
      }
    }

    if (violations.isNotEmpty) {
      fail(
        'Use Theme.of(context).colorScheme, ThemeExtension tokens (CountryColors, '
        'HudPalette, MilestoneColors), or theme-local definitions under lib/ui/theme/. '
        'Also prefer Spacing.* and textTheme over numeric layout/text literals.\n'
        '${violations.join('\n')}',
      );
    }
  });
}

bool _allowlisted(String relativePosix) {
  if (relativePosix.startsWith('lib/ui/theme/')) return true;
  // Throwaway performance spikes — not patterns for production UI.
  if (relativePosix.startsWith('lib/ui/debug/spike_')) return true;
  return false;
}
