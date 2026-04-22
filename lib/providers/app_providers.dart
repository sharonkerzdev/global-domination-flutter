import 'package:riverpod/riverpod.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/services/content_registry_loader.dart';

final contentRegistryProvider = FutureProvider<ContentRegistry>(
  (ref) async => ContentRegistryLoader.loadFromAssets(),
);
