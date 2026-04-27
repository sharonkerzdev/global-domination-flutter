import 'package:drift/drift.dart';

import '../converters/decimal_converter.dart';

@DataClassName('CountryRow')
class Countries extends Table {
  TextColumn get id => text()();

  BoolColumn get unlocked => boolean()();

  IntColumn get ipLevel => integer()();

  /// Persisted as [LeaderTier.name] in the mapper (no table-level converter).
  TextColumn get leaderTier => text()();

  TextColumn get bankedInfluence => text().map(const DecimalConverter())();

  DateTimeColumn get lastCollectedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
