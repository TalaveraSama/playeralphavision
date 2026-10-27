import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/config/app_config.dart';
import 'package:xtream_player/core/models/media_item.dart';
import 'package:xtream_player/core/theme/app_themes.dart';
import 'package:xtream_player/widgets/media_grid.dart';
import 'package:xtream_player/widgets/nova/nova3_dashboard.dart';

void main() {
  late ThemeSpec nova3;
  setUp(() {
    final Map<String, dynamic> config = jsonDecode(
        File('assets/config.json').readAsStringSync()) as Map<String, dynamic>;
    nova3 = ThemeConfig.fromJson(config['theme'] as Map<String, dynamic>).resolve('nova3');
  });

  test('Nova3 es independiente de NOVA y Nova2 y conserva el tema activo', () {
    expect(nova3.id, 'nova3');
    expect(nova3.name, 'Nova3');
    expect(nova3.isNova3, isTrue);
    expect(nova3.isNova2, isFalse);
    expect(nova3.isNova, isTrue);
    expect(ThemeSpec.fromJson(nova3.toJson()).isNova3, isTrue);
    expect(buildThemeData(nova3).scaffoldBackgroundColor, const Color(0xFF000000));
    for (final file in <String>['assets/config.json', 'admin_panel/config.json']) {
      final json = jsonDecode(File(file).readAsStringSync());
      final themes = ThemeConfig.fromJson(json['theme']);
      expect(themes.resolve(null).id, 'nova3');
      expect(themes.resolve('nova2').id, 'nova2');
      expect(themes.resolve('nova3').id, 'nova3');
    }
  });

  for (final width in <double>[360, 960, 1440]) {
    testWidgets('mosaico Nova3 a $width dp activa con toque y OK', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? opened;
      await tester.pumpWidget(MaterialApp(
        theme: buildThemeData(nova3),
        home: Scaffold(body: Nova3Dashboard(
          items: List<MediaItem>.generate(8, (i) => MediaItem(
            id: '$i', name: 'Título $i', kind: MediaKind.movie)),
          onOpen: (item) => opened = item.id,
        )),
      ));
      await tester.tap(find.text('Título 0'));
      expect(opened, '0');
      opened = null;
      final tile = find.byType(NeonFocus).first;
      Focus.of(tester.element(find.descendant(of: tile, matching: find.byType(GestureDetector)).first))
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(opened, '0');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('catálogo vacío muestra mensaje sin rejilla', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Nova3Dashboard(
      items: const <MediaItem>[], onOpen: (_) {},
    ))));
    expect(find.text('No hay contenido disponible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
