import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../../widgets/nova/nova3_dashboard.dart';
import '../details/series_details_page.dart';
import '../details/vod_details_page.dart';
import '../player/open_player.dart';

class Nova3HistoryPage extends StatelessWidget {
  const Nova3HistoryPage({super.key});

  Future<void> _open(BuildContext context, MediaItem item) async {
    switch (item.kind) {
      case MediaKind.movie:
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => VodDetailsPage(item: item)));
      case MediaKind.series:
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => SeriesDetailsPage(item: item)));
      case MediaKind.live:
        final app = context.read<AppState>();
        final playable = app.playableFrom(item);
        if (playable != null) await openPlayer(context, playlist: [playable]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Historial'), actions: <Widget>[
        IconButton(tooltip: 'Borrar historial', icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final bool? clear = await showDialog<bool>(context: context,
              builder: (context) => AlertDialog(title: const Text('¿Borrar historial?'),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
                ]));
            if (clear == true) await app.clearRecent();
          }),
      ]),
      body: app.recent.isEmpty ? const Center(child: Text('Aún no hay contenido en tu historial'))
          : Nova3Dashboard(items: app.recent, onOpen: (item) => _open(context, item)),
    );
  }
}
