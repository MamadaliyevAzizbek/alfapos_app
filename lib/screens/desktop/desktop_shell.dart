import 'package:flutter/material.dart';
import '../../core/app_notify.dart';
import '../../core/seller_preferences.dart';
import '../../core/theme.dart';
import 'desktop_shell_scope.dart';
import 'asosiy_desktop_screen.dart';
import '../hisobotlar_screen.dart';
import '../kirimlar_screen.dart';
import '../katalog_screen.dart';
import '../mijozlar_screen.dart';
import '../savatcha_screen.dart';
import '../tranzaksiyalar_screen.dart';
import '../xarajatlar_screen.dart';
import 'sozlamalar_desktop_screen.dart';

/// Desktop: chap sidebar + asosiy kontent.
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
    'Mijozlar',
    'Mahsulotlar',
    "Sotuv bo'limi",
    'Kirimlar',
    'Xarajatlar',
    'Tranzaksiyalar',
    'Hisobotlar',
    'Sozlamalar',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => syncSellerNameFromApi());
  }

  void _go(int i) => setState(() {
        _built.add(i);
        _index = i;
      });

  Future<void> _onGlobalSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await DesktopShellSync.run(_index);
      if (!mounted) return;
      setState(() => _syncGeneration++);
      AppNotify.success(context, 'Ma\'lumotlar yangilandi');
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
        return const MijozlarScreen();
      case 2:
        return const KatalogScreen();
      case 3:
        return SavatchaScreen(
          isTabActive: _index == 3,
          onLogout: widget.onLogout,
          onNavigateToTransactions: () => _go(6),
        );
      case 4:
        return const KirimlarScreen();
      case 5:
        return const XarajatlarScreen();
      case 6:
        return TranzaksiyalarScreen(tabIndex: 6, currentIndex: _index);
      case 7:
        return const HisobotlarScreen();
      case 8:
        return const SozlamalarDesktopScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  static const int salesSectionIndex = 3;

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
                _DesktopTopBar(
                  title: _sectionTitles[_index],
                  syncing: _syncing,
                  onSync: _onGlobalSync,
                  showSectionMenu: _salesFullscreen,
                  onOpenSectionMenu: _openSectionMenu,
                ),
                Expanded(
                  child: DesktopShellScope(
                    syncGeneration: _syncGeneration,
                    syncing: _syncing,
                    child: IndexedStack(
                      index: _index,
                      children: List.generate(9, _page),
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
  final bool showSectionMenu;
  final VoidCallback? onOpenSectionMenu;

  const _DesktopTopBar({
    required this.title,
    required this.syncing,
    required this.onSync,
    this.showSectionMenu = false,
    this.onOpenSectionMenu,
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
              if (showSectionMenu && onOpenSectionMenu != null) ...[
                IconButton(
                  tooltip: 'Bo\'limlar',
                  onPressed: onOpenSectionMenu,
                  icon: const Icon(Icons.menu_rounded, size: 26),
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: 4),
              ],
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

  static const _bg = Color(0xFF1E293B);
  static const _activeBg = Color(0xFF334155);
  static const double width = 140;
  static const double _width = width;
  static const double _logoHeight = 76;
  static const double _iconSize = 30;
  static const double _labelSize = 12;

  /// Har bir bo'lim uchun ma'noga mos icon.
  static const _items = [
    (Icons.query_stats_rounded, 'Statistika'),
    (Icons.groups_rounded, 'Mijozlar'),
    (Icons.category_rounded, 'Mahsulotlar'),
    (Icons.point_of_sale_rounded, "Sotuv bo'limi"),
    (Icons.move_to_inbox_rounded, 'Kirimlar'),
    (Icons.account_balance_wallet_rounded, 'Xarajatlar'),
    (Icons.swap_horiz_rounded, 'Tranzaksiyalar'),
    (Icons.summarize_rounded, 'Hisobotlar'),
    (Icons.settings_rounded, 'Sozlamalar'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: SizedBox(
        width: _width,
        child: Column(
          children: [
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: _width - 16,
                height: _logoHeight,
                child: Image.asset(
                  'assets/branding/alfapos_sidebar_logo.png',
                  width: _width - 16,
                  height: _logoHeight,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/branding/alfapos_logo.png',
                    width: _width - 16,
                    height: _logoHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      'alfapos',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
            const SizedBox(height: 12),
          ],
        ),
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
        ? Colors.white
        : muted
            ? Colors.white54
            : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? _DesktopSidebar._activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? const Border(
                      left: BorderSide(color: AppTheme.primary, width: 3),
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: _DesktopSidebar._iconSize),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _DesktopSidebar._labelSize,
                    height: 1.25,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
