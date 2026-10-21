import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/models/media_item.dart';
import 'package:xtream_player/widgets/media_grid.dart';

/// Comprobaciones de la adaptación a Android TV: empaquetado (banner y
/// lanzador de TV en el manifiesto) y navegación con el mando (foco visible).
void main() {
  group('Empaquetado para Android TV', () {
    late String manifest;
    late File banner;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      banner = File(
        'android/app/src/main/res/drawable/tv_banner.png',
      );
    });

    test('el manifiesto declara el banner que exige el lanzador de TV', () {
      expect(manifest, contains('android:banner="@drawable/tv_banner"'));
    });

    test('el manifiesto incluye leanback y el lanzador de TV', () {
      expect(manifest, contains('android.software.leanback'));
      expect(manifest, contains('LEANBACK_LAUNCHER'));
      // El mando sustituye al dedo: no se exige pantalla táctil.
      expect(manifest, contains('android.hardware.touchscreen'));
    });

    test('el banner existe y mide 320x180 (formato de Android TV)', () {
      expect(banner.existsSync(), isTrue);
      final Uint8List bytes = banner.readAsBytesSync();
      // Cabecera PNG: firma + longitud + tipo + ancho + alto.
      expect(bytes.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      final ByteData header = ByteData.sublistView(bytes);
      final int width = header.getUint32(16);
      final int height = header.getUint32(20);
      expect(width, 320);
      expect(height, 180);
    });
  });

  group('Navegación con el mando', () {
    List<MediaItem> sample() => <MediaItem>[
          const MediaItem(kind: MediaKind.live, id: '1', name: 'Canal 1'),
          const MediaItem(kind: MediaKind.live, id: '2', name: 'Canal 2'),
          const MediaItem(kind: MediaKind.live, id: '3', name: 'Canal 3'),
        ];

    bool hasFocusRing(Widget widget) {
      if (widget is! AnimatedContainer) return false;
      final Decoration? decoration = widget.decoration;
      if (decoration is! BoxDecoration) return false;
      final BoxBorder? border = decoration.border;
      if (border is! Border) return false;
      return border.top.width > 2 && border.top.color != Colors.transparent;
    }

    testWidgets('la tarjeta resalta cuando el mando la enfoca',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primarySwatch: Colors.red),
          home: Scaffold(
            body: MediaGrid(
              items: sample(),
              onTap: (MediaItem item, int index) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Sin foco no hay ningún borde de marca.
      expect(find.byWidgetPredicate(hasFocusRing), findsNothing);

      // El mando (TAB/ flechas) mueve el foco al primer elemento.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate(hasFocusRing), findsOneWidget);
    });
  });
}
