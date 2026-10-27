import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Timed Media3 output. Bitmap captions keep their original artwork; only text
/// captions can honor a font size and color selected by the user.
class PlayerSubtitleCue {
  const PlayerSubtitleCue({this.text = '', this.bitmap, this.position,
    this.line, this.size, this.bitmapHeight, this.positionAnchor = 1,
    this.lineAnchor = 0, this.alignment = TextAlign.center});
  final String text;
  final Uint8List? bitmap;
  final double? position, line, size, bitmapHeight;
  final int positionAnchor, lineAnchor;
  final TextAlign alignment;
  static double? _fraction(dynamic value) => value is num && value.isFinite &&
      value >= 0 && value <= 1 ? value.toDouble() : null;
  static int _anchor(dynamic value, int fallback) =>
      value is int && value >= 0 && value <= 2 ? value : fallback;
  factory PlayerSubtitleCue.fromMap(Map<dynamic, dynamic> map) => PlayerSubtitleCue(
    text: map['text'] is String ? map['text'] as String : '',
    bitmap: map['bitmap'] is Uint8List ? map['bitmap'] as Uint8List : null,
    position: _fraction(map['position']),
    line: map['lineType'] == 0 ? _fraction(map['line']) : null,
    size: _fraction(map['size']), bitmapHeight: _fraction(map['bitmapHeight']),
    positionAnchor: _anchor(map['positionAnchor'], 1),
    lineAnchor: _anchor(map['lineAnchor'], 0),
    alignment: map['alignment'] == 'ALIGN_NORMAL' ? TextAlign.start :
        map['alignment'] == 'ALIGN_OPPOSITE' ? TextAlign.end : TextAlign.center,
  );
  static List<PlayerSubtitleCue> decode(dynamic payload) => payload is List
      ? payload.whereType<Map>().map(PlayerSubtitleCue.fromMap)
          .where((cue) => cue.text.isNotEmpty || cue.bitmap != null).toList()
      : const <PlayerSubtitleCue>[];
}

class PlayerSubtitles extends StatelessWidget {
  const PlayerSubtitles({super.key, required this.cues, required this.color,
    required this.fontSize, this.bottomInset = 24});
  final List<PlayerSubtitleCue> cues;
  final Color color;
  final double fontSize, bottomInset;
  Widget _content(PlayerSubtitleCue cue) {
    if (cue.bitmap != null) return Image.memory(cue.bitmap!, fit: BoxFit.contain,
      gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox.shrink());
    return Text(cue.text, textAlign: cue.alignment, textScaler: TextScaler.noScaling,
      style: TextStyle(color: color, fontSize: fontSize.clamp(14, 40).toDouble(),
        fontWeight: FontWeight.w600, height: 1.25,
        shadows: const <Shadow>[
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
          Shadow(color: Colors.black, blurRadius: 3, offset: Offset(-1, -1)),
        ]));
  }
  @override
  Widget build(BuildContext context) {
    if (cues.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(child: ClipRect(child: LayoutBuilder(builder: (_, box) {
      final automatic = cues.where((cue) => cue.line == null).toList();
      return Stack(fit: StackFit.expand, children: <Widget>[
        if (automatic.isNotEmpty) Positioned(left: box.maxWidth * .05,
          right: box.maxWidth * .05,
          bottom: bottomInset.clamp(0.0, box.maxHeight * .4).toDouble(),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            for (final cue in automatic) SizedBox(
              width: box.maxWidth * (cue.size ?? .9),
              height: cue.bitmap != null ? box.maxHeight * (cue.bitmapHeight ?? .2) : null,
              child: _content(cue)),
          ])),
        for (final cue in cues.where((cue) => cue.line != null))
          Positioned(
            left: ((cue.position ?? .5) * box.maxWidth -
                box.maxWidth * (cue.size ?? .9) * cue.positionAnchor / 2)
                .clamp(0.0, box.maxWidth * (1 - (cue.size ?? .9))).toDouble(),
            top: cue.line! * box.maxHeight,
            width: box.maxWidth * (cue.size ?? .9),
            child: FractionalTranslation(translation: Offset(0, -cue.lineAnchor / 2),
              child: SizedBox(
                height: cue.bitmap != null ? box.maxHeight * (cue.bitmapHeight ?? .2) : null,
                child: _content(cue))),
          ),
      ]);
    })));
  }
}
