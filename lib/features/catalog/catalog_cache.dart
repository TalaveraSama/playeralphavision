import '../../core/api/xtream_client.dart';
import '../../core/models/media_item.dart';
import '../../core/models/xtream_category.dart';
import '../../core/utils/channel_names.dart';

/// Caché en memoria de categorías y catálogos.
///
/// Evita volver a pedir listas grandes (paneles con miles de canales) cada vez
/// que se cambia de pestaña, y alimenta la búsqueda global.
class CatalogCache {
  CatalogCache._();

  static final Map<String, List<XtreamCategory>> _categories =
      <String, List<XtreamCategory>>{};
  static final Map<String, List<MediaItem>> _items =
      <String, List<MediaItem>>{};

  static String _key(MediaKind kind, String? categoryId) =>
      '${kind.name}|${categoryId ?? 'all'}';

  static Future<List<XtreamCategory>> categories(
    XtreamClient client,
    MediaKind kind, {
    bool force = false,
  }) async {
    final String key = kind.name;
    if (!force && _categories.containsKey(key)) return _categories[key]!;
    final List<XtreamCategory> value = await client.categories(kind);
    _categories[key] = value;
    return value;
  }

  static Future<List<MediaItem>> items(
    XtreamClient client,
    MediaKind kind,
    String? categoryId, {
    bool force = false,
  }) async {
    final String key = _key(kind, categoryId);
    if (!force && _items.containsKey(key)) return _items[key]!;
    final List<MediaItem> value = await client.items(
      kind,
      categoryId: categoryId,
    );
    if (kind == MediaKind.live) {
      // Fuera los separadores decorativos que meten algunos proveedores
      // (`-=Finland=-`, `*** FI ***`): no son canales.
      value.removeWhere(
        (MediaItem item) => isSeparatorChannelName(item.name),
      );
    }
    _items[key] = value;
    return value;
  }

  static List<MediaItem>? cached(MediaKind kind, String? categoryId) =>
      _items[_key(kind, categoryId)];

  /// Todo lo que ya se haya descargado de un tipo (para la búsqueda).
  static List<MediaItem> downloaded(MediaKind kind) {
    final Map<String, MediaItem> unique = <String, MediaItem>{};
    _items.forEach((String key, List<MediaItem> value) {
      if (!key.startsWith('${kind.name}|')) return;
      for (final MediaItem item in value) {
        unique[item.favoriteKey] = item;
      }
    });
    return unique.values.toList();
  }

  static void clear() {
    _categories.clear();
    _items.clear();
  }
}
