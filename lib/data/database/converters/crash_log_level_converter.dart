import 'package:drift/drift.dart';

import '../../repositories/crash_log_entry.dart';

class CrashLogLevelConverter extends TypeConverter<CrashLogLevel, String> {
  const CrashLogLevelConverter();

  @override
  CrashLogLevel fromSql(String fromDb) => CrashLogLevel.values.firstWhere(
    (e) => e.name == fromDb,
    // Fall back to severe so the Support screen stays readable if the DB ever
    // contains a stale/unknown enum name (forward compat, corruption, manual
    // DB inspection). Reading must never throw — the whole point of this
    // screen is to surface problems, not add more.
    orElse: () => CrashLogLevel.severe,
  );

  @override
  String toSql(CrashLogLevel value) => value.name;
}
