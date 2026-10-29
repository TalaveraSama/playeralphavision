/// Preferences apply to standard Android video decoders, not encoding/output.
enum VideoDecodeMode {
  auto('auto', 'Automático', 'ExoPlayer elige los decodificadores del equipo.'),
  hardware('hardware', 'Hardware preferido',
      'Prioriza aceleración disponible; permite otra opción compatible si falla al iniciar.'),
  software('software', 'Software de Android',
      'Solo decodificadores software del sistema. Algunos formatos no estarán disponibles.');

  const VideoDecodeMode(this.id, this.label, this.description);
  final String id, label, description;
  static VideoDecodeMode parse(String? value) => values.firstWhere(
    (mode) => mode.id == value, orElse: () => auto);
}
