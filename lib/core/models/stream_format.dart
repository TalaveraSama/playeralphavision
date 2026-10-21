/// Formatos de salida que aceptan los paneles Xtream/XUI.one para el directo.
enum StreamFormat { auto, hls, mpegTs }

extension StreamFormatX on StreamFormat {
  String get label {
    switch (this) {
      case StreamFormat.auto:
        return 'Automático';
      case StreamFormat.hls:
        return 'HLS (.m3u8)';
      case StreamFormat.mpegTs:
        return 'MPEG-TS (.ts)';
    }
  }

  String get description {
    switch (this) {
      case StreamFormat.auto:
        return 'Usa HLS y cambia a MPEG-TS si el canal no arranca.';
      case StreamFormat.hls:
        return 'Más compatible con conexiones lentas y con la TV en directo.';
      case StreamFormat.mpegTs:
        return 'Flujo continuo; suele ir mejor en redes locales rápidas.';
    }
  }

  String get liveExtension {
    switch (this) {
      case StreamFormat.auto:
      case StreamFormat.hls:
        return 'm3u8';
      case StreamFormat.mpegTs:
        return 'ts';
    }
  }
}
