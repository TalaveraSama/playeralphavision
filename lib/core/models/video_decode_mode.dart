/// Preferences apply to standard Android video decoders, not encoding/output.
enum VideoDecodeMode {
  auto('auto', 'Automático', 'VLC elige la decodificación disponible.'),
  hardware('hardware', 'Hardware preferido',
      'Prioriza aceleración disponible; permite otra opción compatible si falla al iniciar.'),
  software('software', 'Software VLC',
      'Decodificación por software de VLC; puede consumir más CPU.');

  const VideoDecodeMode(this.id, this.label, this.description);
  final String id, label, description;
  static VideoDecodeMode parse(String? value) => values.firstWhere(
    (mode) => mode.id == value, orElse: () => auto);
}
