import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../core/app_notify.dart';
import '../../core/seller_preferences.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../services/app_data_sync.dart';
import '../../widgets/auth_network_image.dart';
import '../../utils/pos_navigation.dart';
import 'desktop_shell_scope.dart';
import 'asosiy_desktop_screen.dart';
import '../savatcha_screen.dart';
import '../tranzaksiyalar_screen.dart';
import '../xarajatlar_screen.dart';
import 'sozlamalar_desktop_screen.dart';

/// Desktop: chap sidebar + asosiy kontent.
/// Faqat sotuv uchun: Statistika, Sotuv, Xarajatlar, Tranzaksiyalar, Sozlamalar.
/// Mijozlar / Mahsulotlar / Kirimlar / Hisobotlar — web orqali.
class DesktopShell extends StatefulWidget {
  final VoidCallback? onLogout;

  const DesktopShell({super.key, this.onLogout});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _index = 0;
  final Set<int> _built = {0};
  int _syncGeneration = 0;
  bool _syncing = false;

  static const _sectionTitles = [
    'Statistika',
    "Sotuv bo'limi",
    'Xarajatlar',
    'Tranzaksiyalar',
    'Sozlamalar',
  ];

  static const int salesSectionIndex = 1;
  static const int transactionsSectionIndex = 3;
  static const int _sectionCount = 5;

  @override
  void initState() {
    super.initState();
    PosNavigation.openSalesSection = () => _go(salesSectionIndex);
    PosNavigation.openTransactionsSection = () => _go(transactionsSectionIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => syncSellerNameFromApi());
  }

  @override
  void dispose() {
    if (PosNavigation.openSalesSection != null) {
      PosNavigation.openSalesSection = null;
    }
    if (PosNavigation.openTransactionsSection != null) {
      PosNavigation.openTransactionsSection = null;
    }
    super.dispose();
  }

  void _go(int i) => setState(() {
        _built.add(i);
        _index = i;
      });

  Future<void> _onGlobalSync() async {
    if (_syncing || AppDataSync.isRunning) return;
    setState(() => _syncing = true);
    try {
      await AppDataSync.syncAll(force: true);
      if (!mounted) return;
      setState(() => _syncGeneration++);
      AppNotify.success(context, 'Ma\'lumotlar sinxronlandi');
    } catch (e) {
      if (mounted) AppNotify.error(context, 'Sinxronlash xatosi: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Widget _page(int i) {
    if (!_built.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return const AsosiyDesktopScreen();
      case 1:
        return SavatchaScreen(
          isTabActive: _index == salesSectionIndex,
          onLogout: widget.onLogout,
          onOpenSectionMenu: _openSectionMenu,
          onGlobalSync: _onGlobalSync,
        );
      case 2:
        return const XarajatlarScreen();
      case 3:
        return TranzaksiyalarScreen(
          tabIndex: transactionsSectionIndex,
          currentIndex: _index,
          filterByCurrentEmployee: true,
        );
      case 4:
        return const SozlamalarDesktopScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  bool get _salesFullscreen => _index == salesSectionIndex;

  void _openSectionMenu() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Bo\'limlar',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) {
        return Align(
          alignment: Alignment.centerLeft,
          child: _DesktopSidebar(
            selectedIndex: _index,
            onSelect: (i) {
              Navigator.of(dialogContext).pop();
              _go(i);
            },
            onLogout: widget.onLogout,
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: _salesFullscreen ? 0 : _DesktopSidebar.width,
              child: _salesFullscreen
                  ? const SizedBox.shrink()
                  : _DesktopSidebar(
                      selectedIndex: _index,
                      onSelect: _go,
                      onLogout: widget.onLogout,
                    ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_salesFullscreen)
                  _DesktopTopBar(
                    title: _sectionTitles[_index],
                    syncing: _syncing,
                    onSync: _onGlobalSync,
                  ),
                Expanded(
                  child: DesktopShellScope(
                    syncGeneration: _syncGeneration,
                    syncing: _syncing,
                    child: IndexedStack(
                      index: _index,
                      children: List.generate(_sectionCount, _page),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  final String title;
  final bool syncing;
  final VoidCallback onSync;

  const _DesktopTopBar({
    required this.title,
    required this.syncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppTheme.divider)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: syncing ? null : onSync,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                icon: syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                      )
                    : const Icon(Icons.sync_rounded, size: 22),
                label: const Text('Sinxronlash'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback? onLogout;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.onSelect,
    this.onLogout,
  });

  static const _bg = Color(0xFF132238);
  static const _activeBg = Color(0xFF1E293B);
  static const double width = 268;
  static const double _width = width;
  static const double _logoHeight = 78;
  static const double _iconSize = 20;
  static const double _labelSize = 15;

  /// Lucide — yupqa stroke, professional sidebar iconlari.
  /// Sotuv POS: faqat kerakli bo‘limlar (qolganlari webda).
  static const _items = [
    (LucideIcons.layout_dashboard, 'Statistika'),
    (LucideIcons.shopping_cart, "Sotuv bo'limi"),
    (LucideIcons.wallet, 'Xarajatlar'),
    (LucideIcons.arrow_left_right, 'Tranzaksiyalar'),
    (LucideIcons.settings, 'Sozlamalar'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: SizedBox(
        width: _width,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Container(
                height: 88,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2C46),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF314967)),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: SizedBox(
                      height: _logoHeight + 4,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _SidebarBrandingLogo(height: _logoHeight + 4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Divider(color: Color(0x2AFFFFFF), height: 1),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'BO‘LIMLAR',
                    style: TextStyle(
                      color: Color(0xFFA8B7CC),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final item = _items[i];
                  final selected = selectedIndex == i;
                  return _SidebarTile(
                    icon: item.$1,
                    label: item.$2,
                    selected: selected,
                    onTap: () => onSelect(i),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Divider(color: Color(0x335A6D88), height: 1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2C46),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF314967)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sistema faol',
                          style: TextStyle(
                            color: Color(0xFFD7E1F0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarBrandingLogo extends StatefulWidget {
  final double height;

  const _SidebarBrandingLogo({required this.height});

  @override
  State<_SidebarBrandingLogo> createState() => _SidebarBrandingLogoState();
}

class _SidebarBrandingLogoState extends State<_SidebarBrandingLogo> {
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    try {
      final res = await BrandingApi.getBranding();
      final url = BrandingApi.logoUrlFromResponse(res);
      if (url != null && mounted) setState(() => _logoUrl = url);
    } catch (_) {}
  }

  Widget _fallbackText() {
    return const Center(
      child: Text(
        'alfapos',
        style: TextStyle(
          color: Color(0xFFE2E8F0),
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
      ),
    );
  }

  Widget _assetFallback() {
    return Image.asset(
      'Untitled-1-01.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) => _fallbackText(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _logoUrl;
    if (url == null) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _assetFallback(),
      );
    }
    return AuthNetworkImage(
      url: url,
      height: widget.height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _assetFallback(),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool muted;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? const Color(0xFFEAF1FF)
        : muted
            ? const Color(0xFF7185A3)
            : const Color(0xFFC2CFE2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? _DesktopSidebar._activeBg : const Color(0xFF1A2D48),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? const Color(0xFF5F7EA8) : const Color(0xFF365276),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(
                    icon,
                    color: fg,
                    size: _DesktopSidebar._iconSize,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _DesktopSidebar._labelSize,
                      height: 1.25,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    LucideIcons.chevron_right,
                    color: const Color(0xFF9FB6D9),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
