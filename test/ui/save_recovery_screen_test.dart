import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';
import 'package:global_domination/ui/save_recovery_screen.dart';

void main() {
  String? clipboardPayload;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    clipboardPayload = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            clipboardPayload = args['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpRecovery(
    WidgetTester tester,
    Object error, {
    StackTrace? stackTrace,
    SaveRecoveryBackupExists? backupExists,
    SaveRecoveryRestoreFromBackup? restoreFromBackup,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: SaveRecoveryScreen(
          error: error,
          stackTrace: stackTrace,
          backupExists: backupExists ?? (_) async => false,
          restoreFromBackup: restoreFromBackup,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('renders error and hides restore when backup is missing', (
    tester,
  ) async {
    await pumpRecovery(
      tester,
      const MigrationFailureException(
        fromVersion: 2,
        toVersion: 3,
        cause: 'synthetic',
      ),
    );

    expect(find.text('Database Recovery'), findsOneWidget);
    expect(find.textContaining('synthetic'), findsOneWidget);
    expect(find.byKey(const ValueKey('saveRecoveryRestore')), findsNothing);
    expect(find.text('Start Fresh'), findsOneWidget);
    expect(find.text('Copy Crash Log'), findsOneWidget);
  });

  testWidgets('shows restore when schema backup exists', (tester) async {
    await pumpRecovery(
      tester,
      const MigrationFailureException(
        fromVersion: 2,
        toVersion: 3,
        cause: 'synthetic',
      ),
      backupExists: (_) async => true,
    );

    expect(find.byKey(const ValueKey('saveRecoveryRestore')), findsOneWidget);
    expect(find.text('Restore from backup v2'), findsOneWidget);
  });

  testWidgets('restore button calls restore action with migration versions', (
    tester,
  ) async {
    var restoredFrom = 0;
    var restoredTo = 0;

    await pumpRecovery(
      tester,
      const MigrationFailureException(
        fromVersion: 2,
        toVersion: 3,
        cause: 'synthetic',
      ),
      backupExists: (_) async => true,
      restoreFromBackup:
          ({required int fromVersion, required int toVersion}) async {
            restoredFrom = fromVersion;
            restoredTo = toVersion;
          },
    );
    await tester.tap(find.byKey(const ValueKey('saveRecoveryRestore')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(restoredFrom, 2);
    expect(restoredTo, 3);
  });

  testWidgets('start fresh CTA shows Story 6-6 placeholder', (tester) async {
    await pumpRecovery(tester, Exception('boot failure'));

    await tester.tap(find.text('Start Fresh'));
    await tester.pump();

    expect(find.text('Start Fresh available in Story 6-6'), findsOneWidget);
  });

  testWidgets('copy crash log writes error and stack trace to clipboard', (
    tester,
  ) async {
    final stackTrace = StackTrace.fromString('stack-line');
    await pumpRecovery(
      tester,
      const MigrationFailureException(
        fromVersion: 1,
        toVersion: 3,
        cause: 'copy me',
      ),
      stackTrace: stackTrace,
    );

    await tester.tap(find.text('Copy Crash Log'));
    await tester.pump();

    expect(clipboardPayload, contains('copy me'));
    expect(clipboardPayload, contains('stack-line'));
    expect(find.text('Copied'), findsOneWidget);
  });
}
