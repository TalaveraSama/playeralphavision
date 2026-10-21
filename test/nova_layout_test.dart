import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/config/app_config.dart';
import 'package:xtream_player/core/state/app_state.dart';

import 'support/nova_fixture.dart';

/// Pruebas del diseño NOVA: portada de descubrimiento, barra superior en
/// pantallas anchas, barra inferior en el móvil y ficha de serie con pestañas.
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

  test('el diseño nova se declara y se lee del JSON', () {
    final ThemeSpec spec = ThemeSpec.fromJson(<String, dynamic>{
      'id': 'nova',
      'name': 'NOVA',
      'layout': 'nova',
    });

    expect(spec.layout, CatalogLayout.nova);
    expect(spec.isNova, isTrue);
    expect(spec.isRows, isFalse);
    expect(spec.isGrid, isFalse);
    expect(spec.layoutLabel, contains('NOVA'));
    expect(spec.toJson()['layout'], 'nova');
  });

  testWidgets('pantalla ancha: barra superior, en vivo y tendencias',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ({dynamic config, AppState app}) result =
        await pumpNovaApp(tester, serverUrl: serverUrl);
    final AppState app = result.app;
    expect(app.isLoggedIn, isTrue, reason: 'lastError=${app.lastError}');
    await settleFrames(tester, ms: 700);

    // Barra de navegación superior del diseño.
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Series'), findsWidgets);
    expect(find.text('Películas'), findsWidgets);
    expect(find.text('Deportes'), findsWidgets);
    expect(find.text('Infantil'), findsWidgets);
    // La barra inferior del móvil no aparece en pantallas anchas.
    expect(find.text('Explorar'), findsNothing);

    // Portada: héroe, «Continuar viendo», «En vivo ahora» y «Tendencias».
    expect(find.text('NOVA'), findsWidgets);
    expect(find.text('ORIGINAL NOVA'), findsOneWidget);
    expect(find.text('Continuar viendo'), findsOneWidget);
    expect(find.text('Ver todo'), findsWidgets);
    expect(find.text('En vivo ahora'), findsWidgets);
    expect(find.text('Tendencias en tu país'), findsOneWidget);
    expect(find.text('EN VIVO'), findsWidgets);
    expect(find.text('Serie de prueba'), findsWidgets);

    await tester.runAsync(() => app.logout());
    await tester.pump();
  });

  testWidgets('móvil: barra inferior, filtros y ficha con pestañas',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ({dynamic config, AppState app}) result =
        await pumpNovaApp(tester, serverUrl: serverUrl);
    final AppState app = result.app;
    expect(app.isLoggedIn, isTrue, reason: 'lastError=${app.lastError}');
    await settleFrames(tester, ms: 700);

    // Barra inferior con los cinco destinos del diseño.
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Mi lista'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);

    // Filtros de la portada compacta.
    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('En vivo'), findsWidgets);

    // Héroe de la serie destacada con su botón.
    expect(find.text('Ver ahora'), findsOneWidget);

    // Abrir la ficha de la serie: pestañas del diseño.
    await tester.tap(find.text('Ver ahora'));
    await settleFrames(tester, ms: 700);

    expect(find.text('Episodios'), findsOneWidget);
    expect(find.text('Más como esto'), findsOneWidget);
    expect(find.text('Detalles'), findsOneWidget);
    // La insignia también existe en el héroe de la portada (ruta anterior).
    expect(find.text('ORIGINAL NOVA'), findsWidgets);
    expect(find.text('Reparto'), findsOneWidget);
    expect(find.text('Ver T1 · E1'), findsOneWidget);
    expect(find.text('Episodio de prueba'), findsOneWidget);
    expect(find.text('52 min'), findsOneWidget);

    await tester.runAsync(() => app.logout());
    await tester.pump();
  });

  testWidgets('la portada NOVA no desborda en varios tamaños',
      (WidgetTester tester) async {
    const List<Size> sizes = <Size>[
      Size(360, 640),
      Size(390, 844),
      Size(768, 1024),
      Size(1024, 768),
      Size(1440, 900),
    ];

    for (final Size size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      final ({dynamic config, AppState app}) result =
          await pumpNovaApp(tester, serverUrl: serverUrl);
      await settleFrames(tester, ms: 600);

      expect(
        tester.takeException(),
        isNull,
        reason: 'desborde o error de pintado a ${size.width}x${size.height}',
      );

      await tester.runAsync(() => result.app.logout());
      await tester.pump();
    }

    tester.view.reset();
  });
}
