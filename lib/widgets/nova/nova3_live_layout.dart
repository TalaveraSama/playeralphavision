import 'package:flutter/material.dart';

import '../../core/models/playable_item.dart';
import '../net_image.dart';
import 'nova_ui.dart';

/// Marco de TV independiente del motor. No crea ni duplica reproductores.
class Nova3LiveLayout extends StatelessWidget {
  const Nova3LiveLayout({super.key, required this.video, required this.playlist,
    required this.index, required this.onSelect, required this.onBack,
    required this.onFullscreen, required this.fullscreen, required this.controls});
  final Widget video;
  final List<PlayableItem> playlist;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;
  final VoidCallback onFullscreen;
  final bool fullscreen;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    if (fullscreen) {
      return Stack(fit: StackFit.expand, children: <Widget>[
        video,
        Positioned(top: 8, left: 8, child: SafeArea(child: NovaSquareButton(
          icon: Icons.fullscreen_exit, tooltip: 'Volver a la lista', onPressed: onFullscreen))),
      ]);
    }
    return SafeArea(child: LayoutBuilder(builder: (context, constraints) {
      final bool small = constraints.maxHeight < 500;
      final double channelWidth = (constraints.maxWidth * 0.24).clamp(170.0, 320.0);
      return Row(children: <Widget>[
        SizedBox(width: small ? 64 : 100, child: Align(
          alignment: Alignment.topCenter,
          child: Padding(padding: const EdgeInsets.only(top: 12), child: NovaSquareButton(
            icon: Icons.arrow_back, tooltip: 'Volver a TV', onPressed: onBack)),
        )),
        Expanded(child: Column(children: <Widget>[
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 12, right: 4),
            child: Stack(fit: StackFit.expand, children: <Widget>[
              video,
              Positioned(right: 8, bottom: 8, left: 8,
                child: Row(children: <Widget>[
                  Expanded(child: Text(playlist[index].title, maxLines: 1,
                    overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))),
                  NovaSquareButton(icon: Icons.fullscreen, tooltip: 'Pantalla completa', onPressed: onFullscreen),
                ])),
            ]),
          )),
          SizedBox(height: 56, child: controls),
        ])),
        SizedBox(width: channelWidth, child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          itemCount: playlist.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Semantics(selected: i == index, child: NovaFocusable(
              autofocus: i == index,
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: i == index ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4)),
                child: Row(children: <Widget>[
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(
                    width: small ? 40 : 56, height: small ? 40 : 56,
                    child: NetImage(url: playlist[i].logo, fit: BoxFit.contain, cacheWidth: 128))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(playlist[i].title, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: small ? 12 : 15))),
                ]),
              ),
            )),
          ),
        )),
      ]);
    }));
  }
}
