import 'package:global_domination/data/repositories/crash_log_entry.dart';
import 'package:test/test.dart';

void main() {
  group('CrashLogLevel', () {
    test('has expected values', () {
      expect(CrashLogLevel.values, hasLength(3));
      expect(CrashLogLevel.values, contains(CrashLogLevel.severe));
      expect(CrashLogLevel.values, contains(CrashLogLevel.warning));
      expect(CrashLogLevel.values, contains(CrashLogLevel.info));
    });

    test('name matches enum constant name', () {
      expect(CrashLogLevel.severe.name, 'severe');
      expect(CrashLogLevel.warning.name, 'warning');
      expect(CrashLogLevel.info.name, 'info');
    });
  });

  group('CrashLogEntry', () {
    final timestamp = DateTime(2026, 4, 21, 12, 0, 0);

    final entry = CrashLogEntry(
      timestamp: timestamp,
      level: CrashLogLevel.severe,
      tag: 'FlutterError',
      message: 'Test error',
      stackTrace: '#0 main (main.dart:1)',
    );

    final entryNoStack = CrashLogEntry(
      timestamp: timestamp,
      level: CrashLogLevel.warning,
      tag: 'Tag',
      message: 'Warning msg',
    );

    test('construction holds all fields', () {
      expect(entry.timestamp, timestamp);
      expect(entry.level, CrashLogLevel.severe);
      expect(entry.tag, 'FlutterError');
      expect(entry.message, 'Test error');
      expect(entry.stackTrace, '#0 main (main.dart:1)');
    });

    test('stackTrace defaults to null', () {
      expect(entryNoStack.stackTrace, isNull);
    });

    test('equality: identical instances are equal', () {
      final same = CrashLogEntry(
        timestamp: timestamp,
        level: CrashLogLevel.severe,
        tag: 'FlutterError',
        message: 'Test error',
        stackTrace: '#0 main (main.dart:1)',
      );
      expect(entry, equals(same));
    });

    test('equality: different message → not equal', () {
      final different = CrashLogEntry(
        timestamp: timestamp,
        level: CrashLogLevel.severe,
        tag: 'FlutterError',
        message: 'Different',
        stackTrace: '#0 main (main.dart:1)',
      );
      expect(entry, isNot(equals(different)));
    });

    test('equality: different level → not equal', () {
      final different = CrashLogEntry(
        timestamp: timestamp,
        level: CrashLogLevel.warning,
        tag: 'FlutterError',
        message: 'Test error',
        stackTrace: '#0 main (main.dart:1)',
      );
      expect(entry, isNot(equals(different)));
    });

    test('hashCode: equal objects have same hashCode', () {
      final same = CrashLogEntry(
        timestamp: timestamp,
        level: CrashLogLevel.severe,
        tag: 'FlutterError',
        message: 'Test error',
        stackTrace: '#0 main (main.dart:1)',
      );
      expect(entry.hashCode, equals(same.hashCode));
    });

    test('hashCode: different objects likely have different hashCode', () {
      expect(entry.hashCode, isNot(equals(entryNoStack.hashCode)));
    });

    test('toString contains all fields', () {
      final str = entry.toString();
      expect(str, contains('CrashLogEntry'));
      expect(str, contains('FlutterError'));
      expect(str, contains('Test error'));
      expect(str, contains('severe'));
    });
  });
}
