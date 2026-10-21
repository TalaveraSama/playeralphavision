import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Decodifica un `data:image/png;base64,...`.
///
/// El panel de administración genera este formato cuando se sube un archivo en
/// lugar de pegar una URL (logo, fondos, anuncios). Devuelve `null` si el texto
/// no es un data URI en Base64 válido.
Uint8List? decodeDataUri(String value) {
  if (!value.startsWith('data:')) return null;
  final int comma = value.indexOf(',');
  if (comma < 0) return null;
  if (!value.substring(0, comma).contains('base64')) return null;
  try {
    return base64Decode(value.substring(comma + 1).trim());
  } catch (_) {
    return null;
  }
}

/// Imagen remota con caché en disco + memoria.
///
/// Acepta tanto una URL (`https://...`) como una imagen incrustada
/// (`data:image/...;base64,...`), que es lo que produce el panel al subir un
/// archivo.
///
/// Nota: antes había una cola propia con `max = 4` descargas simultáneas. El
/// problema es que al volver a entrar a una pantalla los widgets se recrean y,
/// si la cola estaba ocupada, se volvía a pintar el marcador gris hasta que
/// llegara el turno: parecía que "volvían a cargar". `cached_network_image` ya
/// trae su propia cola y caché; basta con `memCacheWidth`/`maxWidthDiskCache`
/// para no reventar la memoria del Fire TV Stick (1 GB).
class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.icon = Icons.image_outlined,
    this.iconSize = 28,
    this.backgroundColor,
    this.cacheWidth,
  });

  final String? url;
  final BoxFit fit;
  final IconData icon;
  final double iconSize;
  final Color? backgroundColor;

  /// Ancho al que se decodifica la imagen en memoria.
  ///
  /// Clave en equipos con poca RAM (Fire TV Stick de 1 GB): un logo de 1000 px
  /// ocupa varios MB en memoria aunque se pinte en 120 px. Indicando el ancho
  /// real de dibujo, la app aguanta miles de canales sin que el sistema la mate.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final Color color =
        backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    final Widget fallback = Container(
      color: color,
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: Colors.white24),
    );

    final String? imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) return fallback;

    if (imageUrl.startsWith('data:')) {
      final Uint8List? bytes = decodeDataUri(imageUrl);
      if (bytes == null) return fallback;
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: cacheWidth,
      maxWidthDiskCache: cacheWidth,
      // Sin fundido y conservando la imagen anterior: si ya está en caché sale
      // al instante y no "parpadea" el marcador.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      // Fuerza el fit (cover = recorta sin deformar; nunca estira).
      imageBuilder: (BuildContext context, ImageProvider<Object> provider) =>
          Image(
        image: provider,
        fit: fit,
        alignment: Alignment.center,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      ),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
