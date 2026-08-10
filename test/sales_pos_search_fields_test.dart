import 'package:alfapos_app/core/theme.dart';
import 'package:alfapos_app/providers/clients_provider.dart';
import 'package:alfapos_app/widgets/sales_customer_search.dart';
import 'package:alfapos_app/widgets/sales_pos_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('product and customer search fields share exact height and style', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final productCtrl = TextEditingController();
    final customerFocus = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: SalesPosSearchField(
                    fieldKey: const ValueKey('product-search'),
                    controller: productCtrl,
                    hintText: "Mahsulotni qidirish - yoki - Shtrix kod",
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Expanded(
                        child: SalesCustomerSearch(
                          selected: null,
                          onSelected: (_) {},
                          onAddNew: () {},
                          iconOnlyAddButton: true,
                          searchFocusNode: customerFocus,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: SalesPosSearchField.height,
                        height: SalesPosSearchField.height,
                        child: const ColoredBox(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final productBox = tester.getSize(find.byKey(const ValueKey('product-search')));
    final customerField = find.descendant(
      of: find.byType(SalesCustomerSearch),
      matching: find.byType(TextField),
    );
    final customerBox = tester.getSize(customerField);

    expect(productBox.height, SalesPosSearchField.height);
    expect(customerBox.height, SalesPosSearchField.height);
    expect(productBox.height, customerBox.height);

    await tester.enterText(find.byKey(const ValueKey('product-search')), 'non');
    await tester.enterText(customerField, 'ad');
    await tester.pump();
    expect(productCtrl.text, 'non');
    expect(find.text('ad'), findsOneWidget);
  });

  testWidgets('POS customer dropdown matches input width and is selectable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    Client? picked;
    final searchKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: SalesCustomerSearch(
                key: searchKey,
                selected: null,
                onSelected: (c) => picked = c,
                onAddNew: () {},
                iconOnlyAddButton: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byType(SalesCustomerSearch),
      matching: find.byType(TextField),
    );
    final fieldRect = tester.getRect(field);

    final state = searchKey.currentState!;
    // ignore: invalid_use_of_visible_for_testing_member
    (state as dynamic).debugShowResults([
      const Client(id: '1', name: 'Ali Valiyev', phone: '+998901112233'),
    ]);
    await tester.pumpAndSettle();

    final results = find.byKey(const ValueKey('customer-search-results'));
    expect(results, findsOneWidget);
    final resultsRect = tester.getRect(results);

    // Dropdown input kengligi bilan bir xil (±1px).
    expect(resultsRect.left, closeTo(fieldRect.left, 1));
    expect(resultsRect.width, closeTo(fieldRect.width, 1));

    // + tugmasidan chapda qoladi.
    final addBtn = find.byIcon(Icons.person_add_alt_1_rounded);
    final addRect = tester.getRect(addBtn);
    expect(resultsRect.right, lessThanOrEqualTo(addRect.left + 1));

    await tester.tap(find.text('Ali Valiyev'));
    await tester.pumpAndSettle();

    expect(picked?.id, '1');
    expect(picked?.name, 'Ali Valiyev');
  });
}
