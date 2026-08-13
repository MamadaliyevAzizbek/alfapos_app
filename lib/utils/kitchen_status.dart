/// Oshxona / TV holati — sotuv `status` (hold/done) dan alohida.
/// Faqat to‘lovdan keyin (`done`) ishlaydi.
enum KitchenStatus {
  preparing,
  ready,
  completed;

  static KitchenStatus? tryParse(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase();
    if (s == null || s.isEmpty || s == 'null') return null;
    switch (s) {
      case 'preparing':
      case 'new':
        return KitchenStatus.preparing;
      case 'ready':
        return KitchenStatus.ready;
      case 'completed':
      case 'served':
        return KitchenStatus.completed;
    }
    return null;
  }

  String get apiValue {
    switch (this) {
      case KitchenStatus.preparing:
        return 'preparing';
      case KitchenStatus.ready:
        return 'ready';
      case KitchenStatus.completed:
        return 'completed';
    }
  }

  String get label {
    switch (this) {
      case KitchenStatus.preparing:
        return 'Tayyorlanmoqda';
      case KitchenStatus.ready:
        return 'Tayyor';
      case KitchenStatus.completed:
        return 'Yakunlandi';
    }
  }

  bool get isVisibleOnTv =>
      this == KitchenStatus.preparing || this == KitchenStatus.ready;
}
