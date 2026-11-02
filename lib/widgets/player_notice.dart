import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ads/ad_engine.dart';
import '../core/config/ads_config.dart';
import '../core/config/config_controller.dart';
import 'net_image.dart';

/// Aviso no modal sobre el reproductor. Las pausas de descanso NO pasan por publicidad.
class PlayerNotice extends StatefulWidget {
  const PlayerNotice({super.key, required this.child, required this.mediaType,
    required this.title, this.categoryName});
  final Widget child;
  final AdMediaType mediaType;
  final String title;
  final String? categoryName;
  @override
  State<PlayerNotice> createState() => _PlayerNoticeState();
}
class _PlayerNoticeState extends State<PlayerNotice> {
  AdsConfig? _last;
  Timer? _rotate;
  Timer? _expiry;
  AdCreative? _ad;
  String? _lastAdId;
  bool _expired = false;
  int _revision = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = context.watch<ConfigController>().config.ads;
    if (!identical(_last, ads)) {
      _last = ads;
      _reset();
    }
  }
  @override
  void didUpdateWidget(covariant PlayerNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.categoryName != widget.categoryName ||
        oldWidget.mediaType != widget.mediaType) _reset();
  }
  void _reset() {
    _rotate?.cancel(); _expiry?.cancel(); _expired = false;
    _lastAdId = null;
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision) return;
      final seconds = context.read<ConfigController>().config.ads.inPlayerSeconds;
      if (seconds > 0) _expiry = Timer(Duration(seconds: seconds), () {
        if (!mounted) return;
        _expired = true; _rotate?.cancel(); setState(() => _ad = null);
      });
      _load();
    });
  }
  void _load() {
    if (!mounted) return;
    _rotate?.cancel();
    if (ModalRoute.of(context)?.isCurrent != true ||
        (WidgetsBinding.instance.lifecycleState != null &&
         WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)) {
      setState(() => _ad = null);
      _rotate = Timer(const Duration(seconds: 1), _load);
      return;
    }
    final config = context.read<ConfigController>();
    final ads = config.config.ads;
    if (_expired || !ads.enabled || !ads.inPlayer) {
      setState(() => _ad = null); return;
    }
    final rotation = config.playerNoticeRotation(mediaType: widget.mediaType,
      title: widget.title, categoryName: widget.categoryName);
    final previousIndex = rotation.indexWhere((ad) => ad.id == _lastAdId);
    final next = rotation.isEmpty ? null : rotation[(previousIndex + 1) % rotation.length];
    _lastAdId = next?.id;
    setState(() => _ad = next);
    if (next != null) {
      unawaited(config.registerImpression(next, AdContext(placement: AdPlacement.overlay,
        now: DateTime.now(), mediaType: widget.mediaType,
        title: widget.title, categoryName: widget.categoryName)));
    }
    // Recalcular cada rotación, respetando topes horarios/diarios y targeting.
    _rotate = Timer(Duration(seconds: next == null ? 60 : ads.rotationSeconds.clamp(2, 3600)), _load);
  }
  @override
  void dispose() { _rotate?.cancel(); _expiry?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<ConfigController>().config.ads;
    final ad = enabled.enabled && enabled.inPlayer ? _ad : null;
    return Stack(fit: StackFit.expand, children: <Widget>[
      widget.child,
      if (ad != null) Positioned(top: 64, left: 16, right: 16,
        child: SafeArea(bottom: false, child: IgnorePointer(child: Material(
          color: const Color(0xD922242A), borderRadius: BorderRadius.circular(6),
          child: Padding(padding: const EdgeInsets.all(10), child: ad.kind == AdKind.image
            ? SizedBox(height: 64, child: NetImage(url: ad.mediaUrl, fit: BoxFit.contain))
            : Text(<String>[if (ad.title.trim().isNotEmpty) ad.title, ad.text].join(' · '),
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14))),
        )))),
    ]);
  }
}
