/// Time-based playback reserve, never a mandatory startup delay.
class PlaybackBuffer {
  PlaybackBuffer._();
  static const options = <int>[10, 20, 30];
  static const defaultSeconds = 10;
  static int normalize(int? value) =>
      options.contains(value) ? value! : defaultSeconds;
}
