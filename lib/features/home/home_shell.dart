import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/config_controller.dart';
import '../../core/models/media_item.dart';
import '../catalog/catalog_page.dart';
import '../favorites/favorites_page.dart';
import '../settings/settings_page.dart';

/// Contenedor principal con la barra de navegación inferior.
///
/// Las pestañas se construyen cuando se visitan por primera vez, así que al
/// entrar solo se descarga el catálogo de la pestaña visible.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _visited = <int>{0};

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigController>().config;
    final features = config.features;
    final bool showLive = config.branding.showLiveSection;

    final List<Widget> pages = <Widget>[
      if (showLive) const CatalogPage(kind: MediaKind.live),
      const CatalogPage(kind: MediaKind.movie),
      const CatalogPage(kind: MediaKind.series),
      if (features.favorites) const FavoritesPage(),
      const SettingsPage(),
    ];

    final List<NavigationDestination> destinations = <NavigationDestination>[
      if (showLive)
        const NavigationDestination(
          icon: Icon(Icons.live_tv_outlined),
          selectedIcon: Icon(Icons.live_tv),
          label: 'En vivo',
        ),
      const NavigationDestination(
        icon: Icon(Icons.movie_outlined),
        selectedIcon: Icon(Icons.movie),
        label: 'Películas',
      ),
      const NavigationDestination(
        icon: Icon(Icons.video_library_outlined),
        selectedIcon: Icon(Icons.video_library),
        label: 'Series',
      ),
      if (features.favorites)
        const NavigationDestination(
          icon: Icon(Icons.favorite_outline),
          selectedIcon: Icon(Icons.favorite),
          label: 'Favoritos',
        ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Ajustes',
      ),
    ];

    final int index = _index.clamp(0, pages.length - 1);

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        // Atrás vuelve a la primera pestaña antes de salir de la app.
        setState(() {
          _index = 0;
          _visited.add(0);
        });
      },
      child: Scaffold(
      body: IndexedStack(
        index: index,
        children: List<Widget>.generate(
          pages.length,
          (int position) => _visited.contains(position)
              ? pages[position]
              : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (int value) => setState(() {
          _index = value;
          _visited.add(value);
        }),
        destinations: destinations,
      ),
      ),
    );
  }
}
