import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/app_info.dart';
import '../../core/config/config_controller.dart';
import '../../core/models/media_item.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/nova_theme.dart';
import '../../widgets/nova/nova_ui.dart';
import '../../widgets/nova/nova3_top_bar.dart';
import '../../widgets/nova/nova3_frame.dart';
import '../catalog/catalog_page.dart';
import '../guide/guide_page.dart';
import '../catalog/nova_browse_page.dart';
import '../favorites/favorites_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import 'nova_discover_page.dart';
import 'nova3_history_page.dart';

/// Contenedor del diseño NOVA.
///
/// En pantallas anchas (web, escritorio, tableta horizontal) usa la **barra
/// superior** de los diseños; en el móvil usa la **barra inferior** con cinco
/// destinos. Las pestañas se construyen al visitarlas por primera vez, así que
/// al entrar solo se descarga el catálogo de la portada.
class NovaShell extends StatefulWidget {
  const NovaShell({super.key});

  @override
  State<NovaShell> createState() => _NovaShellState();
}

class _NovaShellState extends State<NovaShell> {
  int _index = 0;
  final GlobalKey<Nova3FrameState> _nova3Frame = GlobalKey<Nova3FrameState>();
  DateTime? _lastBackAt;
  final Set<int> _visited = <int>{0};

  void _select(int value) {
    setState(() {
      _index = value;
      _visited.add(value);
    });
  }

