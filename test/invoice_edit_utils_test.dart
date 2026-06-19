import 'package:alfapos_app/utils/invoice_edit_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseSalesListEditEnabled defaults true when missing', () {
    expect(parseSalesListEditEnabled({}), isTrue);
    expect(parseSalesListEditEnabled({'salesListEdit': '1'}), isTrue);
    expect(parseSalesListEditEnabled({'salesListEdit': '0'}), isFalse);
  });

  test('canShowInvoiceEditButton rejects returned sale', () {
    final sale = {
      'id': 10,
      'status': 'done',
      'total': 50000,
    };
    expect(canShowInvoiceEditButton(sale), isTrue);
    expect(
      canShowInvoiceEditButton({...sale, 'status': 'cancelled'}),
      isFalse,
    );
  });

  test('invoiceEditResumeFromApi parses order cart', () {
    final resume = invoiceEditResumeFromApi(
      {
        'success': true,
        'order': {
          'id': 8821,
          'invoice_id': 'POS10372',
          'cart': [
            {'productID': 1, 'quantity': 2, 'price': 1000, 'productTitle': 'Test'},
          ],
          'customer': {'id': 5, 'first_name': 'Ali'},
          'payments': [
            {'paid': 2000, 'paymentType': 'cash'},
          ],
        },
      },
      editOrderId: 8821,
      editReason: 'Xato',
    );
    expect(resume, isNotNull);
    expect(resume!.editOrderId, 8821);
    expect(resume.editReason, 'Xato');
    expect(resume.cartRows.length, 1);
    expect(resume.payments.length, 1);
  });
}
