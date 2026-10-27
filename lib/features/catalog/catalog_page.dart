import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ads/ad_engine.dart' show foldAdText;
import '../../core/api/xtream_client.dart';
import '../../core/config/ads_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playable_item.dart';
import '../../core/models/resume_entry.dart';
import '../../core/models/xtream_category.dart';
import '../../core/state/app_state.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/media_grid.dart';
import '../../widgets/state_views.dart';
import '../../widgets/nova/nova3_dashboard.dart';
import '../details/series_details_page.dart';
import '../details/vod_details_page.dart';
import '../player/open_player.dart';
import '../search/search_page.dart';
import 'catalog_cache.dart';
import 'catalog_rows.dart';
import 'category_grid_page.dart';

/// Pantalla de catálogo reutilizada para directo, películas y series.
///
/// Dibuja filas horizontales (tema `rows`, estilo Netflix) o una rejilla
/// (tema `grid`) según la configuración de marca.
class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.kind,
    this.embedded = false,
    this.categoryHints = const <String>[],
    this.nova3Explore = false,
  });

  final MediaKind kind;
  final bool nova3Explore;

  /// Sin barra de aplicación propia: la portada NOVA ya pinta la navegación
  /// superior y la página solo aporta cabecera, filtros y rejilla.
  final bool embedded;

  /// Nombres de categoría que se preseleccionan al abrir (por ejemplo
  /// «Deportes» o «Infantil» desde la barra superior del diseño NOVA).
  final List<String> categoryHints;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage>
    with AutomaticKeepAliveClientMixin {
  List<XtreamCategory> _categories = const <XtreamCategory>[];
  List<MediaItem> _items = const <MediaItem>[];
  String? _categoryId;
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll({bool force = false}) async {
    final AppState app = context.read<AppState>();
    final int request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<XtreamCategory> categories =
          await CatalogCache.categories(app.client, widget.kind, force: force);
      final List<MediaItem> items = await CatalogCache.items(
        app.client,
        widget.kind,
        _categoryId,
        force: force,
      );
      if (!mounted || request != _request) return;

      // «Deportes», «Infantil»…: la portada NOVA abre el catálogo ya filtrado
      // por la categoría que corresponda al botón pulsado.
      final String? hint = _categoryId == null ? _matchHint(categories) : null;
      if (hint != null) {
        final List<MediaItem> filtered =
            await CatalogCache.items(app.client, widget.kind, hint);
        if (!mounted || request != _request) return;
        setState(() {
          _categories = categories;
          _items = filtered;
          _categoryId = hint;
          _loading = false;
        });
        return;
      }

      setState(() {
        _categories = categories;
        _items = items;
        _loading = false;
      });
    } on XtreamException catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = 'Error inesperado: $error';
        _loading = false;
      });
    }
  }

  Future<void> _selectCategory(String? categoryId) async {
    if (_categoryId == categoryId) return;
    final AppState app = context.read<AppState>();
    final int request = ++_request;
    setState(() {
      _categoryId = categoryId;
      _loading = true;
      _error = null;
    });

    try {
      final List<MediaItem> items =
          await CatalogCache.items(app.client, widget.kind, categoryId);
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on XtreamException catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// Primera categoría que encaja con alguna de las pistas del botón pulsado.
  String? _matchHint(List<XtreamCategory> categories) {
    if (widget.categoryHints.isEmpty) return null;
    for (final String hint in widget.categoryHints) {
      final String needle = foldAdText(hint);
      if (needle.isEmpty) continue;
      for (final XtreamCategory category in categories) {
        if (foldAdText(category.name).contains(needle)) return category.id;
      }
    }
    return null;
  }

  /// Playlist reproducible y posición del elemento pulsado.
  ///
  /// [pool] permite limitar la lista al conjunto desde el que se abrió (por
  /// ejemplo una categoría), de modo que "siguiente canal" no salte a otra.
  ({List<PlayableItem> playlist, int index}) _buildPlaylist(
    MediaItem tapped, [
    List<MediaItem>? pool,
  ]) {
    final AppState app = context.read<AppState>();
    final List<MediaItem> source = pool ?? _items;
    final List<PlayableItem> playlist = <PlayableItem>[];
    int start = 0;
    for (int i = 0; i < source.length; i++) {
      final MediaItem current = source[i];
      final PlayableItem? playable = app.playableFrom(current);
      if (playable == null) continue;
      if (current.favoriteKey == tapped.favoriteKey) start = playlist.length;
      playlist.add(playable);
    }
    return (playlist: playlist, index: start);
  }

  Future<void> _openItem(
    MediaItem item,
    int index, [
    List<MediaItem>? pool,
  ]) async {
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
        final ({List<PlayableItem> playlist, int index}) result =
            _buildPlaylist(item, pool);
        if (result.playlist.isEmpty) return;
        await openPlayer(
          context,
          playlist: result.playlist,
          initialIndex: result.index,
          mediaType: AdMediaType.live,
          title: item.name,
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
              ? '«${item.name}» quitado de favoritos'
              : '«${item.name}» añadido a favoritos',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openSearch() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchPage()),
    );
  }

  Future<void> _openSeeAll(CategoryGroup group) {
    final AppState app = context.read<AppState>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryGridPage(
          title: group.title,
          items: group.items,
          favoriteKeys:
              app.favorites.map((MediaItem item) => item.favoriteKey).toSet(),
          iconUrlBuilder: app.iconUrl,
          onOpen: (MediaItem item, int index) =>
              _openItem(item, index, group.items),
          onToggleFavorite: _toggleFavorite,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final AppState app = context.watch<AppState>();
    final ConfigController configController = context.watch<ConfigController>();
    final Set<String> favoriteKeys =
        app.favorites.map((MediaItem item) => item.favoriteKey).toSet();
    final bool canSearch = configController.config.features.search;

    if (configController.theme.isNova3 && widget.kind != MediaKind.live) {
      if (_loading) return const LoadingView(message: 'Cargando catálogo…');
      if (_error != null) return ErrorView(message: _error!, onRetry: () => _loadAll());
      final List<Nova3Collection> collections = <Nova3Collection>[];
      for (final category in _categories) {
        final entries = _items.where((item) => item.categoryId == category.id).take(36).toList();
        if (entries.isNotEmpty) collections.add(Nova3Collection(title: category.name, items: entries));
        if (collections.length >= 15) break;
      }
      return Nova3Dashboard(
        key: ValueKey<String>('nova3-${widget.kind.name}-${widget.categoryHints.join()}'),
        items: _items,
        explore: widget.nova3Explore,
        collections: collections,
        onOpen: (item) => _openItem(item, _items.indexOf(item)),
      );
    }
    if (configController.theme.isRows) {
      return Scaffold(
        body: _buildRowsBody(configController, app, favoriteKeys, canSearch),
      );
    }
    return _buildGridScaffold(configController, favoriteKeys, canSearch);
  }

  Widget _buildRowsBody(
    ConfigController configController,
    AppState app,
    Set<String> favoriteKeys,
    bool canSearch,
  ) {
    if (_loading) {
      return const LoadingView(message: 'Cargando catálogo…');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: () => _loadAll());
    }
    if (_items.isEmpty) {
      return EmptyView(
        message: 'Este panel no devolvió ${widget.kind.label.toLowerCase()}.',
        icon: Icons.tv_off_outlined,
      );
    }

    return CatalogRowsView(
      kind: widget.kind,
      branding: configController.config.branding,
      spec: configController.theme,
      items: _items,
      categories: _categories,
      favoriteKeys: favoriteKeys,
      iconUrlBuilder: app.iconUrl,
      onOpen: _openItem,
      onToggleFavorite: _toggleFavorite,
      onSeeAll: _openSeeAll,
      continueWatching: app.continueWatching,
      onResume: _resumeEntry,
      onSearch: canSearch ? _openSearch : null,
      onRefresh: () => _loadAll(force: true),
    );
  }

  bool get _compactLive => widget.kind == MediaKind.live &&
      context.read<ConfigController>().theme.isNova3;

  Widget _buildGridScaffold(
    ConfigController configController,
    Set<String> favoriteKeys,
    bool canSearch,
  ) {
    final ThemeData theme = Theme.of(context);

    String? countLabel;
    if (!_loading && _error == null) {
      final int count = _items.length;
      final String noun;
      if (widget.kind == MediaKind.live) {
        noun = count == 1 ? 'canal' : 'canales';
      } else {
        noun = count == 1 ? 'título' : 'títulos';
      }
      countLabel = '$count $noun';
    }

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(widget.kind.label),
                  if (countLabel != null)
                    Text(countLabel, style: theme.textTheme.bodySmall),
                ],
              ),
              actions: <Widget>[
                if (canSearch)
                  IconButton(
                    tooltip: 'Buscar',
                    onPressed: _openSearch,
                    icon: const Icon(Icons.search),
                  ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: () => _loadAll(force: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      body: Column(
        children: <Widget>[
          if (widget.embedded) _buildEmbeddedHeader(theme, countLabel, canSearch),
          if (_categories.isNotEmpty) _buildCategoryBar(),
          AdBanner(
            mediaType: _adMediaType,
            categoryName: _selectedCategoryName,
            title: widget.kind.label,
          ),
          Expanded(child: _buildGridBody(favoriteKeys)),
        ],
      ),
    );
  }

  /// Cabecera propia cuando la página va dentro de la portada NOVA (sin AppBar).
  Widget _buildEmbeddedHeader(
    ThemeData theme,
    String? countLabel,
    bool canSearch,
  ) {
    return Padding(
      padding: _compactLive
          ? const EdgeInsets.fromLTRB(22.4, 8, 16, 8)
          : const EdgeInsets.fromLTRB(28, 22, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.kind.label,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800,
                        fontSize: _compactLive ? (theme.textTheme.headlineSmall?.fontSize ?? 24) * 0.8 : null),
                ),
                if (countLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(countLabel, style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: _compactLive ? (theme.textTheme.bodySmall?.fontSize ?? 12) * 0.8 : null)),
                  ),
              ],
            ),
          ),
          if (canSearch && !_compactLive)
            IconButton(
              tooltip: 'Buscar',
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => _loadAll(force: true),
            iconSize: _compactLive ? 19.2 : 24,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  /// Tipo de contenido para segmentar los anuncios.
  AdMediaType get _adMediaType {
    switch (widget.kind) {
      case MediaKind.live:
        return AdMediaType.live;
      case MediaKind.movie:
        return AdMediaType.vod;
      case MediaKind.series:
        return AdMediaType.series;
    }
  }

  String? get _selectedCategoryName {
    final String? id = _categoryId;
    if (id == null) return null;
    for (final XtreamCategory category in _categories) {
      if (category.id == id) return category.name;
    }
    return null;
  }

  /// Reanuda un elemento a medio ver desde la fila «Continuar viendo».
  Future<void> _resumeEntry(ResumeEntry entry) async {
    final AppState app = context.read<AppState>();

    final MediaItem? item = entry.item;
    if (item != null) {
      final PlayableItem? playable = app.playableFrom(item);
      if (playable != null) {
        await openPlayer(
          context,
          playlist: <PlayableItem>[playable],
          mediaType: _adMediaType,
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

  Widget _buildCategoryBar() {
    return SizedBox(
      height: _compactLive ? 40 : 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: widget.embedded ? (_compactLive ? 22.4 : 28) : 12),
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return ChoiceChip(
              label: const Text('Todas'),
              visualDensity: _compactLive ? VisualDensity.compact : null,
              labelStyle: _compactLive ? const TextStyle(fontSize: 11.2) : null,
              padding: _compactLive ? const EdgeInsets.symmetric(horizontal: 6.4) : null,
              selected: _categoryId == null,
              onSelected: (_) => _selectCategory(null),
            );
          }
          final XtreamCategory category = _categories[index - 1];
          return ChoiceChip(
            label: Text(category.name),
            visualDensity: _compactLive ? VisualDensity.compact : null,
            labelStyle: _compactLive ? const TextStyle(fontSize: 11.2) : null,
            padding: _compactLive ? const EdgeInsets.symmetric(horizontal: 6.4) : null,
            selected: _categoryId == category.id,
            onSelected: (_) => _selectCategory(category.id),
          );
        },
      ),
    );
  }

  Widget _buildGridBody(Set<String> favoriteKeys) {
    if (_loading) return const LoadingView(message: 'Cargando catálogo…');
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: () => _loadAll());
    }
    if (_items.isEmpty) {
      return EmptyView(
        message: 'Este panel no devolvió ${widget.kind.label.toLowerCase()} '
            'para la categoría seleccionada.',
        icon: Icons.tv_off_outlined,
      );
    }
    final AppState app = context.read<AppState>();
    return MediaGrid(
      items: _items,
      density: _compactLive ? 0.8 : 1,
      favoriteKeys: favoriteKeys,
      iconUrlBuilder: app.iconUrl,
      onTap: _openItem,
      onLongPress: _toggleFavorite,
    );
  }
}
