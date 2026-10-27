import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';
import '../../core/theme/nova_theme.dart';
import '../media_grid.dart';
import 'nova_art.dart';
import 'nova_ui.dart';

/// Recomendaciones locales, sin títulos inventados ni duplicados.
List<MediaItem> nova3MovieRecommendations(MediaItem current, List<MediaItem> pool) {
  final genres = (current.genre ?? '').toLowerCase().split(RegExp(r'[,;/]'))
      .map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  final seen = <String>{current.favoriteKey};
  int score(MediaItem item) =>
      (current.categoryId != null && current.categoryId == item.categoryId ? 4 : 0) +
      (item.genre ?? '').toLowerCase().split(RegExp(r'[,;/]'))
          .where((e) => genres.contains(e.trim())).length;
  final candidates = pool.where((item) => item.kind == MediaKind.movie && seen.add(item.favoriteKey)).toList();
  candidates.sort((a, b) {
    final bySimilarity = score(b).compareTo(score(a));
    if (bySimilarity != 0) return bySimilarity;
    final byRating = (b.rating ?? 0).compareTo(a.rating ?? 0);
    return byRating != 0 ? byRating : a.name.compareTo(b.name);
  });
  return candidates.take(12).toList();
}

/// Ficha horizontal: datos, vista previa y recomendaciones del catálogo real.
/// La vista previa es una imagen: el vídeo se abre con el motor configurado.
class Nova3MovieDetails extends StatelessWidget {
  const Nova3MovieDetails({super.key, required this.item, required this.favorite,
    required this.recommendations, required this.onFavorite, required this.onBack,
    required this.onLanguage, required this.onQuality, required this.onMore,
    required this.onRecommendation, this.onPlay, this.loading = false,
    this.error, this.onRetry});

  final MediaItem item;
  final bool favorite;
  final List<MediaItem> recommendations;
  final VoidCallback? onPlay;
  final VoidCallback onFavorite;
  final VoidCallback onBack;
  final VoidCallback onLanguage;
  final VoidCallback onQuality;
  final VoidCallback onMore;
  final ValueChanged<MediaItem> onRecommendation;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  Widget _field(String label, String? value, NovaTokens tokens, {int lines = 1}) {
    return Padding(padding: const EdgeInsets.only(bottom: 7), child: Text.rich(
      TextSpan(children: <InlineSpan>[
        TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w700, color: tokens.muted)),
        TextSpan(text: value?.trim().isNotEmpty == true ? value : 'No disponible'),
      ]), maxLines: lines, overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, height: 1.3, color: tokens.text),
    ));
  }

  Widget _action(BuildContext context, IconData icon, String label, VoidCallback? onTap) {
    return Semantics(button: true, label: label,
      child: NovaFocusable(onTap: onTap, borderRadius: BorderRadius.circular(3),
        child: Container(constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: onTap == null ? const Color(0xFF252525) : const Color(0xFF414141),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Icon(icon, size: 19, color: Colors.white),
            const SizedBox(width: 7),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NovaTokens.of(context);
    final title = item.name.replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '').trim();
    final genres = (item.genre ?? '').split(RegExp(r'[,;/]')).map((e) => e.trim())
        .where((e) => e.isNotEmpty).take(5).toList();
    return LayoutBuilder(builder: (context, constraints) {
      final bool narrow = constraints.maxWidth < 520;
      final double posterWidth = (constraints.maxWidth / 7.5).clamp(90.0, 150.0);
      final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: narrow ? 22 : 25, height: 1.1,
              fontWeight: FontWeight.w700, color: tokens.text))),
          if (item.rating != null && item.rating! > 0)
            Padding(padding: const EdgeInsets.only(left: 8, top: 3),
              child: Text(item.rating!.toStringAsFixed(1),
                style: const TextStyle(color: Color(0xFFF3B14A), fontSize: 18))),
        ]),
        const SizedBox(height: 10),
        Text(<String>[
          if (item.releaseDate?.trim().isNotEmpty == true) item.releaseDate!,
          if (item.duration?.trim().isNotEmpty == true) item.duration!,
          if (item.containerExtension?.trim().isNotEmpty == true) item.containerExtension!.toUpperCase(),
        ].join('  |  '), style: tokens.meta.copyWith(fontSize: 11)),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('Género:', style: TextStyle(color: tokens.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            if (genres.isEmpty) Text('No disponible', style: tokens.meta.copyWith(fontSize: 12)),
            for (final genre in genres) Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white38)),
              child: Text(genre, style: TextStyle(color: tokens.text, fontSize: 11))),
          ]),
        const SizedBox(height: 10),
        _field('Director', item.director, tokens),
        _field('Actores', item.cast, tokens, lines: 2),
        _field('Sinopsis', item.plot, tokens, lines: 3),
        Align(alignment: Alignment.centerRight, child: TextButton(
          onPressed: onMore, child: const Text('Más'))),
      ]);
      final preview = Semantics(label: 'Reproducir $title', button: true,
        child: NovaFocusable(onTap: onPlay, autofocus: true,
          borderRadius: BorderRadius.circular(3),
          child: AspectRatio(aspectRatio: 16 / 9, child: NovaArtwork(
            url: item.backdrop?.trim().isNotEmpty == true ? item.backdrop : item.icon,
            seed: item.favoriteKey, radius: 2, cacheWidth: 960,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.12),
              child: Center(child: loading ? const CircularProgressIndicator() :
                const Icon(Icons.play_circle_outline, color: Colors.white, size: 64))),
          )),
        ),
      );
      return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: <Widget>[
        Align(alignment: Alignment.centerLeft, child: IconButton(
          tooltip: 'Atrás', onPressed: onBack, icon: const Icon(Icons.arrow_back, size: 21))),
        if (error != null) Row(children: <Widget>[
          Expanded(child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
        if (narrow) ...<Widget>[info, const SizedBox(height: 12), preview]
        else Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Expanded(child: info), const SizedBox(width: 20), Expanded(child: preview),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) => Wrap(spacing: 10, runSpacing: 8, children: <Widget>[
          for (final action in <({IconData icon, String label, VoidCallback? tap})>[
            (icon: Icons.fullscreen, label: 'Pantalla completa', tap: onPlay),
            (icon: Icons.subtitles_outlined, label: 'Idioma', tap: onLanguage),
            (icon: Icons.high_quality_outlined, label: 'Resolución', tap: onQuality),
            (icon: favorite ? Icons.star : Icons.star_outline, label: favorite ? 'En favoritos' : 'Favorito', tap: onFavorite),
          ]) SizedBox(width: (box.maxWidth - (narrow ? 10 : 30)) / (narrow ? 2 : 4),
            child: _action(context, action.icon, action.label, action.tap)),
        ])),
        const SizedBox(height: 18),
        Text('Quizás te guste', style: TextStyle(color: tokens.text, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (recommendations.isEmpty)
          Text('No hay más películas disponibles en este catálogo.', style: tokens.meta)
        else SizedBox(height: posterWidth * 1.5 + 42, child: ListView.separated(
          scrollDirection: Axis.horizontal, itemCount: recommendations.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final other = recommendations[index];
            return SizedBox(width: posterWidth, child: NeonFocus(onTap: () => onRecommendation(other), radius: 3,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                Expanded(child: NovaArtwork(url: other.icon, seed: other.favoriteKey, radius: 2, cacheWidth: 320)),
                const SizedBox(height: 7),
                Text(other.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.text, fontSize: 11)),
              ]),
            ));
          },
        )),
      ]);
    });
  }
}
