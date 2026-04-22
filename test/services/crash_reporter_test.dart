import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/repositories/crash_log_entry.dart';
import 'package:global_domination/data/repositories/crash_log_repository.dart';
import 'package:global_domination/services/crash_reporter.dart';
import 'package:logging/logging.dart';

// Inline fake — only used here, no separate helper needed.
// Extends CrashLogRepository with an in-memory DB (never used since all methods
// are overridden).
class _FakeCrashLogRepository extends CrashLogRepository {
  _FakeCrashLogRepository(super.db);

  final List<CrashLogEntry> appended = [];
  bool shouldThrow = false;

  @override
  Future<void> append(CrashLogEntry entry) async {
    if (shouldThrow) throw Exception('fake db error');
    appended.add(entry);
  }

  @override
  Future<List<CrashLogEntry>> readAllNewestFirst() async =>
      List.unmodifiable(appended);

  @override
  Future<void> clearAll() async => appended.clear();
}

AppDatabase _memDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('CrashReporter', () {
    setUp(() {
      // Reset singleton state between tests so attach/detach doesn't bleed over.
      CrashReporter.instance.reset();
    });

    tearDown(() {
      CrashReporter.instance.reset();
    });

    test('instance returns the same singleton', () {
      final a = CrashReporter.instance;
      final b = CrashReporter.instance;
      expect(identical(a, b), isTrue);
    });

    test('reportFlutterError does not throw', () {
      final details = FlutterErrorDetails(
        exception: Exception('test flutter error'),
        stack: StackTrace.current,
      );
      expect(
        () => CrashReporter.instance.reportFlutterError(details),
        returnsNormally,
      );
    });

    test('reportPlatformError does not throw', () {
      expect(
        () => CrashReporter.instance.reportPlatformError(
          Exception('test platform error'),
          StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('reportZonedError does not throw', () {
      expect(
        () => CrashReporter.instance.reportZonedError(
          Exception('test zoned error'),
          StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('reportFlutterError logs to CrashReporter logger', () {
      final records = <LogRecord>[];
      Logger('CrashReporter').onRecord.listen(records.add);

      final details = FlutterErrorDetails(
        exception: Exception('logged flutter error'),
        stack: StackTrace.current,
      );
      CrashReporter.instance.reportFlutterError(details);

      expect(records, hasLength(1));
      expect(records.first.level, Level.SEVERE);
      expect(records.first.message, contains('Flutter error'));
    });

    test('reportPlatformError logs to CrashReporter logger', () {
      final records = <LogRecord>[];
      Logger('CrashReporter').onRecord.listen(records.add);

      CrashReporter.instance.reportPlatformError(
        Exception('logged platform error'),
        StackTrace.current,
      );

      expect(records, hasLength(1));
      expect(records.first.level, Level.SEVERE);
      expect(records.first.message, contains('Platform error'));
    });

    test('reportZonedError logs to CrashReporter logger', () {
      final records = <LogRecord>[];
      Logger('CrashReporter').onRecord.listen(records.add);

      CrashReporter.instance.reportZonedError(
        Exception('logged zoned error'),
        StackTrace.current,
      );

      expect(records, hasLength(1));
      expect(records.first.level, Level.SEVERE);
      expect(records.first.message, contains('Zoned error'));
    });

    test(
      'without attach: reportPlatformError does not throw and entries are not persisted',
      () async {
        // No attach called — _repo is null
        expect(
          () => CrashReporter.instance.reportPlatformError(
            Exception('no repo'),
            StackTrace.current,
          ),
          returnsNormally,
        );
        // Give any fire-and-forget async work a microtask to settle
        await Future<void>.delayed(Duration.zero);
        // No way to assert "not persisted" except that no exception was thrown
        // and no fake repo was attached — if it tried to use null it would throw.
      },
    );

    test(
      'after attach: reportPlatformError persists exactly one entry',
      () async {
        final fake = _FakeCrashLogRepository(_memDb());
        CrashReporter.instance.attach(fake);

        CrashReporter.instance.reportPlatformError(
          Exception('the error x'),
          StackTrace.current,
        );

        // Allow fire-and-forget async to complete
        await Future<void>.delayed(Duration.zero);

        expect(fake.appended, hasLength(1));
        final entry = fake.appended.first;
        expect(entry.level, CrashLogLevel.severe);
        expect(entry.tag, 'PlatformError');
        expect(entry.message, contains('the error x'));
      },
    );

    test(
      'after attach: reportFlutterError persists entry with correct tag',
      () async {
        final fake = _FakeCrashLogRepository(_memDb());
        CrashReporter.instance.attach(fake);

        CrashReporter.instance.reportFlutterError(
          FlutterErrorDetails(
            exception: Exception('flutter err'),
            stack: StackTrace.current,
          ),
        );

        await Future<void>.delayed(Duration.zero);

        expect(fake.appended, hasLength(1));
        expect(fake.appended.first.tag, 'FlutterError');
      },
    );

    test(
      'after attach: reportZonedError persists entry with correct tag',
      () async {
        final fake = _FakeCrashLogRepository(_memDb());
        CrashReporter.instance.attach(fake);

        CrashReporter.instance.reportZonedError(
          Exception('zone err'),
          StackTrace.current,
        );

        await Future<void>.delayed(Duration.zero);

        expect(fake.appended, hasLength(1));
        expect(fake.appended.first.tag, 'ZonedError');
      },
    );

    test(
      'if append throws, reportPlatformError still does not throw (AC #4)',
      () async {
        final fake = _FakeCrashLogRepository(_memDb())..shouldThrow = true;
        CrashReporter.instance.attach(fake);

        expect(
          () => CrashReporter.instance.reportPlatformError(
            Exception('fail persist'),
            StackTrace.current,
          ),
          returnsNormally,
        );

        await Future<void>.delayed(Duration.zero);
        // No exception propagated — persistence failure swallowed
      },
    );

    test('reset() clears the attached repository', () async {
      final fake = _FakeCrashLogRepository(_memDb());
      CrashReporter.instance.attach(fake);
      CrashReporter.instance.reset();

      CrashReporter.instance.reportPlatformError(
        Exception('after reset'),
        StackTrace.current,
      );
      await Future<void>.delayed(Duration.zero);

      expect(fake.appended, isEmpty);
    });
  });
}
