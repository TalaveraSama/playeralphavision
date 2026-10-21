import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/tmdb_client.dart';
import '../core/config/config_controller.dart';
import '../core/models/media_item.dart';
import 'nova/nova_art.dart';

/// Imagen de una película/serie con **TMDB como fuente principal** y el póster
/// del panel Xtream como respaldo.
///
/// - Si hay `tmdb.apiKey` en la config, busca el póster/backdrop real de TMDB.
/// - Si no la hay (o no encuentra la peli), usa la imagen del panel.
/// - Cachea el resultado por nombre para no repetir peticiones.
class TmdbPoster extends StatefulWidget {
  const TmdbPoster({
    super.key,
    required this.item,
    this.radius = 14,
    this.fit = BoxFit.cover,
    this.preferBackdrop = false,
    this.child,
  });

  final MediaItem item;
  final double radius;
  final BoxFit fit;

  /// `true` para el hero (usa backdrop horizontal), `false` para carátulas.
  final bool preferBackdrop;
  final Widget? child;

  @override
  State<TmdbPoster> createState() => _TmdbPosterState();
}

class _TmdbPosterState extends State<TmdbPoster> {
  static final Map<String, TmdbArtwork?> _cache = <String, TmdbArtwork?>{};

  String? _tmdbUrl;
  bool _loaded = false;

  int? get _year {
    final String? date = widget.item.releaseDate;
    if (date == null || date.trim().isEmpty) return null;
    final String y = date.trim().split(RegExp(r'[-/]')).first;
    final int? v = int.tryParse(y);
    return (v != null && v >= 1900 && v <= 2100) ? v : null;
  }

  String get _cacheKey => '${widget.item.kind.name}|${widget.item.name}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TmdbPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.favoriteKey != widget.item.favoriteKey) {
      _loaded = false;
      _tmdbUrl = null;
      _load();
    }
  }

  Future<void> _load() async {
    // Los canales en vivo SIEMPRE usan el logo del panel (nunca TMDB).
    if (widget.item.kind == MediaKind.live) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final String apiKey =
        context.read<ConfigController>().config.tmdb.apiKey.trim();
    if (apiKey.isEmpty) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    if (_cache.containsKey(_cacheKey)) {
      final TmdbArtwork? art = _cache[_cacheKey];
      if (mounted) {
        setState(() {
          _tmdbUrl = _pick(art);
          _loaded = true;
        });
      }
      return;
    }
    final TmdbArtwork? art = await TmdbClient(apiKey: apiKey).artwork(
      title: widget.item.name,
      year: _year,
      isSeries: widget.item.kind == MediaKind.series,
    );
    _cache[_cacheKey] = art;
    if (!mounted) return;
    setState(() {
      _tmdbUrl = _pick(art);
      _loaded = true;
    });
  }

  String? _pick(TmdbArtwork? art) {
    if (art == null || art.isEmpty) return null;
    return widget.preferBackdrop
        ? (art.backdrop ?? art.poster)
        : (art.poster ?? art.backdrop);
  }

  @override
  Widget build(BuildContext context) {
    final String? tmdb = _tmdbUrl;
    if (tmdb != null && tmdb.isNotEmpty) {
      return NovaArtwork(
        url: tmdb,
        seed: widget.item.favoriteKey,
        radius: widget.radius,
        fit: widget.fit,
        child: widget.child,
      );
    }

    final String? fallback = widget.preferBackdrop
        ? ((widget.item.backdrop != null && widget.item.backdrop!.isNotEmpty)
            ? widget.item.backdrop
            : widget.item.icon)
        : widget.item.icon;

    return NovaArtwork(
      url: fallback,
      seed: widget.item.favoriteKey,
      radius: widget.radius,
      fit: widget.fit,
      child: widget.child,
    );
  }
}
