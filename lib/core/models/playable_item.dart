import 'media_item.dart';

/// Un elemento reproducible: ya tiene la URL final de streaming resuelta.
class PlayableItem {
  const PlayableItem({
    required this.title,
    required this.url,
    this.subtitle,
    this.logo,
    this.isLive = false,
    this.streamId,
    this.channelNumber,
    this.resumeKey,
    this.source,
  });

  final String title;
  final String url;
  final String? subtitle;
  final String? logo;

  /// En directo no se muestra barra de progreso ni se permite buscar.
  final bool isLive;

  /// `stream_id` del canal, para pedir la guía EPG.
  final String? streamId;

  /// Numero del canal en el panel (1, 2, 3...), para el aviso de cambio.
  final int? channelNumber;

  /// Clave con la que se guarda la posición de reproducción (películas).
  /// Si es `null`, el reproductor usa la propia URL como clave (episodios).
  final String? resumeKey;

  /// Elemento de catálogo del que sale, cuando existe.
  final MediaItem? source;

  /// Clave efectiva para «continuar viendo».
  String get progressKey => resumeKey ?? 'url:$url';
}
