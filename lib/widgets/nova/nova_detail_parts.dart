import 'package:flutter/material.dart';

import '../../core/theme/nova_theme.dart';
import 'nova_art.dart';
import 'nova_ui.dart';

/// Fila de etiqueta/valor de las fichas de NOVA.
typedef NovaInfoRow = ({String label, String value});

/// Reproductor destacado de la ficha: carátula con anillos y botón central.
class NovaPlayerHero extends StatelessWidget {
  const NovaPlayerHero({
    super.key,
    required this.artworkUrl,
    required this.seed,
    this.height = 360,
    this.trailerLabel = '',
    this.onPlay,
    this.onTrailer,
  });

  final String? artworkUrl;
  final String seed;
  final double height;
  final String trailerLabel;
  final VoidCallback? onPlay;
  final VoidCallback? onTrailer;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);

    return SizedBox(
      height: height,
      child: NovaArtwork(
        url: artworkUrl,
        seed: seed,
        radius: 16,
        rings: 3,
        ringAlignment: const Alignment(0.35, -0.1),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: NovaFocusable(
                onTap: onPlay,
                autofocus: true,
                borderRadius: BorderRadius.circular(42),
                child: Material(
                  color: tokens.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onPlay,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 26,
                      color: tokens.background,
                    ),
                  ),
                ),
              ),
            ),
            ),
            if (trailerLabel.isNotEmpty)
              Positioned(
                left: 18,
                bottom: 16,
                child: InkWell(
                  onTap: onTrailer,
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.movie_outlined,
                        size: 16,
                        color: tokens.text.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        trailerLabel,
                        style: tokens.meta.copyWith(
                          color: tokens.text.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tabla de metadatos (Género, Audio, Subtítulos, Dirección…).
class NovaInfoTable extends StatelessWidget {
  const NovaInfoTable({super.key, required this.rows});

  final List<NovaInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);

    return NovaCard(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 110,
                    child: Text(
                      rows[i].label,
                      style: tokens.meta.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      style: tokens.meta.copyWith(
                        color: tokens.text.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Reparto con avatares circulares (degradado estable por nombre).
class NovaCastRow extends StatelessWidget {
  const NovaCastRow({
    super.key,
    required this.names,
    this.title = 'Reparto',
  });

  final List<String> names;
  final String title;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    if (names.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: tokens.sectionTitle),
        const SizedBox(height: 16),
        Wrap(
          spacing: 22,
          runSpacing: 18,
          children: <Widget>[
            for (final String name in names) _CastAvatar(name: name),
          ],
        ),
      ],
    );
  }
}

class _CastAvatar extends StatelessWidget {
  const _CastAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final String trimmed = name.trim();
    final String initial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();

    return SizedBox(
      width: 76,
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: novaGradientFor(trimmed),
              border: Border.all(color: tokens.hairline),
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: tokens.text.withValues(alpha: 0.92),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trimmed,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: tokens.meta.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Pestañas con subrayado del acento (Episodios · Más como esto · Detalles).
class NovaTabBar extends StatelessWidget {
  const NovaTabBar({
    super.key,
    required this.labels,
    required this.index,
    required this.onSelected,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.hairline)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            InkWell(
              onTap: () => onSelected(i),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 26, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            i == index ? FontWeight.w700 : FontWeight.w500,
                        color: i == index
                            ? tokens.text
                            : tokens.text.withValues(alpha: 0.62),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 2,
                      width: i == index ? 42 : 0,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rejilla de carátulas para «Más como esto».
class NovaPosterWrap extends StatelessWidget {
  const NovaPosterWrap({
    super.key,
    required this.items,
    required this.onOpen,
    this.width = 118,
  });

  final List<({String key, String name, String? icon})> items;
  final void Function(int index) onOpen;
  final double width;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);

    return Wrap(
      spacing: 14,
      runSpacing: 18,
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          SizedBox(
            width: width,
            child: InkWell(
              onTap: () => onOpen(i),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 0.68,
                    child: NovaArtwork(
                      url: items[i].icon,
                      seed: items[i].key,
                      radius: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    items[i].name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.cardTitle,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