  Future<void> _openSearch() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SearchPage()),
      );

  Future<void> _openProfile() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
      );

  Future<void> _openHistory() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const Nova3HistoryPage()));

  Future<void> _showNotifications() => showDialog<void>(context: context,
    builder: (context) {
      final update = context.read<ConfigController>().config.update;
      return AlertDialog(title: const Text('Notificaciones'),
        content: Text(update.enabled && update.latestVersion.trim().isNotEmpty
          ? 'Versión publicada por tu proveedor: ${update.latestVersion}. Consulta las actualizaciones en Perfil.'
          : 'No hay avisos publicados por tu proveedor.'),
        actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]);
    });

  @override
  void initState() {
    super.initState();
    // El botón «menú» (≡) del mando abre la lista de secciones, sin tener que
    // bajar toda una fila para llegar al menú.
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    super.dispose();
  }

  bool _onGlobalKey(KeyEvent event) {
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.contextMenu) {
      if (context.read<ConfigController>().theme.isNova3) {
        _nova3Frame.currentState?.toggle();
      } else {
        _showSectionMenu();
      }
      return true;
    }
    return false;
  }

  /// Lista de secciones (Inicio, Series, Películas, En vivo…) como diálogo.
  bool _sectionMenuOpen = false;

  Future<void> _showSectionMenu() async {
    if (_sectionMenuOpen) return;
    _sectionMenuOpen = true;
    final AppConfig config = context.read<ConfigController>().config;
    final bool wide = NovaMetrics.of(context).isTv ||
        MediaQuery.sizeOf(context).width >= NovaBreakpoints.wide;
    final List<_NovaTab> tabs = context.read<ConfigController>().theme.isNova3
        ? _nova3Tabs(config.branding.showLiveSection)
        : wide
        ? _wideTabs(config.branding.showLiveSection)
        : _narrowTabs(
            config.branding.showLiveSection, config.features.favorites);

    final int? selected = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) => SimpleDialog(
        title: const Text('Secciones'),
        children: <Widget>[
          for (int i = 0; i < tabs.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(i),
              child: Row(
                children: <Widget>[
                  Icon(_index == i ? tabs[i].selectedIcon : tabs[i].icon),
                  const SizedBox(width: 12),
                  Text(tabs[i].label),
                ],
              ),
            ),
        ],
      ),
    );

    _sectionMenuOpen = false;
    if (selected != null && mounted) {
      _select(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppConfig config = context.watch<ConfigController>().config;
    final bool showLive = config.branding.showLiveSection;
    final bool canSearch = config.features.search;
    final bool wide = NovaMetrics.of(context).isTv ||
        MediaQuery.sizeOf(context).width >= NovaBreakpoints.wide;
    // En televisores (mando) el menú va a la izquierda: se llega pulsando
    // "izquierda" sin tener que bajar toda la lista para dar con la barra.
    final bool isTv = NovaMetrics.of(context).isTv;

    final bool nova3 = context.watch<ConfigController>().theme.isNova3;
    final List<_NovaTab> tabs = nova3
        ? _nova3Tabs(showLive)
        : wide
        ? _wideTabs(showLive)
        : _narrowTabs(showLive, config.features.favorites);

    final int index = _index.clamp(0, tabs.length - 1);

    final Widget body = IndexedStack(
      index: index,
      children: List<Widget>.generate(
        tabs.length,
        (int position) => _visited.contains(position)
            ? TickerMode(
                enabled: position == index,
                child: tabs[position].builder(context),
              )
            : const SizedBox.shrink(),
      ),
    );

    return PopScope(
      // Nunca deja que el sistema cierre la app de golpe: controlamos el atrás.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (nova3 && (_nova3Frame.currentState?.isOpen ?? false)) {
          _nova3Frame.currentState?.collapse();
          return;
        }
        if (index != 0) {
          _select(0);
          return;
        }
        // En Inicio: doble atrás para salir (evita salidas accidentales).
        final DateTime now = DateTime.now();
        if (_lastBackAt != null &&
            now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackAt = now;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Pulsa Atrás otra vez para salir'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: nova3
          ? Scaffold(
              key: const ValueKey('nova3-sidebar-layout-v2'),
              body: SafeArea(
                child: Nova3Frame(
                  key: _nova3Frame,
                  sidebar: _buildRail(tabs, index),
                  topBar: Nova3TopBar(
                    onSearch: canSearch ? _openSearch : null,
                    onProfile: _openProfile,
                    onFilter: _showSectionMenu,
                    onHistory: _openHistory,
                    onNotifications: _showNotifications,
                    onFavorites: config.features.favorites
                        ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => const FavoritesPage())) : null,
                  ),
                  child: body,
                ),
              ),
            )
          : wide && !isTv
          ? Scaffold(
              body: Column(
                children: <Widget>[
                  _NovaTopBar(
                    labels: tabs.map((_NovaTab tab) => tab.label).toList(),
                    index: index,
                    onSelect: _select,
                    onSearch: canSearch ? _openSearch : null,
                    onProfile: _openProfile,
                  ),
                  Expanded(child: body),
                ],
              ),
            )
          : isTv
              ? Scaffold(
                  body: Row(
                    children: <Widget>[
                      _buildRail(tabs, index),
                      Expanded(child: body),
                    ],
                  ),
                )
              : Scaffold(
                  body: body,
                  bottomNavigationBar: _buildBottomBar(tabs, index),
                ),
    );
  }

  Widget _buildBottomBar(List<_NovaTab> tabs, int index) {
    final NovaTokens tokens = NovaTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 76,
          backgroundColor: Colors.transparent,
          selectedIndex: index,
          onDestinationSelected: _select,
          indicatorColor: tokens.accent.withValues(alpha: 0.16),
          destinations: <NavigationDestination>[
            for (final _NovaTab tab in tabs)
              NavigationDestination(
                icon: Icon(tab.icon, size: 23),
                selectedIcon: Icon(tab.selectedIcon, color: tokens.accent),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }

  /// Destinos grandes, desplazables y con foco explícito para el mando.
  Widget _buildRail(List<_NovaTab> tabs, int index) {
    final NovaTokens tokens = NovaTokens.of(context);
    final bool nova3 = context.watch<ConfigController>().theme.isNova3;
    return Container(
      width: nova3 ? (MediaQuery.sizeOf(context).height < 500 ? 148 : 196) : 184,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(right: BorderSide(color: nova3 ? Colors.transparent : tokens.hairline)),
      ),
      child: SafeArea(
        child: FocusTraversalGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: NovaLogo(fontSize: 20, color: nova3 ? Colors.white : null),
                ),
              ),
              for (final int i in <int>[
                if (nova3 && tabs.length > 1 && tabs[1].label == 'TV') 1,
                0,
                for (int j = 1; j < tabs.length; j++)
                  if (!(nova3 && tabs[j].label == 'TV')) j,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: NovaFocusable(
                    autofocus: i == 0,
                    onTap: () {
                      _select(i);
                      if (nova3) _nova3Frame.currentState?.collapse();
                    },
                    child: Container(
                      constraints: BoxConstraints(minHeight: nova3 && MediaQuery.sizeOf(context).height < 500 ? 44 : 50),
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: nova3 ? 7 : 12),
                      decoration: BoxDecoration(
                        color: i == index
                            ? tokens.accent.withValues(alpha: nova3 ? 0.05 : 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: <Widget>[
                        Icon(i == index ? tabs[i].selectedIcon : tabs[i].icon,
                            size: 22, color: i == index ? tokens.accent : tokens.muted),
                        const SizedBox(width: 12),
                        Expanded(child: Text(nova3 ? tabs[i].label.toUpperCase() : tabs[i].label,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                color: i == index ? tokens.text : tokens.muted))),
                      ]),
                    ),
                  ),
                ),
              if (nova3) const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Nova3 · $kAppVersion', style: TextStyle(fontSize: 10, color: Colors.white38))),
              if (!nova3) ...<Widget>[
              const SizedBox(height: 16),
              if (context.read<ConfigController>().config.features.search)
                NovaSquareButton(icon: Icons.search, tooltip: 'Buscar', onPressed: _openSearch),
              const SizedBox(height: 10),
              NovaSquareButton(icon: Icons.person_outline, tooltip: 'Perfil y ajustes', onPressed: _openProfile),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Secciones de Nova3; los filtros usan categorías reales, no contenido fijo.
  List<_NovaTab> _nova3Tabs(bool showLive) => <_NovaTab>[
    _NovaTab(label: 'Destacados', icon: Icons.thumb_up_outlined,
      selectedIcon: Icons.thumb_up, builder: (_) => const NovaDiscoverPage()),
    if (showLive)
      _NovaTab(label: 'TV', icon: Icons.live_tv_outlined,
        selectedIcon: Icons.live_tv,
        builder: (_) => const CatalogPage(kind: MediaKind.live, embedded: true)),
    _NovaTab(label: 'Películas', icon: Icons.movie_outlined,
      selectedIcon: Icons.movie,
      builder: (_) => const CatalogPage(kind: MediaKind.movie, embedded: true)),
    _NovaTab(label: 'Series', icon: Icons.local_movies_outlined,
      selectedIcon: Icons.local_movies,
      builder: (_) => const CatalogPage(kind: MediaKind.series, embedded: true)),
    _NovaTab(label: 'Kids', icon: Icons.child_care_outlined,
      selectedIcon: Icons.child_care,
      builder: (_) => const CatalogPage(kind: MediaKind.movie, embedded: true,
        categoryHints: <String>['infantil', 'infantiles', 'kids', 'familia', 'family', 'ninos'])),
    _NovaTab(label: 'Anime', icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      builder: (_) => const CatalogPage(kind: MediaKind.series, embedded: true,
        categoryHints: <String>['anime', 'animacion japonesa'])),
    _NovaTab(label: 'Explorar', icon: Icons.explore_outlined,
      selectedIcon: Icons.explore, builder: (_) => const CatalogPage(
        kind: MediaKind.movie, embedded: true, nova3Explore: true)),
  ];

  /// Barra superior: Inicio, Series, Películas, En vivo, Deportes, Infantil.
  List<_NovaTab> _wideTabs(bool showLive) {
    return <_NovaTab>[
      _NovaTab(
        label: 'Inicio',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        builder: (_) => const NovaDiscoverPage(),
      ),
      _NovaTab(
        label: 'Series',
        icon: Icons.video_library_outlined,
        selectedIcon: Icons.video_library,
        builder: (_) => const CatalogPage(
          kind: MediaKind.series,
          embedded: true,
        ),
      ),
      _NovaTab(
        label: 'Películas',
        icon: Icons.movie_outlined,
        selectedIcon: Icons.movie,
        builder: (_) => const CatalogPage(
          kind: MediaKind.movie,
          embedded: true,
        ),
      ),
      if (showLive)
        _NovaTab(
          label: 'En vivo',
          icon: Icons.live_tv_outlined,
          selectedIcon: Icons.live_tv,
          builder: (_) => const CatalogPage(
            kind: MediaKind.live,
            embedded: true,
          ),
        ),
      if (showLive)
        _NovaTab(
          label: 'Guía',
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_note,
          builder: (_) => const GuidePage(),
        ),
      if (showLive)
        _NovaTab(
          label: 'Deportes',
          icon: Icons.sports_soccer_outlined,
          selectedIcon: Icons.sports_soccer,
          builder: (_) => const CatalogPage(
            kind: MediaKind.live,
            embedded: true,
            categoryHints: <String>['deportes', 'deporte', 'sports', 'futbol'],
          ),
        ),
      _NovaTab(
        label: 'Infantil',
        icon: Icons.child_care_outlined,
        selectedIcon: Icons.child_care,
        builder: (_) => const CatalogPage(
          kind: MediaKind.movie,
          embedded: true,
          categoryHints: <String>[
            'infantil',
            'infantiles',
            'ninos',
            'kids',
            'familia',
            'family',
          ],
        ),
      ),
    ];
  }

  /// Barra inferior: Inicio, Explorar, En vivo, Mi lista, Perfil.
  List<_NovaTab> _narrowTabs(bool showLive, bool favorites) {
    return <_NovaTab>[
      _NovaTab(
        label: 'Inicio',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        builder: (_) => const NovaDiscoverPage(),
      ),
      _NovaTab(
        label: 'Explorar',
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
        builder: (_) => const NovaBrowsePage(),
      ),
      if (showLive)
        _NovaTab(
          label: 'En vivo',
          icon: Icons.live_tv_outlined,
          selectedIcon: Icons.live_tv,
          builder: (_) => const CatalogPage(kind: MediaKind.live),
        ),
      if (showLive)
        _NovaTab(
          label: 'Guía',
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_note,
          builder: (_) => const GuidePage(),
        ),
      if (favorites)
        _NovaTab(
          label: 'Mi lista',
          icon: Icons.bookmark_border,
          selectedIcon: Icons.bookmark,
          builder: (_) => const FavoritesPage(),
        ),
      _NovaTab(
        label: 'Perfil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        builder: (_) => const SettingsPage(),
      ),
    ];
  }
}

class _NovaTab {
  const _NovaTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

/// Barra de navegación superior del diseño NOVA (pantallas anchas).
class _NovaTopBar extends StatelessWidget {
  const _NovaTopBar({
    required this.labels,
    required this.index,
    required this.onSelect,
    this.onSearch,
    this.onProfile,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback? onSearch;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final AppState app = context.watch<AppState>();
    final String username = (app.account?.username ?? '').trim();
    final String initial =
        username.isEmpty ? 'P' : username.substring(0, 1).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(bottom: BorderSide(color: tokens.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 7, 16, 7),
      child: Row(
        children: <Widget>[
          const NovaLogo(fontSize: 21),
          const SizedBox(width: 18),
          // Los destinos pueden desplazarse en horizontal en vez de desbordar
          // cuando la ventana es estrecha (1000-1200 px).
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < labels.length; i++)
                    _NovaNavItem(
                      label: labels[i],
                      selected: i == index,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (onSearch != null) ...<Widget>[
            Material(
              color: tokens.surfaceHigh,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onSearch,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.search,
                    size: 17,
                    color: tokens.text.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Tooltip(
            message: username.isEmpty ? 'Perfil' : username,
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.hairline),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NovaNavItem extends StatelessWidget {
  const _NovaNavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? tokens.text
                    : tokens.text.withValues(alpha: 0.66),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              height: 2,
              width: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: tokens.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
