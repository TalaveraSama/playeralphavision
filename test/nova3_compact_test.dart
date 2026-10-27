import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/models/media_item.dart';
import 'package:xtream_player/widgets/media_grid.dart';
import 'package:xtream_player/widgets/nova/nova3_top_bar.dart';

void main() {
  testWidgets('rejilla compacta reduce las medidas base al 80%', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaGrid(
      density: 0.8,
      items: const <MediaItem>[MediaItem(id: '1', name: 'Canal nacional', kind: MediaKind.live)],
      onTap: (_, __) {},
    ))));
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate = grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(delegate.maxCrossAxisExtent, closeTo(132 * 0.8, 0.01));
    expect(delegate.mainAxisSpacing, closeTo(14 * 0.8, 0.01));
    final text = tester.widget<Text>(find.text('Canal nacional'));
    expect(text.maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cabecera Nova3 compacta mantiene acciones sin desbordar', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int searches = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: <Widget>[
      Nova3TopBar(onSearch: () => searches++, onProfile: () {},
        onFavorites: () {}, onFilter: () {}, onHistory: () {}, onNotifications: () {}),
    ]))));
    expect(tester.getSize(find.byType(Nova3TopBar)).height, lessThanOrEqualTo(64));
    await tester.tap(find.byIcon(Icons.search));
    expect(searches, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
