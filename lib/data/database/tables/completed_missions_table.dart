import 'package:drift/drift.dart';

@DataClassName('CompletedMissionRow')
class CompletedMissions extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
