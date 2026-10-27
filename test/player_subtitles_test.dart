import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/core/config/config_controller.dart';
import 'package:xtream_player/core/state/app_state.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';
import 'package:xtream_player/widgets/player_subtitles.dart';

void main() {
  test('decodifica texto, descarta vacío y normaliza DIMEN_UNSET', () {
    final cues = PlayerSubtitleCue.decode(<dynamic>[
      <String, dynamic>{'text': 'Hola\nmundo', 'position': -3.4e38, 'size': -3.4e38,
        'line': -3.4e38, 'lineType': -2147483648, 'positionAnchor': -2147483648},
      <String, dynamic>{'text': ''}, null,
    ]);
    expect(cues.length, 1);
    expect(cues.single.text, 'Hola\nmundo');
    expect(cues.single.position, isNull);
    expect(cues.single.size, isNull);
    expect(cues.single.line, isNull);
    expect(cues.single.positionAnchor, 1);
    expect(PlayerSubtitleCue.decode(null), isEmpty);
    expect(PlayerSubtitleCue.decode(<dynamic>[]), isEmpty);
  });
  test('conserva posiciones relativas y subtítulos de imagen', () {
    final cue = PlayerSubtitleCue.fromMap(<String, dynamic>{
      'bitmap': Uint8List.fromList(<int>[1, 2]), 'position': .2, 'positionAnchor': 0,
      'line': .8, 'lineType': 0, 'size': .5, 'bitmapHeight': .15,
    });
    expect(cue.bitmap, isNotNull);
    expect(cue.line, .8);
    expect(cue.position, .2);
    expect(cue.size, .5);
    expect(cue.bitmapHeight, .15);
  });
  test('color/tamaño se guardan en el perfil', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await PrefsStore.create();
    final config = ConfigController(store: store);
    final state = AppState(store, config);
    await state.setSubtitleColor('#FFFF00');
    await state.setSubtitleSize(32);
    final restored = await PrefsStore.create();
    expect(restored.subtitleColor, '#FFFF00');
    expect(restored.subtitleSize, 32);
    state.dispose(); config.dispose();
  });
  Future<void> mount(WidgetTester tester, {List<PlayerSubtitleCue> cues = const <PlayerSubtitleCue>[
    PlayerSubtitleCue(text: 'Subtítulos visibles'),
  ], Color color = Colors.white, double size = 22, Size viewport = const Size(640, 360)}) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(
      width: viewport.width, height: viewport.height,
      child: PlayerSubtitles(cues: cues, color: color, fontSize: size),
    )))));
  }
  testWidgets('dibuja texto y refleja cambios de color/tamaño sin reiniciar', (tester) async {
    await mount(tester);
    var text = tester.widget<Text>(find.text('Subtítulos visibles'));
    expect(text.style!.color, Colors.white);
    expect(text.style!.fontSize, 22);
    await mount(tester, color: Colors.cyan, size: 36);
    text = tester.widget<Text>(find.text('Subtítulos visibles'));
    expect(text.style!.color, Colors.cyan);
    expect(text.style!.fontSize, 36);
    await mount(tester, cues: const <PlayerSubtitleCue>[]);
    expect(find.text('Subtítulos visibles'), findsNothing);
  });
  testWidgets('vista previa TV y cue posicionado sin errores de layout', (tester) async {
    await mount(tester, viewport: const Size(320, 180), size: 40);
    expect(find.text('Subtítulos visibles'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mount(tester, cues: const <PlayerSubtitleCue>[
      PlayerSubtitleCue(text: 'Texto arriba', position: .5, line: .1, size: .8),
    ]);
    expect(find.text('Texto arriba'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Texto arriba')).dy, lessThan(200));
    expect(tester.takeException(), isNull);
  });
  testWidgets('dibuja PNG de subtítulo sin intentar recolorearlo', (tester) async {
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aXsQAAAAASUVORK5CYII=');
    await mount(tester, cues: <PlayerSubtitleCue>[PlayerSubtitleCue(bitmap: png)]);
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
