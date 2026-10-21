import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/ads_config.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/media_item.dart';
import '../../core/models/resume_entry.dart';
import '../../core/models/xtream_category.dart';
import '../../core/utils/format_utils.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/hero_carousel.dart';
import '../../widgets/net_image.dart';
import '../../widgets/poster_row.dart';

/// Una sección del catálogo agrupada por categoría.
class CategoryGroup {
  const CategoryGroup({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<MediaItem> items;
}

/// Vista de catálogo en filas horizontales (Tema 1): cabecera destacada y una
/// fila por categoría.
class CatalogRowsView extends StatelessWidget {
  const CatalogRowsView({
    super.key,
    required this.kind,
    required this.branding,
    required this.spec,
    required this.items,
    required this.categories,
    required this.favoriteKeys,
    required this.iconUrlBuilder,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.onSeeAll,
    this.continueWatching = const <ResumeEntry>[],
    this.onResume,
    this.onSearch,
    this.onRefresh,
    this.maxRows = 15,
  });

  final MediaKind kind;
  final BrandingConfig branding;
  final ThemeSpec spec;
  final List<MediaItem> items;
  final List<XtreamCategory> categories;
  final Set<String> favoriteKeys;
  final String? Function(MediaItem item) iconUrlBuilder;
  final void Function(MediaItem item, int index) onOpen;
  final void Function(MediaItem item) onToggleFavorite;
  final void Function(CategoryGroup group) onSeeAll;

  /// Elementos a medio ver, que se muestran como primera fila.
  final List<ResumeEntry> continueWatching;
  final void Function(ResumeEntry entry)? onResume;
  final VoidCallback? onSearch;
  final VoidCallback? onRefresh;
  final int maxRows;

  bool get _isLive => kind == MediaKind.live;

  /// La marca decide qué rota en la cabecera destacada.
  bool get _heroAllowed {
    final String source = branding.heroSource.trim().toLowerCase();
    if (source.isEmpty || source == 'mixed') return true;
    switch (kind) {
      case MediaKind.live:
        return source == 'live';
      case MediaKind.movie:
        return source == 'movie' || source == 'movies';
      case MediaKind.series:
        return source == 'series';
    }
  }

  AdMediaType get _adMediaType {
    switch (kind) {
      case MediaKind.live:
        return AdMediaType.live;
      case MediaKind.movie:
        return AdMediaType.vod;
      case MediaKind.series:
        return AdMediaType.series;
    }
  }

  /// Elementos destacados del carrusel de la cabecera.
  ///
  /// El primero cambia cada día (no es aleatorio en cada repintado) y el resto
  /// van detrás para que la cabecera rote sola.
  List<MediaItem> get _featuredList {
    if (items.isEmpty) return const <MediaItem>[];

    // Misma configuracion de banner que la portada Nova: fuente, categorias,
    // canales concretos y modo automatico/aleatorio/manual del panel.
    List<MediaItem> pool = List<MediaItem>.from(items);

    final List<String> cats = branding.heroCategoryList;
    if (cats.isNotEmpty) {
      final Set<String> ids = <String>{};
      for (final XtreamCategory category in categories) {
        if (cats.contains(category.id.toLowerCase()) ||
            cats.contains(category.name.toLowerCase())) {
          ids.add(category.id);
        }
      }
      if (ids.isNotEmpty) {
        final List<MediaItem> filtered =
            pool.where((MediaItem i) => ids.contains(i.categoryId)).toList();
        if (filtered.isNotEmpty) pool = filtered;
      }
    }

    final List<String> manual = branding.heroItemList;
    if (manual.isNotEmpty) {
      final List<MediaItem> picked = pool
          .where((MediaItem i) =>
              manual.contains(i.id.toLowerCase()) ||
              manual.contains(i.name.toLowerCase()))
          .toList();
      if (picked.isNotEmpty) pool = picked;
    }

    final List<MediaItem> withArtwork = pool
        .where((MediaItem item) => (item.backdrop ?? item.icon ?? '').isNotEmpty)
        .toList();
    final List<MediaItem> source = withArtwork.isEmpty ? pool : withArtwork;

    final String mode = branding.heroMode.toLowerCase();
    final bool random = mode == 'random' || mode == 'aleatorio';
    final int seed = random
        ? DateTime.now().day * 7 + DateTime.now().month * 13
        : DateTime.now().day + DateTime.now().month * 31;
    final List<MediaItem> result = <MediaItem>[];
    for (int i = 0; i < source.length && result.length < 5; i++) {
      final MediaItem candidate = source[(seed + i) % source.length];
      final bool repeated = result.any(
        (MediaItem other) => other.favoriteKey == candidate.favoriteKey,
      );
      if (!repeated) result.add(candidate);
    }
    return result;
  }

  /// Mezcla carátulas y anuncios en el banner (si está activado).
  List<Object> _heroSlides(BuildContext context, List<MediaItem> featured) {
    if (!branding.heroAds || featured.isEmpty) return featured;
    final List<AdCreative> ads = context
        .read<ConfigController>()
        .bannerRotation(mediaType: _adMediaType);
    if (ads.isEmpty) return featured;
    final int every = branding.heroAdsEvery <= 0 ? 3 : branding.heroAdsEvery;
    final List<Object> slides = <Object>[];
    int adIndex = 0;
    for (int i = 0; i < featured.length; i++) {
      slides.add(featured[i]);
      if ((i + 1) % every == 0) {
        slides.add(ads[adIndex % ads.length]);
        adIndex++;
      }
    }
    return slides;
  }

  List<CategoryGroup> _groups() {
    final Map<String, List<MediaItem>> byCategory = <String, List<MediaItem>>{};
    for (final MediaItem item in items) {
      byCategory
          .putIfAbsent(item.categoryId ?? '', () => <MediaItem>[])
          .add(item);
    }

    final List<CategoryGroup> groups = <CategoryGroup>[];
    for (final XtreamCategory category in categories) {
      final List<MediaItem>? list = byCategory[category.id];
      if (list == null || list.isEmpty) continue;
      groups.add(
        CategoryGroup(id: category.id, title: category.name, items: list),
      );
    }

    final Set<String> known =
        categories.map((XtreamCategory category) => category.id).toSet();
    final List<MediaItem> others = <MediaItem>[];
    byCategory.forEach((String key, List<MediaItem> value) {
      if (!known.contains(key) && key.isNotEmpty) others.addAll(value);
    });
    if (others.isNotEmpty) {
      groups.add(
        CategoryGroup(id: '', title: 'Otros', items: others),
      );
    }
    if (groups.isEmpty) {
      groups.add(
        CategoryGroup(id: '', title: kind.label, items: items),
      );
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<CategoryGroup> groups = _groups();
    final List<MediaItem> featured = _featuredList;
    final List<Object> slides = _heroSlides(context, featured);

    final List<Widget> blocks = <Widget>[];

    // Primera fila: lo que quedó a medio ver SOLO en películas y series.
    // (En el menú principal ya no se muestra.)
    if ((kind == MediaKind.movie || kind == MediaKind.series) &&
        continueWatching.isNotEmpty &&
        onResume != null) {
      final List<ResumeEntry> entries = continueWatching
          .where((ResumeEntry e) => e.item == null || e.item!.kind == kind)
          .toList();
      if (entries.isNotEmpty) {
        blocks.add(
          _ContinueRow(
            entries: entries,
            iconUrlBuilder: iconUrlBuilder,
            onResume: onResume!,
          ),
        );
      }
    }

    for (int i = 0; i < groups.length && i < maxRows; i++) {
      final CategoryGroup group = groups[i];
      blocks.add(
        PosterRow(
          title: group.title,
          items: group.items,
          itemWidth: _isLive ? 142 : 124,
          rowHeight: _isLive ? 168 : 216,
          cardRadius: spec.cardRadius,
          iconUrlBuilder: iconUrlBuilder,
          favoriteKeys: favoriteKeys,
          onTap: onOpen,
          onLongPress: onToggleFavorite,
          onSeeAll: group.items.length > 6 ? () => onSeeAll(group) : null,
        ),
      );
      // La franja publicitaria se coloca entre las dos primeras filas.
      if (i == 1) {
        blocks.add(
          AdBanner(
            mediaType: _adMediaType,
            categoryName: group.title,
            title: branding.appName,
          ),
        );
      }
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          floating: true,
          backgroundColor: spec.backgroundColor.withValues(alpha: 0.92),
          titleSpacing: 16,
          title: _buildBrandTitle(theme),
          actions: <Widget>[
            if (onSearch != null)
              IconButton(
                tooltip: 'Buscar',
                onPressed: onSearch,
                icon: const Icon(Icons.search),
              ),
            if (onRefresh != null)
              IconButton(
                tooltip: 'Actualizar',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        if (featured.isNotEmpty && spec.useHero && _heroAllowed)
          SliverToBoxAdapter(
            child: HeroCarousel(
              height: _isLive ? 300 : 400,
              itemCount: slides.length,
              builder: (BuildContext context, int index) {
                final Object slide = slides[index];
                if (slide is AdCreative) {
                  return _HeroAd(ad: slide, spec: spec, isLive: _isLive);
                }
                final MediaItem item = slide as MediaItem;
                return _HeroHeader(
                  item: item,
                  spec: spec,
                  imageUrl: iconUrlBuilder(item),
                  isLive: _isLive,
                  isFavorite: favoriteKeys.contains(item.favoriteKey),
                  onPlay: () => onOpen(item, index),
                  onToggleFavorite: () => onToggleFavorite(item),
                );
              },
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) => blocks[index],
            childCount: blocks.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _buildBrandTitle(ThemeData theme) {
    if (branding.logoUrl.trim().isNotEmpty) {
      return SizedBox(
        height: 30,
        width: 130,
        child: NetImage(
          url: branding.logoUrl,
          fit: BoxFit.contain,
          icon: Icons.play_circle_fill_rounded,
          backgroundColor: Colors.transparent,
        ),
      );
    }
    return Text(
      branding.appName,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: theme.colorScheme.primary,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Fila de lo que quedó a medio ver, con barra de progreso.
class _ContinueRow extends StatelessWidget {
  const _ContinueRow({
    required this.entries,
    required this.iconUrlBuilder,
    required this.onResume,
  });

  final List<ResumeEntry> entries;
  final String? Function(MediaItem item) iconUrlBuilder;
  final void Function(ResumeEntry entry) onResume;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
          child: Text(
            'Continuar viendo',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 216,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final ResumeEntry entry = entries[index];
              return SizedBox(
                width: 124,
                child: InkWell(
                  onTap: () => onResume(entry),
                  borderRadius: BorderRadius.circular(10),
                  onFocusChange: (_) {},
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              NetImage(
                                url: entry.image?.isNotEmpty == true
                                    ? entry.image
                                    : (entry.item == null
                                        ? null
                                        : iconUrlBuilder(entry.item!)),
                                icon: Icons.play_circle_outline,
                                cacheWidth: 320,
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: LinearProgressIndicator(
                                  value: entry.progress,
                                  minHeight: 4,
                                  backgroundColor: Colors.black45,
                                ),
                              ),
                              const Positioned(
                                right: 5,
                                top: 5,
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        entry.timeLabel.isEmpty
                            ? formatDuration(entry.position)
                            : entry.timeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.item,
    required this.spec,
    required this.imageUrl,
    required this.isLive,
    required this.isFavorite,
    required this.onPlay,
    required this.onToggleFavorite,
  });

  final MediaItem item;
  final ThemeSpec spec;
  final String? imageUrl;
  final bool isLive;
  final bool isFavorite;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double height = isLive ? 300 : 400;
    final Color tint = spec.heroTint ?? spec.backgroundColor;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          NetImage(
            url: imageUrl,
            fit: BoxFit.cover,
            icon: isLive ? Icons.live_tv_outlined : Icons.movie_outlined,
            iconSize: 54,
            backgroundColor: spec.surfaceColor,
            cacheWidth: 1280,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  tint.withValues(alpha: 0.20),
                  tint.withValues(alpha: 0.55),
                  tint,
                ],
                stops: const <double>[0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (isLive)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EN DIRECTO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Reproducir'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: onToggleFavorite,
                      icon: Icon(
                        isFavorite ? Icons.check : Icons.add,
                        size: 18,
                      ),
                      label: Text(isFavorite ? 'Mi lista' : 'Mi lista'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAd extends StatelessWidget {
  const _HeroAd({
    required this.ad,
    required this.spec,
    required this.isLive,
  });

  final AdCreative ad;
  final ThemeSpec spec;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double height = isLive ? 300 : 400;
    final Color tint = spec.heroTint ?? spec.backgroundColor;
    final String label = ad.title.isNotEmpty
        ? ad.title
        : (ad.text.isNotEmpty ? ad.text : 'Publicidad');

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (ad.mediaUrl.isNotEmpty)
            NetImage(
              url: ad.mediaUrl,
              fit: BoxFit.cover,
              backgroundColor: spec.surfaceColor,
              cacheWidth: 1280,
            )
          else
            Container(color: spec.surfaceColor),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  tint.withValues(alpha: 0.20),
                  tint.withValues(alpha: 0.60),
                  tint,
                ],
                stops: const <double>[0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PUBLICIDAD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

