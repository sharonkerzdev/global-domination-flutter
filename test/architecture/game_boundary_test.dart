// CI-equivalent one-liner (for when CI pipeline is wired — future story):
//   grep -rn "import 'package:flutter/" lib/game/ && exit 1 || exit 0
//   grep -rn "import 'dart:ui" lib/game/ && exit 1 || exit 0
//   grep -rn "import.*package:global_domination/data/" lib/game/ && exit 1 || exit 0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture boundary enforcement tests for `lib/game/`.
///
/// These tests ensure the headless-simulation invariant:
/// - No Flutter SDK imports (`package:flutter/`)
/// - No `dart:ui` imports
/// - No reverse dependencies on `lib/data/`
void main() {
  final gameDir = Directory('lib/game');

  /// Collects all `*.dart` files recursively under [dir].
  List<File> findDartFiles(Directory dir) {
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  /// Scans [files] for lines matching [pattern]. Returns a list of
  /// human-readable violation strings: `<filePath>:<lineNumber>: <line>`.
  List<String> findViolations(List<File> files, RegExp pattern) {
    final violations = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // Skip commented-out lines
        if (line.startsWith('//')) continue;
        if (pattern.hasMatch(line)) {
          violations.add('${file.path}:${i + 1}: $line');
        }
      }
    }
    return violations;
  }

  group('lib/game/ boundary enforcement', () {
    test('contains no Flutter SDK imports (package:flutter/)', () {
      final files = findDartFiles(gameDir);
      // Pass trivially if lib/game/ doesn't exist yet
      if (files.isEmpty) return;

      final pattern = RegExp(r'''import\s+['"]package:flutter/''');
      final violations = findViolations(files, pattern);

      expect(
        violations,
        isEmpty,
        reason:
            'lib/game/ must have ZERO Flutter imports.\n'
            'Violations found:\n${violations.join('\n')}',
      );
    });

    test('contains no dart:ui imports', () {
      final files = findDartFiles(gameDir);
      if (files.isEmpty) return;

      final pattern = RegExp(r'''import\s+['"]dart:ui['"]''');
      final violations = findViolations(files, pattern);

      expect(
        violations,
        isEmpty,
        reason:
            'lib/game/ must not import dart:ui.\n'
            'Violations found:\n${violations.join('\n')}',
      );
    });

    test('does not import from lib/data/ (forbidden reverse dependency)', () {
      final files = findDartFiles(gameDir);
      if (files.isEmpty) return;

      // Match relative imports into data/ or package imports into data/
      final pattern = RegExp(
        r'''import\s+['"](\.\.\/)*data\/|import\s+['"]package:global_domination\/data\/''',
      );
      final violations = findViolations(files, pattern);

      expect(
        violations,
        isEmpty,
        reason:
            'lib/game/ must never import from lib/data/.\n'
            'Violations found:\n${violations.join('\n')}',
      );
    });

    test('passes when lib/game/ directory does not exist', () {
      // Explicitly verify that the test logic handles missing directory
      final nonExistentDir = Directory('lib/game_nonexistent_test_dir');
      final files = findDartFiles(nonExistentDir);
      expect(files, isEmpty);
    });
  });
}
