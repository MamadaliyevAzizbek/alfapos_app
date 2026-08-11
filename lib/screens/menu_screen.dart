import 'package:flutter/material.dart';
import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/seller_preferences.dart';
import '../providers/dashboard_provider.dart';
import '../services/api_service.dart';
import '../services/app_data_sync.dart';
import 'hisobotlar_screen.dart';
import 'kirimlar_screen.dart';
import 'mijozlar_screen.dart';
import 'sozlamalar_screen.dart';
import 'xarajatlar_screen.dart';

class MenuScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const MenuScreen({super.key, this.onLogout});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Future<String>? _userNameFuture;
  bool _syncing = false;

  Future<void> _onSync() async {
    if (_syncing || AppDataSync.isForceSyncBlocked) return;
    setState(() => _syncing = true);
    try {
      await AppDataSync.syncAll(force: true);
      if (mounted) AppNotify.success(context, 'Ma\'lumotlar sinxronlandi');
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Sinxronlash xatosi: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<String> _getUserDisplayName() async {
    try {
      final res = await UserApi.getUser();
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
    _userNameFuture = _getUserDisplayName();
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

  String get _accountName {
    final sellers = DashboardProvider.instance.sellers;
    if (sellers.length == 1 && sellers.first.sellerName.trim().isNotEmpty) {
      return sellers.first.sellerName.trim();
    }
    if (sellers.length > 1) {
      final names = sellers
          .map((s) => s.sellerName.trim())
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return '';
  }

  Future<void> _logout() async {
    await AuthApi.logout();
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text(Strings.barchaModullar),
        centerTitle: false,
        toolbarHeight: 48,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: AppDataSync.forceCooldownSeconds,
            builder: (context, left, _) {
              final cooling = left > 0;
              return TextButton.icon(
                onPressed: (_syncing || cooling) ? null : _onSync,
                icon: _syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 20),
                label: Text(cooling ? 'Sinxronlash ($left)' : 'Sinxronlash'),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _AccountNavBar(
            name: _accountName,
            nameFallback: _userNameFuture,
            onSettings: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const SozlamalarScreen()),
            ),
            onLogout: widget.onLogout == null ? null : _logout,
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.45,
            children: [
              _ModuleCard(
                icon: Icons.people_rounded,
                title: Strings.mijozlar,
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const MijozlarScreen()),
                ),
              ),
              _ModuleCard(
                icon: Icons.payments_rounded,
                title: Strings.xarajatlar,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const XarajatlarScreen()),
                ),
              ),
              _ModuleCard(
                icon: Icons.bar_chart_rounded,
                title: Strings.hisobotlar,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HisobotlarScreen()),
                ),
              ),
              _ModuleCard(
                icon: Icons.inventory_2_rounded,
                title: Strings.kirimlar,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KirimlarScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastki nav bilan bir xil: ikonka + yozuv.
class _AccountNavBar extends StatelessWidget {
  final String name;
  final Future<String>? nameFallback;
  final VoidCallback onSettings;
  final VoidCallback? onLogout;

  const _AccountNavBar({
    required this.name,
    required this.nameFallback,
    required this.onSettings,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: name.isNotEmpty
                ? _NavItem(
                    icon: Icons.person_rounded,
                    label: name,
                    onTap: null,
                  )
                : FutureBuilder<String>(
                    future: nameFallback,
                    builder: (context, snap) {
                      final label = (snap.data ?? '').trim().isEmpty
                          ? 'Akkaunt'
                          : snap.data!.trim();
                      return _NavItem(
                        icon: Icons.person_rounded,
                        label: label,
                        onTap: null,
                      );
                    },
                  ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.settings_rounded,
              label: 'Sozlamalar',
              onTap: onSettings,
            ),
          ),
          if (onLogout != null)
            Expanded(
              child: _NavItem(
                icon: Icons.logout_rounded,
                label: 'Chiqish',
                color: Theme.of(context).colorScheme.error,
                onTap: onLogout,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _NavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: c),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }
}
