import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_notify.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/seller_preferences.dart';
import '../core/user_permissions.dart';
import '../providers/dashboard_provider.dart';
import '../services/api_service.dart';
import '../services/app_data_sync.dart';
import '../utils/platform_layout.dart';
import '../widgets/social_icons.dart';
import 'barcode_print_queue_screen.dart';
import 'inventarizatsiya_screen.dart';
import 'kirimlar_screen.dart';
import 'mijozlar_screen.dart';
import 'sozlamalar_screen.dart';
import 'taminotchilar_screen.dart';
import 'mobile_printer_settings_screen.dart';
import 'xarajatlar_screen.dart';

/// Foydalanuvchi kartasi uchun ism va telefon.
class _Profile {
  const _Profile({required this.name, required this.phone});

  final String name;
  final String phone;
}

class MenuScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const MenuScreen({super.key, this.onLogout});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Future<_Profile>? _profileFuture;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    DashboardProvider.instance.addListener(_onDashboardChanged);
    UserPermissionsStore.instance.addListener(_onPermissionsChanged);
    if (DashboardProvider.instance.sellers.isEmpty) {
      DashboardProvider.instance.loadFromApi();
    }
  }

  @override
  void dispose() {
    DashboardProvider.instance.removeListener(_onDashboardChanged);
    UserPermissionsStore.instance.removeListener(_onPermissionsChanged);
    super.dispose();
  }

  void _onDashboardChanged() {
    if (mounted) setState(() {});
  }

  void _onPermissionsChanged() {
    if (mounted) setState(() {});
  }

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

  Future<_Profile> _loadProfile() async {
    var name = '';
    var phone = '';
    try {
      final res = await UserApi.getUser();
      await UserPermissionsStore.instance.applyFromUserResponse(res);
      final data = res['success'] is Map
          ? res['success'] as Map<String, dynamic>
          : (res['data'] is Map ? res['data'] as Map<String, dynamic> : res);

      final first = (data['first_name'] ?? data['firstName'] ?? '').toString();
      final last = (data['last_name'] ?? data['lastName'] ?? '').toString();
      name = '$first $last'.trim();
      if (name.isEmpty) {
        name = (data['name'] ?? data['email'] ?? '').toString().trim();
      }
      phone = (data['phone'] ??
              data['phone_number'] ??
              data['phoneNumber'] ??
              data['mobile'] ??
              '')
          .toString()
          .trim();
    } catch (_) {}

    if (name.isEmpty) name = _accountName;
    if (name.isEmpty) name = await getSellerName();
    return _Profile(name: name, phone: phone);
  }

  String get _accountName {
    final sellers = DashboardProvider.instance.sellers;
    final names = sellers
        .map((s) => s.sellerName.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) return '';
    return names.join(', ');
  }

  void _open(Widget screen, {bool rootNavigator = false}) {
    final navigator = rootNavigator
        ? Navigator.of(context, rootNavigator: true)
        : Navigator.of(context);
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _launch(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        AppNotify.error(context, 'Ochib bo‘lmadi: ${uri.toString()}');
      }
    } catch (_) {
      if (mounted)
        AppNotify.error(context, 'Ochib bo‘lmadi: ${uri.toString()}');
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chiqish'),
        content: const Text('Akkauntdan chiqmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.bekorQilish),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthApi.logout();
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _ProfileCard(profile: _profileFuture),
          const SizedBox(height: 16),
          _MenuGroup(
            children: [
              _MenuRow(
                icon: LucideIcons.users,
                label: Strings.mijozlar,
                onTap: () => _open(const MijozlarScreen(), rootNavigator: true),
              ),
              _MenuRow(
                icon: LucideIcons.truck,
                label: Strings.taminotchilar,
                onTap: () =>
                    _open(const TaminotchilarScreen(), rootNavigator: true),
              ),
              _MenuRow(
                icon: LucideIcons.wallet,
                label: Strings.xarajatlar,
                onTap: () => _open(const XarajatlarScreen()),
              ),
              _MenuRow(
                icon: LucideIcons.package,
                label: Strings.kirimlar,
                onTap: () => _open(const KirimlarScreen()),
              ),
              if (!isDesktopPosLayout)
                _MenuRow(
                  icon: LucideIcons.barcode,
                  label: Strings.barcodeChopEtish,
                  onTap: () => _open(const BarcodePrintQueueScreen()),
                ),
              if (UserPermissionsStore.instance.canAccessInventory)
                _MenuRow(
                  icon: LucideIcons.clipboard_check,
                  label: Strings.inventarizatsiya,
                  onTap: () => _open(const InventarizatsiyaScreen()),
                ),
              if (!isDesktopPosLayout)
                _MenuRow(
                  icon: LucideIcons.printer,
                  label: 'Printer sozlamalari',
                  onTap: () => _open(
                    const MobilePrinterSettingsScreen(),
                    rootNavigator: true,
                  ),
                ),
              if (isDesktopPosLayout)
                _MenuRow(
                  icon: LucideIcons.settings,
                  label: 'Sozlamalar',
                  onTap: () =>
                      _open(const SozlamalarScreen(), rootNavigator: true),
                ),
              if (widget.onLogout != null)
                _MenuRow(
                  icon: LucideIcons.log_out,
                  label: 'Chiqish',
                  color: error,
                  onTap: _confirmLogout,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ContactBar(
            onPhone: () => _launch(Uri(scheme: 'tel', path: AppContacts.phone)),
            onInstagram: () => _launch(Uri.parse(AppContacts.instagram)),
            onTelegram: () => _launch(Uri.parse(AppContacts.telegram)),
            onYoutube: () => _launch(Uri.parse(AppContacts.youtube)),
          ),
        ],
      ),
    );
  }
}

