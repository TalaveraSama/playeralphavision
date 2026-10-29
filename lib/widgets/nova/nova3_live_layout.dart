import 'package:flutter/material.dart';

import '../../core/models/playable_item.dart';
import '../net_image.dart';
import 'nova_ui.dart';

/// Vídeo siempre a tamaño completo. La lista y los controles se superponen;
/// abrirlos nunca cambia las restricciones del vídeo ni recrea el motor.
class Nova3LiveLayout extends StatelessWidget {
  const Nova3LiveLayout({super.key, required this.video, required this.playlist,
    required this.index, required this.onSelect, required this.onBack,
    required this.onFullscreen, required this.fullscreen, required this.controls});
  final Widget video;
  final List<PlayableItem> playlist;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack, onFullscreen;
  final bool fullscreen;
  final Widget controls;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final bool small = constraints.maxHeight < 500;
    final double channelWidth = (constraints.maxWidth * .26).clamp(170.0, 320.0);
    return Stack(fit: StackFit.expand, children: <Widget>[
      Positioned.fill(child: GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: onFullscreen, child: video)),
      if (!fullscreen) ...<Widget>[
        Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: <Color>[Colors.black.withValues(alpha: .5), Colors.transparent,
              Colors.black.withValues(alpha: .7)], stops: const <double>[0, .55, 1]))))),
        Positioned(top: 8, left: 8, child: SafeArea(bottom: false,
          child: NovaSquareButton(icon: Icons.arrow_back, tooltip: 'Volver a TV', onPressed: onBack))),
        Positioned(top: 8, left: 68, right: channelWidth + 24,
          child: SafeArea(bottom: false, child: Text(playlist[index].title,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        Positioned(top: 0, right: 0, bottom: 0, width: channelWidth,
          child: Material(color: const Color(0xE6101420), child: SafeArea(left: false,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              itemCount: playlist.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Semantics(selected: i == index, child: NovaFocusable(
                  autofocus: i == index, onTap: () => onSelect(i),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: i == index ? Theme.of(context).colorScheme.primary.withValues(alpha: .25) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4)),
                    child: Row(children: <Widget>[
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(
                        width: small ? 40 : 56, height: small ? 40 : 56,
                        child: NetImage(url: playlist[i].logo, fit: BoxFit.contain, cacheWidth: 128))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(playlist[i].title, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: small ? 12 : 15))),
                    ]),
                  ),
                ))),
            )))),
        Positioned(left: 8, right: channelWidth + 8, bottom: 8,
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 48, child: FittedBox(fit: BoxFit.scaleDown, child: controls)),
              TextButton.icon(onPressed: onFullscreen, icon: const Icon(Icons.fullscreen),
                label: const Text('Ocultar controles'),
                style: TextButton.styleFrom(foregroundColor: Colors.white)),
            ]))),
      ],
    ]);
  });
}
