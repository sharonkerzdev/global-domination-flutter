import 'package:drift/drift.dart';

import 'continents_table.dart';

@DataClassName('ContinentMilestoneRow')
class ContinentMilestones extends Table {
  TextColumn get continentId =>
      text().references(Continents, #id, onDelete: KeyAction.cascade)();

  IntColumn get milestone => integer()();

  @override
  Set<Column<Object>> get primaryKey => {continentId, milestone};
}
