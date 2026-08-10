import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/seller_preferences.dart';
import '../providers/dashboard_provider.dart';
import '../services/api_service.dart';
import 'mijozlar_screen.dart';
import 'xarajatlar_screen.dart';

class MenuScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const MenuScreen({super.key, this.onLogout});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  /// API /user dan ism (sotuvchilar ro'yxati bo'sh bo'lsa zaxira)
  Future<String> _getUserDisplayName() async {
    try {
      final res = await UserApi.getUser();
      // Murod API: user ma'lumotlari "success" obyektida (first_name, last_name, email)
      final data = res['success'] is Map
          ? res['success'] as Map<String, dynamic>
          : (res['data'] is Map ? res['data'] as Map<String, dynamic> : res);
      final first = data['first_name'] as String? ?? data['firstName'] as String? ?? '';
      final last = data['last_name'] as String? ?? data['lastName'] as String? ?? '';
      final name = '$first $last'.trim();
      if (name.isNotEmpty) return name;
      final email = data['email'] as String? ?? data['name'] as String?;
      if (email != null && email.toString().isNotEmpty) return email.toString();
    } catch (_) {}
    return getSellerName();
  }

  @override
  void initState() {
    super.initState();
    DashboardProvider.instance.addListener(_onDashboardChanged);
    if (DashboardProvider.instance.sellers.isEmpty) {
      DashboardProvider.instance.loadFromApi();
    }
  }

  void _onDashboardChanged() => setState(() {});

  @override
  void dispose() {
    DashboardProvider.instance.removeListener(_onDashboardChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sellers = DashboardProvider.instance.sellers;

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.barchaModullar),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.person_rounded, color: AppTheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sellers.isEmpty
                                ? Strings.sotuvchiIsmFamiliya
                                : (sellers.length == 1 ? 'Sotuvchi' : 'Sotuvchilar'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (sellers.isNotEmpty)
                            ...sellers.map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    s.sellerName.isEmpty ? '—' : s.sellerName,
                                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                )),
                          if (sellers.isEmpty)
                            FutureBuilder<String>(
                              future: _getUserDisplayName(),
                              builder: (context, snap) {
                                final name = snap.data ?? '…';
                                return Text(
                                  name,
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.onLogout != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AuthApi.logout();
                    widget.onLogout?.call();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Chiqish'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _MenuButton(
              icon: Icons.people_rounded,
              title: Strings.mijozlar,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MijozlarScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              icon: Icons.payments_rounded,
              title: Strings.xarajatlar,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const XarajatlarScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuButton({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
