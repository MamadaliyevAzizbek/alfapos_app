// Basic Flutter widget test for Alfapos POS app.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alfapos_app/app.dart';

void main() {
  testWidgets('App starts with login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AlfaposApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Kirish'), findsNWidgets(2));
  });
}
