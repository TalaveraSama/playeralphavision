import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';
import '../../core/theme/nova_theme.dart';
import '../media_grid.dart';
import 'nova_art.dart';

class Nova3Collection {
  const Nova3Collection({required this.title, required this.items});
  final String title;
  final List<MediaItem> items;
}

/// Mosaico de Nova3: dos destacados y una rejilla compacta sin espacios grandes.
/// Usa únicamente las imágenes y títulos reales del catálogo del proveedor.
class Nova3Dashboard extends StatelessWidget {
  const Nova3Dashboard({super.key, required this.items, required this.onOpen,
    this.collections = const <Nova3Collection>[], this.explore = false});

  final List<MediaItem> items;
  final ValueChanged<MediaItem> onOpen;
  final List<Nova3Collection> collections;
  final bool explore;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No hay contenido disponible'));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final bool compact = constraints.maxWidth < 440;
      final int featured = items.length.clamp(0, 2);
      final int columns = compact ? 2 : 4;
      final int teaserCount = (items.length - featured).clamp(0, 4);
      final List<Nova3Collection> shelves = collections.isNotEmpty ? collections
          : <Nova3Collection>[if (items.length > 6)
              Nova3Collection(title: 'Más para descubrir', items: items.skip(6).toList())];
      return CustomScrollView(
        key: const PageStorageKey<String>('nova3-dashboard'),
        slivers: <Widget>[
          if (explore && !compact)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 24, 24),
              child: SizedBox(height: (constraints.maxWidth * 0.42).clamp(210.0, 510.0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Expanded(flex: 3, child: _MosaicTile(item: items.first, featured: true,
                    onOpen: () => onOpen(items.first))),
                  if (items.length > 1) ...<Widget>[
                    const SizedBox(width: 4),
                    Expanded(child: Column(children: <Widget>[
                      for (final item in items.skip(1).take(3))
                        Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 4),
                          child: _MosaicTile(item: item, onOpen: () => onOpen(item)))),
                    ])),
                  ],
                ]),
              ),
            ))
          else SliverPadding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 8, 12, compact ? 12 : 24, 0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: compact ? 1 : 2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: compact ? 16 / 9 : 1.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _MosaicTile(item: items[index], featured: true,
                    onOpen: () => onOpen(items[index])),
                childCount: featured,
              ),
            ),
          ),
          if (!explore || compact) SliverPadding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 8, 4, compact ? 12 : 24, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 16 / 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index + featured];
                  return _MosaicTile(item: item, onOpen: () => onOpen(item));
                },
                childCount: teaserCount,
              ),
            ),
          ),
          SliverList(delegate: SliverChildBuilderDelegate(
            (context, index) => _PosterShelf(collection: shelves[index], onOpen: onOpen),
            childCount: shelves.length,
          )),
        ],
      );
    });
  }
}

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({required this.item, required this.onOpen, this.featured = false});
  final MediaItem item;
  final VoidCallback onOpen;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final tokens = NovaTokens.of(context);
    final String? backdrop = item.backdrop;
    return Semantics(
      label: item.name,
      button: true,
      child: NeonFocus(
        radius: 3,
        onTap: onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(fit: StackFit.expand, children: <Widget>[
            NovaArtwork(
              url: backdrop != null && backdrop.trim().isNotEmpty ? backdrop : item.icon,
              seed: item.favoriteKey,
              radius: 3,
              cacheWidth: featured ? 960 : 480,
              fit: BoxFit.cover,
            ),
            const DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                stops: <double>[0.5, 1], colors: <Color>[Colors.transparent, Color(0xD9000000)]),
            )),
            Positioned(
              left: featured ? 18 : 12,
              right: 12,
              bottom: featured ? 16 : 10,
              child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.text, height: 1.15,
                  fontSize: featured ? 20 : 14, fontWeight: FontWeight.w600)),
            ),
            if (item.kind == MediaKind.live)
              Positioned(top: 12, left: 12, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: tokens.live, borderRadius: BorderRadius.circular(3)),
                child: const Text('EN VIVO', style: TextStyle(color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w700)),
              )),
          ]),
        ),
      ),
    );
  }
}


class _PosterShelf extends StatelessWidget {
  const _PosterShelf({required this.collection, required this.onOpen});
  final Nova3Collection collection;
  final ValueChanged<MediaItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double width = (constraints.maxWidth / 6.2).clamp(94.0, 190.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(collection.title, style: const TextStyle(fontSize: 19,
            fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 12),
          SizedBox(height: width * 1.5 + 46, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: collection.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = collection.items[index];
              return SizedBox(width: width, child: NeonFocus(
                radius: 3, onTap: () => onOpen(item),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Expanded(child: NovaArtwork(url: item.icon ?? item.backdrop,
                    seed: item.favoriteKey, radius: 2, cacheWidth: 320)),
                  const SizedBox(height: 8),
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                ]),
              ));
            },
          )),
        ]),
      );
    });
  }
}
