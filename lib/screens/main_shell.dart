import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/seller_preferences.dart';
import '../core/theme.dart';
import '../utils/platform_layout.dart';
import 'asosiy_screen.dart';
import 'desktop/desktop_shell.dart';
import 'katalog_screen.dart';
import 'savatcha_screen.dart';
import 'tranzaksiyalar_screen.dart';
import 'menu_screen.dart';

class MainShell extends StatefulWidget {
  final VoidCallback? onLogout;

  const MainShell({super.key, this.onLogout});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final Set<int> _builtTabs = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => syncSellerNameFromApi());
  }

  Widget _screenAt(int index) {
    switch (index) {
      case 0:
        return const AsosiyScreen();
      case 1:
        return const KatalogScreen();
      case 2:
        return const SavatchaScreen();
      case 3:
        return TranzaksiyalarScreen(tabIndex: 3, currentIndex: _currentIndex);
      case 4:
        return MenuScreen(onLogout: widget.onLogout);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktopPosLayout) {
      return DesktopShell(onLogout: widget.onLogout);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    // Kichik telefonlarda matn sig‘masligi uchun qisqa yorliq / faqat ikonka
    final compactNav = screenWidth < 400;
    final iconOnlyNav = screenWidth < 340;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(5, (i) => _builtTabs.contains(i) ? _screenAt(i) : const SizedBox.shrink()),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: iconOnlyNav ? 6 : 8),
                child: Row(
                  children: [
                    Expanded(child: _navItem(0, Icons.home_rounded, Strings.navAsosiy, compactNav, iconOnlyNav)),
                    Expanded(child: _navItem(1, Icons.shopping_cart_rounded, Strings.navMahsulotlar, compactNav, iconOnlyNav)),
                    Expanded(child: _navItem(2, Icons.qr_code_scanner_rounded, Strings.navSotuvlar, compactNav, iconOnlyNav)),
                    Expanded(child: _navItem(3, Icons.receipt_long_rounded, Strings.navTranzaksiyalar, compactNav, iconOnlyNav)),
                    Expanded(child: _navItem(4, Icons.grid_view_rounded, Strings.navMenu, compactNav, iconOnlyNav)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _navLabel(String label, bool compact) {
    if (!compact) return label;
    switch (label) {
      case Strings.navMahsulotlar:
        return 'Mahsulot';
      case Strings.navTranzaksiyalar:
        return 'Tranzaks.';
      default:
        return label;
    }
  }

  Widget _navItem(int index, IconData icon, String label, bool compact, bool iconOnly) {
    final selected = _currentIndex == index;
    final displayLabel = _navLabel(label, compact);
    final iconSize = iconOnly ? 26.0 : (compact ? 22.0 : 24.0);
    final fontSize = compact ? 9.0 : 11.0;

    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() {
          _builtTabs.add(index);
          _currentIndex = index;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 2 : 4, vertical: iconOnly ? 6 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              if (!iconOnly) ...[
                const SizedBox(height: 3),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      displayLabel,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: selected ? AppTheme.primary : AppTheme.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
