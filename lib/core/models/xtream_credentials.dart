/// User-Agent por defecto: muchos paneles XUI.one filtran por agente/cliente y
/// rechazan peticiones sin uno conocido.
const String kDefaultUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

/// Datos de conexión introducidos por el usuario.
class XtreamCredentials {
  const XtreamCredentials({
    required this.server,
    required this.username,
    required this.password,
    this.userAgent = kDefaultUserAgent,
    this.preferHttps = false,
    this.streamToken = '',
  });

  /// Tal cual lo escribió el usuario: `http://host:8080`, `host:8080`, ...
  final String server;
  final String username;
  final String password;
  final String userAgent;

  /// Token/«Access Token» de XUI.one: sustituye usuario/contraseña
  /// en las URLs de stream (`/live/{token}/{id}.m3u8`).
  final String streamToken;

  /// Se usa solo cuando el usuario no escribió el esquema.
  final bool preferHttps;

  XtreamCredentials copyWith({
    String? server,
    String? username,
    String? password,
    String? userAgent,
    bool? preferHttps,
    String? streamToken,
  }) {
    return XtreamCredentials(
      server: server ?? this.server,
      username: username ?? this.username,
      password: password ?? this.password,
      userAgent: userAgent ?? this.userAgent,
      preferHttps: preferHttps ?? this.preferHttps,
      streamToken: streamToken ?? this.streamToken,
    );
  }

  /// Normaliza el servidor: agrega el esquema si falta y elimina rutas o
  /// parámetros que el usuario haya pegado (`player_api.php`, `get.php`, ...).
  ///
  /// Lanza [FormatException] si la dirección no es utilizable.
  Uri get baseUri {
    var raw = server.trim();
    if (raw.isEmpty) {
      throw const FormatException('Escribe la dirección del servidor.');
    }
    if (!raw.contains('://')) {
      raw = '${preferHttps ? 'https' : 'http'}://$raw';
    }

    Uri parsed;
    try {
      parsed = Uri.parse(raw);
    } on FormatException {
      throw const FormatException('La dirección del servidor no es válida.');
    }

    if (parsed.host.isEmpty) {
      throw const FormatException('La dirección del servidor no es válida.');
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      throw const FormatException('Solo se admiten direcciones http o https.');
    }

    var path = parsed.path;
    const suffixes = <String>[
      '/player_api.php',
      '/panel_api.php',
      '/get.php',
      '/xmltv.php',
      '/enigma2.php',
    ];
    final lower = path.toLowerCase();
    for (final suffix in suffixes) {
      if (lower.endsWith(suffix)) {
        path = path.substring(0, path.length - suffix.length);
        break;
      }
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    // Se reconstruye como texto para no volver a codificar la ruta ni dejar
    // un `?`/`#` vacío al final.
    final StringBuffer buffer = StringBuffer()
      ..write(parsed.scheme)
      ..write('://');
    if (parsed.userInfo.isNotEmpty) {
      buffer
        ..write(parsed.userInfo)
        ..write('@');
    }
    buffer.write(parsed.host);
    if (parsed.hasPort) {
      buffer
        ..write(':')
        ..write(parsed.port);
    }
    buffer.write(path);

    return Uri.parse(buffer.toString());
  }
}
