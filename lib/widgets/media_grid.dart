import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models/media_item.dart';
import '../core/theme/nova_theme.dart';
import '../core/utils/channel_names.dart';
import 'net_image.dart';

/// Tarjeta de un elemento del catálogo (canal, película o serie).
///
/// Está preparada para Android TV: al recibir el foco con el mando muestra un
/// borde del color de marca y crece un poco, de modo que siempre se ve qué está
/// seleccionado.
class MediaTile extends StatefulWidget {
  const MediaTile({
    super.key,
    required this.item,
    this.iconUrl,
    this.onTap,
    this.onLongPress,
    this.isFavorite = false,
    this.radius = 12,
  });

  final MediaItem item;
  final String? iconUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isFavorite;
  final double radius;

  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;
    final bool isLive = widget.item.kind == MediaKind.live;

    IconData placeholderIcon;
    switch (widget.item.kind) {
      case MediaKind.live:
        placeholderIcon = Icons.live_tv_outlined;
      case MediaKind.movie:
        placeholderIcon = Icons.movie_outlined;
      case MediaKind.series:
        placeholderIcon = Icons.video_library_outlined;
    }

    final BorderRadius outerRadius =
        BorderRadius.circular(widget.radius + 3);

    return AnimatedScale(
      scale: _focused ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: outerRadius,
          border: Border.all(
            color: _focused ? primary : Colors.transparent,
            width: 2.2,
          ),
          boxShadow: _focused
              ? <BoxShadow>[
                  BoxShadow(
                    color: primary.withValues(alpha: 0.55),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onFocusChange: (bool value) {
            if (_focused != value) setState(() => _focused = value);
          },
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.radius),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(widget.radius),
                          child: NetImage(
                            url: widget.iconUrl ?? widget.item.icon,
                            fit: isLive ? BoxFit.contain : BoxFit.cover,
                            icon: placeholderIcon,
                            iconSize: isLive ? 34 : 30,
                            backgroundColor: const Color(0xFF1B222C),
                            cacheWidth: 320,
                          ),
                        ),
                      ),
                      if (isLive)
                        Positioned(
                          left: 5,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'VIVO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      if (isLive &&
                          channelQualityTag(widget.item.name) != null)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.66),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: primary.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Text(
                              channelQualityTag(widget.item.name)!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: primary,
                              ),
                            ),
                          ),
                        ),
                      if (widget.item.rating != null && widget.item.rating! > 0)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ ${widget.item.rating!.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFFC107),
                              ),
                            ),
                          ),
                        ),
                      if (widget.isFavorite)
                        const Positioned(
                          right: 5,
                          bottom: 5,
                          child: Icon(
                            Icons.favorite,
                            size: 16,
                            color: Color(0xFFFF5252),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rejilla responsive reutilizada por catálogo, búsqueda y favoritos.
class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.onLongPress,
    this.iconUrlBuilder,
    this.favoriteKeys,
    this.maxCrossAxisExtent = 132,
    this.childAspectRatio = 0.68,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onTap;
  final void Function(MediaItem item)? onLongPress;
  final String? Function(MediaItem item)? iconUrlBuilder;
  final Set<String>? favoriteKeys;
  final double maxCrossAxisExtent;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    final double scale = NovaMetrics.of(context).scale;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent * scale,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final MediaItem item = items[index];
        return MediaTile(
          item: item,
          iconUrl: iconUrlBuilder?.call(item),
          isFavorite: favoriteKeys?.contains(item.favoriteKey) ?? false,
          onTap: () => onTap(item, index),
          onLongPress: onLongPress == null ? null : () => onLongPress!(item),
        );
      },
    );
  }
}


/// Envuelve una tarjeta con resplandor neón al enfocarla con el mando.
class NeonFocus extends StatefulWidget {
  const NeonFocus({super.key, required this.onTap, required this.child, this.radius = 14});
  final VoidCallback? onTap;
  final Widget child;
  final double radius;
  @override
  State<NeonFocus> createState() => _NeonFocusState();
}

class _NeonFocusState extends State<NeonFocus> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Focus(
      canRequestFocus: widget.onTap != null,
      onFocusChange: (bool v) {
        setState(() => _focused = v);
        if (v) {
          Scrollable.ensureVisible(context,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero : const Duration(milliseconds: 180));
        }
      },
      onKeyEvent: _onKey,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius + 3),
          border: Border.all(
            color: _focused ? primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: _focused
              ? <BoxShadow>[
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: GestureDetector(onTap: widget.onTap, child: widget.child),
      ),
    );
  }
}

