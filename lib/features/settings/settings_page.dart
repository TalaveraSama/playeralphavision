import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/stream_format.dart';
import '../../core/models/playback_buffer.dart';
import '../../core/models/video_decode_mode.dart';
import '../../core/models/xtream_account.dart';
import '../../core/models/xtream_credentials.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/device_profile.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/launcher.dart';
import '../../widgets/nova/nova_ui.dart';
import '../catalog/catalog_cache.dart';
import '../update/update_dialog.dart';

/// Ajustes de la cuenta, del reproductor, del tema y de los datos locales.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// El cliente no debe ver nada tecnico: estas secciones quedan ocultas.
  final bool _mostrarAvanzado = false;

  late final TextEditingController _userAgent;
  bool _savingUserAgent = false;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _userAgent = TextEditingController(
      text: context.read<AppState>().credentials?.userAgent ?? kDefaultUserAgent,
    );
  }

  @override
  void dispose() {
    _userAgent.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _saveUserAgent() async {
    final AppState app = context.read<AppState>();
    setState(() => _savingUserAgent = true);
    final bool ok = await app.updateUserAgent(_userAgent.text);
    if (!mounted) return;
    setState(() => _savingUserAgent = false);
    _toast(ok
        ? 'Conectado con el nuevo User-Agent.'
        : app.lastError ?? 'No se pudo aplicar el User-Agent.');
  }

  Future<void> _checkUpdates(AppState app, ConfigController config) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _toast('En iPhone actualiza desde TestFlight o App Store, según la distribución de tu marca.');
      return;
    }
    if (!config.config.hasRemoteConfig) {
      _toast('La marca no tiene servidor de configuración remota.');
      return;
    }
    setState(() => _checkingUpdate = true);
    final bool ok = await config.refreshRemote();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    if (!ok && config.hasRemoteError) {
      _toast('No se pudo consultar el servidor de configuración.');
      return;
    }
    if (!config.config.update.hasUpdate) {
      _toast('Ya tienes la última versión ($kAppVersion).');
      return;
    }
    await maybeShowUpdateDialog(context, config, app);
  }

  Future<void> _unlinkDevice() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Desvincular este aparato'),
      content: const Text('Se cerrará la sesión y se liberará la vinculación en el panel. Podrás iniciar sesión de nuevo.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desvincular'))]));
    if (confirm != true || !mounted) return;
    try { await context.read<AppState>().unlinkDevice(); }
    catch (_) { if (mounted) _toast('No se pudo desvincular. Inténtalo después o contacta con soporte.'); }
  }

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Se desconectará la cuenta de este dispositivo. '
          'Los favoritos y el historial se conservan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    CatalogCache.clear();
    await context.read<AppState>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ConfigController config = context.watch<ConfigController>();
    final ThemeData theme = Theme.of(context);
    final AppConfig appConfig = config.config;
    final BrandingConfig branding = appConfig.branding;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          if (appConfig.features.showAccountInfo)
            _buildAccountCard(app, config),
          if (appConfig.features.allowThemeSwitch &&
              appConfig.theme.available.length > 1) ...<Widget>[
            _sectionTitle(theme, 'Apariencia'),
            ...appConfig.theme.available.map(
              (ThemeSpec spec) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: NovaFocusable(
                  onTap: () => config.setTheme(spec.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: spec.primaryColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white30, width: 2),
                          ),
                          child: Icon(
                            spec.isRows
                                ? Icons.view_carousel_outlined
                                : (spec.isNova
                                    ? Icons.auto_awesome
                                    : Icons.grid_view),
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                spec.name,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                spec.layoutLabel,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          config.theme.id == spec.id
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: config.theme.id == spec.id
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (config.themeOverrideId != null)
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Volver al tema de la marca'),
                onTap: config.clearThemeOverride,
              ),
          ],
          if (_mostrarAvanzado) _sectionTitle(theme, 'Formato del directo'),
          if (_mostrarAvanzado) ...StreamFormat.values.map(
            (StreamFormat format) => ListTile(
              title: Text(format.label),
              subtitle: Text(format.description),
              trailing: Icon(
                app.format == format
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: app.format == format ? theme.colorScheme.primary : null,
              ),
              onTap: () => app.setFormat(format),
            ),
          ),
          const Divider(height: 24),
          if (_mostrarAvanzado) _sectionTitle(theme, 'Reproductor'),
          if (_mostrarAvanzado)
            Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _userAgent,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'User-Agent del reproductor',
                      helperText: 'Algunos paneles solo aceptan clientes '
                          'conocidos (VLC, Kodi, etc.).',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _savingUserAgent
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: _saveUserAgent,
                        child: const Text('Aplicar'),
                      ),
              ],
            ),
          ),
          const Divider(height: 24),
          const Divider(height: 24),
          _sectionTitle(theme, 'Reproductor'),
          const ListTile(
            leading: Icon(Icons.movie_filter_outlined),
            title: Text('ExoPlayer · único motor'),
            subtitle: Text('Android / Android TV. Decodificación estándar del dispositivo.'),
          ),
          ListTile(
            leading: const Icon(Icons.memory),
            title: const Text('Decodificación de vídeo'),
            subtitle: Text('${app.videoDecodeMode.label} · se aplica al volver a abrir el reproductor'),
            onTap: () async {
              final mode = await showDialog<VideoDecodeMode>(context: context,
                builder: (ctx) => SimpleDialog(title: const Text('Decodificación de vídeo'),
                  children: <Widget>[
                    for (final option in VideoDecodeMode.values) ListTile(
                      leading: Icon(option == app.videoDecodeMode
                          ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                      title: Text(option.label), subtitle: Text(option.description),
                      onTap: () => Navigator.of(ctx).pop(option)),
                  ]));
              if (mode != null) await app.setVideoDecodeMode(mode);
            },
          ),
          const ListTile(
            dense: true, title: Text('Flujo original, sin recodificar'),
            subtitle: Text('No transcodifica ni genera salida UDP. Audio y vídeo conservan el formato del proveedor.'),
          ),
          const Divider(height: 24),
          _sectionTitle(theme, 'Subt\u00edtulos'),
          const ListTile(
            leading: Icon(Icons.subtitles_outlined),
            title: Text('Color de los subtítulos'),
            subtitle: Text('Blanco por defecto; puedes cambiarlo a amarillo, cian o verde.'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final MapEntry<String, Color> c in <MapEntry<String, Color>>[
                  const MapEntry<String, Color>('#FFFFFF', Colors.white),
                  const MapEntry<String, Color>('#FFFF00', Colors.yellow),
                  const MapEntry<String, Color>('#00FFFF', Colors.cyan),
                  const MapEntry<String, Color>('#00FF00', Colors.green),
                ])
                  NovaFocusable(
                    onTap: () => app.setSubtitleColor(c.key),
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: c.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: app.subtitleColor.toUpperCase() == c.key
                              ? theme.colorScheme.primary
                              : Colors.grey,
                          width: 3,
                        ),
                      ),
                      child: app.subtitleColor.toUpperCase() == c.key
                          ? Icon(
                              Icons.check,
                              size: 20,
                              color: c.value.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: Text('Tamaño: ${app.subtitleSize.toStringAsFixed(0)}'),
            // En TV el Slider atrapa las flechas: se controla con - / +.
            // La barra queda solo para toque (ExcludeFocus = el mando la salta).
            subtitle: Row(
              children: <Widget>[
                NovaFocusable(
                  onTap: () => app.setSubtitleSize(
                      (app.subtitleSize - 2).clamp(14.0, 40.0)),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.remove, size: 20),
                  ),
                ),
                Expanded(
                  child: ExcludeFocus(
                    child: Slider(
                      value: app.subtitleSize.clamp(14, 40),
                      min: 14,
                      max: 40,
                      divisions: 13,
                      onChanged: (double value) =>
                          app.setSubtitleSize(value),
                    ),
                  ),
                ),
                NovaFocusable(
                  onTap: () => app.setSubtitleSize(
                      (app.subtitleSize + 2).clamp(14.0, 40.0)),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          _sectionTitle(theme, 'Datos locales'),
          SwitchListTile(
            title: const Text('Recordar sesión'),
            subtitle: const Text(
              'Guarda las credenciales en el dispositivo.',
            ),
            value: app.rememberSession,
            onChanged: app.setRememberSession,
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Vaciar historial'),
            subtitle: Text('${app.recent.length} elementos vistos'),
            onTap: () async {
              await app.clearRecent();
              _toast('Historial vaciado.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Vaciar caché de catálogos'),
            subtitle: const Text(
              'Libera las listas descargadas del panel en memoria.',
            ),
            onTap: () {
              CatalogCache.clear();
              _toast('Caché de catálogos vaciada.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Vaciar caché de imágenes'),
            onTap: () {
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              _toast('Caché de imágenes vaciada.');
            },
          ),
          const Divider(height: 24),
          _sectionTitle(theme, 'Actualizaciones y soporte'),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Buscar actualizaciones'),
            subtitle: Text(
              defaultTargetPlatform == TargetPlatform.iOS
                  ? 'iPhone: TestFlight / App Store; no instala APK.'
                  : config.config.update.enabled
                  ? 'Última publicada: ${config.config.update.latestVersion}'
                  : 'Las actualizaciones están desactivadas por la marca.',
            ),
            trailing: _checkingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _checkingUpdate
                ? null
                : () => _checkUpdates(app, config),
          ),
          if (branding.whatsappUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Soporte por WhatsApp'),
              onTap: () => openExternal(whatsappLink(branding.whatsappUrl)),
            ),
          if (branding.telegramUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.send_outlined),
              title: const Text('Canal de Telegram'),
              onTap: () => openExternal(branding.telegramUrl),
            ),
          if (branding.supportUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Centro de ayuda'),
              onTap: () => openExternal(branding.supportUrl),
            ),
          const Divider(height: 24),
          _sectionTitle(theme, 'Cuenta'),
          ListTile(leading: const Icon(Icons.link_off), title: const Text('Desvincular este aparato'), onTap: _unlinkDevice),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Cerrar sesión'),
              ),
            ),
          ),
          const Divider(height: 24),
          if (app.lastUnexpectedError != null)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Último error registrado'),
              subtitle: Text(
                app.lastUnexpectedError!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Borrar',
                icon: const Icon(Icons.delete_outline),
                onPressed: app.clearUnexpectedError,
              ),
            ),
          _sectionTitle(theme, 'Reproducción'),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Búfer de reproducción'),
            subtitle: Text('${app.bufferLabel} de reserva máxima · no es tiempo de espera'),
            trailing: const Icon(Icons.tune),
            onTap: () => _pickBuffer(app),
          ),
          _sectionTitle(theme, 'Acerca de'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.verified_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Alpha Vision Digital',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Internet de fibra y televisión IPTV',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${branding.appName} · Versión $kAppVersion ($kAppBuild)',
                  style: theme.textTheme.bodyMedium,
                ),
                if (DeviceProfile.current != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Dispositivo: ${DeviceProfile.current!.label}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Servicio de internet y televisión digital para hogares y '
                  'empresas. La aplicación forma parte del servicio de '
                  'Alpha Vision Digital; el contenido y la conexión los '
                  'proporciona tu proveedor.',
                  style: theme.textTheme.bodySmall,
                ),
                if (branding.whatsappUrl.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.support_agent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Soporte: ${branding.whatsappUrl}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                if (branding.supportUrl.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.language, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        branding.supportUrl,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '© ${DateTime.now().year} Alpha Vision Digital. '
                  'Todos los derechos reservados.',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  /// Reserva en segundos; arranque corto independiente.
  Future<void> _pickBuffer(AppState app) async {
    const List<int> options = PlaybackBuffer.options;
    final int? chosen = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: const Text('Búfer de reproducción'),
        children: <Widget>[
          for (final int value in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(value),
              child: Row(
                children: <Widget>[
                  Icon(
                    app.bufferSeconds == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(_bufferLabel(value)),
                        const SizedBox(height: 2),
                        Text(
                          value == 10
                              ? 'Menor reserva para una red estable'
                              : (value == 30
                                  ? 'Más reserva ante variaciones de red'
                                  : 'Reserva intermedia'),
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await app.setBufferSeconds(chosen);
    if (mounted) _toast('Búfer: ${_bufferLabel(chosen)}. Se aplica al volver a abrir el reproductor.');
  }

  String _bufferLabel(int value) => '$value segundos';

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAccountCard(AppState app, ConfigController config) {
    final ThemeData theme = Theme.of(context);
    final XtreamAccount? account = app.account;
    final XtreamCredentials? credentials = app.credentials;
    final DateTime? expDate = account?.expDate;
    final int? days = account?.daysRemaining;
    final List<String> formats = account?.allowedFormats ?? const <String>[];
    // La dirección del panel solo se enseña si el usuario tuvo que escribirla:
    // en una app de marca blanca queda oculta.
    final bool showServer = config.config.showsServerField;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        account?.username ?? '—',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        showServer
                            ? (credentials?.server ?? '—')
                            : (app.appConfig.branding.appName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    (account?.isActive ?? false)
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 16,
                    color: (account?.isActive ?? false)
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                  label: Text(
                    (account?.isActive ?? false) ? 'Activa' : 'Inactiva',
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _infoRow('Estado', account?.statusText ?? '—'),
            _infoRow(
              'Caducidad',
              expDate == null ? 'Sin caducidad' : formatDate(expDate),
            ),
            if (days != null) _infoRow('Días restantes', '$days'),
            _infoRow(
              'Conexiones',
              '${account?.activeConnections ?? 0} de '
                  '${account?.maxConnections ?? 0}',
            ),
            if (_mostrarAvanzado && showServer) ...<Widget>[
              _infoRow('Servidor', account?.serverInfo.url ?? '—'),
              _infoRow('Zona horaria', account?.serverInfo.timezone ?? '—'),
            ],
            if (_mostrarAvanzado)
              _infoRow(
              'Formatos permitidos',
              formats.isEmpty ? '—' : formats.join(', '),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
