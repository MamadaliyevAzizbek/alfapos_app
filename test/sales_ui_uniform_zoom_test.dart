import 'package:alfapos_app/services/sales_ui_scale_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setSurface(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  Widget zoomHost({required Widget child}) {
    return MaterialApp(
      home: Scaffold(
        body: SalesUiScaleSettings.wrapUniformZoom(child: child),
      ),
    );
  }

  testWidgets('uniform zoom fills parent at 100%', (tester) async {
    await setSurface(tester, const Size(1200, 800));
    SalesUiScaleSettings.scale.value = 1.0;

    await tester.pumpWidget(
      zoomHost(
        child: const ColoredBox(
          key: ValueKey('zoom-fill-marker'),
          color: Colors.blue,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final host = tester.getSize(find.byType(Scaffold));
    expect(host.width, closeTo(1200, 1));
    expect(host.height, closeTo(800, 1));

    final marker = tester.getSize(find.byKey(const ValueKey('zoom-fill-marker')));
    expect(marker.width, closeTo(1200, 1));
    expect(marker.height, closeTo(800, 1));
  });

  testWidgets('uniform zoom fills parent at 75% (no empty margins)', (tester) async {
    await setSurface(tester, const Size(1200, 800));
    SalesUiScaleSettings.scale.value = 0.75;

    await tester.pumpWidget(
      zoomHost(
        child: const ColoredBox(
          key: ValueKey('zoom-fill-marker'),
          color: Colors.blue,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Outer host still fills the window.
    final host = tester.getSize(find.byType(Scaffold));
    expect(host.width, closeTo(1200, 1));
    expect(host.height, closeTo(800, 1));

    // Logical layout is larger (more content fits), then scaled to fill.
    final marker = tester.getSize(find.byKey(const ValueKey('zoom-fill-marker')));
    expect(marker.width, closeTo(1200 / 0.75, 1));
    expect(marker.height, closeTo(800 / 0.75, 1));
  });

  testWidgets('uniform zoom fills parent at 150%', (tester) async {
    await setSurface(tester, const Size(1200, 800));
    SalesUiScaleSettings.scale.value = 1.5;

    await tester.pumpWidget(
      zoomHost(
        child: const ColoredBox(
          key: ValueKey('zoom-fill-marker'),
          color: Colors.blue,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final host = tester.getSize(find.byType(Scaffold));
    expect(host.width, closeTo(1200, 1));
    expect(host.height, closeTo(800, 1));

    final marker = tester.getSize(find.byKey(const ValueKey('zoom-fill-marker')));
    expect(marker.width, closeTo(1200 / 1.5, 1));
    expect(marker.height, closeTo(800 / 1.5, 1));
  });

  testWidgets('TextField accepts typing under uniform zoom at 75%', (tester) async {
    await setSurface(tester, const Size(1200, 800));
    SalesUiScaleSettings.scale.value = 0.75;
    final controller = TextEditingController();

    await tester.pumpWidget(
      zoomHost(
        child: Center(
          child: SizedBox(
            width: 400,
            child: TextField(
              key: const ValueKey('zoom-input'),
              controller: controller,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('zoom-input')), 'non');
    await tester.pump();

    expect(controller.text, 'non');
  });

  testWidgets('TextField accepts typing under uniform zoom at 150%', (tester) async {
    await setSurface(tester, const Size(1200, 800));
    SalesUiScaleSettings.scale.value = 1.5;
    final controller = TextEditingController();

    await tester.pumpWidget(
      zoomHost(
        child: Center(
          child: SizedBox(
            width: 400,
            child: TextField(
              key: const ValueKey('zoom-input'),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('zoom-input')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('zoom-input')), 'olma');
    await tester.pump();

    expect(controller.text, 'olma');
  });

  test('chromeScaled always multiplies by zoom', () {
    expect(SalesUiScaleSettings.chromeScaled(100, 0.75), closeTo(75, 0.01));
    expect(SalesUiScaleSettings.chromeScaled(100, 1.5), closeTo(150, 0.01));
  });
}
