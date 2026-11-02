import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/iptv_profile.dart';
import '../../core/state/app_state.dart';

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key});
  Future<void> _add(BuildContext context) async {
    final name = TextEditingController(), server = TextEditingController(), user = TextEditingController(), password = TextEditingController();
    ProfileSource source = ProfileSource.xtream;
    String file = ''; bool allowHttp = false;
    final profile = await showDialog<IptvProfile>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: const Text('Agregar perfil IPTV'),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre del perfil')),
        DropdownButtonFormField<ProfileSource>(value: source, items: const [
          DropdownMenuItem(value: ProfileSource.xtream, child: Text('Xtream Codes estándar')),
          DropdownMenuItem(value: ProfileSource.tvlister, child: Text('TVLister (con control de aparato)')),
          DropdownMenuItem(value: ProfileSource.playlist, child: Text('Lista M3U / M3U8 o canal HLS')),
        ], onChanged: (value) { if (value != null) update(() { source = value; allowHttp = false; if (source != ProfileSource.playlist) file = ''; }); }),
        TextField(controller: server, decoration: InputDecoration(labelText: source == ProfileSource.playlist ? 'URL de lista/canal (o importa archivo)' : 'Servidor con http:// o https://')),
        if (source != ProfileSource.playlist) ...[
          TextField(controller: user, decoration: const InputDecoration(labelText: 'Usuario')),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
        ],
        if (source == ProfileSource.playlist) OutlinedButton.icon(icon: const Icon(Icons.file_open),
          label: Text(file.isEmpty ? 'Seleccionar archivo M3U/M3U8' : 'Archivo seleccionado'), onPressed: () async {
            try {
              final text = await const MethodChannel('alphavision/playlists').invokeMethod<String>('pick');
              if (ctx.mounted && text != null) update(() { file = text; server.clear(); });
            } catch (_) { if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el selector de archivos.'))); }
          }),
        if (source != ProfileSource.tvlister) SwitchListTile(value: allowHttp, title: const Text('Permitir HTTP en este perfil'),
          subtitle: const Text('Sólo para proveedores externos. Sin cifrado.'), onChanged: (v) async {
            if (!v) { update(() => allowHttp = false); return; }
            final consent = await showDialog<bool>(context: ctx, builder: (warn) => AlertDialog(title: const Text('Conexión sin cifrado'),
              content: const Text('HTTP puede exponer usuario, contraseña, token y vídeo a terceros en la red. ¿Autorizas HTTP sólo para este perfil externo?'),
              actions: [TextButton(onPressed: () => Navigator.pop(warn, false), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.pop(warn, true), child: const Text('Autorizar HTTP'))]));
            if (ctx.mounted && consent == true) update(() => allowHttp = true);
          }),
      ]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () {
          final uri = Uri.tryParse(server.text.trim());
          if (name.text.trim().isEmpty || (file.isEmpty && (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty)) ||
              (source != ProfileSource.playlist && (user.text.trim().isEmpty || password.text.isEmpty)) ||
              (uri?.scheme == 'http' && !allowHttp)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa los datos y autoriza HTTP si es necesario.'))); return;
          }
          Navigator.pop(ctx, IptvProfile(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.text.trim(),
            source: source, server: server.text.trim(), username: user.text.trim(), password: password.text,
            playlistText: source == ProfileSource.playlist ? file : '', allowHttp: allowHttp));
        }, child: const Text('Guardar'))],
    )));
    name.dispose(); server.dispose(); user.dispose(); password.dispose();
    if (profile == null || !context.mounted) return;
    try { await context.read<AppState>().addProfile(profile); }
    catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar el perfil. Máximo 20 perfiles.'))); }
  }
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(appBar: AppBar(title: const Text('Perfiles IPTV')), body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: FilledButton.icon(onPressed: app.switchingProfile ? null : () => _add(context),
        icon: const Icon(Icons.person_add), label: const Text('Agregar perfil'))),
      if (app.switchingProfile) const LinearProgressIndicator(),
      if (app.profiles.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Agrega tu cuenta Xtream Codes o una lista M3U/M3U8.')),
      Expanded(child: ListView.builder(itemCount: app.profiles.length, itemBuilder: (_, i) {
        final profile = app.profiles[i];
        return ListTile(leading: const Icon(Icons.account_circle), title: Text(profile.name),
          subtitle: Text('${profile.source.name}${profile.allowHttp ? ' · HTTP autorizado' : ' · HTTPS'}'),
          selected: app.activeProfileId == profile.id && app.isLoggedIn,
          onTap: app.switchingProfile ? null : () async {
            final success = await app.activateProfile(profile);
            if (!context.mounted) return;
            if (success) Navigator.popUntil(context, (route) => route.isFirst);
            else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.lastError ?? 'No se pudo abrir el perfil.')));
          }, trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Eliminar perfil',
            onPressed: app.switchingProfile ? null : () async {
              final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('¿Eliminar perfil?'),
                content: const Text('Se borrarán esta cuenta, su lista y sus datos locales. No se elimina la cuenta del proveedor.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar'))]));
              if (confirm == true) await app.removeProfile(profile.id);
            }));
      })),
    ]));
  }
}
