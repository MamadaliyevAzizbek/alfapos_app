import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/seller_preferences.dart';
import '../core/theme.dart';
import '../utils/platform_layout.dart';
import '../utils/pos_navigation.dart';
import 'asosiy_screen.dart';
import 'desktop/desktop_shell.dart';
import 'katalog_screen.dart';
import 'savatcha_screen.dart';
import 'tranzaksiyalar_screen.dart';
import 'menu_screen.dart';

bool get _navUsesBackdropBlur {
  if (kIsWeb) return false;
  return !Platform.isAndroid;
}

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
    PosNavigation.openSalesSection = () {
      if (!mounted) return;
      setState(() {
        _builtTabs.add(2);
        _currentIndex = 2;
      });
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => syncSellerNameFromApi());
  }

  @override
  void dispose() {
    if (PosNavigation.openSalesSection != null) {
      PosNavigation.openSalesSection = null;
    }
    super.dispose();
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

    // Android: 3-tugmali nav odatda ≥40dp; gesture/home indicator kichikroq.
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    final hasSystemNavButtons = systemBottom >= 40;
    // Uzum/iOS uslubi: juda ixcham — faqat minimal top, pastki = system inset.
    final navTopPad = iconOnlyNav ? 2.0 : 3.0;
    final navBottomPad = hasSystemNavButtons
        ? systemBottom + 2.0
        : (systemBottom > 0 ? systemBottom : 4.0);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(5, (i) => _builtTabs.contains(i) ? _screenAt(i) : const SizedBox.shrink()),
      ),
      bottomNavigationBar: ClipRect(
        child: _navUsesBackdropBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: _buildNavBar(navTopPad, navBottomPad, compactNav, iconOnlyNav, frosted: true),
              )
            : _buildNavBar(navTopPad, navBottomPad, compactNav, iconOnlyNav, frosted: false),
      ),
    );
  }

  Widget _buildNavBar(
    double navTopPad,
    double navBottomPad,
    bool compactNav,
    bool iconOnlyNav, {
    required bool frosted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: frosted ? 0.72 : 0.96),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: frosted ? 0.5 : 0.9),
            width: 1,
          ),
        ),
      ),
      // SafeArea o‘rniga aniq pastki inset — ortiqcha «ko‘tarilish» bo‘lmasin.
      padding: EdgeInsets.only(top: navTopPad, bottom: navBottomPad),
      child: Row(
        children: [
          Expanded(child: _navItem(0, Icons.home_rounded, Strings.navAsosiy, compactNav, iconOnlyNav)),
          Expanded(child: _navItem(1, Icons.shopping_cart_rounded, Strings.navMahsulotlar, compactNav, iconOnlyNav)),
          Expanded(child: _navItem(2, Icons.qr_code_scanner_rounded, Strings.navSotuvlar, compactNav, iconOnlyNav)),
          Expanded(child: _navItem(3, Icons.receipt_long_rounded, Strings.navTranzaksiyalar, compactNav, iconOnlyNav)),
          Expanded(child: _navItem(4, Icons.grid_view_rounded, Strings.navMenu, compactNav, iconOnlyNav)),
        ],
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
    final iconSize = iconOnly ? 24.0 : (compact ? 20.0 : 22.0);
    final fontSize = compact ? 9.0 : 10.0;

    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() {
          _builtTabs.add(index);
          _currentIndex = index;
        }),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 2 : 2, vertical: iconOnly ? 2 : 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              if (!iconOnly) ...[
                const SizedBox(height: 1),
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
                        height: 1.05,
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
