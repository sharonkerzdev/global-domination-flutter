import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final supportDir = Directory.systemTemp.createTempSync(
    'global_domination_google_fonts_test_',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return supportDir.path;
          }
          return null;
        },
      );
  google_fonts_base.httpClient = _FixtureGoogleFontsClient();
  await testMain();
}

class _FixtureGoogleFontsClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final filename = request.url.pathSegments.last;
    final hash = filename.endsWith('.ttf')
        ? filename.substring(0, filename.length - '.ttf'.length)
        : filename;
    final file = File('test/fixtures/google_fonts/$hash.ttf');
    if (!file.existsSync()) {
      return http.StreamedResponse(
        const Stream<List<int>>.empty(),
        404,
        request: request,
      );
    }

    final bytes = await file.readAsBytes();
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
    );
  }
}
