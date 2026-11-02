import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/ads_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/playable_item.dart';
import '../../core/state/app_state.dart';
import '../../widgets/ad_banner.dart';
import 'player_texture_page.dart';

bool _playerOpen = false;

/// Abre el reproductor mostrando antes el anuncio de pantalla completa si toca.
///
/// Centraliza el paso por publicidad para que cualquier pantalla (catálogo,
/// búsqueda, favoritos o ficha de serie) se comporte igual.
Future<void> openPlayer(
  BuildContext context, {
  required List<PlayableItem> playlist,
  int initialIndex = 0,
  AdMediaType? mediaType,
  String? categoryName,
  String? title,
}) async {
  if (playlist.isEmpty || _playerOpen) return;
  if (!Platform.isAndroid) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Esta edición usa ExoPlayer y solo reproduce en Android / Android TV.')));
    return;
  }

  _playerOpen = true;
  try {
  final ConfigController config = context.read<ConfigController>();
  final AppState app = context.read<AppState>();

  try {
    await app.preparePlayback();
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('No se pudo autorizar la reproducción. Revisa tu sesión o contacta con soporte.')));
    return;
  }
  if (!context.mounted) return;

  // Interstitial: pantalla completa antes de entrar al reproductor.
  final AdCreative? ad = config.pickFullScreenAd(
    AdPlacement.interstitial,
    mediaType: mediaType,
    categoryName: categoryName,
    title: title,
  );
  if (ad != null) {
    await showFullScreenAd(context, ad);
    if (!context.mounted) return;
  }

  // ExoPlayer (Media3) es el motor principal. Se suelta la cache de
  // imagenes antes de abrir el reproductor para no competir con el video.
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();

  await Navigator.of(context).push<void>(MaterialPageRoute<void>(
    builder: (_) => PlayerTexturePage(playlist: playlist, initialIndex: initialIndex,
      headers: app.headers, categoryName: categoryName),
  ));
  } finally { _playerOpen = false; }
}
