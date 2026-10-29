import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/models/playable_item.dart';
import 'package:xtream_player/widgets/nova/nova3_live_layout.dart';

void main() {
  for (final size in const <Size>[Size(640, 360), Size(1280, 720)]) {
    testWidgets('lista superpuesta no reduce el vídeo en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const videoKey = ValueKey('full-video');
      bool fullscreen = true;
      int selected = 0;
      late StateSetter update;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return Nova3LiveLayout(
            video: const ColoredBox(key: videoKey, color: Colors.black),
            playlist: const <PlayableItem>[
              PlayableItem(title: 'Canal uno', url: '', isLive: true),
              PlayableItem(title: 'Canal dos', url: '', isLive: true),
            ], index: selected, fullscreen: fullscreen,
            onSelect: (i) => update(() => selected = i), onBack: () {},
            onFullscreen: () => update(() => fullscreen = !fullscreen),
            controls: const Row(mainAxisSize: MainAxisSize.min,
              children: <Widget>[Icon(Icons.pause), Icon(Icons.subtitles)]),
          );
        },
      ))));
      expect(tester.getSize(find.byKey(videoKey)), size);
      expect(find.text('Canal dos'), findsNothing);
      await tester.tap(find.byKey(videoKey));
      await tester.pumpAndSettle();
      expect(find.text('Canal dos'), findsOneWidget);
      expect(tester.getSize(find.byKey(videoKey)), size);
      expect(tester.getTopLeft(find.byKey(videoKey)), Offset.zero);
      await tester.tap(find.text('Canal dos'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(tester.getSize(find.byKey(videoKey)), size);
      await tester.tap(find.text('Ocultar controles'));
      await tester.pumpAndSettle();
      expect(find.text('Canal dos'), findsNothing);
      expect(tester.getSize(find.byKey(videoKey)), size);
      expect(tester.takeException(), isNull);
    });
  }
}
