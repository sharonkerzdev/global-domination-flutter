import 'package:drift/drift.dart';

import '../converters/decimal_converter.dart';

@DataClassName('ActiveMissionRow')
class ActiveMissions extends Table {
  IntColumn get slot => integer()();

  TextColumn get id => text()();

  IntColumn get progress => integer()();

  IntColumn get target => integer()();

  TextColumn get rewardIntel => text().map(const DecimalConverter())();

  @override
  Set<Column<Object>> get primaryKey => {slot};
}
