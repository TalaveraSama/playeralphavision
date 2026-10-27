import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/xtream_client.dart';
import '../../core/config/ads_config.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playable_item.dart';
import '../../core/models/resume_entry.dart';
import '../../core/models/xtream_category.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/nova_theme.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/media_grid.dart';
import '../../widgets/nova/nova_art.dart';
import '../../widgets/nova/nova_ui.dart';
import '../../widgets/nova/nova2_hero.dart';
import '../../widgets/state_views.dart';
import '../../widgets/tmdb_poster.dart';
import '../catalog/catalog_cache.dart';
import '../catalog/catalog_page.dart';
import '../details/series_details_page.dart';
import '../details/vod_details_page.dart';
import '../player/open_player.dart';
import '../search/search_page.dart';

/// Portada de descubrimiento del diseño NOVA («Inicio»).
///
/// En pantallas anchas reproduce el diseño de escritorio: héroe con el motivo
/// de anillos, «Continuar viendo», «En vivo ahora» y «Tendencias en tu país».
/// En el móvil usa la versión compacta con filtros Todo · Series · Películas ·
/// En vivo.
class NovaDiscoverPage extends StatefulWidget {
  const NovaDiscoverPage({super.key});

  @override
  State<NovaDiscoverPage> createState() => _NovaDiscoverPageState();
}

enum _FeedFilter { all, series, movies, live }

