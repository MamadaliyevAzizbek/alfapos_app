import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_sync_throttle.dart';
import '../core/input_formatters.dart';
import '../core/seller_preferences.dart';
import '../services/api_service.dart';
import '../utils/cash_register_utils.dart';

/// Kassa smenasi — MOBILE_CASH_REGISTER_SHIFT_API_UZ.md
class CashRegisterShiftProvider extends ChangeNotifier {
  CashRegisterShiftProvider._();
  static final CashRegisterShiftProvider instance = CashRegisterShiftProvider._();

  List<Map<String, dynamic>> registers = [];
  Map<String, dynamic>? activeRegister;
  int? cashRegisterId;
  int? registerLogId;
  String cashRegisterTitle = '';

  Map<String, dynamic>? shiftInfo;
  Map<String, dynamic>? shiftAnalytics;
  num? expectedClosingAmount;
  int? currentUserId;

  /// Ro‘yxat yoki smena ochish/yopish jarayoni.
  bool loading = false;
  /// Faqat hisobot yuklanishi (POS bloklanmaydi).
  bool detailLoading = false;
  String? error;

  bool get requiresCashRegister => registers.isNotEmpty;

  bool get isShiftOpen {
    if (registerLogId == null || cashRegisterId == null) return false;
    final r = activeRegister;
    if (r == null) return true;
    return cashRegisterUserIsEnrolled(r, currentUserId);
  }

  bool get isCurrentUserOpener =>
      activeRegister != null && cashRegisterUserIsOpener(activeRegister!, currentUserId);

  bool get canLeaveCurrentShift =>
      isShiftOpen && activeRegister != null && !isCurrentUserOpener;

  Future<void> ensureCurrentUserId() async {
    currentUserId ??= await getCurrentUserId();
  }

  /// Serverdan kassalar ro‘yxatini qayta yuklaydi (telefon/desktop sinxron).
  Future<bool> syncWithServer({bool reloadShiftDetail = true, bool force = false}) async {
    if (!force &&
        !ApiSyncThrottle.shouldRun('cash_register_sync', const Duration(seconds: 90))) {
      return error == null;
    }
    if (!force) ApiSyncThrottle.markRan('cash_register_sync');
    await loadRegisters();
    if (reloadShiftDetail && isShiftOpen) {
      await loadShiftDetail();
    }
    return error == null;
  }

