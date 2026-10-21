import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';
import '../../widgets/media_grid.dart';
import '../../widgets/state_views.dart';

/// Rejilla completa de una categoría, a la que se llega desde "Ver todo".
class CategoryGridPage extends StatelessWidget {
  const CategoryGridPage({
    super.key,
    required this.title,
    required this.items,
    required this.iconUrlBuilder,
    required this.onOpen,
    required this.onToggleFavorite,
    this.favoriteKeys,
  });

  final String title;
  final List<MediaItem> items;
  final String? Function(MediaItem item) iconUrlBuilder;
  final void Function(MediaItem item, int index) onOpen;
  final void Function(MediaItem item) onToggleFavorite;
  final Set<String>? favoriteKeys;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title),
            Text(
              '${items.length} elementos',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: items.isEmpty
          ? const EmptyView(message: 'Esta categoría está vacía.')
          : MediaGrid(
              items: items,
              favoriteKeys: favoriteKeys,
              iconUrlBuilder: iconUrlBuilder,
              onTap: onOpen,
              onLongPress: onToggleFavorite,
            ),
    );
  }
}
