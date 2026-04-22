import 'package:drift/drift.dart';

import '../converters/crash_log_level_converter.dart';

@DataClassName('CrashLogRow')
class CrashLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get timestamp => dateTime()();

  TextColumn get level => text().map(const CrashLogLevelConverter())();

  TextColumn get tag => text()();

  TextColumn get message => text()();

  TextColumn get stackTrace => text().nullable()();
}