  Future<void> loadRegisters() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await ensureCurrentUserId();
      await _fetchRegisters();
    } on ApiException catch (e) {
      error = e.message;
      registers = [];
      _clearActive();
    } catch (_) {
      error = 'Kassalar yuklanmadi';
      registers = [];
      _clearActive();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchRegisters() async {
    final res = await SalesApi.getCashRegisters();
    final raw = res['cash_registers'] ?? res['data'] ?? res['datarows'] ?? res;
    registers = parseApiList(raw);
    _syncActiveFromRegisters();
  }

  void _clearActive() {
    activeRegister = null;
    cashRegisterId = null;
    registerLogId = null;
    cashRegisterTitle = '';
    shiftInfo = null;
    shiftAnalytics = null;
    expectedClosingAmount = null;
  }

  void _applyRegister(Map<String, dynamic> r) {
    activeRegister = r;
    cashRegisterId = cashRegisterParseId(r['id'] ?? r['cash_register_id']);
    cashRegisterTitle = cashRegisterDisplayTitle(r);
    registerLogId = cashRegisterIsOpen(r) ? cashRegisterLogId(r) : null;
  }

  void _syncActiveFromRegisters() {
    if (registers.isEmpty) {
      _clearActive();
      return;
    }

    if (activeRegister != null) {
      final id = cashRegisterParseId(activeRegister!['id']);
      for (final r in registers) {
        if (cashRegisterParseId(r['id']) == id) {
          if (cashRegisterUserIsEnrolled(r, currentUserId)) {
            _applyRegister(r);
          } else {
            _clearActive();
          }
          return;
        }
      }
    }

    if (currentUserId != null) {
      for (final r in registers) {
        if (cashRegisterUserIsEnrolled(r, currentUserId)) {
          _applyRegister(r);
          return;
        }
      }
    }

    _clearActive();
  }

  Future<void> _reloadRegisterById(int registerId) async {
    await _fetchRegisters();
    for (final r in registers) {
      if (cashRegisterParseId(r['id']) == registerId) {
        _applyRegister(r);
        return;
      }
    }
  }

  void selectRegister(Map<String, dynamic> r) {
    _applyRegister(r);
    notifyListeners();
  }

  Future<bool> openShift({
    required int registerId,
    required num openingAmount,
    String accessPassword = '',
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await SalesApi.openCloseCashRegister({
        'id': registerId,
        'status': 'open',
        'openingAmount': openingAmount,
        'openingTime': shiftOpeningTimeBody(),
        'access_password': accessPassword,
      });
      await _reloadRegisterById(registerId);
      if (!isShiftOpen) {
        error = 'Kassa ochildi, lekin smena ma’lumoti kelmedi. Ro‘yxatni yangilang.';
        return false;
      }
      unawaited(loadShiftDetail());
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> enrollShift(int registerId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await ensureCurrentUserId();
      await SalesApi.openCloseCashRegister({'id': registerId, 'status': 'enroll'});
      await _reloadRegisterById(registerId);
      if (!isShiftOpen) {
        error = 'Birlashish amalga oshmadi. Kassa ochiq emas yoki ruxsat yo‘q.';
        return false;
      }
      unawaited(loadShiftDetail());
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> leaveShift(int registerId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await ensureCurrentUserId();
      await SalesApi.openCloseCashRegister({'id': registerId, 'status': 'leave'});
      await _fetchRegisters();
      final stillHere = registers.any(
        (r) =>
            cashRegisterParseId(r['id']) == registerId &&
            cashRegisterUserIsEnrolled(r, currentUserId),
      );
      if (stillHere) {
        error = 'Smenadan chiqish amalga oshmadi';
        return false;
      }
      _syncActiveFromRegisters();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadShiftDetail() async {
    final logId = registerLogId;
    if (logId == null) return;
    if (detailLoading) return;
    detailLoading = true;
    notifyListeners();
    try {
      final regId = cashRegisterId;
      final futures = <Future<Map<String, dynamic>>>[
        SalesApi.getShiftInfo(logId),
        SalesApi.getShiftAnalytics(logId),
      ];
      if (regId != null) {
        futures.add(SalesApi.getRegisterExpectedAmount(regId));
      }
      final results = await Future.wait(futures);
      shiftInfo = apiResponseMap(results[0]);
      shiftAnalytics = apiResponseMap(results[1]);
      expectedClosingAmount = parseAmountFromApi(
        shiftAnalytics!['expected_amount'] ?? shiftAnalytics!['total_current_amount'],
      );
      if (regId != null && results.length > 2) {
        try {
          final amt = results[2];
          final v = amt['expected_amount'] ?? amt['amount'] ?? amt['data'];
          if (v != null) expectedClosingAmount = parseAmountFromApi(v);
        } catch (_) {}
      }
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      detailLoading = false;
      notifyListeners();
    }
  }

  Future<bool> closeShift({
    required num closingAmount,
    String note = '',
  }) async {
    final logId = registerLogId;
    if (logId == null) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await SalesApi.closeShift({
        'register_log_id': logId,
        'closingAmount': closingAmount,
        'closingTime': shiftClosingTimeBody(),
        'note': note,
      });
      await _fetchRegisters();
      _clearActive();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool get canCloseFromInfo {
    final info = shiftInfo;
    if (info == null) return true;
    if (info['can_close'] == true) return true;
    if (info['can_close'] == 1) return true;
    return info['can_close'] != false;
  }
}