/// Yuqoridagi katta karta: avatar + «Ism» va «Nomer» maydonlari.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final Future<_Profile>? profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: FutureBuilder<_Profile>(
        future: profile,
        builder: (context, snap) {
          final p = snap.data;
          final loading = snap.connectionState == ConnectionState.waiting;
          final name = (p?.name ?? '').trim();
          final phone = (p?.phone ?? '').trim();

          return Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  LucideIcons.circle_user,
                  size: 46,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProfileField(
                      label: 'Ism',
                      value: loading && name.isEmpty
                          ? '…'
                          : (name.isEmpty ? '—' : name),
                    ),
                    const SizedBox(height: 8),
                    _ProfileField(
                      label: 'Nomer',
                      value: loading && phone.isEmpty
                          ? '…'
                          : (phone.isEmpty ? AppContacts.phone : phone),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
      ),
    );
  }
}

/// Qatorlar guruhi — oralarida ingichka ajratgich bo‘lgan bitta oq karta.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          const Padding(
            padding: EdgeInsets.only(left: 68),
            child: Divider(height: 1, thickness: 1, color: AppTheme.divider),
          ),
        );
      }
      rows.add(children[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppTheme.primary;
    final isDanger = color != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDanger
                    ? tint.withValues(alpha: 0.10)
                    : AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDanger ? tint : AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevron_right,
              size: 20,
              color: isDanger
                  ? tint.withValues(alpha: 0.6)
                  : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastdagi bog‘lanish tugmalari: telefon, Instagram, Telegram, YouTube.
class _ContactBar extends StatelessWidget {
  const _ContactBar({
    required this.onPhone,
    required this.onInstagram,
    required this.onTelegram,
    required this.onYoutube,
  });

  final VoidCallback onPhone;
  final VoidCallback onInstagram;
  final VoidCallback onTelegram;
  final VoidCallback onYoutube;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ContactButton(
            tooltip: AppContacts.phone,
            onTap: onPhone,
            child: const Icon(
              LucideIcons.phone,
              size: 24,
              color: AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContactButton(
            tooltip: 'Instagram',
            onTap: onInstagram,
            child: const InstagramIcon(size: 24, color: AppTheme.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContactButton(
            tooltip: 'Telegram: @${AppContacts.telegramUsername}',
            onTap: onTelegram,
            child: const Icon(
              LucideIcons.send,
              size: 24,
              color: AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContactButton(
            tooltip: 'YouTube',
            onTap: onYoutube,
            child: const YoutubeIcon(size: 24, color: AppTheme.primary),
          ),
        ),
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
