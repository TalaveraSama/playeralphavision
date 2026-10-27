import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/widgets/nova/nova3_frame.dart';
import 'package:xtream_player/widgets/nova/nova3_loading.dart';

void main() {
  testWidgets('spinner no inventa velocidad antes de medir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Nova3Loading()));
    expect(find.text('Conectando…'), findsOneWidget);
    expect(find.text('0B/S'), findsNothing);
    await tester.pumpWidget(const MaterialApp(home: Nova3Loading(bytesPerSecond: 81920)));
    expect(find.text('80 KB/s · estimada'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in <Size>[Size(640, 360), Size(1280, 720)]) {
    testWidgets('lateral Nova3 sin barra inferior en $size; derecha/izquierda y Atrás', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey<Nova3FrameState>();
      final contentFocus = FocusNode();
      addTearDown(contentFocus.dispose);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Nova3Frame(
        key: key,
        sidebar: SizedBox(width: 160, child: Column(children: <Widget>[
          TextButton(autofocus: true, onPressed: () {}, child: const Text('DESTACADOS')),
          TextButton(onPressed: () {}, child: const Text('TV')),
        ])),
        topBar: const Text('Acciones'),
        child: Align(alignment: Alignment.topLeft, child: TextButton(
          focusNode: contentFocus, onPressed: () {}, child: const Text('Carátula'))),
      ))));
      await tester.pump();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('DESTACADOS'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(key.currentState!.isOpen, isFalse);
      expect(find.text('DESTACADOS'), findsNothing);
      contentFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump();
      expect(key.currentState!.isOpen, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(key.currentState!.isOpen, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('no oculta el menú mientras el mando navega por él', (tester) async {
    final key = GlobalKey<Nova3FrameState>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Nova3Frame(
      key: key,
      sidebar: SizedBox(width: 180, child: TextButton(autofocus: true,
        onPressed: () {}, child: const Text('TV'))),
      topBar: const Text('Acciones'), child: const Text('Contenido'),
    ))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(key.currentState!.isOpen, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
