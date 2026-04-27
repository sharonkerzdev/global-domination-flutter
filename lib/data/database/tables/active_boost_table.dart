import 'package:drift/drift.dart';

import '../converters/decimal_converter.dart';

@DataClassName('ActiveBoostRow')
class ActiveBoost extends Table {
  IntColumn get singletonId => integer().withDefault(const Constant(0))();

  TextColumn get multiplier => text().map(const DecimalConverter())();

  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};

  @override
  List<String> get customConstraints => ['CHECK (singleton_id = 0)'];
}
