import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/models/playable_item.dart';
import '../../core/state/app_state.dart';
import '../../widgets/media_grid.dart';
import '../../widgets/state_views.dart';
import '../details/series_details_page.dart';
import '../details/vod_details_page.dart';
import '../player/open_player.dart';

/// Favoritos guardados en el dispositivo.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  MediaKind? _filter;

  Future<void> _open(List<MediaItem> visible, MediaItem item, int index) async {
    final AppState app = context.read<AppState>();
    await app.addRecent(item);
    if (!mounted) return;

    switch (item.kind) {
      case MediaKind.series:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SeriesDetailsPage(item: item),
          ),
        );
      case MediaKind.movie:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VodDetailsPage(item: item),
          ),
        );
      case MediaKind.live:
        final List<PlayableItem> playlist = <PlayableItem>[];
        int start = 0;
        for (int i = 0; i < visible.length; i++) {
          final PlayableItem? playable = app.playableFrom(visible[i]);
          if (playable == null) continue;
          if (i == index) start = playlist.length;
          playlist.add(playable);
        }
        if (playlist.isEmpty) return;
        await openPlayer(context, playlist: playlist, initialIndex: start);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final List<MediaItem> all = app.favorites;
    final List<MediaItem> visible = _filter == null
        ? all
        : all.where((MediaItem item) => item.kind == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Favoritos'),
            Text(
              '${all.length} guardados',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                ...MediaKind.values.map(
                  (MediaKind kind) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(kind.label),
                      selected: _filter == kind,
                      onSelected: (_) => setState(() => _filter = kind),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: all.isEmpty
                ? const EmptyView(
                    message: 'Todavía no tienes favoritos.\n'
                        'Mantén pulsado un canal, una película o una serie '
                        'para guardarlos aquí.',
                    icon: Icons.favorite_border,
                  )
                : visible.isEmpty
                    ? const EmptyView(
                        message: 'No hay favoritos en esta categoría.',
                        icon: Icons.filter_alt_off_outlined,
                      )
                    : MediaGrid(
                        items: visible,
                        favoriteKeys: all
                            .map((MediaItem item) => item.favoriteKey)
                            .toSet(),
                        iconUrlBuilder: (MediaItem item) =>
                            context.read<AppState>().iconUrl(item),
                        onTap: (MediaItem item, int index) =>
                            _open(visible, item, index),
                        onLongPress: (MediaItem item) =>
                            app.toggleFavorite(item),
                      ),
          ),
        ],
      ),
    );
  }
}
