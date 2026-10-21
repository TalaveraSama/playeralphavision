import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/ads/ad_engine.dart';
import '../core/config/ads_config.dart';
import '../core/config/config_controller.dart';
import '../core/utils/launcher.dart';
import 'net_image.dart';

/// Franja publicitaria rotativa.
///
/// Los anuncios los elige el motor (`core/ads/ad_engine.dart`), que aplica
/// pesos, topes por hora, límite diario por anuncio y segmentación por tipo de
/// contenido, categoría, palabras clave y franja horaria.
class AdBanner extends StatefulWidget {
  const AdBanner({
    super.key,
    this.mediaType,
    this.categoryName,
    this.title,
    this.margin = const EdgeInsets.fromLTRB(12, 6, 12, 10),
    this.height = 96,
    this.borderRadius = 10,
  });

  final AdMediaType? mediaType;
  final String? categoryName;
  final String? title;
  final EdgeInsets margin;
  final double height;
  final double borderRadius;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  List<AdCreative> _rotation = const <AdCreative>[];
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant AdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryName != widget.categoryName ||
        oldWidget.mediaType != widget.mediaType) {
      _load();
    }
  }

  void _load() {
    if (!mounted) return;
    final ConfigController config = context.read<ConfigController>();
    // La franja solo admite imágenes y avisos: los vídeos van a pantalla
    // completa.
    final List<AdCreative> rotation = config
        .bannerRotation(
          mediaType: widget.mediaType,
          categoryName: widget.categoryName,
          title: widget.title,
        )
        .where((AdCreative ad) => ad.kind != AdKind.video)
        .toList();

    setState(() {
      _rotation = rotation;
      _index = 0;
    });
    _timer?.cancel();

    if (rotation.isEmpty) return;
    _countImpression(rotation.first);
    if (rotation.length < 2) return;

    final int seconds = config.config.ads.rotationSeconds <= 0
        ? 12
        : config.config.ads.rotationSeconds;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!mounted || _rotation.length < 2) return;
      setState(() => _index = (_index + 1) % _rotation.length);
      _countImpression(_rotation[_index]);
    });
  }

  void _countImpression(AdCreative ad) {
    final ConfigController config = context.read<ConfigController>();
    unawaited(
      config.registerImpression(
        ad,
        AdContext(
          placement: AdPlacement.banner,
          now: DateTime.now(),
          mediaType: widget.mediaType,
          categoryName: widget.categoryName,
          title: widget.title,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted || _rotation.isEmpty) return const SizedBox.shrink();
    final AdCreative ad = _rotation[_index % _rotation.length];

    return Padding(
      padding: widget.margin,
      child: GestureDetector(
        onTap: () => openExternal(ad.clickUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _AdSurface(
                  ad: ad,
                  fallback: Container(
                    color: const Color(0xFF1B1B1B),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: Colors.white24,
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: _AdLabel(text: ad.label),
                ),
                if (ad.title.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0x00000000), Color(0xCC000000)],
                        ),
                      ),
                      child: Text(
                        ad.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdLabel extends StatelessWidget {
  const _AdLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 9, color: Colors.white70),
      ),
    );
  }
}

/// Pinta la creatividad según su tipo (imagen o aviso de texto).
class _AdSurface extends StatelessWidget {
  const _AdSurface({required this.ad, required this.fallback});

  final AdCreative ad;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (ad.kind == AdKind.video) return fallback;
    if (ad.kind == AdKind.message || !ad.hasMedia) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.all(12),
        alignment: Alignment.centerLeft,
        child: Text(
          ad.text.isEmpty ? ad.title : ad.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }
    return NetImage(url: ad.mediaUrl, fit: BoxFit.cover, icon: Icons.campaign_outlined);
  }
}

/// Muestra un anuncio a pantalla completa (interstitial o preroll).
///
/// Admite imagen, vídeo y aviso de texto, con botón de cierre tras
/// [AdCreative.skipAfterSec] segundos y cierre automático a los
/// [AdCreative.durationSec].
Future<void> showFullScreenAd(
  BuildContext context,
  AdCreative ad,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => _FullScreenAdDialog(ad: ad),
  );
}

class _FullScreenAdDialog extends StatefulWidget {
  const _FullScreenAdDialog({required this.ad});

  final AdCreative ad;

  @override
  State<_FullScreenAdDialog> createState() => _FullScreenAdDialogState();
}

class _FullScreenAdDialogState extends State<_FullScreenAdDialog> {
  Timer? _countdown;
  Timer? _autoClose;
  VideoPlayerController? _video;
  bool _videoReady = false;
  late int _remainingSkip;

  @override
  void initState() {
    super.initState();
    _remainingSkip = widget.ad.skipAfterSec.clamp(0, 120);

    if (_remainingSkip > 0) {
      _countdown = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        if (!mounted) return;
        setState(() => _remainingSkip--);
        if (_remainingSkip <= 0) timer.cancel();
      });
    }

    final int duration = widget.ad.durationSec.clamp(0, 300);
    if (duration > 0) {
      _autoClose = Timer(Duration(seconds: duration), _close);
    }

    if (widget.ad.kind == AdKind.video && widget.ad.hasMedia) {
      _startVideo();
    }
  }

  Future<void> _startVideo() async {
    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.ad.mediaUrl),
    );
    _video = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(false);
      await controller.play();
      setState(() => _videoReady = true);
    } catch (_) {
      // Si el vídeo no se puede reproducir, el anuncio se cierra solo.
      _close();
    }
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _autoClose?.cancel();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdCreative ad = widget.ad;
    final bool canClose = _remainingSkip <= 0;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            onTap: () => openExternal(ad.clickUrl),
            child: _buildContent(ad),
          ),
          Positioned(left: 12, top: 12, child: _AdLabel(text: ad.label)),
          Positioned(
            right: 12,
            top: 12,
            child: canClose
                ? IconButton.filledTonal(
                    tooltip: 'Cerrar',
                    onPressed: _close,
                    icon: const Icon(Icons.close),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Puedes cerrar en $_remainingSkip s'),
                  ),
          ),
          if (ad.title.isNotEmpty || ad.text.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: 26,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (ad.title.isNotEmpty)
                    Text(
                      ad.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (ad.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        ad.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(AdCreative ad) {
    if (ad.kind == AdKind.video) {
      final VideoPlayerController? controller = _video;
      if (controller == null || !_videoReady) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio == 0
              ? 16 / 9
              : controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }
    if (ad.kind == AdKind.message || !ad.hasMedia) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            ad.text.isEmpty ? ad.title : ad.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, height: 1.4),
          ),
        ),
      );
    }
    return NetImage(
      url: ad.mediaUrl,
      fit: BoxFit.contain,
      icon: Icons.campaign_outlined,
      iconSize: 60,
      backgroundColor: Colors.black,
      cacheWidth: 1280,
    );
  }
}

/// Aviso publicitario **encima del vídeo**: se cierra solo al acabar la cuenta
/// atrás o con el botón «Cerrar». Para avisos especiales de la marca.
class AdOverlay extends StatelessWidget {
  const AdOverlay({
    super.key,
    required this.ad,
    required this.remainingSeconds,
    required this.onClose,
  });

  final AdCreative ad;
  final int remainingSeconds;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool showMedia = ad.hasMedia && ad.kind != AdKind.message;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 400),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showMedia)
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _AdSurface(
                      ad: ad,
                      fallback: const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (ad.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    ad.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              if (ad.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    ad.text,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${ad.label} · se cierra en $remainingSeconds s',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 14),
                  FilledButton(onPressed: onClose, child: const Text('Cerrar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}