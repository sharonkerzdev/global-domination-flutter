import 'package:drift/drift.dart';

import '../converters/decimal_converter.dart';

@DataClassName('MetaRow')
class Meta extends Table {
  IntColumn get singletonId => integer().withDefault(const Constant(0))();

  IntColumn get schemaVersion => integer()();

  DateTimeColumn get lastSavedAt => dateTime()();

  TextColumn get totalInfluence => text().map(const DecimalConverter())();

  TextColumn get totalIntel => text().map(const DecimalConverter())();

  TextColumn get goldenOpportunityMultiplier =>
      text().map(const DecimalConverter())();

  TextColumn get boostMultiplier => text().map(const DecimalConverter())();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};

  @override
  List<String> get customConstraints => ['CHECK (singleton_id = 0)'];
}
