import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nova_ui.dart';

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
          else SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 24, 4),
            child: SizedBox(height: (constraints.maxWidth * (compact ? 0.58 : 0.30)).clamp(160.0, 410.0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                Expanded(child: _HeroPager(items: items.take(5).toList(), onOpen: onOpen)),
                if (!compact && items.length > 1) ...<Widget>[
                  const SizedBox(width: 4),
                  Expanded(child: _MosaicTile(item: items[1], featured: true, onOpen: () => onOpen(items[1]))),
                ],
              ]),
            ),
          )),
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
              fit: item.kind == MediaKind.live ? BoxFit.contain : BoxFit.cover,
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


class _HeroPager extends StatefulWidget {
  const _HeroPager({required this.items, required this.onOpen});
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onOpen;
  @override
  State<_HeroPager> createState() => _HeroPagerState();
}

class _HeroPagerState extends State<_HeroPager> {
  final PageController _pages = PageController();
  int _page = 0;
  @override
  void dispose() { _pages.dispose(); super.dispose(); }
  @override
  void didUpdateWidget(covariant _HeroPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.map((e) => e.favoriteKey).join('|') !=
        widget.items.map((e) => e.favoriteKey).join('|')) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(0);
      });
    }
  }
  void _go(int page) {
    if (!_pages.hasClients) return;
    _pages.animateToPage(page,
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOut);
  }
  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight && _page < widget.items.length - 1) {
        _go(_page + 1); return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _page > 0) {
        _go(_page - 1); return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Stack(children: <Widget>[
      Positioned.fill(child: PageView.builder(controller: _pages,
        onPageChanged: (page) => setState(() => _page = page),
        itemCount: widget.items.length,
        itemBuilder: (context, i) => _MosaicTile(item: widget.items[i], featured: true,
          onOpen: () => widget.onOpen(widget.items[i])))),
      Positioned(right: 10, bottom: 8, child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          for (int i = 0; i < widget.items.length; i++)
            Semantics(label: 'Destacado ${i + 1}', selected: i == _page,
              child: NovaFocusable(onTap: () => _go(i), child: SizedBox(width: 28, height: 30,
                child: Center(child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                  width: i == _page ? 18 : 6, height: 6,
                  decoration: BoxDecoration(color: i == _page ? const Color(0xFF456BFF) : Colors.white54,
                    borderRadius: BorderRadius.circular(8))))))),
        ]),
      )),
    ]),
  );
}
