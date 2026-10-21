import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/widgets/net_image.dart';

/// El panel de administración permite subir archivos: en ese caso la imagen se
/// guarda como `data:image/...;base64,...` dentro del config.json. Estas
/// pruebas garantizan que la app sabe pintarla (los logos y fondos de marca).
void main() {
  // PNG transparente de 1x1 píxel.
  const String png1x1 =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

  test('decodeDataUri reconoce Base64 y descarta lo que no lo es', () {
    expect(decodeDataUri(png1x1), isNotNull);
    expect(decodeDataUri(png1x1)!.isNotEmpty, isTrue);
    expect(decodeDataUri('https://misitio.com/logo.png'), isNull);
    expect(decodeDataUri('data:image/png,sinBase64'), isNull);
    expect(decodeDataUri('data:image/png;base64,esto no es base64 !!'), isNull);
    expect(decodeDataUri(''), isNull);
  });

  testWidgets('NetImage pinta un logo subido como data URI',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              height: 80,
              child: NetImage(url: png1x1, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
  });

  testWidgets('NetImage cae al marcador si el data URI está roto',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 80,
            child: NetImage(url: 'data:image/png;base64,%%%'),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('NetImage muestra el marcador cuando no hay imagen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 80, height: 80, child: NetImage(url: '')),
        ),
      ),
    );

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });
}
