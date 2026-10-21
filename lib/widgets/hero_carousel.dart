import 'dart:async';

import 'package:flutter/material.dart';

/// Carrusel de la cabecera destacada.
///
/// Rota solo cada [seconds] segundos entre los elementos que se le pasan, deja
/// puntos indicadores y no corta el desplazamiento manual (mientras el usuario
/// arrastra, el temporizador no cambia de página).
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    super.key,
    required this.itemCount,
    required this.builder,
    required this.height,
    this.seconds = 7,
    this.dotsBottom = 18,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) builder;
  final double height;

  /// Segundos que cada elemento permanece en pantalla.
  final int seconds;
  final double dotsBottom;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.seconds != widget.seconds) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    if (widget.itemCount < 2) return;
    final int seconds = widget.seconds <= 0 ? 7 : widget.seconds;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!mounted || _dragging || !_controller.hasClients) return;
      final int next = (_index + 1) % widget.itemCount;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return SizedBox(height: widget.height);

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: <Widget>[
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (notification is ScrollStartNotification) _dragging = true;
              if (notification is ScrollEndNotification) _dragging = false;
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.itemCount,
              onPageChanged: (int index) => setState(() => _index = index),
              itemBuilder: widget.builder,
            ),
          ),
          if (widget.itemCount > 1)
            Positioned(
              right: 18,
              bottom: widget.dotsBottom,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < widget.itemCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: i == _index ? 20 : 6,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
