import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/seller_preferences.dart';
import '../core/theme.dart';
import 'asosiy_screen.dart';
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navItem(0, Icons.home_rounded, Strings.navAsosiy),
                    _navItem(1, Icons.shopping_cart_rounded, Strings.navMahsulotlar),
                    _navItem(2, Icons.qr_code_scanner_rounded, Strings.navSotuvlar),
                    _navItem(3, Icons.receipt_long_rounded, Strings.navTranzaksiyalar),
                    _navItem(4, Icons.grid_view_rounded, Strings.navMenu),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _builtTabs.add(index);
        _currentIndex = index;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
