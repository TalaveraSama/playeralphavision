import 'dart:async';
import '../../widgets/tv_text_field.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/xtream_credentials.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/launcher.dart';
import '../../widgets/net_image.dart';

/// Intención de mover el foco con el mando (arriba/abajo).
///
/// Se declara aquí para poder interceptar las flechas ANTES de que el campo de
/// texto las use para mover el cursor: en Android TV eso era lo que impedía
/// bajar después de escribir la contraseña.
class _MoveFocusIntent extends Intent {
  const _MoveFocusIntent(this.delta);

  final int delta;
}

/// Pantalla de acceso de marca blanca.
///
/// Si la configuración trae el servidor grabado, el usuario solo ve los campos
/// de usuario y contraseña; el fondo, el logo y los colores salen del panel de
/// administración. Preparada para Android TV y Fire TV: el D-pad recorre los
/// campos y botones aunque el teclado en pantalla esté abierto.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _server;
  late final TextEditingController _username;
  late final TextEditingController _password;
  bool _obscurePassword = true;

  final FocusNode _serverFocus = FocusNode(debugLabel: 'login-servidor', skipTraversal: true);
  final FocusNode _usernameFocus = FocusNode(debugLabel: 'login-usuario', skipTraversal: true);
  final FocusNode _passwordFocus = FocusNode(debugLabel: 'login-clave', skipTraversal: true);
  final FocusNode _rememberFocus = FocusNode(debugLabel: 'login-recordar');
  final FocusNode _submitFocus = FocusNode(debugLabel: 'login-entrar');

  @override
  void initState() {
    super.initState();
    final AppState app = context.read<AppState>();
    final ConfigController config = context.read<ConfigController>();
    final XtreamCredentials? saved = app.credentials;

    _server = TextEditingController(
      text: saved?.server ?? config.config.xtream.server,
    );
    _username = TextEditingController(text: saved?.username ?? '');
    _password = TextEditingController(text: saved?.password ?? '');
  }

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _serverFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _rememberFocus.dispose();
    _submitFocus.dispose();
    super.dispose();
  }

  /// Orden de recorrido con el mando.
  List<FocusNode> _focusOrder(bool showsServer) {
    return <FocusNode>[
      if (showsServer) _serverFocus,
      _usernameFocus,
      _passwordFocus,
      _rememberFocus,
      _submitFocus,
    ];
  }

  void _moveFocus(int delta, bool showsServer) {
    final List<FocusNode> order = _focusOrder(showsServer);
    final FocusNode? current = FocusManager.instance.primaryFocus;
    int index = current == null ? -1 : order.indexOf(current);
    if (index < 0) {
      // Nada enfocado todavía: el primer DOWN entra por el principio.
      order.first.requestFocus();
      return;
    }
    index = (index + delta).clamp(0, order.length - 1);
    order[index].requestFocus();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    await context.read<AppState>().login(
          XtreamCredentials(
            server: _server.text.trim(),
            username: _username.text.trim(),
            password: _password.text,
          ),
        );
    // Si falla, `lastError` se pinta dentro del formulario.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ConfigController config = context.watch<ConfigController>();
    final ThemeData theme = Theme.of(context);
    final branding = config.config.branding;
    final bool showsServer = config.config.showsServerField;
    final bool hasSupport = branding.supportUrl.isNotEmpty ||
        branding.whatsappUrl.isNotEmpty ||
        branding.telegramUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _LoginBackground(
            urls: branding.loginBackgrounds,
            interval: branding.loginBackgroundSeconds,
            accent: branding.primaryColor,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 72),
                child: Shortcuts(
                  shortcuts: <ShortcutActivator, Intent>{
                  },
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      _MoveFocusIntent: CallbackAction<_MoveFocusIntent>(
                        onInvoke: (_MoveFocusIntent intent) {
                          _moveFocus(intent.delta, showsServer);
                          return null;
                        },
                      ),
                    },
                    child: FocusTraversalGroup(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Form(
                          key: _formKey,
                          child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildLogo(branding.logoUrl, branding.appName, theme),
                        if (branding.tagline.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            branding.tagline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.74),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                branding.loginTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                branding.loginSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                              if (app.lastError != null) ...<Widget>[
                                const SizedBox(height: 16),
                                _ErrorBox(message: app.lastError!),
                              ],
                              if (showsServer) ...<Widget>[
                                const SizedBox(height: 18),
                                TvTextField(
  fieldFocus: _serverFocus,
  child: TextFormField(
                                  controller: _server,
                                  focusNode: _serverFocus,
                                  keyboardType: TextInputType.url,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      _usernameFocus.requestFocus(),
                                  decoration: const InputDecoration(
                                    labelText: 'Servidor',
                                    hintText: 'http://midominio.com:8080',
                                    prefixIcon: Icon(Icons.dns_outlined),
                                  ),
                                  validator: (String? value) =>
                                      (value == null || value.trim().isEmpty)
                                          ? 'Escribe la dirección del panel.'
                                          : null,
                                ),
),
                              ],
                              const SizedBox(height: 18),
                              TvTextField(
  fieldFocus: _usernameFocus,
  child: TextFormField(
                                controller: _username,
                                focusNode: _usernameFocus,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                                decoration: const InputDecoration(
                                  labelText: 'Usuario',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (String? value) =>
                                    (value == null || value.trim().isEmpty)
                                        ? 'Escribe tu usuario.'
                                        : null,
                              ),
),
                              const SizedBox(height: 14),
                              TvTextField(
  fieldFocus: _passwordFocus,
  child: TextFormField(
                                controller: _password,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                autocorrect: false,
                                // Con el mando, "OK" en el teclado baja al botón
                                // en vez de enviar el formulario a medias.
                                textInputAction: TextInputAction.done,
                                // En Fire TV / Android TV el teclado de pantalla
                                // se queda abierto y no deja bajar al botón: el
                                // botón "Listo/✔" del teclado entra directamente.
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Mostrar'
                                        : 'Ocultar',
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword =
                                          !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (String? value) =>
                                    (value == null || value.isEmpty)
                                        ? 'Escribe tu contraseña.'
                                        : null,
                              ),
),
                              const SizedBox(height: 22),
                              FilledButton(
                                focusNode: _submitFocus,
                                onPressed: app.loggingIn ? null : _submit,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: app.loggingIn
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Iniciar sesión',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Recordar sesión',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  Switch(
                                    focusNode: _rememberFocus,
                                    value: app.rememberSession,
                                    onChanged: app.setRememberSession,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fire TV / Android TV: con el teclado abierto, '
                                'entra con el botón ✔ del propio teclado; con el '
                                'teclado cerrado, las flechas del mando cambian '
                                'de campo.',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white54,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
          if (hasSupport || branding.loginFooter.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _SupportBar(branding: branding),
            ),
        ],
      ),
    );
  }

  Widget _buildLogo(String logoUrl, String appName, ThemeData theme) {
    if (logoUrl.trim().isNotEmpty) {
      return SizedBox(
        height: 96,
        child: Center(
          child: NetImage(
            url: logoUrl,
            fit: BoxFit.contain,
            icon: Icons.play_circle_fill_rounded,
            iconSize: 56,
            backgroundColor: Colors.transparent,
          ),
        ),
      );
    }
    return Column(
      children: <Widget>[
        Icon(
          Icons.play_circle_fill_rounded,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 10),
        Text(
          appName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE50914).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE50914).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SupportBar extends StatelessWidget {
  const _SupportBar({required this.branding});

  final BrandingConfig branding;

  bool get _hasLinks =>
      branding.supportUrl.isNotEmpty ||
      branding.whatsappUrl.isNotEmpty ||
      branding.telegramUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x00000000), Color(0xE6000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_hasLinks)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (branding.whatsappUrl.isNotEmpty)
                  _SupportButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'WhatsApp',
                    url: whatsappLink(branding.whatsappUrl),
                  ),
                if (branding.telegramUrl.isNotEmpty)
                  _SupportButton(
                    icon: Icons.send_outlined,
                    label: 'Telegram',
                    url: branding.telegramUrl,
                  ),
                if (branding.supportUrl.isNotEmpty)
                  _SupportButton(
                    icon: Icons.help_outline,
                    label: 'Soporte',
                    url: branding.supportUrl,
                  ),
              ],
            ),
          if (branding.loginFooter.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                branding.loginFooter,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => openExternal(url),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(foregroundColor: Colors.white70),
    );
  }
}

