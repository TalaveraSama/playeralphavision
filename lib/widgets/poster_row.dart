import 'package:flutter/material.dart';

import '../core/models/media_item.dart';
import 'media_grid.dart';

/// Fila horizontal de carátulas con título de sección, al estilo Netflix.
class PosterRow extends StatelessWidget {
  const PosterRow({
    super.key,
    required this.title,
    required this.items,
    required this.onTap,
    this.onLongPress,
    this.onSeeAll,
    this.iconUrlBuilder,
    this.favoriteKeys,
    this.itemWidth = 122,
    this.rowHeight = 214,
    this.cardRadius = 8,
  });

  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onTap;
  final void Function(MediaItem item)? onLongPress;
  final VoidCallback? onSeeAll;
  final String? Function(MediaItem item)? iconUrlBuilder;
  final Set<String>? favoriteKeys;
  final double itemWidth;
  final double rowHeight;
  final double cardRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 6, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Ver todo', style: TextStyle(fontSize: 12)),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final MediaItem item = items[index];
              return SizedBox(
                width: itemWidth,
                child: MediaTile(
                  item: item,
                  radius: cardRadius,
                  iconUrl: iconUrlBuilder?.call(item),
                  isFavorite:
                      favoriteKeys?.contains(item.favoriteKey) ?? false,
                  onTap: () => onTap(item, index),
                  onLongPress:
                      onLongPress == null ? null : () => onLongPress!(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
