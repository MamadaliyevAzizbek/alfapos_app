import 'dart:convert';

import 'package:alfapos_app/core/api_http.dart';
import 'package:alfapos_app/models/product.dart';
import 'package:alfapos_app/providers/receive_session_provider.dart';
import 'package:alfapos_app/services/receive_draft_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Soxta backend: MOBILE_RECEIVES_API_UZ.md §6 qoralamalar.
class _FakeDraftsApi {
  final Map<String, Map<String, dynamic>> drafts = {};
  int _nextId = 1;

  final List<String> posts = [];
  final List<String> deletes = [];

  MockClient build() {
    return MockClient((request) async {
      final path = request.url.path;
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(request.body) as Map);

      if (request.method == 'GET' && path.endsWith('/receives/drafts')) {
        final list = drafts.values.toList()
          ..sort((a, b) => (b['savedAt'] as String)
              .compareTo(a['savedAt'] as String));
        return _json({'data': list});
      }

      final updateMatch =
          RegExp(r'/receives/drafts/([^/]+)$').firstMatch(path);
      if (request.method == 'POST' &&
          updateMatch != null &&
          !path.endsWith('/receives/drafts')) {
        final id = updateMatch.group(1)!;
        posts.add('update:$id');
        final row = {
          ...body,
          'id': id,
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'branchId': 1,
          'createdBy': 2,
        };
        drafts[id] = row;
        return _json({'message': 'updated', 'data': row});
      }

      if (request.method == 'POST' && path.endsWith('/receives/drafts')) {
        posts.add('create');
        final id = '${_nextId++}';
        final row = {
          ...body,
          'id': id,
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'branchId': 1,
          'createdBy': 2,
        };
        drafts[id] = row;
        return _json({'message': 'created', 'data': row});
      }

      if (request.method == 'DELETE' && updateMatch != null) {
        final id = updateMatch.group(1)!;
        deletes.add(id);
        drafts.remove(id);
        return _json({'message': 'deleted'});
      }

      return _json({'message': 'not found'}, status: 404);
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const product = Product(
    id: '10',
    name: 'DDR4 8GB Laptop',
    variantId: 20,
    costPriceUzs: 600000,
    wholesalePriceUzs: 700000,
    priceUzs: 750000,
  );

  final session = ReceiveSessionProvider.instance;
  late _FakeDraftsApi fake;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'alfapos_api_token': 'test-token',
      'alfapos_api_company_id': '1',
    });
    fake = _FakeDraftsApi();
    ApiHttp.debugClient = fake.build();
    session.resetForAccountChange();
    session.branchId = 1;
  });

  tearDown(() {
    ApiHttp.debugClient = null;
  });

  test('draft save keeps cart items via API', () async {
    session.addToCart(product, quantity: 2);
    session.setComment('Izoh');
    session.setDeliveryCost(15000);

    await ReceiveDraftStorage.saveFromSession(session);
    final drafts = await ReceiveDraftStorage.loadDrafts(1);

    expect(drafts, hasLength(1));
    expect(drafts.single.cartItems, hasLength(1));
    expect(drafts.single.comment, 'Izoh');
    expect(drafts.single.receivingDeliveryCost, 15000);
    expect(drafts.single.cartItems.single['productID'], 10);
    expect(drafts.single.cartItems.single['quantity'], 2);
    expect(drafts.single.cartItems.single['price'], 600000);
    expect(drafts.single.cartItems.single['sellingPrice'], 750000);
    expect(drafts.single.cartItems.single['wholesalePrice'], 700000);
    expect(fake.posts, ['create']);
  });

  test('cart and comment are emptied after draft is saved', () async {
    session.addToCart(product);
    session.setComment('Izoh');
    session.setDeliveryCost(15000);

    await ReceiveDraftStorage.saveFromSession(session);
    session.resetAfterDraftSaved();

    expect(session.cart, isEmpty);
    expect(session.cartTotalUzs, 0);
    expect(session.comment, '');
    expect(session.deliveryCostUzs, 0);
  });

  test('two separate carts create two drafts', () async {
    session.addToCart(product);
    await ReceiveDraftStorage.saveFromSession(session);
    session.resetAfterDraftSaved();

    session.addToCart(product);
    await ReceiveDraftStorage.saveFromSession(session);
    session.resetAfterDraftSaved();

    final drafts = await ReceiveDraftStorage.loadDrafts(1);
    expect(drafts, hasLength(2));
    expect(drafts.every((d) => d.cartItems.length == 1), isTrue);
    expect(fake.posts, ['create', 'create']);
  });

  test('reopened draft is updated in place, not saved as a new one', () async {
    session.addToCart(product);
    final draftId = await ReceiveDraftStorage.saveFromSession(session);
    session.resetAfterDraftSaved();

    session.addToCart(product);
    session.activeDraftId = draftId;
    session.addToCart(
      const Product(id: '11', name: 'Sichqoncha', priceUzs: 90000),
    );
    await ReceiveDraftStorage.saveFromSession(session);
    session.resetAfterDraftSaved();

    final drafts = await ReceiveDraftStorage.loadDrafts(1);
    expect(drafts, hasLength(1));
    expect(drafts.single.id, draftId);
    expect(drafts.single.cartItems, hasLength(2));
    expect(fake.posts, ['create', 'update:$draftId']);
  });

  test('active draft id is dropped when cart is cleared', () {
    session.addToCart(product);
    session.activeDraftId = '123';

    session.clearCart();

    expect(session.activeDraftId, isNull);
  });

  test('empty cart cannot be saved as draft', () async {
    expect(
      () => ReceiveDraftStorage.saveFromSession(session),
      throwsStateError,
    );
  });

  test('deleteDraft calls DELETE /receives/drafts/{id}', () async {
    session.addToCart(product);
    final id = await ReceiveDraftStorage.saveFromSession(session);
    await ReceiveDraftStorage.deleteDraft(1, id);

    expect(fake.deletes, [id]);
    expect(await ReceiveDraftStorage.loadDrafts(1), isEmpty);
  });
}
