import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/theme/nova_theme.dart';
import 'package:xtream_player/widgets/nova/nova_ui.dart';

void main() {
  testWidgets('TV de 960dp usa métricas de mando, no de tableta', (tester) async {
    late NovaMetrics metrics;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(960, 540),
          navigationMode: NavigationMode.directional,
        ),
        child: Builder(builder: (context) {
          metrics = NovaMetrics.of(context);
          return const SizedBox();
        }),
      ),
    ));
    expect(metrics.isTv, isTrue);
    expect(metrics.isNarrow, isFalse);
    expect(metrics.scale, greaterThan(1));
  });

  testWidgets('botón principal tiene un solo destino de foco y activa con OK',
      (tester) async {
    int presses = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NovaPrimaryButton(
        label: 'Reproducir',
        autofocus: true,
        onPressed: () => presses++,
      )),
    ));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(presses, 1);
    await tester.tap(find.text('Reproducir'));
    expect(presses, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('acción de sección conserva área táctil de 48dp', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NovaSectionHeader(
        title: 'Películas', actionLabel: 'Ver todo', onAction: () {},
      )),
    ));
    expect(tester.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));
  });
}
