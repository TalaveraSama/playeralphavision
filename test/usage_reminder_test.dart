import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/config/app_config.dart';
import 'package:xtream_player/core/config/usage_reminder_config.dart';
import 'package:xtream_player/features/reminders/usage_reminder_host.dart';

void main() {
  test('JSON antiguo no activa un cierre inesperado; ajustes se serializan', () {
    expect(AppConfig.fromJson(<String, dynamic>{}).usageReminder.enabled, isFalse);
    final config = AppConfig.fromJson(<String, dynamic>{
      'usageReminder': <String, dynamic>{'enabled': true, 'intervalMinutes': 240, 'countdownSeconds': 10},
    });
    expect(config.usageReminder.displayMessage, contains('4 horas'));
    expect(config.usageReminder.displayMessage, contains('10 segundos'));
    expect(AppConfig.fromJson(config.copyWith().toJson()).usageReminder.signature,
        config.usageReminder.signature);
  });
  test('normaliza valores de panel sin temporizadores negativos', () {
    final config = UsageReminderConfig.fromJson(<String, dynamic>{
      'intervalMinutes': -1, 'countdownSeconds': 900, 'title': '',
    });
    expect(config.intervalMinutes, 1);
    expect(config.countdownSeconds, 120);
    expect(config.title, 'Consejos');
  });
  Future<void> mount(WidgetTester tester, {required GlobalKey<NavigatorState> key,
    required VoidCallback onTimeout, bool enabled = true}) async {
    await tester.pumpWidget(MaterialApp(navigatorKey: key,
      builder: (_, child) => UsageReminderHost(
        navigatorKey: key, active: true, onTimeout: onTimeout,
        config: UsageReminderConfig(enabled: enabled), child: child!),
      home: const Scaffold(body: Text('Inicio'))));
    await tester.pump();
  }
  testWidgets('a las 4 horas abre Consejos y Enter permite continuar', (tester) async {
    final key = GlobalKey<NavigatorState>();
    int exits = 0;
    await mount(tester, key: key, onTimeout: () => exits++);
    await tester.pump(const Duration(hours: 4));
    await tester.pumpAndSettle();
    expect(find.text('Consejos'), findsOneWidget);
    expect(find.text('Continuar usando'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Consejos'), findsNothing);
    expect(exits, 0);
    await tester.pump(const Duration(hours: 3));
    expect(find.text('Consejos'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('sin respuesta vuelve a Inicio y ejecuta salida', (tester) async {
    final key = GlobalKey<NavigatorState>();
    int exits = 0;
    await mount(tester, key: key, onTimeout: () => exits++);
    key.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Vídeo'))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(hours: 4));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Vídeo'), findsNothing);
    expect(find.text('Inicio'), findsOneWidget);
    expect(exits, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('en segundo plano no avanza ni el intervalo ni la cuenta atrás', (tester) async {
    final key = GlobalKey<NavigatorState>();
    int exits = 0;
    await mount(tester, key: key, onTimeout: () => exits++);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(hours: 5));
    expect(find.text('Consejos'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(hours: 4));
    await tester.pumpAndSettle();
    expect(find.text('Consejos'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Consejos'), findsOneWidget);
    expect(exits, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(exits, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('desactivar durante el diálogo no cierra la app', (tester) async {
    final key = GlobalKey<NavigatorState>();
    int exits = 0;
    await mount(tester, key: key, onTimeout: () => exits++);
    await tester.pump(const Duration(hours: 4));
    await tester.pumpAndSettle();
    await mount(tester, key: key, onTimeout: () => exits++, enabled: false);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Consejos'), findsNothing);
    expect(exits, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
