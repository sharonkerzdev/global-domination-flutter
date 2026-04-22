import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('no duplicate baseInfluence income math outside IncomeCalculator', () {
    final root = Directory('lib/game');
    expect(root.existsSync(), isTrue);
    final patterns = <RegExp>[
      RegExp(r'def\.baseInfluence\s*\*'),
      RegExp(r'country\.baseInfluence\s*\*'),
      RegExp(r'baseInfluence\s*\*\s*ratio'),
    ];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = p.normalize(entity.path);
      if (normalized ==
          p.normalize('lib/game/features/economy/income_calculator.dart')) {
        continue;
      }
      final text = entity.readAsStringSync();
      for (final re in patterns) {
        if (re.hasMatch(text)) {
          fail(
            'Duplicate income math detected in $normalized — '
            'route through IncomeCalculator.compute',
          );
        }
      }
    }
  });
}
