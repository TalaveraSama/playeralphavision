import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/models/playable_item.dart';
import 'package:xtream_player/widgets/nova/nova3_live_layout.dart';

void main() {
  testWidgets('despertar y cambiar canal sincronizan scroll y foco lejos del inicio', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool hidden = true;
    int index = 80;
    late StateSetter update;
    final playlist = List<PlayableItem>.generate(200,
      (i) => PlayableItem(title: 'Canal $i', url: '', isLive: true));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (_, setState) {
        update = setState;
        return Nova3LiveLayout(video: const ColoredBox(color: Colors.black),
          playlist: playlist, index: index, fullscreen: hidden,
          onSelect: (i) => update(() => index = i), onBack: () {},
          onFullscreen: () => update(() => hidden = !hidden),
          controls: const SizedBox(width: 200, height: 40));
      },
    ))));
    Future<void> check(int selected) async {
      await tester.pumpAndSettle();
      final row = find.descendant(of: find.byType(ListView), matching: find.text('Canal $selected'));
      expect(row, findsOneWidget);
      expect(tester.getRect(find.byType(ListView)).overlaps(tester.getRect(row)), isTrue);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'channel-$selected');
      expect(tester.takeException(), isNull);
    }
    update(() => hidden = false);
    await check(80);
    update(() => index = 150);
    await check(150);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(index, 150); // Browsing focus must not switch playback.
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'channel-151');
    update(() => hidden = true);
    await tester.pumpAndSettle();
    update(() { index = 190; hidden = false; });
    await check(190);
    update(() => index = 199);
    await check(199);
    update(() => index = 0);
    await check(0);
    await tester.pumpWidget(const SizedBox());
  });
}
