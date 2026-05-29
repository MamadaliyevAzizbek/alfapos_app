import '../core/input_formatters.dart';

int? cashRegisterParseId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

bool cashRegisterIsOpen(Map<String, dynamic> r) {
  final s = (r['status'] ?? r['register_status'] ?? '').toString().toLowerCase();
  if (s == 'open' || s == '1' || s == 'true' || s.contains('ochiq')) return true;
  if (s == 'closed' || s == '0' || s.contains('yopiq')) return false;
  return cashRegisterLogId(r) != null;
}

String cashRegisterDisplayTitle(Map<String, dynamic> r) {
  return (r['title'] ?? r['name'] ?? 'Kassa').toString();
}

int? cashRegisterLogId(Map<String, dynamic> r) {
  return cashRegisterParseId(
    r['register_log_id'] ?? r['registerLogId'] ?? r['log_id'] ?? r['cash_register_log_id'],
  );
}

String cashRegisterShiftStaffNames(Map<String, dynamic> r) {
  final names = (r['shift_staff_names'] ?? '').toString().trim();
  if (names.isNotEmpty) return names;
  final staff = r['shift_staff'];
  if (staff is List) {
    final parts = <String>[];
    for (final s in staff) {
      if (s is Map) {
        final n = (s['name'] ?? '').toString().trim();
        if (n.isNotEmpty) parts.add(n);
      }
    }
    if (parts.isNotEmpty) return parts.join(', ');
  }
  return '';
}

List<int> cashRegisterShiftUserIds(Map<String, dynamic> r) {
  final ids = <int>{};

  void addRaw(dynamic raw) {
    if (raw is List) {
      for (final v in raw) {
        final id = cashRegisterParseId(v);
        if (id != null) ids.add(id);
      }
    } else {
      final id = cashRegisterParseId(raw);
      if (id != null) ids.add(id);
    }
  }

  for (final key in [
    'userID',
    'user_ids',
    'userIds',
    'user_id',
    'open_user_id',
    'opened_by',
    'openedBy',
  ]) {
    if (r.containsKey(key)) addRaw(r[key]);
  }

  final staff = r['shift_staff'];
  if (staff is List) {
    for (final s in staff) {
      if (s is Map) {
        final id = cashRegisterParseId(s['id'] ?? s['user_id'] ?? s['userId']);
        if (id != null) ids.add(id);
      }
    }
  }

  final log = r['log'];
  if (log is Map) {
    final opened = cashRegisterParseId(log['opened_by'] ?? log['user_id']);
    if (opened != null) ids.add(opened);
  }

  return ids.toList();
}

bool cashRegisterUserIsEnrolled(Map<String, dynamic> r, int? userId) {
  if (!cashRegisterIsOpen(r)) return false;
  if (userId == null) return cashRegisterLogId(r) != null;
  if (cashRegisterShiftUserIds(r).contains(userId)) return true;
  return cashRegisterUserIsOpener(r, userId);
}

bool cashRegisterUserIsOpener(Map<String, dynamic> r, int? userId) {
  if (userId == null) return false;
  final opener = cashRegisterParseId(r['open_user_id']);
  if (opener == userId) return true;
  final staff = r['shift_staff'];
  if (staff is List) {
    for (final s in staff) {
      if (s is Map &&
          cashRegisterParseId(s['id']) == userId &&
          cashRegisterTruthy(s['is_opener'])) {
        return true;
      }
    }
  }
  return false;
}

bool cashRegisterTruthy(dynamic v) =>
    v == true || v == 1 || v == '1' || v == 'true';

bool cashRegisterShiftStaffContainsUser(Map<String, dynamic>? info, int? userId) {
  if (info == null || userId == null) return false;
  final staff = info['shift_staff'];
  if (staff is! List) return false;
  for (final s in staff) {
    if (s is Map && cashRegisterParseId(s['id']) == userId) return true;
  }
  return false;
}

/// GET .../cash-register-shifts/{logId}/info — ochuvchi aniqlash (aniqroq).
bool cashRegisterUserIsOpenerFromShiftInfo(Map<String, dynamic>? info, int? userId) {
  if (userId == null || info == null) return false;
  final log = info['log'];
  if (log is Map) {
    final openedBy = cashRegisterParseId(log['opened_by']);
    if (openedBy == userId) return true;
  }
  final openedByTop = cashRegisterParseId(info['opened_by']);
  if (openedByTop == userId) return true;
  final staff = info['shift_staff'];
  if (staff is List) {
    for (final s in staff) {
      if (s is Map &&
          cashRegisterParseId(s['id']) == userId &&
          cashRegisterTruthy(s['is_opener'])) {
        return true;
      }
    }
  }
  return false;
}

Map<String, dynamic> apiResponseMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

String formatShiftDateTime(dynamic v) {
  if (v == null) return '—';
  final s = v.toString();
  if (s.isEmpty) return '—';
  try {
    final dt = DateTime.parse(s);
    final d = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d, $t';
  } catch (_) {
    return s.length > 16 ? s.substring(0, 16) : s;
  }
}

String formatShiftMoney(dynamic v) {
  return formatThousands(parseAmountFromApi(v));
}

String shiftOpeningTimeBody() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
      '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
}

String shiftClosingTimeBody() {
  return DateTime.now().toUtc().toIso8601String();
}

List<Map<String, dynamic>> parseApiList(dynamic raw) {
  if (raw is List) {
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return [];
}

List<Map<String, dynamic>> parseDropdownList(dynamic raw, {List<String> keys = const ['data', 'datarows']}) {
  if (raw is List) return parseApiList(raw);
  if (raw is Map) {
    for (final k in keys) {
      final v = raw[k];
      if (v is List) return parseApiList(v);
    }
  }
  return [];
}

String dropdownLabel(Map<String, dynamic> item) {
  return (item['name'] ??
          item['payment_method'] ??
          item['title'] ??
          item['text'] ??
          '#${item['id']}')
      .toString();
}

int? dropdownId(Map<String, dynamic> item) {
  return cashRegisterParseId(item['id'] ?? item['value']);
}
