import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/api/tmdb_client.dart';
import '../../core/api/xtream_client.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playable_item.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../widgets/nova/nova_art.dart';
import '../../widgets/nova/nova_detail_parts.dart';
import '../../widgets/nova/nova_ui.dart';
import '../../widgets/nova/nova3_movie_details.dart';
import '../../widgets/state_views.dart';
import '../catalog/catalog_cache.dart';
import '../player/open_player.dart';

/// Ficha de una película con el diseño NOVA: reproductor con anillos,
/// metadatos a la derecha, reparto circular y pestañas «Detalles / Más como
/// esto».
class VodDetailsPage extends StatefulWidget {
  const VodDetailsPage({super.key, required this.item});

  final MediaItem item;

  @override
  State<VodDetailsPage> createState() => _VodDetailsPageState();
}

enum _VodTab { details, similar }

class _VodDetailsPageState extends State<VodDetailsPage> {
  late MediaItem _item = widget.item;
  bool _loading = true;
  String? _error;
  _VodTab _tab = _VodTab.details;
  String? _tmdbTrailer;
  List<MediaItem> _recommendationPool = CatalogCache.downloaded(MediaKind.movie);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      if (context.read<ConfigController>().theme.isNova3) _loadRecommendations();
    });
  }

  Future<void> _load() async {
    final AppState app = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final MediaItem detailed = await app.client.vodInfo(widget.item.id);
      if (!mounted) return;
      setState(() {
        _item = detailed.copyWith(
          icon: detailed.icon ?? widget.item.icon,
          backdrop: detailed.backdrop ?? widget.item.backdrop,
          categoryId: detailed.categoryId ?? widget.item.categoryId,
          genre: detailed.genre ?? widget.item.genre,
          plot: detailed.plot ?? widget.item.plot,
          director: detailed.director ?? widget.item.director,
          cast: detailed.cast ?? widget.item.cast,
          rating: detailed.rating ?? widget.item.rating,
          releaseDate: detailed.releaseDate ?? widget.item.releaseDate,
          duration: detailed.duration ?? widget.item.duration,
          containerExtension: detailed.containerExtension ?? widget.item.containerExtension,
          name: detailed.name.isEmpty ? widget.item.name : detailed.name,
        );
        _loading = false;
      });
    } on XtreamException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadRecommendations() async {
    if (_recommendationPool.any((other) => other.favoriteKey != widget.item.favoriteKey)) return;
    try {
      final pool = await CatalogCache.items(context.read<AppState>().client, MediaKind.movie, null);
      if (mounted) setState(() => _recommendationPool = pool);
    } catch (_) {
      // La ficha y la reproducción siguen disponibles si falla este catálogo.
    }
  }

  Future<void> _showMore() => showDialog<void>(context: context,
    builder: (context) => AlertDialog(title: Text(cleanDetailName(_item.name)),
      content: SingleChildScrollView(child: Text(_item.plot?.trim().isNotEmpty == true
        ? _item.plot! : 'Sin sinopsis disponible.')),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]));

  Future<void> _showPlaybackInfo(bool language) => showDialog<void>(context: context,
    builder: (context) => AlertDialog(title: Text(language ? 'Idioma y subtítulos' : 'Resolución'),
      content: Text(language
        ? 'Las pistas disponibles se consultan al reproducir. Abre la película y usa el botón de audio y subtítulos del reproductor.'
        : 'Se reproduce la calidad enviada por tu proveedor. No se han recibido variantes de resolución para elegir en esta ficha.'),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        FilledButton(onPressed: () { Navigator.pop(context); _play(); }, child: const Text('Reproducir')),
      ]));

  Future<void> _play() async {
    final AppState app = context.read<AppState>();
    final PlayableItem? playable = app.playableFrom(_item);
    if (playable == null) return;
    await openPlayer(context, playlist: <PlayableItem>[playable]);
  }

  Future<void> _openTrailer() async {
    final String raw = (_item.youtubeTrailer ?? _tmdbTrailer ?? '').trim();
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta película no trae tráiler')),
        );
      }
      return;
    }
    final String? videoId = _youtubeId(raw);
    if (videoId == null) return;

    // WebView con pagina completa de YouTube (el /embed/ da error 153).
    final WebViewController controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    await controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (String url) {
        // Quita el silencio del autoplay y fuerza la reproduccion.
        controller.runJavaScript("""
          (function () {
            var v = document.querySelector('video');
            if (!v) return;
            v.muted = false;
            v.volume = 1.0;
            var p = v.play();
            if (p && p.catch) { p.catch(function () {}); }
          })();
        """);
      },
    ));
    await controller.loadRequest(Uri.parse(
        'https://www.youtube.com/watch?v=$videoId&autoplay=1&app=desktop'));

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Tráiler · ${cleanDetailName(_item.name)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: WebViewWidget(controller: controller),
            ),
          ],
        ),
      ),
    );
  }

  String? _youtubeId(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return null;
    // ID suelto de 11 caracteres.
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value)) return value;
    final RegExp re = RegExp(
        r'(?:youtu\.be/|youtube\.com/(?:watch\?v=|embed/|shorts/|live/))([A-Za-z0-9_-]{11})');
    return re.firstMatch(value)?.group(1);
  }


  /// Si el panel no trae tráiler, se resuelve con TMDB (necesita API key).
  Future<void> _resolveTmdbTrailer() async {
    if (_trailerUrl(_item.youtubeTrailer) != null) return;
    final String key =
        context.read<ConfigController>().config.tmdb.apiKey.trim();
    if (key.isEmpty) return;
    final int? year =
        int.tryParse((_item.releaseDate ?? '').split(RegExp(r'[-/]')).first);
    final String? trailer = await TmdbClient(apiKey: key)
        .trailerKey(title: _item.name, year: year);
    if (!mounted || trailer == null || trailer.isEmpty) return;
    setState(() => _tmdbTrailer = trailer);
  }


  String? _trailerUrl(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    // Normaliza siempre a https://www.youtube.com/watch?v=ID
    final String? id = _youtubeId(value);
    if (id != null) return 'https://www.youtube.com/watch?v=$id';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return null;
  }


  /// Quita el año final del nombre: "Masterplan (2026)" -> "Masterplan".
  String cleanDetailName(String name) =>
      name.replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '').trim();

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    if (context.watch<ConfigController>().theme.isNova3) {
      return Scaffold(backgroundColor: const Color(0xFF080808), body: SafeArea(
        child: FocusTraversalGroup(child: Nova3MovieDetails(
          item: _item, favorite: app.isFavorite(_item), loading: _loading,
          error: _error, onRetry: _load,
          recommendations: nova3MovieRecommendations(_item, _recommendationPool),
          onBack: () => Navigator.of(context).maybePop(),
          onPlay: _loading ? null : _play,
          onFavorite: () => app.toggleFavorite(_item),
          onLanguage: () => _showPlaybackInfo(true),
          onQuality: () => _showPlaybackInfo(false),
          onMore: _showMore,
          onRecommendation: (other) => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => VodDetailsPage(item: other))),
        )),
      ));
    }
    final bool wide =
        MediaQuery.sizeOf(context).width >= NovaBreakpoints.details;

    return Scaffold(
      backgroundColor: const Color(0xFF0C111B),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (!_loading) ...<Widget>[
            Opacity(
              opacity: 0.5,
              child: NovaArtwork(
                url: _backdropUrl(_item),
                seed: _item.favoriteKey,
                radius: 0,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[Color(0xF20C111B), Color(0xA60C111B)],
                ),
              ),
            ),
          ],
          CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      wide ? 20 : 8, 12, wide ? 28 : 12, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Atrás',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 20, 6, wide ? 28 : 20, 0),
                  child:
                      wide ? _buildWide(context, _item) : _buildNarrow(context, _item),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }

  String? _backdropUrl(MediaItem item) => item.backdrop ?? item.icon;

  String? _posterUrl(MediaItem item) => item.icon;

  Widget _buildWide(BuildContext context, MediaItem item) {
    final NovaTokens tokens = NovaTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 250,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: NovaArtwork(
              url: _posterUrl(item),
              seed: item.favoriteKey,
              radius: 14,
            ),
          ),
        ),
        const SizedBox(width: 34),
        Expanded(child: _buildInfo(context, item, tokens, wide: true)),
      ],
    );
  }

  Widget _buildNarrow(BuildContext context, MediaItem item) {
    final NovaTokens tokens = NovaTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(
          child: SizedBox(
            width: 150,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: NovaArtwork(
                url: _posterUrl(item),
                seed: item.favoriteKey,
                radius: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _buildInfo(context, item, tokens, wide: false),
      ],
    );
  }

  Widget _buildActions(BuildContext context, MediaItem item) {
    final bool isFavorite = context.watch<AppState>().isFavorite(item);
    // FocusTraversalGroup + fila explicita para que el mando recorra los
    // botones de izquierda a derecha de forma fiable.
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 240,
            child: NovaPrimaryButton(
              label: 'Reproducir ahora',
              icon: Icons.play_arrow_rounded,
              compact: true,
              autofocus: true,
              onPressed: _loading ? null : _play,
            ),
          ),
          NovaSquareButton(
            icon: isFavorite ? Icons.check : Icons.add,
            tooltip: 'Mi lista',
            selected: isFavorite,
            size: 46,
            onPressed: () => context.read<AppState>().toggleFavorite(item),
          ),
          NovaSquareButton(
            icon: Icons.movie_outlined,
            tooltip: 'Tráiler',
            size: 46,
            // Siempre enfocable: si no hay trailer, muestra un aviso.
            onPressed: _openTrailer,
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(
    BuildContext context,
    MediaItem item,
    NovaTokens tokens, {
    required bool wide,
  }) {
    final List<String> genres = (item.genre ?? '')
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    final double? vote =
        (item.rating != null && item.rating! > 0) ? item.rating : null;
    final String overview = item.plot ?? '';
    final List<String> cast = (item.cast ?? '')
        .split(RegExp(r'[,\n]'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .take(8)
        .toList();
    final int? year = int.tryParse(
        (item.releaseDate ?? '').split(RegExp(r'[-/]')).first);
    final String title = cleanDetailName(item.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          year != null ? '$title ($year)' : title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: wide ? tokens.heroTitle : tokens.heroTitleCompact,
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            if (vote != null && vote > 0) ...<Widget>[
              _RatingCircle(vote: vote),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: <Widget>[
                  if (item.duration != null &&
                      item.duration!.trim().isNotEmpty)
                    Text(item.duration!.trim(), style: tokens.meta),
                  if (item.releaseDate != null &&
                      item.releaseDate!.trim().isNotEmpty)
                    Text(item.releaseDate!.trim(), style: tokens.meta),
                  if (genres.isNotEmpty)
                    Text(genres.join(' · '), style: tokens.meta),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildActions(context, item),
        const SizedBox(height: 26),
        Text('Vista general', style: tokens.cardTitle),
        const SizedBox(height: 8),
        Text(
          overview.isNotEmpty ? overview : 'Sin sinopsis disponible.',
          style: tokens.body,
        ),
        if (cast.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          Text('Reparto', style: tokens.cardTitle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: <Widget>[
              for (final String name in cast) Text(name, style: tokens.meta),
            ],
          ),
        ],
      ],
    );
  }

  String get _trailerLabel {
    if (_trailerUrl(_item.youtubeTrailer) != null) return 'Tráiler';
    if (_trailerUrl(_tmdbTrailer) != null) return 'Tráiler';
    return '';
  }

  List<String> _metaParts(MediaItem item) {
    final List<String> parts = <String>[];
    if (item.duration != null && item.duration!.trim().isNotEmpty) {
      parts.add(item.duration!);
    }
    if (item.rating != null && item.rating! > 0) {
      parts.add('★ ${item.rating!.toStringAsFixed(1)}');
    }
    final String? genre = item.genre;
    if (genre != null && genre.trim().isNotEmpty) {
      parts.add(genre.split(',').first.trim());
    }
    final int? year = int.tryParse(
      (item.releaseDate ?? '').split(RegExp(r'[-/]')).first,
    );
    if (year != null && year > 1900) parts.add('$year');
    return parts;
  }

  Widget _buildTabs() {
    return NovaTabBar(
      labels: const <String>['Detalles', 'Más como esto'],
      index: _tab.index,
      onSelected: (int index) => setState(() => _tab = _VodTab.values[index]),
    );
  }

  Widget _buildTabContent(MediaItem item) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: ErrorView(message: _error!, onRetry: _load),
      );
    }

    switch (_tab) {
      case _VodTab.details:
        return _buildDetailsTab(context, item);
      case _VodTab.similar:
        return _buildSimilar(context, item);
    }
  }

  Widget _buildDetailsTab(BuildContext context, MediaItem item) {
    final NovaTokens tokens = NovaTokens.of(context);
    final List<NovaInfoRow> rows = <NovaInfoRow>[
      (label: 'Título', value: item.name),
      (label: 'Género', value: item.genre ?? '—'),
      (label: 'Año', value: item.releaseDate ?? '—'),
      (
        label: 'Duración',
        value: item.duration == null || item.duration!.isEmpty
            ? '—'
            : item.duration!,
      ),
      (
        label: 'Nota',
        value: item.rating == null || item.rating! <= 0
            ? '—'
            : formatRating(item.rating),
      ),
      (label: 'Dirección', value: item.director ?? '—'),
      (label: 'Reparto', value: item.cast ?? '—'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (item.plot != null && item.plot!.isNotEmpty) ...<Widget>[
          Text('Sinopsis', style: tokens.cardTitle),
          const SizedBox(height: 8),
          Text(item.plot!, style: tokens.body),
          const SizedBox(height: 20),
        ],
        NovaInfoTable(rows: rows),
      ],
    );
  }

  Widget _buildSimilar(BuildContext context, MediaItem item) {
    final AppState app = context.watch<AppState>();
    final List<MediaItem> pool = CatalogCache.downloaded(MediaKind.movie)
        .where((MediaItem other) => other.favoriteKey != item.favoriteKey)
        .take(12)
        .toList();

    if (pool.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Text(
          'Este panel no devolvió más películas en la misma lista.',
          style: NovaTokens.of(context).body,
        ),
      );
    }

    return NovaPosterWrap(
      items: <({String key, String name, String? icon})>[
        for (final MediaItem other in pool)
          (
            key: other.favoriteKey,
            name: other.name,
            icon: app.iconUrl(other),
          ),
      ],
      onOpen: (int index) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VodDetailsPage(item: pool[index]),
        ),
      ),
    );
  }
}

class _RatingCircle extends StatelessWidget {
  const _RatingCircle({required this.vote});

  final double vote;

  @override
  Widget build(BuildContext context) {
    final double pct = (vote / 10).clamp(0.0, 1.0);
    final Color color =
        pct >= 0.7 ? const Color(0xFF3DDC84) : (pct >= 0.4 ? const Color(0xFFFFC043) : const Color(0xFFFF5C5C));
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '${(vote * 10).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewCell extends StatelessWidget {
  const _CrewCell({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white54,
            ),
          ),
          const SizedBox(height: 2),
          Text(role, style: tokens.meta),
        ],
      ),
    );
  }
}
