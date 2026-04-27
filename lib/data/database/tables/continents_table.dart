import 'package:drift/drift.dart';

@DataClassName('ContinentRow')
class Continents extends Table {
  TextColumn get id => text()();

  BoolColumn get unlocked => boolean()();

  BoolColumn get completed => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
