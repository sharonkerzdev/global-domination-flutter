import 'package:drift/drift.dart';

@DataClassName('SettingsRow')
class Settings extends Table {
  IntColumn get singletonId => integer().withDefault(const Constant(0))();

  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();

  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};

  @override
  List<String> get customConstraints => ['CHECK (singleton_id = 0)'];
}
