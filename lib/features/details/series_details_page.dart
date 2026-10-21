import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/xtream_client.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playable_item.dart';
import '../../core/models/series_detail.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/nova_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/launcher.dart';
import '../../widgets/nova/nova_art.dart';
import '../../widgets/nova/nova_detail_parts.dart';
import '../../widgets/nova/nova_ui.dart';
import '../../widgets/state_views.dart';
import '../catalog/catalog_cache.dart';
import '../player/open_player.dart';

/// Ficha de una serie con el diseño NOVA de los diseños de referencia:
/// reproductor con el motivo de anillos, metadatos a la derecha, pestañas
/// «Episodios / Más como esto / Detalles» y lista de episodios con progreso.
class SeriesDetailsPage extends StatefulWidget {
  const SeriesDetailsPage({super.key, required this.item});

  final MediaItem item;

  @override
  State<SeriesDetailsPage> createState() => _SeriesDetailsPageState();
}

enum _SeriesTab { episodes, similar, details }

class _SeriesDetailsPageState extends State<SeriesDetailsPage> {
  SeriesDetail? _detail;
  bool _loading = true;
  String? _error;
  _SeriesTab _tab = _SeriesTab.episodes;
  int _season = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final AppState app = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final SeriesDetail detail = await app.client.seriesInfo(widget.item.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _season = detail.seasons.isEmpty ? 1 : detail.seasons.first.number;
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

  List<EpisodeInfo> get _seasonEpisodes {
    final SeriesDetail? detail = _detail;
    if (detail == null) return const <EpisodeInfo>[];
    final List<EpisodeInfo> episodes = detail.episodesOf(_season);
    return episodes.isEmpty ? detail.episodes : episodes;
  }

  Future<void> _playEpisode(
    EpisodeInfo episode,
    List<EpisodeInfo> seasonEpisodes,
  ) async {
    final AppState app = context.read<AppState>();
    final String? logo = app.iconUrl(widget.item);

    final List<PlayableItem> playlist = seasonEpisodes
        .map(
          (EpisodeInfo item) => PlayableItem(
            title: 'T${item.season}E${item.episodeNum.toString().padLeft(2, '0')}'
                ' · ${item.label}',
            url: app.api.seriesUrl(
              item.id,
              extension: item.containerExtension,
            ),
            subtitle: widget.item.name,
            logo: logo,
          ),
        )
        .toList();

    final int index = seasonEpisodes.indexOf(episode);
    await openPlayer(
      context,
      playlist: playlist,
      initialIndex: index < 0 ? 0 : index,
    );
  }

  Future<void> _playFirst() async {
    final SeriesDetail? detail = _detail;
    if (detail == null || detail.episodes.isEmpty) return;
    final EpisodeInfo episode = detail.episodes.first;
    final List<EpisodeInfo> season = detail.episodesOf(episode.season);
    setState(() {
      _season = episode.season;
      _tab = _SeriesTab.episodes;
    });
    await _playEpisode(
      episode,
      season.isEmpty ? <EpisodeInfo>[episode] : season,
    );
  }

  Future<void> _openTrailer() async {
    final String? trailer =
        _info('youtube_trailer') ?? widget.item.youtubeTrailer;
    if (trailer == null || trailer.trim().isEmpty) return;
    await openExternal(trailer.trim());
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: '${widget.item.name} — NOVA'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Título copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String? _info(String key) {
    final Map<String, dynamic>? map = _detail?.info;
    if (map == null) return null;
    final dynamic value = map[key];
    if (value == null) return null;
    final String text = value is String ? value : value.toString();
    return text.trim().isEmpty ? null : text.trim();
  }

  String _episodeDuration(EpisodeInfo episode) {
    final String? raw = episode.duration;
    if (raw == null || raw.trim().isEmpty) return '';
    final int? value = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    if (value == null) return raw;
    if (value <= 400) return '$value min';
    return formatDuration(Duration(seconds: value));
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final MediaItem item = widget.item;
    final bool wide =
        MediaQuery.sizeOf(context).width >= NovaBreakpoints.details;
    final bool isFavorite = app.isFavorite(item);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(wide ? 20 : 8, 12, wide ? 28 : 12, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Atrás',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  NovaSquareButton(
                    icon: isFavorite ? Icons.check : Icons.add,
                    tooltip: 'Mi lista',
                    selected: isFavorite,
                    size: 42,
                    onPressed: () => app.toggleFavorite(item),
                  ),
                  const SizedBox(width: 10),
                  NovaSquareButton(
                    icon: Icons.ios_share,
                    tooltip: 'Compartir',
                    size: 42,
                    onPressed: _share,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(wide ? 28 : 20, 6, wide ? 28 : 20, 0),
              child: wide
                  ? _buildWide(context, item)
                  : _buildNarrow(context, item),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- escritorio
  Widget _buildWide(BuildContext context, MediaItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              NovaPlayerHero(
                artworkUrl: item.backdrop ?? item.icon,
                seed: item.favoriteKey,
                height: NovaTokens.of(context).detailHero,
                trailerLabel: _trailerLabel,
                onPlay: _loading ? null : _playFirst,
                onTrailer: _openTrailer,
              ),
              const SizedBox(height: 26),
              _buildTabs(),
              const SizedBox(height: 18),
              _buildTabContent(item, wide: true),
            ],
          ),
        ),
        const SizedBox(width: 36),
        SizedBox(
          width: 380,
          child: _buildSidePanel(context, item, wide: true),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- móvil
  Widget _buildNarrow(BuildContext context, MediaItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: MediaQuery.sizeOf(context).width * 0.56,
          child: NovaPlayerHero(
            artworkUrl: item.backdrop ?? item.icon,
            seed: item.favoriteKey,
            height: double.infinity,
            trailerLabel: _trailerLabel,
            onPlay: _loading ? null : _playFirst,
            onTrailer: _openTrailer,
          ),
        ),
        const SizedBox(height: 20),
        _buildSidePanel(context, item, wide: false),
        const SizedBox(height: 22),
        _buildTabs(),
        const SizedBox(height: 16),
        _buildTabContent(item, wide: false),
      ],
    );
  }

