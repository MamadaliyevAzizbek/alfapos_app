import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../providers/sales_session_provider.dart';
import '../../services/api_service.dart';
import '../../utils/tv_orders_response.dart';

/// Restoran TV / oshxona: chapda preparing, o‘ngda ready. Faqat navbat raqami.
class RestaurantTvScreen extends StatefulWidget {
  const RestaurantTvScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (_, __, ___) => const RestaurantTvScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<RestaurantTvScreen> createState() => _RestaurantTvScreenState();
}

class _RestaurantTvScreenState extends State<RestaurantTvScreen> {
  Timer? _poll;
  TvOrdersSnapshot _snapshot = const TvOrdersSnapshot();
  Map<int, String> _prevStatus = {};
  String? _error;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(_refresh());
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_refresh()));
  }

  @override
  void dispose() {
    _poll?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _refresh() async {
    final branchId = SalesSessionProvider.instance.branchId;
    if (branchId == null || branchId <= 0) {
      if (mounted) {
        setState(() => _error = 'Filial tanlanmagan. Avval sotuv bo‘limini oching.');
      }
      return;
    }
    try {
      final res = await SalesApi.getTvOrders(
        branchId: branchId,
        cacheBust: DateTime.now().millisecondsSinceEpoch,
      );
      final next = TvOrdersResponse.parse(res);
      if (!mounted) return;
      _playStatusSounds(next);
      setState(() {
        _snapshot = next;
        _error = null;
        _firstLoad = false;
        _prevStatus = {
          for (final o in next.orders)
            if (o.kitchenStatus != null) o.orderId: o.kitchenStatus!.apiValue,
        };
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _firstLoad = false;
        if (e.statusCode == 401 || e.statusCode == 403) {
          _error = 'Sessiya tugagan. Qayta kiring.';
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _firstLoad = false;
        _error = '$e';
      });
    }
  }

  void _playStatusSounds(TvOrdersSnapshot next) {
    if (_firstLoad) return;
    var newPreparing = false;
    var newReady = false;
    for (final order in next.orders) {
      final status = order.kitchenStatus?.apiValue;
      if (status == null) continue;
      final prev = _prevStatus[order.orderId];
      if (status == 'preparing' && prev != 'preparing') newPreparing = true;
      if (status == 'ready' && prev != 'ready') newReady = true;
    }
    if (newReady) {
      unawaited(SystemSound.play(SystemSoundType.alert));
    } else if (newPreparing) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch = _snapshot.branchName ?? SalesSessionProvider.instance.branchName;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.tv_rounded, color: Colors.white70, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      branch.isEmpty ? 'Oshxona TV' : branch,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_snapshot.serverTime != null)
                    Text(
                      _snapshot.serverTime!,
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  IconButton(
                    tooltip: 'Yopish',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFFFAB91))),
              ),
            Expanded(
              child: _firstLoad && _snapshot.orders.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TvColumn(
                              title: 'Tayyorlanmoqda',
                              color: const Color(0xFFF59E0B),
                              background: const Color(0xFF422006),
                              orders: _snapshot.preparing,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _TvColumn(
                              title: 'Tayyor',
                              color: const Color(0xFF22C55E),
                              background: const Color(0xFF052E16),
                              orders: _snapshot.ready,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvColumn extends StatelessWidget {
  const _TvColumn({
    required this.title,
    required this.color,
    required this.background,
    required this.orders,
  });

  final String title;
  final Color color;
  final Color background;
  final List<TvQueueOrder> orders;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  '${orders.length}',
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Text(
                      '—',
                      style: TextStyle(color: color.withValues(alpha: 0.35), fontSize: 48),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: orders.length,
                    itemBuilder: (context, i) {
                      final n = orders[i].queueNumber;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withValues(alpha: 0.45)),
                        ),
                        child: Center(
                          child: Text(
                            n == null ? '—' : '$n',
                            style: TextStyle(
                              color: color,
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
