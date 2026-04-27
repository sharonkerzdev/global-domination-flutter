import 'package:drift/drift.dart';

@DataClassName('EarnedAchievementRow')
class EarnedAchievements extends Table {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