  String get _trailerLabel {
    final String? trailer =
        _info('youtube_trailer') ?? widget.item.youtubeTrailer;
    return (trailer != null && trailer.trim().isNotEmpty) ? 'Tráiler' : '';
  }

  // -------------------------------------------------------- panel de metadatos
  Widget _buildSidePanel(
    BuildContext context,
    MediaItem item, {
    required bool wide,
  }) {
    final NovaTokens tokens = NovaTokens.of(context);
    final String brand = context.watch<ConfigController>().config.branding.appName.trim();
    final List<String> names = (_info('cast') ?? item.cast ?? '')
        .split(RegExp(r'[,\n]'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        NovaBadge(label: 'Original ${brand.isEmpty ? 'Nova' : brand}'),
        const SizedBox(height: 16),
        Text(
          item.name,
          style: wide ? tokens.heroTitle : tokens.heroTitleCompact,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: <Widget>[
            for (final String part in _metaParts(item))
              Text(part, style: tokens.meta),
          ],
        ),
        if (item.plot != null && item.plot!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(item.plot!, style: tokens.body),
        ],
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Expanded(
              child: NovaPrimaryButton(
                label: _playLabel,
                icon: Icons.play_arrow_rounded,
                onPressed: _loading ? null : _playFirst,
              ),
            ),
            const SizedBox(width: 10),
            NovaSquareButton(
              icon: Icons.add,
              tooltip: 'Mi lista',
              onPressed: () => context.read<AppState>().toggleFavorite(item),
            ),
            const SizedBox(width: 10),
            NovaSquareButton(
              icon: Icons.ios_share,
              tooltip: 'Compartir',
              onPressed: _share,
            ),
          ],
        ),
        const SizedBox(height: 24),
        NovaInfoTable(rows: _infoRows(item)),
        if (names.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          NovaCastRow(names: names),
        ],
      ],
    );
  }

  List<NovaInfoRow> _infoRows(MediaItem item) {
    return <NovaInfoRow>[
      (label: 'Género', value: _info('genre') ?? item.genre ?? '—'),
      (label: 'Audio', value: _info('audio') ?? '—'),
      (
        label: 'Subtítulos',
        value: _info('subtitles') ?? _info('subtitle') ?? '—',
      ),
      (label: 'Dirección', value: _info('director') ?? item.director ?? '—'),
      (
        label: 'Emisión',
        value: item.releaseDate ?? _info('releaseDate') ?? '—',
      ),
    ];
  }

  String get _playLabel {
    final SeriesDetail? detail = _detail;
    if (detail == null || detail.episodes.isEmpty) return 'Ver ahora';
    final EpisodeInfo first = detail.episodes.first;
    return 'Ver T${first.season} · E${first.episodeNum}';
  }

  List<String> _metaParts(MediaItem item) {
    final List<String> parts = <String>[];
    final int seasons = _detail?.seasons.length ?? 0;
    if (seasons > 0) {
      parts.add(seasons == 1 ? '1 temporada' : '$seasons temporadas');
    }
    final int episodes = _detail?.episodes.length ?? 0;
    if (episodes > 0) {
      parts.add(episodes == 1 ? '1 episodio' : '$episodes episodios');
    }
    if (item.episodeRunTime != null) parts.add('${item.episodeRunTime} min');
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

  // ------------------------------------------------------------------ pestañas
  Widget _buildTabs() {
    return NovaTabBar(
      labels: const <String>['Episodios', 'Más como esto', 'Detalles'],
      index: _tab.index,
      onSelected: (int index) =>
          setState(() => _tab = _SeriesTab.values[index]),
    );
  }

  Widget _buildTabContent(MediaItem item, {required bool wide}) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: LoadingView(message: 'Cargando episodios…'),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: ErrorView(message: _error!, onRetry: _load),
      );
    }

    switch (_tab) {
      case _SeriesTab.episodes:
        if (_detail == null || _detail!.episodes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: EmptyView(
              message: 'El panel no devolvió episodios para esta serie.',
              icon: Icons.video_settings_outlined,
            ),
          );
        }
        return _buildEpisodes(context, wide: wide);
      case _SeriesTab.similar:
        return _buildSimilar(context, item);
      case _SeriesTab.details:
        return _buildDetailsTab(context, item);
    }
  }

  Widget _buildEpisodes(BuildContext context, {required bool wide}) {
    final SeriesDetail detail = _detail!;
    final List<EpisodeInfo> episodes = _seasonEpisodes;
    final AppState app = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (detail.seasons.length > 1) ...<Widget>[
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: detail.seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final SeasonInfo season = detail.seasons[index];
                return ChoiceChip(
                  label: Text(season.title),
                  selected: season.number == _season,
                  onSelected: (_) => setState(() => _season = season.number),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        for (final EpisodeInfo episode in episodes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EpisodeRow(
              episode: episode,
              duration: _episodeDuration(episode),
              progress: _progressFor(app, episode),
              thumbnailWidth: wide ? 148 : 104,
              onTap: () => _playEpisode(episode, episodes),
            ),
          ),
      ],
    );
  }

  double _progressFor(AppState app, EpisodeInfo episode) {
    // Si la sesión se cierra mientras la ficha está abierta, no hay URL que
    // resolver y no debe romperse el pintado.
    if (!app.isLoggedIn) return 0;
    final String url = app.api.seriesUrl(
      episode.id,
      extension: episode.containerExtension,
    );
    return app.resumeFor('url:$url')?.progress ?? 0;
  }

  Widget _buildSimilar(BuildContext context, MediaItem item) {
    final AppState app = context.watch<AppState>();
    final List<MediaItem> pool = CatalogCache.downloaded(MediaKind.series)
        .where((MediaItem other) => other.favoriteKey != item.favoriteKey)
        .take(12)
        .toList();

    if (pool.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Text(
          'Este panel no devolvió más series en la misma lista.',
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
          builder: (_) => SeriesDetailsPage(item: pool[index]),
        ),
      ),
    );
  }

  Widget _buildDetailsTab(BuildContext context, MediaItem item) {
    final NovaTokens tokens = NovaTokens.of(context);
    final List<NovaInfoRow> rows = <NovaInfoRow>[
      (label: 'Título', value: item.name),
      (label: 'Género', value: _info('genre') ?? item.genre ?? '—'),
      (label: 'Año', value: item.releaseDate ?? _info('releaseDate') ?? '—'),
      (label: 'Nota', value: item.rating?.toStringAsFixed(1) ?? '—'),
      (label: 'Temporadas', value: '${_detail?.seasons.length ?? 0}'),
      (label: 'Episodios', value: '${_detail?.episodes.length ?? 0}'),
      (label: 'Dirección', value: _info('director') ?? item.director ?? '—'),
      (label: 'Reparto', value: _info('cast') ?? item.cast ?? '—'),
      (label: 'Audio', value: _info('audio') ?? '—'),
      (
        label: 'Subtítulos',
        value: _info('subtitles') ?? _info('subtitle') ?? '—',
      ),
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
}

// ------------------------------------------------------------------ episodio

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.duration,
    required this.progress,
    required this.thumbnailWidth,
    required this.onTap,
  });

  final EpisodeInfo episode;
  final String duration;
  final double progress;
  final double thumbnailWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.surfaceHigh,
          borderRadius: BorderRadius.circular(tokens.radius),
          border: Border.all(color: tokens.hairline),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Text(
                '${episode.episodeNum}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tokens.text.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: thumbnailWidth,
              height: thumbnailWidth * 0.56,
              child: NovaArtwork(
                url: episode.image,
                seed: '${episode.id}-${episode.title}',
                radius: 10,
                child: progress > 0
                    ? Padding(
                        padding: const EdgeInsets.only(
                          bottom: 4,
                          left: 4,
                          right: 4,
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: NovaProgressLine(value: progress),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    episode.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.cardTitle.copyWith(fontSize: 15),
                  ),
                  if (episode.plot != null &&
                      episode.plot!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      episode.plot!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.body.copyWith(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            if (duration.isNotEmpty) ...<Widget>[
              const SizedBox(width: 14),
              Text(duration, style: tokens.meta),
            ],
          ],
        ),
      ),
    );
  }
}
