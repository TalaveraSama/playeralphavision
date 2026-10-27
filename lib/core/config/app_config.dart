import 'dart:ui' show Brightness, Color;

import '../app_info.dart';
import '../utils/parse_utils.dart';
import 'ads_config.dart';

/// Convierte `#RRGGBB`, `#AARRGGBB`, `RRGGBB` o un entero en un [Color].
Color parseHexColor(dynamic value, Color fallback) {
  if (value is int) return Color(value);
  final text = asString(value);
  if (text == null) return fallback;

  var hex = text.trim().replaceFirst('#', '').replaceFirst('0x', '');
  if (hex.length == 3) {
    hex = hex.split('').map((String char) => '$char$char').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return fallback;

  final int? parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

String colorToHex(Color color) {
  final int rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

List<int> versionParts(String version) {
  return version
      .split(RegExp(r'[.\-+_]'))
      .map((String part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}

/// `true` si [candidate] es una versión más nueva que [current].
bool isVersionNewer(String candidate, String current) {
  final List<int> a = versionParts(candidate);
  final List<int> b = versionParts(current);
  final int length = a.length > b.length ? a.length : b.length;
  for (int i = 0; i < length; i++) {
    final int left = i < a.length ? a[i] : 0;
    final int right = i < b.length ? b[i] : 0;
    if (left != right) return left > right;
  }
  return false;
}

/// Fusiona dos mapas de configuración; `override` gana campo a campo.
///
/// Las listas se reemplazan completas (una lista remota sustituye a la del
/// paquete), los valores `null` no borran nada y un valor con el tipo
/// equivocado se ignora: una configuración remota corrupta nunca debe romper la
/// app ni dejarla sin tema.
Map<String, dynamic> deepMerge(
  Map<String, dynamic> base,
  Map<String, dynamic> override,
) {
  final Map<String, dynamic> result = Map<String, dynamic>.from(base);
  override.forEach((String key, dynamic value) {
    if (value == null) return;

    final dynamic current = result[key];
    if (current is Map && value is Map) {
      result[key] = deepMerge(asMap(current), asMap(value));
      return;
    }
    if (current is List && value is! List) return;
    if (current is Map && value is! Map) return;
    result[key] = value;
  });
  return result;
}

// ---------------------------------------------------------------- branding

class BrandingConfig {
  const BrandingConfig({
    this.appName = 'Xtream Player',
    this.logoUrl = '',
    this.headerLogoUrl = '',
    this.splashLogoUrl = '',
    this.tagline = '',
    this.primaryColor = const Color(0xFFE50914),
    this.loginBackgrounds = const <String>[],
    this.loginBackgroundSeconds = 8,
    this.loginTitle = 'Inicia sesión',
    this.loginSubtitle = 'Introduce tu usuario y contraseña',
    this.loginFooter = '',
    this.supportUrl = '',
    this.whatsappUrl = '',
    this.telegramUrl = '',
    this.hideServerField = true,
    this.heroSource = 'mixed',
    // Banner: seleccion manual o aleatoria de canales/categorias.
    this.heroMode = 'auto',
    this.heroCategories = '',
    this.heroItems = '',
    this.heroAds = false,
    this.heroAdsEvery = 3,
    this.showLiveSection = true,
    this.tabAll = 'Todo',
    this.tabSeries = 'Series',
    this.tabMovies = 'Películas',
    this.tabLive = 'En vivo',
  });

  final String appName;
  final String logoUrl;

  /// Logo de la cabecera y de la portada (si esta vacio se usa [logoUrl]).
  final String headerLogoUrl;

  /// Logo de la pantalla de carga (si esta vacio se usa [logoUrl]).
  final String splashLogoUrl;

  final String tagline;
  final Color primaryColor;
  final List<String> loginBackgrounds;
  final int loginBackgroundSeconds;
  final String loginTitle;
  final String loginSubtitle;
  final String loginFooter;
  final String supportUrl;
  final String whatsappUrl;
  final String telegramUrl;
  final bool hideServerField;

  /// Qué contenido rota en la cabecera destacada: `movies`, `series`, `live`
  /// o `mixed`.
  final String heroSource;

  /// `auto` (orden del panel) | `random` (aleatorio) | `manual` (los indicados).
  final String heroMode;

  /// Categorias del banner separadas por coma (ids o nombres).
  final String heroCategories;

  /// Canales/peliculas/series del banner separadas por coma (ids o titulos).
  final String heroItems;

  /// Inserta anuncios en el carrusel de la cabecera.
  final bool heroAds;

  /// Cada cuántas carátulas se intercala un anuncio (1..N).
  final int heroAdsEvery;

  /// Muestra u oculta toda la sección de televisión en directo.
  final bool showLiveSection;

  /// Nombres de las pestañas de la portada.
  final String tabAll;
  final String tabSeries;
  final String tabMovies;
  final String tabLive;

  factory BrandingConfig.fromJson(Map<String, dynamic> json) {
    return BrandingConfig(
      appName: asStringOr(json['appName'], 'Xtream Player'),
      logoUrl: asStringOr(json['logoUrl'], ''),
      headerLogoUrl: asStringOr(json['headerLogoUrl'], ''),
      splashLogoUrl: asStringOr(json['splashLogoUrl'], ''),
      tagline: asStringOr(json['tagline'], ''),
      primaryColor: parseHexColor(json['primaryColor'], const Color(0xFFE50914)),
      loginBackgrounds: asStringList(json['loginBackgrounds']),
      loginBackgroundSeconds: asInt(json['loginBackgroundSeconds'], 8),
      loginTitle: asStringOr(json['loginTitle'], 'Inicia sesión'),
      loginSubtitle:
          asStringOr(json['loginSubtitle'], 'Introduce tu usuario y contraseña'),
      loginFooter: asStringOr(json['loginFooter'], ''),
      supportUrl: asStringOr(json['supportUrl'], ''),
      whatsappUrl: asStringOr(json['whatsappUrl'], ''),
      telegramUrl: asStringOr(json['telegramUrl'], ''),
      hideServerField: asBool(json['hideServerField']) ||
          json['hideServerField'] == null,
      heroSource: asStringOr(json['heroSource'], 'mixed'),
      heroMode: asStringOr(json['heroMode'], 'auto'),
      heroCategories: asStringOr(json['heroCategories'], ''),
      heroItems: asStringOr(json['heroItems'], ''),
      heroAds: asBool(json['heroAds']),
      heroAdsEvery: asInt(json['heroAdsEvery'], 3),
      showLiveSection: json['showLiveSection'] == null
          ? true
          : asBool(json['showLiveSection']),
      tabAll: asStringOr(json['tabAll'], 'Todo'),
      tabSeries: asStringOr(json['tabSeries'], 'Series'),
      tabMovies: asStringOr(json['tabMovies'], 'Películas'),
      tabLive: asStringOr(json['tabLive'], 'En vivo'),
    );
  }

  /// Categorias del banner ya normalizadas (minusculas, sin espacios).
  List<String> get heroCategoryList => _csv(heroCategories);

  /// Canales/titulos del banner ya normalizados (minusculas, sin espacios).
  List<String> get heroItemList => _csv(heroItems);

  static List<String> _csv(String value) => value
      .split(',')
      .map((String e) => e.trim().toLowerCase())
      .where((String e) => e.isNotEmpty)
      .toList();

  /// Logo que se pinta en la cabecera (cae al del login si no hay).
  String get effectiveHeaderLogo =>
      headerLogoUrl.trim().isNotEmpty ? headerLogoUrl : logoUrl;

  /// Logo de la pantalla de carga (cae al del login si no hay).
  String get effectiveSplashLogo =>
      splashLogoUrl.trim().isNotEmpty ? splashLogoUrl : logoUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'appName': appName,
        'logoUrl': logoUrl,
        'headerLogoUrl': headerLogoUrl,
        'splashLogoUrl': splashLogoUrl,
        'tagline': tagline,
        'primaryColor': colorToHex(primaryColor),
        'loginBackgrounds': loginBackgrounds,
        'loginBackgroundSeconds': loginBackgroundSeconds,
        'loginTitle': loginTitle,
        'loginSubtitle': loginSubtitle,
        'loginFooter': loginFooter,
        'supportUrl': supportUrl,
        'whatsappUrl': whatsappUrl,
        'telegramUrl': telegramUrl,
        'hideServerField': hideServerField,
        'heroSource': heroSource,
        'heroMode': heroMode,
        'heroCategories': heroCategories,
        'heroItems': heroItems,
        'heroAds': heroAds,
        'heroAdsEvery': heroAdsEvery,
        'showLiveSection': showLiveSection,
        'tabAll': tabAll,
        'tabSeries': tabSeries,
        'tabMovies': tabMovies,
        'tabLive': tabLive,
      };
}

// ------------------------------------------------------------------- temas

/// `rows` = filas horizontales tipo Netflix; `grid` = rejilla clásica;
/// `nova` = portada de descubrimiento NOVA (héroe, «Continuar viendo»,
/// «En vivo ahora» y «Tendencias») con barra superior en pantallas anchas y
/// barra inferior en el móvil.
enum CatalogLayout { rows, grid, nova }

class ThemeSpec {
  const ThemeSpec({
    required this.id,
    required this.name,
    this.layout = CatalogLayout.rows,
    this.primaryColor = const Color(0xFFE50914),
    this.backgroundColor = const Color(0xFF0B0B0B),
    this.surfaceColor = const Color(0xFF161616),
    this.textColor = const Color(0xFFFFFFFF),
    this.brightness = Brightness.dark,
    this.useHero = true,
    this.cardRadius = 8,
    this.lightButtons = false,
    this.heroTint,
  });

  final String id;
  final String name;
  final CatalogLayout layout;
  final Color primaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color textColor;
  final Brightness brightness;
  final bool useHero;
  final double cardRadius;

  /// Botones principales en blanco con texto oscuro (estilo HBO Max).
  final bool lightButtons;

  /// Tinte de la cabecera destacada; si es `null` se usa el fondo.
  final Color? heroTint;

  static const ThemeSpec fallback = ThemeSpec(
    id: 'theme1',
    name: 'Tema 1',
  );

  bool get isRows => layout == CatalogLayout.rows;

  bool get isGrid => layout == CatalogLayout.grid;

  /// Portada NOVA de descubrimiento.
  bool get isNova => layout == CatalogLayout.nova;

  bool get isNova2 => isNova && id.toLowerCase() == 'nova2';

  /// Nombre del estilo, para el panel y los ajustes.
  String get layoutLabel {
    switch (layout) {
      case CatalogLayout.rows:
        return 'Filas horizontales (estilo streaming)';
      case CatalogLayout.grid:
        return 'Rejilla de carátulas';
      case CatalogLayout.nova:
        return 'Portada NOVA (héroe, tendencias y en vivo)';
    }
  }

  factory ThemeSpec.fromJson(Map<String, dynamic> json) {
    final String layoutName = asStringOr(json['layout'], 'rows').toLowerCase();
    final CatalogLayout layout = switch (layoutName) {
      'grid' => CatalogLayout.grid,
      'nova' => CatalogLayout.nova,
      _ => CatalogLayout.rows,
    };
    return ThemeSpec(
      id: asStringOr(json['id'], 'theme1'),
      name: asStringOr(json['name'], 'Tema'),
      layout: layout,
      primaryColor: parseHexColor(json['primaryColor'], const Color(0xFFE50914)),
      backgroundColor:
          parseHexColor(json['backgroundColor'], const Color(0xFF0B0B0B)),
      surfaceColor: parseHexColor(json['surfaceColor'], const Color(0xFF161616)),
      textColor: parseHexColor(json['textColor'], const Color(0xFFFFFFFF)),
      brightness: asStringOr(json['brightness'], 'dark').toLowerCase() == 'light'
          ? Brightness.light
          : Brightness.dark,
      useHero: json['useHero'] == null ? true : asBool(json['useHero']),
      cardRadius: asDouble(json['cardRadius'], 8),
      lightButtons: asBool(json['lightButtons']),
      heroTint: json['heroTint'] == null
          ? null
          : parseHexColor(json['heroTint'], const Color(0xFF0B0B0B)),
    );
  }


  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'layout': layout.name,
        'primaryColor': colorToHex(primaryColor),
        'backgroundColor': colorToHex(backgroundColor),
        'surfaceColor': colorToHex(surfaceColor),
        'textColor': colorToHex(textColor),
        'brightness': brightness.name,
        'useHero': useHero,
        'cardRadius': cardRadius,
        'lightButtons': lightButtons,
        'heroTint': heroTint == null ? null : colorToHex(heroTint!),
      };
}

class ThemeConfig {
  const ThemeConfig({
    this.active = 'theme1',
    this.available = const <ThemeSpec>[],
  });

  final String active;
  final List<ThemeSpec> available;

  ThemeSpec resolve(String? id) {
    if (id != null) {
      for (final ThemeSpec theme in available) {
        if (theme.id == id) return theme;
      }
    }
    for (final ThemeSpec theme in available) {
      if (theme.id == active) return theme;
    }
    if (available.isNotEmpty) return available.first;
    return ThemeSpec.fallback;
  }

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    final List<ThemeSpec> themes = <ThemeSpec>[];
    final dynamic raw = json['available'];
    if (raw is List) {
      for (final dynamic entry in raw) {
        if (entry is Map) themes.add(ThemeSpec.fromJson(asMap(entry)));
      }
    }
    return ThemeConfig(
      active: asStringOr(json['active'], themes.isEmpty ? 'theme1' : themes.first.id),
      available: themes,
    );
  }


  Map<String, dynamic> toJson() => <String, dynamic>{
        'active': active,
        'available': available.map((ThemeSpec theme) => theme.toJson()).toList(),
      };
}

// ----------------------------------------------------------------- xtream

class XtreamConfig {
  const XtreamConfig({
    this.server = '',
    this.userAgent = 'VLC/3.0.20 LibVLC/3.0.20',
    this.streamToken = '',
  });

  final String server;
  final String userAgent;
  final String streamToken;

  factory XtreamConfig.fromJson(Map<String, dynamic> json) => XtreamConfig(
        server: asStringOr(json['server'], ''),
        userAgent: asStringOr(json['userAgent'], 'VLC/3.0.20 LibVLC/3.0.20'),
        streamToken: asStringOr(json['streamToken'], ''),
      );


  Map<String, dynamic> toJson() => <String, dynamic>{
        'server': server,
        'userAgent': userAgent,
        'streamToken': streamToken,
      };
}

// --------------------------------------------------------------- updates

class UpdateConfig {
  const UpdateConfig({
    this.enabled = false,
    this.latestVersion = kAppVersion,
    this.minVersion = '1.0.0',
    this.apkUrl = '',
    this.apkUrlArm32 = '',
    this.apkUrlArm64 = '',
    this.changelog = '',
    this.forceUpdate = false,
  });

  final bool enabled;
  final String latestVersion;
  final String minVersion;
  final String apkUrl;

  /// APK especifico para 32 bits (Fire TV Stick y cajas antiguas).
  final String apkUrlArm32;

  /// APK especifico para 64 bits (moviles modernos, Cube, Shield).
  final String apkUrlArm64;

  final String changelog;
  final bool forceUpdate;

  bool get hasUpdate => enabled && isVersionNewer(latestVersion, kAppVersion);

  /// Obligatorio si la marca lo pide o si la versión instalada es inferior a la
  /// mínima soportada.
  bool get isMandatory =>
      hasUpdate && (forceUpdate || isVersionNewer(minVersion, kAppVersion));

  bool get canDownload =>
      apkUrl.trim().isNotEmpty ||
      apkUrlArm32.trim().isNotEmpty ||
      apkUrlArm64.trim().isNotEmpty;

  /// APK que le toca a este equipo: 64 bits, 32 bits o el universal.
  String apkUrlForAbis(List<String> abis) {
    final bool isArm64 = abis.contains('arm64-v8a');
    final bool isArm32 = abis.contains('armeabi-v7a');
    if (isArm64 && apkUrlArm64.trim().isNotEmpty) return apkUrlArm64.trim();
    if (isArm32 && apkUrlArm32.trim().isNotEmpty) return apkUrlArm32.trim();
    // x86_64 (emulador) y cualquier otro: APK universal.
    return apkUrl.trim();
  }

  factory UpdateConfig.fromJson(Map<String, dynamic> json) => UpdateConfig(
        enabled: asBool(json['enabled']),
        latestVersion: asStringOr(json['latestVersion'], kAppVersion),
        minVersion: asStringOr(json['minVersion'], '1.0.0'),
        apkUrl: asStringOr(json['apkUrl'], ''),
        apkUrlArm32: asStringOr(json['apkUrlArm32'], ''),
        apkUrlArm64: asStringOr(json['apkUrlArm64'], ''),
        changelog: asStringOr(json['changelog'], ''),
        forceUpdate: asBool(json['forceUpdate']),
      );


  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'latestVersion': latestVersion,
        'minVersion': minVersion,
        'apkUrl': apkUrl,
        'apkUrlArm32': apkUrlArm32,
        'apkUrlArm64': apkUrlArm64,
        'changelog': changelog,
        'forceUpdate': forceUpdate,
      };
}

// -------------------------------------------------------------- features

class FeaturesConfig {
  const FeaturesConfig({
    this.search = true,
    this.favorites = true,
    this.epg = true,
    this.dkPlayer = false,
    this.vlcPlayer = true,
    this.allowThemeSwitch = true,
    this.showAccountInfo = true,
  });

  final bool search;
  final bool favorites;
  final bool epg;

  /// Obsoleto: el motor principal es siempre ExoPlayer (Media3).
  final bool dkPlayer;

  /// Segundo motor: libmpv (media_kit). Solo se usa si ExoPlayer no puede
  /// abrir el canal/pelicula. Activado por defecto.
  final bool vlcPlayer;

  final bool allowThemeSwitch;
  final bool showAccountInfo;

  factory FeaturesConfig.fromJson(Map<String, dynamic> json) => FeaturesConfig(
        search: json['search'] == null ? true : asBool(json['search']),
        favorites:
            json['favorites'] == null ? true : asBool(json['favorites']),
        epg: json['epg'] == null ? true : asBool(json['epg']),
        dkPlayer: json['dkPlayer'] == null ? false : asBool(json['dkPlayer']),
        vlcPlayer: json['vlcPlayer'] == null
            ? true
            : asBool(json['vlcPlayer']),
        allowThemeSwitch: json['allowThemeSwitch'] == null
            ? true
            : asBool(json['allowThemeSwitch']),
        showAccountInfo: json['showAccountInfo'] == null
            ? true
            : asBool(json['showAccountInfo']),
      );


  Map<String, dynamic> toJson() => <String, dynamic>{
        'search': search,
        'favorites': favorites,
        'epg': epg,
        'dkPlayer': dkPlayer,
        'vlcPlayer': vlcPlayer,
        'allowThemeSwitch': allowThemeSwitch,
        'showAccountInfo': showAccountInfo,
      };
}

// ------------------------------------------------------------ configuración

/// Configuración completa de la app (marca blanca, temas, anuncios y updates).
class PlayerConfig {
  const PlayerConfig({
    this.idlePromptHours = 6,
    this.idlePromptMessage = '¿Quieres seguir viendo este canal?',
    this.idlePromptTestMode = false,
    this.subtitleColor = '#FFFFFF',
    this.subtitleSize = 22,
  });

  /// Cada cuántas horas (en directo) se pregunta si sigues viendo. 0 = nunca.
  final int idlePromptHours;

  /// Texto del aviso de inactividad.
  final String idlePromptMessage;

  /// Modo prueba: muestra el aviso cada 60 s (para verlo sin esperar horas).
  final bool idlePromptTestMode;

  /// Color de los subtítulos (hex). Por defecto blanco.
  final String subtitleColor;

  /// Tamaño de los subtítulos. Por defecto 22 (algo grande).
  final double subtitleSize;

  factory PlayerConfig.fromJson(Map<String, dynamic> json) => PlayerConfig(
        idlePromptHours: asInt(json['idlePromptHours'], 6),
        idlePromptMessage: asStringOr(
            json['idlePromptMessage'], '¿Quieres seguir viendo este canal?'),
        idlePromptTestMode: asBool(json['idlePromptTestMode']),
        subtitleColor: asStringOr(json['subtitleColor'], '#FFFFFF'),
        subtitleSize: asDouble(json['subtitleSize'], 22),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'idlePromptHours': idlePromptHours,
        'idlePromptMessage': idlePromptMessage,
        'idlePromptTestMode': idlePromptTestMode,
        'subtitleColor': subtitleColor,
        'subtitleSize': subtitleSize,
      };
}

class TmdbConfig {
  const TmdbConfig({this.apiKey = ''});

  /// API key v3 de TMDB (https://www.themoviedb.org/settings/api).
  /// Se usa para resolver el tráiler de películas/series cuando el panel
  /// Xtream no lo trae.
  final String apiKey;

  factory TmdbConfig.fromJson(Map<String, dynamic> json) => TmdbConfig(
        apiKey: asStringOr(json['apiKey'], ''),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'apiKey': apiKey,
      };
}

class AppConfig {
  const AppConfig({
    this.schemaVersion = 1,
    this.remoteConfigUrl = '',
    this.packageId = '',
    this.branding = const BrandingConfig(),
    this.theme = const ThemeConfig(),
    this.xtream = const XtreamConfig(),
    this.tmdb = const TmdbConfig(),
    this.ads = const AdsConfig(),
    this.update = const UpdateConfig(),
    this.features = const FeaturesConfig(),
    this.player = const PlayerConfig(),
  });

  final int schemaVersion;

  /// Si se informa, la app descarga ahí un JSON parcial que sobrescribe esta
  /// configuración (permite cambiar anuncios, fondos o versiones sin compilar).
  final String remoteConfigUrl;

  /// Identificador Android de esta marca (`com.ibwtv.app`). Lo usa el script de
  /// compilación para que varias versiones convivan en el mismo dispositivo.
  final String packageId;

  final BrandingConfig branding;
  final ThemeConfig theme;
  final XtreamConfig xtream;
  final TmdbConfig tmdb;
  final AdsConfig ads;
  final UpdateConfig update;
  final FeaturesConfig features;
  final PlayerConfig player;

  bool get hasRemoteConfig => remoteConfigUrl.trim().isNotEmpty;

  /// Ajustes del emplazamiento publicitario indicado.
  AdPlacementConfig adPlacement(AdPlacement placement) =>
      ads.placement(placement);

  /// El campo de servidor solo aparece si NO hay uno grabado en la marca.
  /// Si el panel ya viene configurado, el usuario nunca debe escribir IP/dominio.
  bool get showsServerField => xtream.server.trim().isEmpty;

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        schemaVersion: asInt(json['schemaVersion'], 1),
        remoteConfigUrl: asStringOr(json['remoteConfigUrl'], ''),
        packageId: asStringOr(json['packageId'], ''),
        branding: BrandingConfig.fromJson(asMap(json['branding'])),
        theme: ThemeConfig.fromJson(asMap(json['theme'])),
        xtream: XtreamConfig.fromJson(asMap(json['xtream'])),
        tmdb: TmdbConfig.fromJson(asMap(json['tmdb'])),
        ads: AdsConfig.fromJson(asMap(json['ads'])),
        update: UpdateConfig.fromJson(asMap(json['update'])),
        features: FeaturesConfig.fromJson(asMap(json['features'])),
        player: PlayerConfig.fromJson(asMap(json['player'])),
      );


  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'remoteConfigUrl': remoteConfigUrl,
        'packageId': packageId,
        'branding': branding.toJson(),
        'theme': theme.toJson(),
        'xtream': xtream.toJson(),
        'tmdb': tmdb.toJson(),
        'ads': ads.toJson(),
        'update': update.toJson(),
        'features': features.toJson(),
        'player': player.toJson(),
      };

  AppConfig copyWith({
    String? remoteConfigUrl,
    String? packageId,
    BrandingConfig? branding,
    ThemeConfig? theme,
    XtreamConfig? xtream,
    TmdbConfig? tmdb,
    AdsConfig? ads,
    UpdateConfig? update,
    FeaturesConfig? features,
    PlayerConfig? player,
  }) {
    return AppConfig(
      schemaVersion: schemaVersion,
      remoteConfigUrl: remoteConfigUrl ?? this.remoteConfigUrl,
      packageId: packageId ?? this.packageId,
      branding: branding ?? this.branding,
      theme: theme ?? this.theme,
      xtream: xtream ?? this.xtream,
      tmdb: tmdb ?? this.tmdb,
      ads: ads ?? this.ads,
      update: update ?? this.update,
      features: features ?? this.features,
      player: player ?? this.player,
    );
  }
}
