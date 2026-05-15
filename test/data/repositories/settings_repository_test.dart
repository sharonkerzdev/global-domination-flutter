import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/repositories/app_settings.dart';
import 'package:global_domination/data/repositories/settings_repository.dart';

void main() {
  group('SettingsRepository', () {
    test('absent row maps to defaults', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final repo = SettingsRepository(db);
      expect(await repo.readSettings(), AppSettings.defaults);
    });

    test('setSoundEnabled persists and preserves other flags', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final repo = SettingsRepository(db);
      await repo.setSoundEnabled(false);
      expect(
        await repo.readSettings(),
        AppSettings.defaults.copyWith(soundEnabled: false),
      );
      await repo.setHapticsEnabled(false);
      expect(
        await repo.readSettings(),
        const AppSettings(
          soundEnabled: false,
          hapticsEnabled: false,
          notificationsEnabled: false,
        ),
      );
    });

    test('setNotificationsEnabled true round-trips', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final repo = SettingsRepository(db);
      await repo.setNotificationsEnabled(true);
      expect(
        await repo.readSettings(),
        AppSettings.defaults.copyWith(notificationsEnabled: true),
      );
    });

    test('watch emits defaults then updates', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final repo = SettingsRepository(db);
      final values = <AppSettings>[];
      final sub = repo.watchSettings().listen(values.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);
      await repo.setSoundEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(values.first, AppSettings.defaults);
      expect(values.last.soundEnabled, isFalse);
    });

    test('repeated writes keep a single row', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final repo = SettingsRepository(db);
      await repo.setSoundEnabled(false);
      await repo.setSoundEnabled(true);
      await repo.setHapticsEnabled(false);
      final rows = await db.select(db.settings).get();
      expect(rows, hasLength(1));
    });
  });
}
