import 'dart:math' as math;
import 'package:flutter/material.dart';

class Nova3Loading extends StatefulWidget {
  const Nova3Loading({super.key, this.bytesPerSecond});
  /// Muestra de Media3; null significa que aún no existe medición.
  final double? bytesPerSecond;
  @override
  State<Nova3Loading> createState() => _Nova3LoadingState();
}
class _Nova3LoadingState extends State<Nova3Loading> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this,
    duration: const Duration(milliseconds: 1000));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
    } else {
      _spin.repeat();
    }
  }
  @override
  void dispose() { _spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Center(child: Semantics(
    label: 'Cargando vídeo', child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      AnimatedBuilder(animation: _spin, builder: (context, _) => SizedBox(width: 72, height: 72,
        child: Stack(children: <Widget>[
          for (int i = 0; i < 8; i++)
            Positioned(left: 30 + 27 * math.cos(i * math.pi / 4),
              top: 30 + 27 * math.sin(i * math.pi / 4),
              child: Opacity(opacity: MediaQuery.disableAnimationsOf(context) ? 0.8 :
                  0.2 + 0.8 * ((i / 8 + _spin.value) % 1),
                child: Container(width: 12, height: 12,
                  decoration: const BoxDecoration(color: Color(0xFF456BFF), shape: BoxShape.circle)))),
        ]))),
      const SizedBox(height: 14),
      Text(widget.bytesPerSecond == null ? 'Conectando…' :
        '${(widget.bytesPerSecond! / 1024).toStringAsFixed(0)} KB/s · estimada',
        style: const TextStyle(color: Colors.white, fontSize: 13)),
    ]),
  ));
}
