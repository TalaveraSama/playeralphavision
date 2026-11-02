import '../models/xtream_account.dart';
import '../models/stream_format.dart';
import '../models/xtream_credentials.dart';
import '../utils/format_utils.dart';

/// Construye todas las URLs de un panel Xtream Codes / XUI.one.
///
/// Los identificadores se codifican con [Uri.encodeComponent] y las URLs se
/// arman como texto para no volver a codificar rutas ya codificadas.
class XtreamApi {
  XtreamApi({
    required this.baseUri,
    required this.username,
    required this.password,
    this.userAgent = kDefaultUserAgent,
    this.streamToken = '',
  });

  factory XtreamApi.fromCredentials(XtreamCredentials credentials) {
    return XtreamApi(
      baseUri: credentials.baseUri,
      username: credentials.username,
      password: credentials.password,
      userAgent: credentials.userAgent,
      streamToken: credentials.streamToken,
    );
  }

  final Uri baseUri;
  final String username;
  final String password;
  final String userAgent;
  final String streamToken;
  String deviceToken = '';

  XtreamApi? _streamApi;

  /// API remains on the login host. Video follows the origin advertised by the panel.
  void configureStreams(XtreamServerInfo info) {
    final advertised = info.url?.trim() ?? '';
    if (advertised.isEmpty) return;
    final protocol = (info.protocol ?? baseUri.scheme).toLowerCase();
    if (protocol != 'http' && protocol != 'https') return;
    final uri = Uri.tryParse(advertised.contains('://') ? advertised : '$protocol://$advertised');
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        !['http', 'https'].contains(uri.scheme)) return;
    final explicitOrigin = advertised.contains('://');
    final port = int.tryParse((uri.scheme == 'https' ? info.httpsPort ?? info.port : info.port) ?? '');
    final target = !uri.hasPort && !explicitOrigin && port != null && port > 0 && port <= 65535
        ? uri.replace(port: port) : uri;
    _streamApi = XtreamApi(baseUri: target, username: username, password: password,
      userAgent: userAgent, streamToken: streamToken);
  }
  String _streamBuild(List<String> segments) => (_streamApi ?? this)._build(segments);

  /// Segmentos de autenticación: con token usa `/live/{token}/...`,
  /// sin token usa `/live/{usuario}/{clave}/...`.
  List<String> get _auth => streamToken.trim().isNotEmpty
      ? <String>[streamToken.trim()]
      : <String>[username, password];

  String get scheme => baseUri.scheme;
  String get host => baseUri.host;
  int get port => baseUri.hasPort
      ? baseUri.port
      : (scheme == 'https' ? 443 : 80);

  String get origin {
    final isDefaultPort =
        (scheme == 'https' && port == 443) || (scheme == 'http' && port == 80);
    return isDefaultPort ? '$scheme://$host' : '$scheme://$host:$port';
  }

  String get basePath {
    var path = baseUri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  /// Cabeceras que se envían tanto a la API como al reproductor.
  /// Muchos paneles XUI.one filtran por `User-Agent`.
  Map<String, String> get defaultHeaders => <String, String>{
        'User-Agent': userAgent,
        'Accept': '*/*',
        if (deviceToken.isNotEmpty) 'X-Device-Token': deviceToken,
      };

  /// Une los segmentos ya codificados a la URL base.
  String _assemble(List<String> segments, [Map<String, String>? query]) {
    final buffer = StringBuffer(origin)..write(basePath);
    for (final segment in segments) {
      buffer.write('/');
      buffer.write(segment);
    }
    if (query != null && query.isNotEmpty) {
      final pairs = query.entries.map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      );
      buffer.write('?${pairs.join('&')}');
    }
    return buffer.toString();
  }

  String _build(List<String> segments, [Map<String, String>? query]) =>
      _assemble(segments.map(Uri.encodeComponent).toList(), query);

  /// `player_api.php` con las credenciales y, opcionalmente, una `action`.
  Uri apiUri([Map<String, String> extra = const <String, String>{}]) {
    final query = <String, String>{
      'username': username,
      'password': password,
      ...extra,
    };
    return Uri.parse(_build(const <String>['player_api.php'], query));
  }

  /// Lista M3U completa compatible con VLC/Kodi/OttPlayer.
  Uri get playlistUri => Uri.parse(
        _build(const <String>['get.php'], <String, String>{
          'username': username,
          'password': password,
          'type': 'm3u_plus',
          'output': 'ts',
        }),
      );

  /// Guía EPG completa en XMLTV.
  Uri get xmltvUri => Uri.parse(
        _build(const <String>['xmltv.php'], <String, String>{
          'username': username,
          'password': password,
        }),
      );

  /// `/live/{usuario}/{clave}/{stream_id}.{ext}`
  String liveUrl(String streamId, {StreamFormat format = StreamFormat.auto}) =>
      _streamBuild(<String>['live', ..._auth, '$streamId.${format.liveExtension}']);

  /// `/movie/{usuario}/{clave}/{stream_id}.{ext}`
  String movieUrl(String streamId, {String? extension}) => _streamBuild(<String>[
        'movie', ..._auth, '$streamId.${_cleanExtension(extension, 'mp4')}',
      ]);

  /// `/series/{usuario}/{clave}/{episode_id}.{ext}`
  String seriesUrl(String episodeId, {String? extension}) => _streamBuild(<String>[
        'series', ..._auth, '$episodeId.${_cleanExtension(extension, 'mkv')}',
      ]);

  /// `/timeshift/{usuario}/{clave}/{minutos}/{inicio}/{stream_id}.ts`
  /// (catch-up de canales con `tv_archive = 1`).
  ///
  /// El formato de fecha lleva `:` literal, así que este segmento no se
  /// codifica como los demás.
  String timeshiftUrl({
    required String streamId,
    required int durationMinutes,
    required DateTime start,
  }) =>
      (_streamApi ?? this)._assemble(<String>[
        'timeshift',
        ..._auth.map(Uri.encodeComponent),
        '$durationMinutes',
        formatTimeshiftStart(start),
        Uri.encodeComponent('$streamId.ts'),
      ]);

  /// Algunos paneles devuelven rutas relativas para los logos.
  String? resolveIcon(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) return '$scheme:$value';
    return '$origin${value.startsWith('/') ? '' : '/'}$value';
  }

  static String _cleanExtension(String? extension, String fallback) {
    final value = extension?.trim().replaceAll('.', '') ?? '';
    if (value.isEmpty) return fallback;
    return value;
  }
}
