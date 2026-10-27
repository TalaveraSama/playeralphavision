import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';
import '../../core/theme/nova_theme.dart';
import 'nova_art.dart';
import 'nova_ui.dart';

/// Cabecera editorial de Nova2. Sin rotación automática ni logos de terceros.
class Nova2Hero extends StatelessWidget {
  const Nova2Hero({super.key, required this.item, required this.onOpen});

  final MediaItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final bool compact = constraints.maxWidth < 700;
      return SizedBox(
        height: compact ? 460 : 440,
        child: Stack(fit: StackFit.expand, children: <Widget>[
          NovaArtwork(
            url: item.backdrop ?? item.icon,
            seed: item.favoriteKey,
            radius: 8,
            fit: BoxFit.cover,
          ),
          DecoratedBox(decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: compact ? Alignment.topCenter : Alignment.centerRight,
              end: compact ? Alignment.bottomCenter : Alignment.centerLeft,
              colors: <Color>[
                tokens.background.withValues(alpha: 0.05),
                tokens.background.withValues(alpha: 0.82),
                tokens.background,
              ],
              stops: const <double>[0, 0.65, 1],
            ),
          )),
          Padding(
            padding: EdgeInsets.all(compact ? 24 : 40),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 500 : 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('TU PRÓXIMA GRAN HISTORIA', style: tokens.eyebrow),
                    const SizedBox(height: 16),
                    Text(item.name, maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compact ? 32 : 48,
                        height: 1.04, letterSpacing: -1.2,
                        fontWeight: FontWeight.w800, color: tokens.text)),
                    const SizedBox(height: 14),
                    Text(<String>[
                      item.kind == MediaKind.series ? 'Serie' : item.kind == MediaKind.live ? 'En vivo' : 'Película',
                      if (item.rating != null && item.rating! > 0) '★ ${item.rating!.toStringAsFixed(1)}',
                      if (item.genre?.trim().isNotEmpty ?? false) item.genre!.split(',').first,
                    ].join('   ·   '), style: tokens.meta),
                    if (item.plot?.trim().isNotEmpty ?? false) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(item.plot!, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: tokens.body),
                    ],
                    const SizedBox(height: 24),
                    NovaPrimaryButton(label: 'Descubrir',
                      icon: Icons.play_arrow_rounded, onPressed: onOpen),
                  ],
                ),
              ),
            ),
          ),
        ]),
      );
    });
  }
}
