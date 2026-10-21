import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/xtream_client.dart';
import '../../core/config/ads_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playable_item.dart';
import '../../core/models/xtream_category.dart';
import '../../core/state/app_state.dart';
import '../../widgets/media_grid.dart';
import '../../widgets/nova/nova_ui.dart';
import '../../widgets/state_views.dart';
import '../details/series_details_page.dart';
import '../details/vod_details_page.dart';
import '../player/open_player.dart';
import '../search/search_page.dart';
import 'catalog_cache.dart';

/// «Explorar» del móvil: catálogo completo con filtros de tipo y categoría.
class NovaBrowsePage extends StatefulWidget {
  const NovaBrowsePage({super.key});

  @override
  State<NovaBrowsePage> createState() => _NovaBrowsePageState();
}

class _NovaBrowsePageState extends State<NovaBrowsePage> {
  MediaKind _kind = MediaKind.series;
  List<XtreamCategory> _categories = const <XtreamCategory>[];
  List<MediaItem> _items = const <MediaItem>[];
  String? _categoryId;
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<MediaKind> get _kinds {
    final bool showLive =
        context.read<ConfigController>().config.branding.showLiveSection;
    return <MediaKind>[
      MediaKind.series,
      MediaKind.movie,
      if (showLive) MediaKind.live,
    ];
  }

  Future<void> _load({bool force = false}) async {
    final AppState app = context.read<AppState>();
    final int request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<XtreamCategory> categories =
          await CatalogCache.categories(app.client, _kind, force: force);
      final List<MediaItem> items = await CatalogCache.items(
        app.client,
        _kind,
        _categoryId,
        force: force,
      );
      if (!mounted || request != _request) return;
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
    }
  }

  Future<void> _selectKind(MediaKind kind) async {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _categoryId = null;
    });
    await _load();
  }

  Future<void> _selectCategory(String? categoryId) async {
    if (categoryId == _categoryId) return;
    final AppState app = context.read<AppState>();
    final int request = ++_request;
    setState(() {
      _categoryId = categoryId;
      _loading = true;
      _error = null;
    });
    try {
      final List<MediaItem> items =
          await CatalogCache.items(app.client, _kind, categoryId);
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

  Future<void> _open(MediaItem item, int index) async {
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
        final List<PlayableItem> playlist = app.playlistFrom(_items);
        if (playlist.isEmpty) return;
        int start = 0;
        for (int i = 0; i < index && i < _items.length; i++) {
          if (app.playableFrom(_items[i]) != null) start++;
        }
        await openPlayer(
          context,
          playlist: playlist,
          initialIndex: start,
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
              ? '«${item.name}» quitado de Mi lista'
              : '«${item.name}» añadido a Mi lista',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final bool canSearch = context.watch<ConfigController>().config.features.search;
    final List<MediaKind> kinds = _kinds;
    final int kindIndex = kinds.indexOf(_kind);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
        actions: <Widget>[
          if (canSearch)
            IconButton(
              tooltip: 'Buscar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchPage()),
              ),
              icon: const Icon(Icons.search),
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => _load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: NovaFilterBar(
              labels: kinds.map((MediaKind kind) => kind.label).toList(),
              selectedIndex: kindIndex < 0 ? 0 : kindIndex,
              onSelected: (int index) => _selectKind(kinds[index]),
            ),
          ),
          if (_categories.isNotEmpty) _buildCategoryBar(),
          Expanded(child: _buildBody(app)),
        ],
      ),
    );
  }

  Widget _buildBody(AppState app) {
    if (_loading) return const LoadingView(message: 'Cargando catálogo…');
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: () => _load());
    }
    if (_items.isEmpty) {
      return EmptyView(
        message: 'Este panel no devolvió ${_kind.label.toLowerCase()} '
            'para la categoría seleccionada.',
        icon: Icons.tv_off_outlined,
      );
    }
    return MediaGrid(
      items: _items,
      favoriteKeys:
          app.favorites.map((MediaItem item) => item.favoriteKey).toSet(),
      iconUrlBuilder: app.iconUrl,
      onTap: _open,
      onLongPress: _toggleFavorite,
    );
  }

  Widget _buildCategoryBar() {
    final String? selected = _categoryId;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool isAll = index == 0;
          final XtreamCategory? category =
              isAll ? null : _categories[index - 1];
          final String? categoryId = category?.id;
          final bool active =
              isAll ? selected == null : selected == categoryId;
          return ChoiceChip(
            label: Text(isAll ? 'Todas' : category!.name),
            selected: active,
            onSelected: (_) => _selectCategory(isAll ? null : categoryId),
          );
        },
      ),
    );
  }
}
