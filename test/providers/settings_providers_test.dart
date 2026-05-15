import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/repositories/settings_repository.dart';
import 'package:global_domination/providers/database_providers.dart';

void main() {
  group('settings providers', () {
    test('bool providers use defaults before first stream value', () {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SettingsRepository(db);
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      expect(container.read(soundEnabledProvider), isTrue);
      expect(container.read(hapticsEnabledProvider), isTrue);
      expect(container.read(notificationsEnabledProvider), isFalse);
    });

    test('bool providers follow repository writes', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final repo = SettingsRepository(db);
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        appSettingsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await repo.setSoundEnabled(false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(soundEnabledProvider), isFalse);
    });
  });
}
