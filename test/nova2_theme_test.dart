import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/config/app_config.dart';
import 'package:xtream_player/core/theme/app_themes.dart';
import 'package:xtream_player/core/models/media_item.dart';
import 'package:xtream_player/widgets/nova/nova2_hero.dart';

void main() {
  late ThemeSpec nova2;
  setUp(() {
    final json = jsonDecode(File('assets/config.json').readAsStringSync())
        as Map<String, dynamic>;
    nova2 = ThemeConfig.fromJson(json['theme'] as Map<String, dynamic>)
        .resolve('nova2');
  });

  test('Nova2 es independiente y conserva los demás temas', () {
    expect(nova2.id, 'nova2');
    expect(nova2.name, 'Nova2');
    expect(nova2.isNova, isTrue);
    expect(nova2.isNova2, isTrue);
    expect(nova2.lightButtons, isTrue);
    expect(ThemeSpec.fromJson(nova2.toJson()).isNova2, isTrue);
    final json = jsonDecode(File('assets/config.json').readAsStringSync());
    expect(ThemeConfig.fromJson(json['theme']).resolve(null).id, 'nova3');
  });

  test('el tema publica su identidad cinematográfica', () {
    final theme = buildThemeData(nova2);
    expect(theme.extension<NovaAppearance>()!.cinematic, isTrue);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF08070E));
  });

  for (final width in <double>[360, 960]) {
    testWidgets('cabecera Nova2 sin desbordar a $width dp', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int opens = 0;
      await tester.pumpWidget(MaterialApp(
        theme: buildThemeData(nova2),
        home: Scaffold(body: SingleChildScrollView(child: Nova2Hero(
          item: const MediaItem(id: '1', name: 'Una historia para descubrir',
            kind: MediaKind.movie),
          onOpen: () => opens++,
        ))),
      ));
      await tester.tap(find.text('Descubrir'));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
