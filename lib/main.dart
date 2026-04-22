import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/data_providers.dart';
import 'services/crash_reporter.dart';
import 'ui/fallback_error_widget.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        CrashReporter.instance.reportFlutterError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        CrashReporter.instance.reportPlatformError(error, stack);
        return true;
      };

      ErrorWidget.builder = (FlutterErrorDetails details) {
        return const FallbackErrorWidget();
      };

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Manually construct a ProviderContainer so we can attach CrashReporter
      // before the first frame. Only lib/main.dart contains boot-time global setup.
      final container = ProviderContainer();
      CrashReporter.instance.attach(container.read(crashLogRepositoryProvider));

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const GlobalDominationApp(),
        ),
      );
    },
    (error, stack) {
      CrashReporter.instance.reportZonedError(error, stack);
    },
  );
}
