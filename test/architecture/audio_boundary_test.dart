import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture boundary enforcement for the Audio + Haptics services
/// introduced in Story 8.1.
void main() {
  List<File> findDartFiles(Directory dir) {
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  String norm(String path) => path.replaceAll(r'\', '/');

  group('AudioService import boundary', () {
    test('lib/services/audio_service.dart exists and is framework-light', () {
      final svc = File('lib/services/audio_service.dart');
      expect(svc.existsSync(), isTrue);
      final text = svc.readAsStringSync();
      expect(text, isNot(contains('package:flutter_riverpod')));
      expect(text, isNot(contains('package:global_domination/ui/')));
      expect(text, isNot(contains('package:global_domination/data/')));
      expect(text, isNot(contains('package:global_domination/providers/')));
      expect(text, isNot(contains("import 'package:audioplayers/")));
      expect(text, isNot(contains("import 'package:flutter/")));
    });
  });

  group('HapticsService import boundary', () {
    test('lib/services/haptics_service.dart exists and is framework-light', () {
      final svc = File('lib/services/haptics_service.dart');
      expect(svc.existsSync(), isTrue);
      final text = svc.readAsStringSync();
      expect(text, isNot(contains('package:flutter_riverpod')));
      expect(text, isNot(contains('package:global_domination/ui/')));
      expect(text, isNot(contains('package:global_domination/data/')));
      expect(text, isNot(contains('package:global_domination/providers/')));
      expect(text, isNot(contains("import 'package:flutter/services.dart")));
    });
  });

  group('audioplayers exclusivity', () {
    test("only lib/services/audio_backend.dart imports audioplayers", () {
      const allow = {'lib/services/audio_backend.dart'};
      final files = findDartFiles(Directory('lib'));
      final pattern = RegExp(r'''import\s+['"]package:audioplayers/''');
      final violations = <String>[];
      for (final f in files) {
        final path = norm(f.path);
        final rel = path.substring(path.indexOf('lib/'));
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//')) continue;
          if (pattern.hasMatch(line) && !allow.contains(rel)) {
            violations.add('$rel:${i + 1}: $line');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            "audioplayers import is restricted to lib/services/audio_backend.dart.\n"
            'Violations: ${violations.join('\n')}',
      );
    });
  });

  group('HapticFeedback exclusivity', () {
    test("only lib/services/haptics_backend.dart calls HapticFeedback", () {
      const allow = {'lib/services/haptics_backend.dart'};
      final files = findDartFiles(Directory('lib'));
      final pattern = RegExp(
        r'\bHapticFeedback\.(lightImpact|mediumImpact|heavyImpact|selectionClick|vibrate)\b',
      );
      final violations = <String>[];
      for (final f in files) {
        final path = norm(f.path);
        final rel = path.substring(path.indexOf('lib/'));
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//')) continue;
          if (pattern.hasMatch(line) && !allow.contains(rel)) {
            violations.add('$rel:${i + 1}: $line');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            "HapticFeedback calls are restricted to lib/services/haptics_backend.dart.\n"
            'Violations: ${violations.join('\n')}',
      );
    });
  });

  group('exhaustive switch coverage', () {
    test('AudioService and HapticsService switch every GameEvent variant', () {
      final eventFile = File('lib/game/game_event.dart');
      expect(eventFile.existsSync(), isTrue);
      final eventText = eventFile.readAsStringSync();
      final variantPattern = RegExp(r'final class (\w+) extends GameEvent');
      final variants = variantPattern
          .allMatches(eventText)
          .map((m) => m.group(1)!)
          .toSet();
      expect(variants.length, greaterThanOrEqualTo(19));

      for (final servicePath in const [
        'lib/services/audio_service.dart',
        'lib/services/haptics_service.dart',
      ]) {
        final text = File(servicePath).readAsStringSync();
        final caseNames = RegExp(
          r'\bcase (\w+)\s*\(',
        ).allMatches(text).map((m) => m.group(1)!).toSet();
        final missing = variants.difference(caseNames);
        expect(
          missing,
          isEmpty,
          reason:
              '$servicePath is missing switch arms for: ${missing.join(', ')}',
        );
      }
    });
  });
}
