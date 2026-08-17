import 'package:alfapos_app/core/constants.dart';
import 'package:alfapos_app/screens/main_shell.dart';
import 'package:alfapos_app/utils/platform_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// iPhone 12: 390×844 logical pt (@3x). Pastki menyu sig‘ishi tekshiriladi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpMainShell(WidgetTester tester, Size logicalSize) async {
    debugIsDesktopPosLayoutOverride = false;
    tester.view.physicalSize = Size(
      logicalSize.width * 3,
      logicalSize.height * 3,
    );
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpWidget(
      const MaterialApp(
        home: MainShell(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('iPhone 12 (390pt): pastki menyu overflow yo‘q, qisqa yorliqlar', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => debugIsDesktopPosLayoutOverride = null);

    await pumpMainShell(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Mahsulot'), findsOneWidget);
    expect(find.text('Tranzaks.'), findsOneWidget);
    expect(find.text(Strings.navSotuvlar), findsOneWidget);
    expect(find.text(Strings.navMenu), findsOneWidget);
    expect(find.text(Strings.navAsosiy), findsWidgets);
    // Uzun yozuvlar compact rejimda ko‘rinmasligi kerak
    expect(find.text(Strings.navMahsulotlar), findsNothing);
    expect(find.text(Strings.navTranzaksiyalar), findsNothing);
  });

  testWidgets('iPhone SE (320pt): faqat ikonka, overflow yo‘q', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => debugIsDesktopPosLayoutOverride = null);

    await pumpMainShell(tester, const Size(320, 568));

    expect(tester.takeException(), isNull);
    expect(find.text(Strings.navTranzaksiyalar), findsNothing);
    expect(find.text('Tranzaks.'), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
  });

  testWidgets('iPhone 14 Pro Max (430pt): to‘liq yorliqlar', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => debugIsDesktopPosLayoutOverride = null);

    await pumpMainShell(tester, const Size(430, 932));

    expect(tester.takeException(), isNull);
    expect(find.text(Strings.navMahsulotlar), findsOneWidget);
    expect(find.text(Strings.navTranzaksiyalar), findsOneWidget);
  });
}
