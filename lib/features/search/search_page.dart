import 'dart:async';
import '../../widgets/tv_text_field.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/xtream_client.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playable_item.dart';
import '../../core/state/app_state.dart';
import '../../widgets/media_grid.dart';
import '../../widgets/state_views.dart';
import '../catalog/catalog_cache.dart';
import '../details/series_details_page.dart';
import '../details/vod_details_page.dart';
import '../player/open_player.dart';

/// Búsqueda global sobre los catálogos ya descargados del panel.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const int _maxResults = 300;

  final TextEditingController _controller = TextEditingController();
  final List<MediaItem> _pool = <MediaItem>[];
  Future<void>? _poolFuture;
  Timer? _debounce;
  List<MediaItem> _results = const <MediaItem>[];
  MediaKind? _filter;
  String _query = '';
  bool _loadingPool = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensurePool() {
    return _poolFuture ??= _downloadCatalogs();
  }

  Future<void> _downloadCatalogs() async {
    final AppState app = context.read<AppState>();
    setState(() {
      _loadingPool = true;
      _error = null;
    });

    try {
      for (final MediaKind kind in MediaKind.values) {
        final List<MediaItem> cached = CatalogCache.downloaded(kind);
        if (cached.isNotEmpty) {
          _pool.addAll(cached);
          continue;
        }
        final List<MediaItem> items =
            await CatalogCache.items(app.client, kind, null);
        _pool.addAll(items);
      }
      if (!mounted) return;
      setState(() => _loadingPool = false);
    } on XtreamException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPool = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPool = false;
        _error = 'Error inesperado: $error';
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(value));
  }

  Future<void> _search(String value) async {
    final String query = _normalize(value.trim());
    setState(() => _query = value.trim());

    if (query.length < 2) {
      setState(() => _results = const <MediaItem>[]);
      return;
    }

    await _ensurePool();
    if (!mounted) return;

    final List<MediaItem> matches = <MediaItem>[];
    for (final MediaItem item in _pool) {
      if (_filter != null && item.kind != _filter) continue;
      if (_normalize(item.name).contains(query)) {
        matches.add(item);
        if (matches.length >= _maxResults) break;
      }
    }
    setState(() => _results = matches);
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
        final List<PlayableItem> playlist = <PlayableItem>[];
        int start = 0;
        for (int i = 0; i < _results.length; i++) {
          final PlayableItem? playable = app.playableFrom(_results[i]);
          if (playable == null) continue;
          if (i == index) start = playlist.length;
          playlist.add(playable);
        }
        if (playlist.isEmpty) return;
        await openPlayer(context, playlist: playlist, initialIndex: start);
    }
  }

  static String _normalize(String input) {
    const Map<String, String> replacements = <String, String>{
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.toLowerCase().runes) {
      final String char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }

  final FocusNode _searchFocus =
      FocusNode(debugLabel: 'buscar', skipTraversal: true);

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: TvTextField(
  fieldFocus: _searchFocus,
  child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Buscar canal, película o serie…',
            border: InputBorder.none,
            filled: false,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  ),
          ),
        ),
),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Todo'),
                  selected: _filter == null,
                  onSelected: (_) {
                    setState(() => _filter = null);
                    _search(_controller.text);
                  },
                ),
                const SizedBox(width: 8),
                ...MediaKind.values.map(
                  (MediaKind kind) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(kind.label),
                      selected: _filter == kind,
                      onSelected: (_) {
                        setState(() => _filter = kind);
                        _search(_controller.text);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loadingPool) const LinearProgressIndicator(),
          Expanded(child: _buildBody(app)),
        ],
      ),
    );
  }

  Widget _buildBody(AppState app) {
    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: () {
          _poolFuture = null;
          _search(_controller.text);
        },
      );
    }
    if (_query.length < 2) {
      return const EmptyView(
        message: 'Escribe al menos dos letras para buscar en los tres '
            'catálogos del panel.',
        icon: Icons.search,
      );
    }
    if (_loadingPool || (_pool.isEmpty && _results.isEmpty)) {
      return const LoadingView(message: 'Descargando catálogos…');
    }
    if (_results.isEmpty) {
      return EmptyView(
        message: 'Sin resultados para «$_query».',
        icon: Icons.search_off,
      );
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_results.length} resultados'
              '${_results.length >= _maxResults ? ' (mostrando los primeros $_maxResults)' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: MediaGrid(
            items: _results,
            favoriteKeys:
                app.favorites.map((MediaItem item) => item.favoriteKey).toSet(),
            iconUrlBuilder: (MediaItem item) => app.iconUrl(item),
            onTap: _open,
            onLongPress: app.toggleFavorite,
          ),
        ),
      ],
    );
  }
}
