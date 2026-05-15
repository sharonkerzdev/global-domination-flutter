import 'package:drift/drift.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/repositories/app_settings.dart';
import 'package:logging/logging.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;
  final _log = Logger('SettingsRepository');

  Stream<AppSettings> watchSettings() {
    return (_db.select(_db.settings)..where((t) => t.singletonId.equals(0)))
        .watchSingleOrNull()
        .map(_rowToAppSettings);
  }

  Future<AppSettings> readSettings() async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.singletonId.equals(0))).getSingleOrNull();
    return _rowToAppSettings(row);
  }

  AppSettings _rowToAppSettings(SettingsRow? row) {
    if (row == null) {
      return AppSettings.defaults;
    }
    return AppSettings(
      soundEnabled: row.soundEnabled,
      hapticsEnabled: row.hapticsEnabled,
      notificationsEnabled: row.notificationsEnabled,
    );
  }

  Future<void> setSoundEnabled(bool enabled) =>
      _upsertPartial(soundEnabled: enabled);

  Future<void> setHapticsEnabled(bool enabled) =>
      _upsertPartial(hapticsEnabled: enabled);

  Future<void> setNotificationsEnabled(bool enabled) =>
      _upsertPartial(notificationsEnabled: enabled);

  Future<void> _upsertPartial({
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? notificationsEnabled,
  }) async {
    try {
      await _db.transaction(() async {
        final current = await readSettings();
        final next = AppSettings(
          soundEnabled: soundEnabled ?? current.soundEnabled,
          hapticsEnabled: hapticsEnabled ?? current.hapticsEnabled,
          notificationsEnabled:
              notificationsEnabled ?? current.notificationsEnabled,
        );
        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion(
                singletonId: const Value(0),
                soundEnabled: Value(next.soundEnabled),
                hapticsEnabled: Value(next.hapticsEnabled),
                notificationsEnabled: Value(next.notificationsEnabled),
              ),
            );
      });
    } catch (e, s) {
      _log.severe('Failed to persist settings', e, s);
      rethrow;
    }
  }
}
