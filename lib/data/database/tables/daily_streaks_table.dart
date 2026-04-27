import 'package:drift/drift.dart';

@DataClassName('DailyStreakRow')
class DailyStreaks extends Table {
  IntColumn get singletonId => integer().withDefault(const Constant(0))();

  IntColumn get day => integer()();

  DateTimeColumn get lastClaimDate => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};

  @override
  List<String> get customConstraints => ['CHECK (singleton_id = 0)'];
}
