import '../utils/parse_utils.dart';

/// Categoría de `get_live_categories`, `get_vod_categories` o
/// `get_series_categories`.
class XtreamCategory {
  const XtreamCategory({required this.id, required this.name, this.parentId});

  final String id;
  final String name;
  final int? parentId;

  factory XtreamCategory.fromJson(Map<String, dynamic> json) {
    return XtreamCategory(
      id: asStringOr(json['category_id'], ''),
      name: asStringOr(json['category_name'], 'Sin categoría'),
      parentId: asIntOrNull(json['parent_id']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is XtreamCategory && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
