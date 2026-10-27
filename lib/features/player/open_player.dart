import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/ads_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/playable_item.dart';
import '../../core/state/app_state.dart';
import '../../widgets/ad_banner.dart';
import 'player_native_ijk_page.dart';
import 'player_texture_page.dart';
import 'player_vlc_page.dart';
import 'player_mpv_page.dart';

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
  if (playlist.isEmpty) return;

  final ConfigController config = context.read<ConfigController>();
  final AppState app = context.read<AppState>();

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

  // Motor elegido por el usuario en Ajustes (ExoPlayer por defecto).
  final String engine = app.playerEngine;
  final Object? result = await Navigator.of(context).push<Object>(
    MaterialPageRoute<Object>(
      builder: (_) {
        if (engine == 'ijk') {
          return PlayerNativeIjkPage(
            playlist: playlist,
            initialIndex: initialIndex,
            headers: app.headers,
          );
        }
        if (engine == 'vlc') {
          return PlayerVlcPage(
            playlist: playlist,
            initialIndex: initialIndex,
            headers: app.headers,
          );
        }
        if (engine == 'mpv') {
          return PlayerMpvPage(
            playlist: playlist,
            initialIndex: initialIndex,
            headers: app.headers,
            mediaType: mediaType,
            categoryName: categoryName,
          );
        }
        return PlayerTexturePage(
          playlist: playlist,
          initialIndex: initialIndex,
          headers: app.headers,
          categoryName: categoryName,
        );
      },
    ),
  );

  // 2) Si libVLC no arranco (timeout), se reintenta con ExoPlayer.
  if (result == 'exo') {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerTexturePage(
          playlist: playlist,
          initialIndex: initialIndex,
          headers: app.headers,
          categoryName: categoryName,
        ),
      ),
    );
    return;
  }

  // 3) Segunda opcion: libmpv (media_kit), solo si el panel lo permite.
  if (result != 'mpv') return;
  if (!Platform.isAndroid) return;
  if (!config.config.features.vlcPlayer) return;
  if (!context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerMpvPage(
        playlist: playlist,
        initialIndex: initialIndex,
        headers: app.headers,
        mediaType: mediaType,
        categoryName: categoryName,
      ),
    ),
  );
}
