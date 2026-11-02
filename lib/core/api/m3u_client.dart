import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';
import '../models/xtream_category.dart';
import '../models/epg_entry.dart';
import '../security/panel_http_client.dart';
import 'xtream_api.dart';
import 'xtream_client.dart';

/// No segments/keys are downloaded while importing an HLS URL.
List<MediaItem> parseM3u(String text, {Uri? source}) {
  final lines = const LineSplitter().convert(text.replaceFirst('\uFEFF', ''));
  if (!lines.any((l) => l.trimLeft().startsWith('#EXTM3U'))) throw const FormatException('El archivo no es una lista M3U válida.');
  if (lines.any((l) => l.trimLeft().startsWith('#EXT-X-'))) {
    if (source == null) throw const FormatException('Para un manifiesto HLS utiliza su enlace, no un archivo local.');
    return [MediaItem(kind: MediaKind.live, id: 'hls', name: 'Canal HLS', containerExtension: 'm3u8', directUrl: source.toString(), categoryId: 'Directo')];
  }
  final result = <MediaItem>[];
  String title = '', group = 'Sin grupo'; String? logo;
  String? attr(String line, String name) => RegExp('$name="([^"]*)"').firstMatch(line)?.group(1);
  for (final raw in lines) {
    final line = raw.trim();
    if (line.startsWith('#EXTINF:')) {
      var quoted = false; var comma = -1;
      for (var i = 0; i < line.length; i++) {
        if (line[i] == '"') quoted = !quoted;
        if (line[i] == ',' && !quoted) { comma = i; break; }
      }
      title = comma < 0 ? '' : line.substring(comma + 1).trim();
      group = attr(line, 'group-title') ?? 'Sin grupo'; logo = attr(line, 'tvg-logo');
    } else if (line.isNotEmpty && !line.startsWith('#')) {
      final parsed = Uri.tryParse(line);
      final url = parsed?.hasScheme == true ? parsed : source?.resolve(line);
      if (url == null || !['http', 'https'].contains(url.scheme) || url.host.isEmpty || url.userInfo.isNotEmpty) {
        throw const FormatException('La lista contiene un enlace no compatible. Sólo se admiten HTTP/HTTPS.');
      }
      var hash = 2166136261;
      for (final c in url.toString().codeUnits) { hash = ((hash ^ c) * 16777619) & 0xffffffff; }
      result.add(MediaItem(kind: MediaKind.live, id: 'm3u-${hash.toRadixString(16)}',
        name: title.isEmpty ? 'Canal ${result.length + 1}' : title, categoryId: group, icon: logo, directUrl: url.toString()));
      title = ''; group = 'Sin grupo'; logo = null;
    }
    if (result.length > 50000) throw const FormatException('La lista supera 50.000 entradas.');
  }
  if (result.isEmpty) throw const FormatException('La lista no contiene canales.');
  return result;
}

class M3uClient extends XtreamClient {
  M3uClient({required super.api, required this.channels}) : super(httpClient: http.Client());
  final List<MediaItem> channels;
  static Future<List<MediaItem>> load(String url, String contents, {required bool allowHttp}) async {
    if (contents.isNotEmpty) return parseM3u(contents);
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        (!allowHttp && uri.scheme != 'https')) throw const FormatException('Enlace de lista inválido o HTTP no autorizado.');
    final client = PanelHttpClient.create(allowHttp: allowHttp, maxResponseBytes: 10 * 1024 * 1024);
    try {
      final req = http.Request('GET', uri)..followRedirects = false;
      final response = await client.send(req).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) throw const FormatException('No se pudo descargar la lista. Usa el enlace final del proveedor.');
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(const Duration(seconds: 25))) {
        bytes.addAll(chunk);
        if (bytes.length > 10 * 1024 * 1024) throw const FormatException('La lista supera 10 MB.');
      }
      return parseM3u(utf8.decode(bytes), source: uri);
    } finally { client.close(); }
  }
  @override
  Future<List<XtreamCategory>> categories(MediaKind kind) async => kind != MediaKind.live ? [] :
    channels.map((c) => c.categoryId!).toSet().map((g) => XtreamCategory(id: g, name: g)).toList();
  @override
  Future<List<MediaItem>> items(MediaKind kind, {String? categoryId}) async => kind != MediaKind.live ? [] :
    channels.where((c) => categoryId == null || c.categoryId == categoryId).toList();
  @override
  Future<List<EpgEntry>> shortEpg(String streamId, {int limit = 8}) async => [];
}