class _NovaDiscoverPageState extends State<NovaDiscoverPage> {
  List<MediaItem> _live = const <MediaItem>[];
  List<MediaItem> _movies = const <MediaItem>[];
  List<MediaItem> _series = const <MediaItem>[];
  List<XtreamCategory> _liveCategories = const <XtreamCategory>[];
  List<XtreamCategory> _seriesCategories = const <XtreamCategory>[];
  List<XtreamCategory> _movieCategories = const <XtreamCategory>[];
  bool _loading = true;
  String? _error;
  _FeedFilter _filter = _FeedFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final AppState app = context.read<AppState>();
    final bool showLive =
        context.read<ConfigController>().config.branding.showLiveSection;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<MediaItem> movies =
          await CatalogCache.items(app.client, MediaKind.movie, null);
      final List<MediaItem> series =
          await CatalogCache.items(app.client, MediaKind.series, null);
      List<MediaItem> live = const <MediaItem>[];
      List<XtreamCategory> categories = const <XtreamCategory>[];
      if (showLive) {
        live = await CatalogCache.items(app.client, MediaKind.live, null);
        categories = await CatalogCache.categories(app.client, MediaKind.live);
      }
      final List<XtreamCategory> seriesCats =
          await CatalogCache.categories(app.client, MediaKind.series);
      final List<XtreamCategory> movieCats =
          await CatalogCache.categories(app.client, MediaKind.movie);
      if (!mounted) return;
      setState(() {
        _movies = movies;
        _series = series;
        _live = live;
        _liveCategories = categories;
        _seriesCategories = seriesCats;
        _movieCategories = movieCats;
        _loading = false;
        _bannerSeed = DateTime.now().millisecondsSinceEpoch;
      });
    } on XtreamException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Error inesperado: $error';
        _loading = false;
      });
    }
  }

  // ------------------------------------------------------------- aperturas
  Future<void> _open(MediaItem item) async {
    final AppState app = context.read<AppState>();
    await app.addRecent(item);
    if (!mounted) return;

    switch (item.kind) {
      case MediaKind.series:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SeriesDetailsPage(item: item),
          ),
        );
      case MediaKind.movie:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VodDetailsPage(item: item),
          ),
        );
      case MediaKind.live:
        await _playLive(item);
    }
  }

  Future<void> _playLive(MediaItem item) async {
    final AppState app = context.read<AppState>();
    final List<MediaItem> source = _live.isEmpty ? <MediaItem>[item] : _live;
    final List<PlayableItem> playlist = app.playlistFrom(source);
    if (playlist.isEmpty) {
      final PlayableItem? single = app.playableFrom(item);
      if (single == null) return;
      await openPlayer(
        context,
        playlist: <PlayableItem>[single],
        mediaType: AdMediaType.live,
        title: item.name,
      );
      return;
    }
    final int index = source.indexWhere(
      (MediaItem other) => other.favoriteKey == item.favoriteKey,
    );
    await openPlayer(
      context,
      playlist: playlist,
      initialIndex: index < 0 ? 0 : index,
      mediaType: AdMediaType.live,
      title: item.name,
    );
  }

  Future<void> _resume(ResumeEntry entry) async {
    final AppState app = context.read<AppState>();
    final MediaItem? item = entry.item;
    if (item != null) {
      final PlayableItem? playable = app.playableFrom(item);
      if (playable != null) {
        await openPlayer(
          context,
          playlist: <PlayableItem>[playable],
          title: item.name,
        );
        return;
      }
    }
    final PlayableItem? playable = entry.playable;
    if (playable != null) {
      await openPlayer(
        context,
        playlist: <PlayableItem>[playable],
        mediaType: AdMediaType.series,
        title: playable.title,
      );
    }
  }

  Future<void> _toggleFavorite(MediaItem item) async {
    final AppState app = context.read<AppState>();
    final bool wasFavorite = app.isFavorite(item);
    await app.toggleFavorite(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasFavorite
              ? '«${item.name}» quitado de Mi lista'
              : '«${item.name}» añadido a Mi lista',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openSearch() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SearchPage()),
      );

  List<XtreamCategory> get _brandCategories {
    final List<XtreamCategory> all = <XtreamCategory>[
      ..._seriesCategories,
      ..._movieCategories,
    ];
    // Cuentas sin VOD (solo canales): usar las categorias del directo.
    if (all.isEmpty) all.addAll(_liveCategories);
    final Set<String> seen = <String>{};
    final List<XtreamCategory> out = <XtreamCategory>[];
    for (final XtreamCategory c in all) {
      final String key = c.name.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      out.add(c);
      if (out.length >= 8) break;
    }
    return out;
  }

  Future<void> _openCategory(XtreamCategory category) {
    final bool isSeries =
        _seriesCategories.any((XtreamCategory c) => c.id == category.id);
    final bool isLive =
        _liveCategories.any((XtreamCategory c) => c.id == category.id);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogPage(
          kind: isSeries
              ? MediaKind.series
              : (isLive ? MediaKind.live : MediaKind.movie),
          categoryHints: <String>[category.name],
        ),
      ),
    );
  }

  Future<void> _openLiveCatalog() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const CatalogPage(kind: MediaKind.live),
        ),
      );

  Future<void> _openAllResume() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NovaAllResumePage(onResume: _resume),
        ),
      );

  // ----------------------------------------------------------------- datos
  List<MediaItem> get _heroPool {
    switch (_filter) {
      case _FeedFilter.all:
        return <MediaItem>[..._series, ..._movies, ..._live];
      case _FeedFilter.series:
        return _series;
      case _FeedFilter.movies:
        return _movies;
      case _FeedFilter.live:
        return _live;
    }
  }

  // ------------------------------------------------------- banner destacado
  /// Semilla estable por carga: el modo aleatorio no cambia en cada repintado.
  int _bannerSeed = 1;

  /// Items del carrusel grande segun el panel: fuente (peliculas/series/vivo),
  /// filtro por categoria y seleccion manual, con modo automatico o aleatorio.
  List<MediaItem> get _bannerPool {
    final BrandingConfig branding =
        context.read<ConfigController>().config.branding;
    final String src = branding.heroSource.toLowerCase();
    List<MediaItem> pool;
    switch (src) {
      case 'movie':
      case 'movies':
        pool = List<MediaItem>.from(_movies);
        break;
      case 'series':
        pool = List<MediaItem>.from(_series);
        break;
      case 'live':
        pool = List<MediaItem>.from(_live);
        break;
      default:
        pool = <MediaItem>[..._movies, ..._series];
    }

    // Categorias indicadas (por id o por nombre) en cualquier tipo.
    final List<String> cats = branding.heroCategoryList;
    if (cats.isNotEmpty) {
      final Set<String> ids = <String>{};
      for (final List<XtreamCategory> list in <List<XtreamCategory>>[
        _movieCategories,
        _seriesCategories,
        _liveCategories,
      ]) {
        for (final XtreamCategory category in list) {
          if (cats.contains(category.id.toLowerCase()) ||
              cats.contains(category.name.toLowerCase())) {
            ids.add(category.id);
          }
        }
      }
      if (ids.isNotEmpty) {
        pool = pool
            .where((MediaItem item) => ids.contains(item.categoryId))
            .toList();
      }
    }

    // Seleccion manual: ids o titulos concretos.
    final List<String> manual = branding.heroItemList;
    if (manual.isNotEmpty) {
      final List<MediaItem> picked = pool
          .where((MediaItem item) =>
              manual.contains(item.id.toLowerCase()) ||
              manual.contains(item.name.toLowerCase()))
          .toList();
      if (picked.isNotEmpty) pool = picked;
    }

    final String mode = branding.heroMode.toLowerCase();
    if (pool.length > 1 && (mode == 'random' || mode == 'aleatorio')) {
      pool.shuffle(Random(_bannerSeed));
    }
    return pool;
  }

  MediaItem? get _heroItem {
    final List<MediaItem> pool = _heroPool;
    if (pool.isEmpty) return null;
    for (final MediaItem item in pool) {
      if ((item.backdrop ?? item.icon ?? '').isNotEmpty) return item;
    }
    return pool.first;
  }

  String? _categoryName(String? id) {
    if (id == null) return null;
    for (final XtreamCategory category in _liveCategories) {
      if (category.id == id) return category.name;
    }
    return null;
  }

  /// Mezcla de series y películas ordenada por nota (y por el orden del panel).
  List<MediaItem> get _trending {
    final List<MediaItem> pool = <MediaItem>[..._movies, ..._series];
    pool.sort((MediaItem a, MediaItem b) {
      final double left = a.rating ?? 0;
      final double right = b.rating ?? 0;
      if (left != right) return right.compareTo(left);
      return (a.order ?? 0).compareTo(b.order ?? 0);
    });
    return pool.take(12).toList();
  }

  /// Películas más recientes según la fecha en que se añadieron al panel.
  List<MediaItem> get _latestMovies {
    final List<MediaItem> pool = List<MediaItem>.from(_movies);
    pool.sort((MediaItem a, MediaItem b) {
      if (a.added != null && b.added != null) return b.added!.compareTo(a.added!);
      if (a.added != null) return -1;
      if (b.added != null) return 1;
      return (a.order ?? 0).compareTo(b.order ?? 0);
    });
    return pool;
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = NovaMetrics.of(context).isTv ||
        MediaQuery.sizeOf(context).width >= NovaBreakpoints.wide;
    final EdgeInsets padding = EdgeInsets.symmetric(horizontal: wide ? 32 : 20);

    if (_loading) {
      return const LoadingView(message: 'Cargando la portada…');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    final MediaItem? hero = _heroItem;
    if (context.watch<ConfigController>().theme.isNova2) {
      return _buildNova2(context, padding, hero);
    }
  
    if (!wide) {
      return _buildCompact(context, padding, hero);
    }

    return _buildWide(context, padding, hero);
  }

  Widget _buildNova2(BuildContext context, EdgeInsets padding, MediaItem? hero) {
    final bool tv = NovaMetrics.of(context).isTv;
    final bool wide = MediaQuery.sizeOf(context).width >= NovaBreakpoints.wide;
    final bool showLive = context.watch<ConfigController>().config.branding.showLiveSection;
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: <Widget>[
        if (!tv && !wide)
          Padding(
            padding: padding.copyWith(top: 16, bottom: 12),
            child: Row(children: <Widget>[
              const Expanded(child: NovaLogo(fontSize: 22)),
              if (context.watch<ConfigController>().config.features.search)
                NovaSquareButton(icon: Icons.search, tooltip: 'Buscar', onPressed: _openSearch),
            ]),
          ),
        if (hero != null)
          Padding(
            padding: padding.copyWith(top: 12, bottom: 16),
            child: Nova2Hero(item: hero, onOpen: () => _open(hero)),
          ),
        AdBanner(mediaType: AdMediaType.vod, margin: padding.copyWith(top: 12, bottom: 12)),
        if (_series.isNotEmpty)
          _PosterRow(title: 'Series para maratonear', items: _series.take(16).toList(),
            padding: padding, onOpen: _open, portrait: true),
        if (_latestMovies.isNotEmpty)
          _PosterRow(title: 'Una noche de cine', items: _latestMovies.take(16).toList(),
            padding: padding, onOpen: _open, portrait: true),
        if (_trending.isNotEmpty)
          _PosterRow(title: 'Historias que atrapan', items: _trending,
            padding: padding, onOpen: _open),
        if (showLive && _live.isNotEmpty)
          _PosterRow(title: 'En vivo ahora', items: _live.take(12).toList(),
            padding: padding, onOpen: _open, live: true),
      ],
    );
  }

  // ------------------------------------------------------------- escritorio
  Widget _buildWide(
    BuildContext context,
    EdgeInsets padding,
    MediaItem? hero,
  ) {
    final NovaTokens tokens = NovaTokens.of(context);

    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: padding.copyWith(top: 18),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              if (_heroPool.isNotEmpty || _latestMovies.isNotEmpty)
                _BigCarousel(
                  items: (_bannerPool.isNotEmpty
                          ? _bannerPool
                          : (_latestMovies.isNotEmpty ? _latestMovies : _heroPool))
                      .take(8)
                      .toList(),
                  onOpen: _open,
                ),
              const SizedBox(height: 26),
              AdBanner(
                mediaType: AdMediaType.vod,
                margin: const EdgeInsets.only(bottom: 34),
              ),
              if (_live.isNotEmpty) ...<Widget>[
                NovaSectionHeader(
                  title: 'En vivo ahora',
                  leadingDot: true,
                  actionLabel: 'Ver todo',
                  onAction: _openLiveCatalog,
                ),
                _LiveNowRow(
                  items: _live.take(3).toList(),
                  categoryName: _categoryName,
                  onOpen: _open,
                ),
                const SizedBox(height: 34),
              ],
              if (_trending.isNotEmpty) ...<Widget>[
                NovaSectionHeader(title: 'Tendencias en tu país'),
                _TrendGrid(
                  items: _trending,
                  onOpen: _open,
                  columns: (MediaQuery.sizeOf(context).width / 240)
                      .floor()
                      .clamp(2, 7)
                      .toInt(),
                ),
                const SizedBox(height: 40),
              ],
              _buildFooter(context, tokens),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, NovaTokens tokens) {
    final ConfigController config = context.watch<ConfigController>();
    final String supportUrl = config.config.branding.supportUrl.trim();
    const List<String> links = <String>[
      'Ayuda',
      'Dispositivos',
      'Términos',
      'Privacidad',
    ];

    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      child: Row(
        children: <Widget>[
          const NovaLogo(fontSize: 18),
          const Spacer(),
          for (final String link in links)
            TextButton(
              onPressed: supportUrl.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _NovaWebPage(
                            title: link,
                            url: supportUrl,
                          ),
                        ),
                      ),
              style: TextButton.styleFrom(
                foregroundColor: tokens.text.withValues(alpha: 0.7),
                disabledForegroundColor: tokens.text.withValues(alpha: 0.35),
              ),
              child: Text(link, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ móvil
  Widget _buildCompact(
    BuildContext context,
    EdgeInsets padding,
    MediaItem? hero,
  ) {
    final bool showLive =
        context.watch<ConfigController>().config.branding.showLiveSection;

    final ConfigController tabCfg = context.watch<ConfigController>();
    final String tabAllRaw = tabCfg.config.branding.tabAll.trim();
    final String tabSeriesRaw = tabCfg.config.branding.tabSeries.trim();
    final String tabMoviesRaw = tabCfg.config.branding.tabMovies.trim();
    final String tabLiveRaw = tabCfg.config.branding.tabLive.trim();
    final List<String> labels = <String>[
      tabAllRaw.isEmpty ? 'Todo' : tabAllRaw,
      tabSeriesRaw.isEmpty ? 'Series' : tabSeriesRaw,
      tabMoviesRaw.isEmpty ? 'Películas' : tabMoviesRaw,
      if (showLive) (tabLiveRaw.isEmpty ? 'En vivo' : tabLiveRaw),
    ];

    final bool showSeries =
        _filter == _FeedFilter.all || _filter == _FeedFilter.series;
    final bool showMovies =
        _filter == _FeedFilter.all || _filter == _FeedFilter.movies;
    final bool showLiveSection = showLive &&
        (_filter == _FeedFilter.all || _filter == _FeedFilter.live);

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: padding.copyWith(top: 18, bottom: 8),
            child: Row(
              children: <Widget>[
                const NovaLogo(fontSize: 19),
                const SizedBox(width: 14),
                Expanded(
                  child: NovaFilterBar(
                    labels: labels,
                    selectedIndex: _filter.index.clamp(0, labels.length - 1),
                    padding: EdgeInsets.zero,
                    onSelected: (int index) => setState(() {
                      _filter = _FeedFilter.values[index];
                    }),
                  ),
                ),
                IconButton(
                  tooltip: 'Buscar',
                  visualDensity: VisualDensity.compact,
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search, size: 20),
                ),
              ],
            ),
          ),
        ),
        if (_heroPool.isNotEmpty || _latestMovies.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: padding.copyWith(top: 10),
              child: _BigCarousel(
                items: (_bannerPool.isNotEmpty
                          ? _bannerPool
                          : (_latestMovies.isNotEmpty ? _latestMovies : _heroPool))
                    .take(8)
                    .toList(),
                onOpen: _open,
              ),
            ),
          ),
        if (showSeries && _series.isNotEmpty)
          SliverToBoxAdapter(
            child: _PosterRow(
              title: 'Series',
              items: _series.take(12).toList(),
              padding: padding,
              onOpen: _open,
            ),
          ),
        if (showMovies && _movies.isNotEmpty)
          SliverToBoxAdapter(
            child: _PosterRow(
              title: 'Películas',
              items: _movies.take(12).toList(),
              padding: padding,
              onOpen: _open,
            ),
          ),
        if (showLiveSection && _live.isNotEmpty)
          SliverToBoxAdapter(
            child: _PosterRow(
              title: 'En vivo ahora',
              items: _live.take(12).toList(),
              padding: padding,
              live: true,
              onOpen: _open,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// Piezas de metadatos reales del panel (año, duración, nota, género…).
  List<String> _metaPieces(MediaItem item) {
    final List<String> parts = <String>[];
    final String? date = item.releaseDate;
    if (date != null && date.trim().isNotEmpty) {
      final String year = date.trim().split(RegExp(r'[-/]')).first;
      if (year.length >= 4) parts.add(year);
    }
    if (item.kind == MediaKind.series && item.episodeRunTime != null) {
      parts.add('${item.episodeRunTime} min');
    }
    if (item.kind == MediaKind.movie && item.duration != null) {
      parts.add(item.duration!);
    }
    if (item.rating != null && item.rating! > 0) {
      parts.add('★ ${item.rating!.toStringAsFixed(1)}');
    }
    final String? genre = item.genre;
    if (genre != null && genre.trim().isNotEmpty) {
      parts.add(genre.split(',').first.trim());
    }
    return parts;
  }
}

// --------------------------------------------------------------------- héroe

class _WideHero extends StatelessWidget {
  const _WideHero({
    required this.item,
    required this.isFavorite,
    required this.onPlay,
    required this.onToggleFavorite,
  });

  final MediaItem item;
  final bool isFavorite;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final List<String> meta = _metaPieces(item);
    final String brand = context.watch<ConfigController>().config.branding.appName.trim();

    return SizedBox(
      height: NovaTokens.of(context).heroHeightWide,
      child: NovaArtwork(
        url: item.backdrop ?? item.icon,
        seed: item.favoriteKey,
        radius: 20,
        rings: 3,
        ringAlignment: const Alignment(0.6, -0.15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                tokens.background.withValues(alpha: 0.94),
                tokens.background.withValues(alpha: 0.72),
                tokens.background.withValues(alpha: 0.10),
              ],
              stops: const <double>[0.0, 0.45, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(44, 40, 44, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          NovaBadge(label: 'Original ${brand.isEmpty ? 'Nova' : brand}'),
                          const SizedBox(width: 14),
                          Text(
                            'Estreno de temporada',
                            style: tokens.meta,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.heroTitle,
                      ),
                      if (meta.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        _MetaLine(parts: meta, style: tokens.meta),
                      ],
                      if (item.plot != null && item.plot!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          item.plot!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.body,
                        ),
                      ],
                      const SizedBox(height: 26),
                      Row(
                        children: <Widget>[
                          NovaPrimaryButton(
                            label: 'Ver ahora',
                            icon: Icons.play_arrow_rounded,
                            onPressed: onPlay,
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: onToggleFavorite,
                              icon: Icon(
                                isFavorite ? Icons.check : Icons.add,
                                size: 18,
                              ),
                              label: const Text('Mi lista'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: tokens.text,
                                side: BorderSide(color: tokens.hairline),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _metaPieces(MediaItem item) {
    final List<String> parts = <String>[];
    final String? date = item.releaseDate;
    if (date != null && date.trim().isNotEmpty) {
      final String year = date.trim().split(RegExp(r'[-/]')).first;
      if (year.length >= 4) parts.add(year);
    }
    if (item.episodeRunTime != null) parts.add('${item.episodeRunTime} min');
    if (item.duration != null) parts.add(item.duration!);
    if (item.rating != null && item.rating! > 0) {
      parts.add('★ ${item.rating!.toStringAsFixed(1)}');
    }
    final String? genre = item.genre;
    if (genre != null && genre.trim().isNotEmpty) {
      parts.add(genre.split(',').first.trim());
    }
    return parts;
  }
}

class _CompactHero extends StatelessWidget {
  const _CompactHero({
    required this.item,
    required this.isFavorite,
    required this.meta,
    required this.onPlay,
    required this.onToggleFavorite,
  });

  final MediaItem item;
  final bool isFavorite;
  final List<String> meta;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final String brand = context.watch<ConfigController>().config.branding.appName.trim();

    return SizedBox(
      height: NovaTokens.of(context).heroHeightCompact,
      child: NovaArtwork(
        url: item.backdrop ?? item.icon,
        seed: item.favoriteKey,
        radius: 18,
        rings: 3,
        ringAlignment: const Alignment(0.55, -0.35),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                tokens.background.withValues(alpha: 0.10),
                tokens.background.withValues(alpha: 0.80),
                tokens.background.withValues(alpha: 0.96),
              ],
              stops: const <double>[0.0, 0.62, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                NovaBadge(label: 'Original ${brand.isEmpty ? 'Nova' : brand}'),
                const SizedBox(height: 12),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.heroTitleCompact,
                ),
                if (meta.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _MetaLine(parts: meta, style: tokens.meta),
                ],
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: NovaPrimaryButton(
                          label: 'Ver ahora',
                          icon: Icons.play_arrow_rounded,
                          onPressed: onPlay,
                          compact: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    NovaSquareButton(
                      icon: isFavorite ? Icons.check : Icons.add,
                      tooltip: 'Mi lista',
                      selected: isFavorite,
                      size: 46,
                      onPressed: onToggleFavorite,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Línea de metadatos separada por puntos.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.parts, required this.style});

  final List<String> parts;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        for (final String part in parts) Text(part, style: style),
      ],
    );
  }
}

// ----------------------------------------------------------- continuar viendo

class _ContinueRow extends StatelessWidget {
  const _ContinueRow({
    required this.entries,
    required this.onResume,
    this.cardWidth = 268,
    this.cardHeight = 172,
    this.horizontalPadding = 0,
  });

  final List<ResumeEntry> entries;
  final void Function(ResumeEntry entry) onResume;
  final double cardWidth;
  final double cardHeight;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight + 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (BuildContext context, int index) => SizedBox(
          width: cardWidth,
          child: _ResumeTile(entry: entries[index], onResume: onResume),
        ),
      ),
    );
  }
}

/// Tarjeta de una entrada de «Continuar viendo» (carátula + progreso).
class _ResumeTile extends StatelessWidget {
  const _ResumeTile({required this.entry, required this.onResume});

  final ResumeEntry entry;
  final void Function(ResumeEntry entry) onResume;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final String subtitle = <String>[
      if (entry.subtitle != null && entry.subtitle!.isNotEmpty) entry.subtitle!,
      if (entry.timeLabel.isNotEmpty) entry.timeLabel,
    ].join(' · ');

    return NeonFocus(
      onTap: () => onResume(entry),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: NovaArtwork(
              url: entry.image,
              seed: entry.key,
              radius: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      NovaProgressLine(value: entry.progress),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle.isEmpty ? 'A medio ver' : subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.meta,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- en vivo ahora

class _LiveNowRow extends StatelessWidget {
  const _LiveNowRow({
    required this.items,
    required this.categoryName,
    required this.onOpen,
  });

  final List<MediaItem> items;
  final String? Function(String? id) categoryName;
  final void Function(MediaItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns =
            (constraints.maxWidth / 420).floor().clamp(1, 4).toInt();
        final double spacing = 18;
        final double width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 20,
          children: <Widget>[
            for (final MediaItem item in items)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InkWell(
                      onTap: () => onOpen(item),
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: NovaArtwork(
                          url: item.icon,
                          seed: item.favoriteKey,
                          radius: 14,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.68),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  const _LiveFlag(),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _subtitleFor(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.meta,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _subtitleFor(MediaItem item) {
    final String? category = categoryName(item.categoryId);
    if (category == null || category.isEmpty) return 'En directo ahora';
    return 'Ahora: $category · En directo';
  }
}

/// Insignia «EN VIVO» que va sobre las tarjetas de directo.
class _LiveFlag extends StatelessWidget {
  const _LiveFlag();

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    return NovaBadge(
      label: 'En vivo',
      background: tokens.live,
      foreground: Colors.white,
      dot: true,
    );
  }
}

// ---------------------------------------------------------------- tendencias

class _TrendGrid extends StatelessWidget {
  const _TrendGrid({
    required this.items,
    required this.onOpen,
    this.columns = 6,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item) onOpen;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int count = columns.clamp(2, 8).toInt();
        final double spacing = 16;
        final double width =
            (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: 20,
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              SizedBox(
                width: width,
                child: InkWell(
                  onTap: () => onOpen(items[i]),
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 0.66,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: NovaArtwork(
                            url: items[i].icon,
                            seed: items[i].favoriteKey,
                            radius: 14,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[
                                    Colors.black.withValues(alpha: 0.10),
                                    Colors.black.withValues(alpha: 0.62),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          top: 6,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 58,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: tokens.text.withValues(alpha: 0.88),
                              shadows: const <Shadow>[
                                Shadow(blurRadius: 12, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: Text(
                            items[i].name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------- fila de móvil

/// Quita el año del nombre: "Spenser: confidencial (2020)" -> "Spenser: confidencial".
String cleanMediaName(String name) =>
    name.replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '').trim();

class _PosterRow extends StatelessWidget {
  const _PosterRow({
    required this.title,
    required this.items,
    required this.padding,
    required this.onOpen,
    this.live = false,
    this.portrait = false,
  });

  final String title;
  final List<MediaItem> items;
  final EdgeInsets padding;
  final void Function(MediaItem item) onOpen;
  final bool live;
  final bool portrait;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final double width = portrait ? (tokens.isTv ? 156 : 138) : 210;

    return Padding(
      padding: padding.copyWith(top: portrait ? 28 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NovaSectionHeader(
            title: title,
            leadingDot: live,
            padding: EdgeInsets.zero,
          ),
          SizedBox(
            height: portrait ? width * 1.5 + 48 : 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                final MediaItem item = items[index];
                return SizedBox(
                  width: width,
                  child: NeonFocus(
                    onTap: () => onOpen(item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: NovaArtwork(
                            url: item.icon,
                            seed: item.favoriteKey,
                            radius: 14,
                            fit: BoxFit.cover,
                            child: live
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: _LiveFlag(),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cleanMediaName(item.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.cardTitle,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Página con todas las entradas de «Continuar viendo».
class NovaAllResumePage extends StatelessWidget {
  const NovaAllResumePage({super.key, required this.onResume});

  final void Function(ResumeEntry entry) onResume;

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final List<ResumeEntry> entries = app.continueWatching;
    final bool wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      appBar: AppBar(title: const Text('Continuar viendo')),
      body: entries.isEmpty
          ? const EmptyView(
              message: 'Todavía no has empezado nada.',
              icon: Icons.play_circle_outline,
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: wide ? 320 : 240,
                mainAxisSpacing: 18,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: entries.length,
              itemBuilder: (BuildContext context, int index) => _ResumeTile(
                entry: entries[index],
                onResume: onResume,
              ),
            ),
    );
  }
}

/// Visor sencillo para los enlaces legales del pie.
class _NovaWebPage extends StatelessWidget {
  const _NovaWebPage({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(url, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              'Configura la dirección en el panel de administración '
              '(marca → Soporte) para enlazar la página real.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------- carrusel grande (auto)
/// Carrusel editorial; sin avance automático con mando o movimiento reducido.




class _BigCarousel extends StatefulWidget {
  const _BigCarousel({required this.items, required this.onOpen});

  final List<MediaItem> items;
  final ValueChanged<MediaItem> onOpen;

  @override
  State<_BigCarousel> createState() => _BigCarouselState();
}

class _BigCarouselState extends State<_BigCarousel> {
  final CarouselController _controller = CarouselController();
  Timer? _timer;
  int _page = 0;
  late List<MediaItem> _items;

  @override
  void initState() {
    super.initState();
    // Orden aleatorio de las ultimas agregadas.
    _items = List<MediaItem>.of(widget.items);
    // Avance automatico: estilo carrusel, una ficha cada 5 s.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _items.length < 2 ||
          NovaMetrics.of(context).isTv ||
          MediaQuery.disableAnimationsOf(context) ||
          !TickerMode.of(context)) return;
      _page = (_page + 1) % _items.length;
      try {
        _controller.animateToItem(
          _page,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut,
        );
      } catch (_) {}
    });
  }

  @override
  void didUpdateWidget(covariant _BigCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mantener el orden mientras se navega; actualizar al cambiar el catálogo.
    if (oldWidget.items.map((e) => e.favoriteKey).join('|') !=
        widget.items.map((e) => e.favoriteKey).join('|')) {
      _items = List<MediaItem>.of(widget.items);
      _page = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _subtitle(MediaItem item) {
    final List<String> parts = <String>[];
    final String? date = item.releaseDate;
    if (date != null && date.trim().isNotEmpty) {
      final String year = date.trim().split(RegExp(r'[-/]')).first;
      if (year.length >= 4) parts.add(year);
    }
    switch (item.kind) {
      case MediaKind.series:
        parts.add('Serie');
      case MediaKind.movie:
        parts.add('Película');
      case MediaKind.live:
        parts.add('En vivo');
    }
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final Size screen = MediaQuery.sizeOf(context);
    final bool tv = NovaMetrics.of(context).isTv;
    final double h = (screen.height * (tv ? 0.48 : 0.36))
        .clamp(tv ? 200.0 : 180.0, 400.0);
    final double w = tv ? h * 16 / 9 : (screen.width - 48).clamp(240.0, 640.0);
    return SizedBox(
      height: h,
      child: CarouselView(
        controller: _controller,
        itemExtent: w + 16,
        shrinkExtent: w * 0.72,
        itemSnapping: true,
        children: _items
            .map(
              (MediaItem item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: NeonFocus(
                  onTap: () => widget.onOpen(item),
                  radius: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        NovaArtwork(
                          url: (item.backdrop != null &&
                                  item.backdrop!.isNotEmpty)
                              ? item.backdrop
                              : item.icon,
                          seed: item.favoriteKey,
                          radius: 16,
                          fit: BoxFit.cover,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Colors.transparent,
                                Color(0xE60C111B)
                              ],
                              stops: <double>[0.45, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                cleanMediaName(item.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: tv ? 30 : 23,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _subtitle(item),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Tiles de categorías (marcas) al estilo Disney+.
class _CategoryTiles extends StatelessWidget {
  const _CategoryTiles({
    required this.categories,
    required this.onOpen,
    required this.padding,
  });

  final List<XtreamCategory> categories;
  final void Function(XtreamCategory category) onOpen;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (BuildContext context, int index) {
          final XtreamCategory c = categories[index];
          return NeonFocus(
            onTap: () => onOpen(c),
            radius: 14,
            child: Container(
              width: 132,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: NovaTokens.of(context).surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              alignment: Alignment.center,
              child: Text(
                c.name.toUpperCase(),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

