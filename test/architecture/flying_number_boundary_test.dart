import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture boundary enforcement for FlyingNumber (Story 8.2).
///
/// flying_number.dart must remain UI-only: no lib/game/, no lib/data/,
/// no lib/providers/ imports.
void main() {
  group('flying_number.dart import boundary', () {
    test('file exists', () {
      final file = File('lib/ui/features/map/flying_number.dart');
      expect(file.existsSync(), isTrue);
    });

    test('does not import lib/game/', () {
      final file = File('lib/ui/features/map/flying_number.dart');
      final text = file.readAsStringSync();
      expect(
        text,
        isNot(contains('package:global_domination/game/')),
        reason: 'flying_number.dart must not import from lib/game/',
      );
    });

    test('does not import lib/data/', () {
      final file = File('lib/ui/features/map/flying_number.dart');
      final text = file.readAsStringSync();
      expect(
        text,
        isNot(contains('package:global_domination/data/')),
        reason: 'flying_number.dart must not import from lib/data/',
      );
    });

    test('does not import lib/providers/', () {
      final file = File('lib/ui/features/map/flying_number.dart');
      final text = file.readAsStringSync();
      expect(
        text,
        isNot(contains('package:global_domination/providers/')),
        reason: 'flying_number.dart must not import from lib/providers/',
      );
    });
  });
}
