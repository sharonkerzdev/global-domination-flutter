import 'package:drift/drift.dart';

// No FK to countries: country may be re-locked between spawn and claim; reducer owns that invariant.
@DataClassName('ActiveGoldenRow')
class ActiveGoldens extends Table {
  TextColumn get id => text()();

  TextColumn get countryId => text()();

  IntColumn get multiplier => integer()();

  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