/// Fondo del login con carrusel automático de imágenes de marca.
class _LoginBackground extends StatefulWidget {
  const _LoginBackground({
    required this.urls,
    required this.interval,
    required this.accent,
  });

  final List<String> urls;
  final int interval;
  final Color accent;

  @override
  State<_LoginBackground> createState() => _LoginBackgroundState();
}

class _LoginBackgroundState extends State<_LoginBackground> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _LoginBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls.length != widget.urls.length ||
        oldWidget.interval != widget.interval) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.urls.length < 2) return;
    final int seconds = widget.interval <= 0 ? 8 : widget.interval;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!mounted) return;
      _index = (_index + 1) % widget.urls.length;
      if (_controller.hasClients) {
        _controller.animateToPage(
          _index,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> urls = widget.urls;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (urls.isEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.black,
                  Color.lerp(Colors.black, widget.accent, 0.4) ??
                      widget.accent,
                  Colors.black,
                ],
              ),
            ),
          )
        else
          PageView.builder(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: urls.length,
            itemBuilder: (BuildContext context, int index) => NetImage(
              url: urls[index],
              fit: BoxFit.cover,
              icon: Icons.image_outlined,
              iconSize: 42,
              backgroundColor: Colors.black,
              cacheWidth: 1080,
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xCC000000),
                Color(0x88000000),
                Color(0xF2000000),
              ],
              stops: <double>[0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
