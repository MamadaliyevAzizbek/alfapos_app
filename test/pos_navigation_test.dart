import 'package:alfapos_app/utils/pos_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goToSales notifies openSalesRequest listeners', () {
    var hits = 0;
    void listener() => hits++;
    PosNavigation.openSalesRequest.addListener(listener);
    addTearDown(() {
      PosNavigation.openSalesRequest.removeListener(listener);
      PosNavigation.openSalesSection = null;
    });

    final before = PosNavigation.openSalesRequest.value;
    PosNavigation.goToSales();
    expect(PosNavigation.openSalesRequest.value, before + 1);
    expect(hits, 1);

    PosNavigation.goToSales();
    expect(hits, 2);
  });
}
