import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/repositories/crash_log_repository.dart';
import 'package:global_domination/data/repositories/settings_repository.dart';
import 'package:global_domination/providers/database_providers.dart';
import 'package:global_domination/ui/debug/support_screen.dart';
import 'package:global_domination/ui/features/settings/settings_modal.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

import 'package:drift/native.dart';

Future<void> _disposeSheetDb(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  await db.close();
}

void main() {
  group('SettingsModal', () {
    Future<AppDatabase> openMemoryDb() async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      return db;
    }

    Future<AppDatabase> pumpSheet(
      WidgetTester tester, {
      required AppDatabase db,
    }) async {
      final repo = SettingsRepository(db);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(repo),
            crashLogRepositoryProvider.overrideWithValue(
              CrashLogRepository(db),
            ),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showSettingsModal(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return db;
    }

    testWidgets('toggles persist across reopen', (tester) async {
      final db = await openMemoryDb();
      try {
        await pumpSheet(tester, db: db);
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final switches = tester
            .widgetList<Switch>(find.byType(Switch))
            .toList();
        expect(switches.first.value, isFalse);
      } finally {
        await _disposeSheetDb(tester, db);
      }
    });

    testWidgets('credits tap opens dialog', (tester) async {
      final db = await openMemoryDb();
      try {
        await pumpSheet(tester, db: db);
        await tester.tap(find.textContaining('Tap for credits'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Thank you for playing.'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      } finally {
        await _disposeSheetDb(tester, db);
      }
    });

    testWidgets('short pointer hold does not open support', (tester) async {
      final db = await openMemoryDb();
      try {
        await pumpSheet(tester, db: db);
        final center = tester.getCenter(
          find.byKey(const Key('settingsCreditsSupportRow')),
        );
        final g = await tester.startGesture(center);
        await tester.pump(const Duration(seconds: 2));
        await g.up();
        await tester.pumpAndSettle();
        expect(find.byType(SupportScreen), findsNothing);
      } finally {
        await _disposeSheetDb(tester, db);
      }
    });

    testWidgets('pointer movement cancels support hold', (tester) async {
      final db = await openMemoryDb();
      try {
        await pumpSheet(tester, db: db);
        final center = tester.getCenter(
          find.byKey(const Key('settingsCreditsSupportRow')),
        );
        final g = await tester.startGesture(center);
        await g.moveBy(const Offset(60, 0));
        await tester.pump(const Duration(seconds: 5));
        await g.up();
        await tester.pumpAndSettle();
        expect(find.byType(SupportScreen), findsNothing);
      } finally {
        await _disposeSheetDb(tester, db);
      }
    });

    testWidgets('five second hold opens support and closes sheet', (
      tester,
    ) async {
      final db = await openMemoryDb();
      try {
        await pumpSheet(tester, db: db);
        final center = tester.getCenter(
          find.byKey(const Key('settingsCreditsSupportRow')),
        );
        final g = await tester.startGesture(center);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await g.up();
        await tester.pumpAndSettle();
        expect(find.byType(SupportScreen), findsOneWidget);
        expect(find.byType(SettingsModal), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(SupportScreen), findsNothing);
        expect(find.text('open'), findsOneWidget);
      } finally {
        await _disposeSheetDb(tester, db);
      }
    });

    testWidgets('support opens from a nested navigator without popping it', (
      tester,
    ) async {
      final db = await openMemoryDb();
      try {
        final repo = SettingsRepository(db);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              settingsRepositoryProvider.overrideWithValue(repo),
              crashLogRepositoryProvider.overrideWithValue(
                CrashLogRepository(db),
              ),
            ],
            child: MaterialApp(
              theme: appTheme(),
              home: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (nestedContext) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => showSettingsModal(nestedContext),
                        child: const Text('open nested'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open nested'));
        await tester.pumpAndSettle();
        final center = tester.getCenter(
          find.byKey(const Key('settingsCreditsSupportRow')),
        );
        final g = await tester.startGesture(center);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await g.up();
        await tester.pumpAndSettle();
        expect(find.byType(SupportScreen), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('open nested'), findsOneWidget);
      } finally {
        await _disposeSheetDb(tester, db);
      }
    });

    testWidgets('semantic long press opens support', (tester) async {
      final db = await openMemoryDb();
      SemanticsHandle? sem;
      try {
        await pumpSheet(tester, db: db);
        sem = tester.ensureSemantics();
        tester.semantics.longPress(find.semantics.byLabel('Credits'));
        await tester.pumpAndSettle();
        expect(find.byType(SupportScreen), findsOneWidget);
      } finally {
        sem?.dispose();
        await _disposeSheetDb(tester, db);
      }
    });

    testWidgets('sheet leaves bottom navigation visible behind the scrim', (
      tester,
    ) async {
      final db = await openMemoryDb();
      try {
        final repo = SettingsRepository(db);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              settingsRepositoryProvider.overrideWithValue(repo),
              crashLogRepositoryProvider.overrideWithValue(
                CrashLogRepository(db),
              ),
            ],
            child: MaterialApp(
              theme: appTheme(),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showSettingsModal(context),
                    child: const Text('open'),
                  ),
                ),
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: 0,
                  onTap: (_) {},
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.public),
                      label: 'Map',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final sheetRect = tester.getRect(find.byType(SettingsModal));
        final navRect = tester.getRect(find.byType(BottomNavigationBar));
        expect(sheetRect.bottom, lessThanOrEqualTo(navRect.top + 0.1));
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      } finally {
        await _disposeSheetDb(tester, db);
      }
    });

    testWidgets('narrow width and large text scale do not overflow', (
      tester,
    ) async {
      final db = await openMemoryDb();
      try {
        final repo = SettingsRepository(db);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              settingsRepositoryProvider.overrideWithValue(repo),
              crashLogRepositoryProvider.overrideWithValue(
                CrashLogRepository(db),
              ),
            ],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(1.6),
              ),
              child: MaterialApp(
                theme: appTheme(),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showSettingsModal(context),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await _disposeSheetDb(tester, db);
      }
    });
  });
}
