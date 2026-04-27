import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/database_providers.dart';
import 'package:global_domination/providers/offline_catchup_providers.dart';

import '../helpers/test_content_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test(
    'offlineCatchupBootProvider completes with memory db and test content',
    () async {
      final content = testMapperContentRegistry();
      late AppDatabase db;
      final container = ProviderContainer(
        overrides: [
          appDatabaseFactoryProvider.overrideWithValue(() {
            db = AppDatabase(NativeDatabase.memory());
            return db;
          }),
          contentRegistryProvider.overrideWith((ref) async => content),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() async => db.close());

      await container.read(databaseBootstrapProvider.future);
      await container.read(offlineCatchupBootProvider.future);
    },
  );
}
