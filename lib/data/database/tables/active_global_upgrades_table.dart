import 'package:drift/drift.dart';

@DataClassName('ActiveGlobalUpgradeRow')
class ActiveGlobalUpgrades extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
