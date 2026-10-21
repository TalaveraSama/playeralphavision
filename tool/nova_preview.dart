import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/nova_fixture.dart';

/// Herramienta de capturas del diseño NOVA (no forma parte de `flutter test`).
///
///   flutter test tool/nova_preview.dart --update-goldens
///
/// Deja los PNG en `doc/preview/` para revisar el diseño sin abrir la app.
void main() {
  late HttpServer server;
  late String serverUrl;

  setUp(() async {
    HttpOverrides.global = null;
    server = await startFakeXtream();
    serverUrl = 'http://127.0.0.1:${server.port}';
  });

  tearDown(() async {
    await server.close(force: true);
  });

  testWidgets('captura de escritorio', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ({dynamic config, dynamic app}) result =
        await pumpNovaApp(tester, serverUrl: serverUrl);
    await settleFrames(tester, ms: 700);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../doc/preview/nova_inicio_escritorio.png'),
    );

    await tester.runAsync(() => result.app.logout());
    await tester.pump();
  });

  testWidgets('captura de móvil', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ({dynamic config, dynamic app}) result =
        await pumpNovaApp(tester, serverUrl: serverUrl);
    await settleFrames(tester, ms: 700);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../doc/preview/nova_inicio_movil.png'),
    );

    await tester.runAsync(() => result.app.logout());
    await tester.pump();
  });

  testWidgets('captura de la ficha de serie', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ({dynamic config, dynamic app}) result =
        await pumpNovaApp(tester, serverUrl: serverUrl);
    await settleFrames(tester, ms: 700);

    await tester.tap(find.text('Ver ahora'));
    await tester.pump();
    // La transición de ruta necesita tiempo del reloj de la prueba.
    await tester.pump(const Duration(milliseconds: 500));
    await settleFrames(tester, ms: 700);

    expect(find.text('Episodios'), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../doc/preview/nova_ficha_serie.png'),
    );

    await tester.runAsync(() => result.app.logout());
    await tester.pump();
  });
}
