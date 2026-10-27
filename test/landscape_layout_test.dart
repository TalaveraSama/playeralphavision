import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/models/playable_item.dart';
import 'package:xtream_player/widgets/nova/nova3_live_layout.dart';

void main() {
  test('arranque y manifiestos solo permiten orientación horizontal', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('DeviceOrientation.landscapeLeft'));
    expect(main, isNot(contains('DeviceOrientation.portrait')));
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:screenOrientation="sensorLandscape"'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains('UIInterfaceOrientationPortrait')));
    expect(plist, contains('UIRequiresFullScreen'));
  });

  for (final size in <Size>[Size(640, 360), Size(1280, 720)]) {
    testWidgets('TV dividida sin desbordamiento en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int selected = 0;
      bool fullscreen = false;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Nova3LiveLayout(
        video: const ColoredBox(color: Colors.black),
        playlist: const <PlayableItem>[
          PlayableItem(title: 'Canal uno', url: '', isLive: true),
          PlayableItem(title: 'Canal dos', url: '', isLive: true),
        ],
        index: 0, onSelect: (i) => selected = i, onBack: () {},
        fullscreen: false, onFullscreen: () => fullscreen = true,
        controls: const Text('Controles'),
      ))));
      await tester.tap(find.text('Canal dos'));
      expect(selected, 1);
      await tester.tap(find.byIcon(Icons.fullscreen));
      expect(fullscreen, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
