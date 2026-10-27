import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';
import '../../core/theme/nova_theme.dart';
import '../media_grid.dart';
import 'nova_art.dart';

/// Mosaico de Nova3: dos destacados y una rejilla compacta sin espacios grandes.
/// Usa únicamente las imágenes y títulos reales del catálogo del proveedor.
class Nova3Dashboard extends StatelessWidget {
  const Nova3Dashboard({super.key, required this.items, required this.onOpen});

  final List<MediaItem> items;
  final ValueChanged<MediaItem> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No hay contenido disponible'));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final bool compact = constraints.maxWidth < 600;
      final int featured = items.length.clamp(0, 2);
      final int columns = compact ? 2 : constraints.maxWidth < 850 ? 3 : 4;
      return CustomScrollView(
        key: const PageStorageKey<String>('nova3-dashboard'),
        slivers: <Widget>[
          SliverPadding(
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
          SliverPadding(
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
                childCount: items.length - featured,
              ),
            ),
          ),
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
