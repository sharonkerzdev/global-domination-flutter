import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture boundary enforcement for `lib/data/` ↔ `lib/game/`.
void main() {
  List<File> findDartFiles(Directory dir) {
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  List<String> findViolations(List<File> files, RegExp pattern) {
    final violations = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue;
        if (pattern.hasMatch(line)) {
          violations.add('${file.path}:${i + 1}: $line');
        }
      }
    }
    return violations;
  }

  group('lib/data/database tables and converters', () {
    test('do not import lib/game/', () {
      final dirs = [
        Directory('lib/data/database/tables'),
        Directory('lib/data/database/converters'),
      ];
      final pattern = RegExp(
        r'''import\s+['"]package:global_domination/game/''',
      );
      final violations = <String>[];
      for (final dir in dirs) {
        violations.addAll(findViolations(findDartFiles(dir), pattern));
      }
      expect(
        violations,
        isEmpty,
        reason:
            '${violations.join('\n')} imports lib/game/ — tables/converters must be pure persistence types; mapping logic belongs in lib/data/mappers/game_state_mapper.dart',
      );
    });
  });

  const dualImportAllowlist = <String>{
    'lib/data/mappers/game_state_mapper.dart',
    'lib/data/repositories/save_repository.dart',
  };

  group('lib/data/ mapper bridge', () {
    test('only allowlisted files import both database and game', () {
      final dataRoot = Directory('lib/data');
      final files = findDartFiles(dataRoot);
      final gamePat = RegExp(
        r'''import\s+['"]package:global_domination/game/''',
      );
      final dbPat = RegExp(
        r'''import\s+['"]package:global_domination/data/database/''',
      );
      final dual = <String>[];
      for (final f in files) {
        final text = f.readAsStringSync();
        if (gamePat.hasMatch(text) && dbPat.hasMatch(text)) {
          final norm = f.path.replaceAll(r'\', '/');
          const marker = 'lib/data/';
          final i = norm.indexOf(marker);
          dual.add(i >= 0 ? norm.substring(i) : norm);
        }
      }
      for (final path in dual) {
        expect(
          dualImportAllowlist.contains(path),
          isTrue,
          reason:
              'Dual-import file $path must be explicitly allowlisted. '
              'If intentional, add it to dualImportAllowlist.',
        );
      }
      expect(
        dual.toSet(),
        dualImportAllowlist,
        reason: 'Dual-import set must match allowlist. Found: $dual',
      );
    });

    test('save_repository.dart is in the dual-import allowlist', () {
      expect(
        dualImportAllowlist,
        contains('lib/data/repositories/save_repository.dart'),
      );
    });
  });
}
