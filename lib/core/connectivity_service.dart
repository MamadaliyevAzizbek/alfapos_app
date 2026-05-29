import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'api_http.dart';

/// Internet va server aloqasi — uzilganda butun ilova bloklanadi.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pollTimer;
  bool _started = false;
  bool _checkInFlight = false;

  bool _isOnline = true;
  bool _checking = false;

  bool get isOnline => _isOnline;
  bool get checking => _checking;

  void start() {
    if (_started) return;
    _started = true;
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    unawaited(_evaluate());
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _evaluate());
  }

  void stop() {
    _subscription?.cancel();
    _pollTimer?.cancel();
    _fastPollTimer?.cancel();
    _started = false;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!_hasLocalNetwork(results)) {
      _setOnline(false);
      _startFastPoll();
      return;
    }
    unawaited(_evaluate());
  }

  void reportNetworkFailure() {
    if (!_isOnline) return;
    _setOnline(false);
    _startFastPoll();
  }

  void reportNetworkSuccess() {
    if (_isOnline) return;
    _setOnline(true);
    _stopFastPoll();
  }

  Timer? _fastPollTimer;

  void _startFastPoll() {
    _fastPollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) => _evaluate());
  }

  void _stopFastPoll() {
    _fastPollTimer?.cancel();
    _fastPollTimer = null;
  }

  Future<void> _evaluate() async {
    if (_checkInFlight) return;
    _checkInFlight = true;
    try {
      List<ConnectivityResult> results;
      try {
        results = await _connectivity.checkConnectivity();
      } catch (_) {
        results = [ConnectivityResult.none];
      }

      if (!_hasLocalNetwork(results)) {
        _setOnline(false);
        _startFastPoll();
        return;
      }

      if (!_checking) {
        _checking = true;
        notifyListeners();
      }

      final err = await ApiHttp.reachabilityDetail();
      final online = err == null;
      _setOnline(online);
      if (online) {
        _stopFastPoll();
      } else {
        _startFastPoll();
      }
    } finally {
      _checkInFlight = false;
      if (_checking) {
        _checking = false;
        notifyListeners();
      }
    }
  }

  void _setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    notifyListeners();
  }

  static bool _hasLocalNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) {
      switch (r) {
        case ConnectivityResult.mobile:
        case ConnectivityResult.wifi:
        case ConnectivityResult.ethernet:
        case ConnectivityResult.vpn:
        case ConnectivityResult.other:
        case ConnectivityResult.satellite:
          return true;
        case ConnectivityResult.none:
        case ConnectivityResult.bluetooth:
          return false;
      }
    });
  }
}
