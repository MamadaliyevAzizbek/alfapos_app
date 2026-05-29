import 'package:flutter/material.dart';

import '../core/connectivity_service.dart';
import '../core/theme.dart';

/// Internet uzilganda butun ekranni bloklaydi — aloqa tiklanguncha yopilmaydi.
class ConnectivityBlocker extends StatefulWidget {
  final Widget child;

  const ConnectivityBlocker({super.key, required this.child});

  @override
  State<ConnectivityBlocker> createState() => _ConnectivityBlockerState();
}

class _ConnectivityBlockerState extends State<ConnectivityBlocker> {
  static const Color _headerRed = Color(0xFFE53935);
  static const Color _headerRedDark = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.start();
    ConnectivityService.instance.addListener(_onConnectivity);
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_onConnectivity);
    super.dispose();
  }

  void _onConnectivity() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = ConnectivityService.instance;
    final blocked = !service.isOnline;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (blocked)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _OfflineConnectionCard(
                          checking: service.checking,
                          headerRed: _headerRed,
                          headerRedDark: _headerRedDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OfflineConnectionCard extends StatelessWidget {
  final bool checking;
  final Color headerRed;
  final Color headerRedDark;

  const _OfflineConnectionCard({
    required this.checking,
    required this.headerRed,
    required this.headerRedDark,
  });

  static const List<String> _tips = [
    'Wi‑Fi yoki mobil internetni qayta yoqing',
    'Routerga yaqinroq joylashib ko\'ring',
    'Aloqa tiklanguncha kuting — oyna o\'zi yopiladi',
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: headerRed,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        children: [
          const Text(
            'Internet aloqasi yo\'q',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: headerRedDark,
              shape: BoxShape.circle,
            ),
            child: CustomPaint(
              painter: _DisconnectedPlugPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ilovadan foydalanish uchun internetga qayta ulaning.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Agar muammo bo\'lsa:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ..._tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (checking) ...[
            const SizedBox(height: 18),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Tekshirilmoqda...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Qayta ulanish kutilmoqda...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rasmdagi uzilgan rozetka / vilka — oq kontur, qizil fon ustida.
class _DisconnectedPlugPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Yuqori rozetka (uzilgan)
    final socketR = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.34),
        width: 44,
        height: 36,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(socketR, stroke);

    // «Xafa» yuz
    canvas.drawCircle(Offset(cx - 8, size.height * 0.32), 2.2, fill);
    canvas.drawCircle(Offset(cx + 8, size.height * 0.32), 2.2, fill);
    final mouth = Path()
      ..moveTo(cx - 7, size.height * 0.39)
      ..quadraticBezierTo(cx, size.height * 0.36, cx + 7, size.height * 0.39);
    canvas.drawPath(mouth, stroke..strokeWidth = 2);

    // Pastki vilka (uzilgan)
    final plugBody = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.72),
        width: 28,
        height: 22,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(plugBody, stroke);

    canvas.drawLine(
      Offset(cx - 6, size.height * 0.64),
      Offset(cx - 6, size.height * 0.58),
      stroke..strokeWidth = 3.5,
    );
    canvas.drawLine(
      Offset(cx + 6, size.height * 0.64),
      Offset(cx + 6, size.height * 0.58),
      stroke..strokeWidth = 3.5,
    );

    // Uzilish chiziqlari (ko'k accent)
    final gap = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - 14, size.height * 0.5),
      Offset(cx - 4, size.height * 0.5),
      gap,
    );
    canvas.drawLine(
      Offset(cx + 4, size.height * 0.5),
      Offset(cx + 14, size.height * 0.5),
      gap,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
