import 'package:drift/drift.dart';

@DataClassName('ActiveGoldenEffectRow')
class ActiveGoldenEffect extends Table {
  IntColumn get singletonId => integer().withDefault(const Constant(0))();

  TextColumn get goldenId => text()();

  IntColumn get multiplier => integer()();

  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {singletonId};

  @override
  List<String> get customConstraints => ['CHECK (singleton_id = 0)'];
}
