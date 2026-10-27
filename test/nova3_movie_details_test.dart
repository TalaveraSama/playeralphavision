import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/models/media_item.dart';
import 'package:xtream_player/widgets/nova/nova3_movie_details.dart';

const movie = MediaItem(id: '1', name: 'El jardinero fiel (2005)',
  kind: MediaKind.movie, categoryId: 'drama', genre: 'Drama, Mystery',
  rating: 7.4, director: 'Fernando Meirelles', cast: 'Ralph Fiennes, Rachel Weisz',
  plot: 'Un diplomático investiga la muerte de su esposa.', releaseDate: '2005-08-31');

void main() {
  test('recomendaciones excluyen la película, duplicados y canales', () {
    const same = MediaItem(id: '2', name: 'Otro drama', categoryId: 'drama', kind: MediaKind.movie);
    final result = nova3MovieRecommendations(movie, <MediaItem>[
      movie, same, same,
      const MediaItem(id: '3', name: 'Acción', kind: MediaKind.movie),
      const MediaItem(id: '4', name: 'Canal', kind: MediaKind.live),
    ]);
    expect(result.map((e) => e.id), <String>['2', '3']);
  });

  for (final size in <Size>[Size(640, 360), Size(960, 540), Size(1440, 810)]) {
    testWidgets('ficha horizontal $size reproduce y permite favoritos', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int plays = 0;
      int favorites = 0;
      await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: Scaffold(
        body: Nova3MovieDetails(item: movie, favorite: false,
          recommendations: const <MediaItem>[], onPlay: () => plays++,
          onFavorite: () => favorites++, onBack: () {}, onMore: () {},
          onLanguage: () {}, onQuality: () {}, onRecommendation: (_) {}),
      )));
      expect(find.text('El jardinero fiel'), findsOneWidget);
      expect(find.text('7.4'), findsOneWidget);
      expect(tester.getTopLeft(find.text('El jardinero fiel')).dx,
        lessThan(tester.getCenter(find.byIcon(Icons.play_circle_outline)).dx));
      await tester.tap(find.byIcon(Icons.play_circle_outline));
      expect(plays, 1);
      await tester.ensureVisible(find.text('Favorito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorito'));
      expect(favorites, 1);
      expect(find.text('Quizás te guste'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
