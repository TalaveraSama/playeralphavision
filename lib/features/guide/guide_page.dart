import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/ads_config.dart';
import '../../core/models/epg_entry.dart';
import '../../core/models/media_item.dart';
import '../../core/models/playable_item.dart';
import '../../core/models/xtream_category.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/nova_theme.dart';
import '../../widgets/net_image.dart';
import '../../widgets/nova/nova_ui.dart';
import '../catalog/catalog_cache.dart';
import '../player/open_player.dart';

/// Guía de programación (EPG) dentro del menú principal.
///
/// Reutiliza todo lo que ya existe:
/// - `CatalogCache` para canales y categorías en vivo.
/// - `XtreamClient.shortEpg()` para "ahora" y "siguiente" de cada canal.
/// - `AppState.playableFrom()` + `openPlayer()` para zapping con el motor
///   elegido en Ajustes.
class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  List<MediaItem> _channels = <MediaItem>[];
  List<XtreamCategory> _categories = <XtreamCategory>[];
  final Map<String, List<EpgEntry>> _epg = <String, List<EpgEntry>>{};
  String? _categoryId;
  bool _loading = true;
  String? _error;

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
      final List<MediaItem> items =
          await CatalogCache.items(app.client, MediaKind.live, null);
      final List<XtreamCategory> cats =
          await CatalogCache.categories(app.client, MediaKind.live);
      if (!mounted) return;
      setState(() {
        _channels = items;
        _categories = cats;
        _loading = false;
      });
      unawaited(_loadEpg(app));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la guía: $e';
        _loading = false;
      });
    }
  }

  List<MediaItem> get _visible {
    if (_categoryId == null) return _channels;
    return _channels
        .where((MediaItem m) => m.categoryId == _categoryId)
        .toList();
  }

  /// EPG por canal en segundo plano (4 peticiones a la vez) para que la lista
  /// aparezca al instante y los programas se vayan rellenando solo.
  Future<void> _loadEpg(AppState app) async {
    final List<MediaItem> list = _visible.take(40).toList();
    const int batch = 4;
    for (int i = 0; i < list.length; i += batch) {
      if (!mounted) return;
      final int end = (i + batch).clamp(0, list.length);
      await Future.wait(list.sublist(i, end).map((MediaItem m) async {
        if (_epg.containsKey(m.id)) return;
        try {
          final List<EpgEntry> entries =
              await app.client.shortEpg(m.id, limit: 4);
          if (!mounted || entries.isEmpty) return;
          setState(() => _epg[m.id] = entries);
        } catch (_) {}
      }));
    }
  }

  String? _categoryName(MediaItem item) {
    for (final XtreamCategory category in _categories) {
      if (category.id == item.categoryId) return category.name;
    }
    return null;
  }

  Future<void> _play(MediaItem channel) async {
    final AppState app = context.read<AppState>();
    final List<MediaItem> pool = _visible;
    final List<PlayableItem> playlist = <PlayableItem>[];
    int start = 0;
    for (final MediaItem m in pool) {
      final PlayableItem? playable = app.playableFrom(m);
      if (playable == null) continue;
      if (m.id == channel.id) start = playlist.length;
      playlist.add(playable);
    }
    if (playlist.isEmpty) return;
    await openPlayer(
      context,
      playlist: playlist,
      initialIndex: start,
      mediaType: AdMediaType.live,
      title: channel.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!, style: TextStyle(color: tokens.muted)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final List<MediaItem> items = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
          child: Row(
            children: <Widget>[
              Icon(Icons.event_note_outlined, color: tokens.accent),
              const SizedBox(width: 10),
              Text(
                'Guía de programación',
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} canales',
                style: TextStyle(color: tokens.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final bool all = index == 0;
              final XtreamCategory? cat =
                  all ? null : _categories[index - 1];
              final String id = all ? '' : cat!.id;
              final bool active = _categoryId == (all ? null : id);
              return NovaFocusable(
                onTap: () {
                  setState(() => _categoryId = all ? null : id);
                  final AppState app = context.read<AppState>();
                  unawaited(_loadEpg(app));
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: active
                        ? tokens.accent.withValues(alpha: 0.22)
                        : tokens.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    all ? 'Todos' : cat!.name,
                    style: TextStyle(
                      color: active ? tokens.accent : tokens.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text('Sin canales en esta categoría',
                      style: TextStyle(color: tokens.muted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GuideRow(
                        tokens: tokens,
                        channel: items[index],
                        categoryName: _categoryName(items[index]),
                        programs: _epg[items[index].id] ?? const <EpgEntry>[],
                        onTap: () => _play(items[index]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.tokens,
    required this.channel,
    required this.programs,
    required this.onTap,
    this.categoryName,
  });

  final NovaTokens tokens;
  final MediaItem channel;
  final List<EpgEntry> programs;
  final VoidCallback onTap;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final EpgEntry? now = programs.isNotEmpty ? programs.first : null;
    final EpgEntry? next = programs.length > 1 ? programs[1] : null;
    return NovaFocusable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 42,
                child: NetImage(
                  url: channel.icon ?? '',
                  fit: BoxFit.contain,
                  icon: Icons.live_tv,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (categoryName != null)
                        Text(
                          categoryName!,
                          style:
                              TextStyle(color: tokens.muted, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    now == null
                        ? 'Sin guía disponible'
                        : '${now.timeRange}  ·  ${now.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: now == null ? tokens.muted : tokens.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (next != null)
                    Text(
                      'Sigue: ${next.timeRange}  ·  ${next.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.muted, fontSize: 11),
                    ),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline, color: tokens.muted),
          ],
        ),
      ),
    );
  }
}
