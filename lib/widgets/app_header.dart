import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;

  const AppHeader({
    super.key,
    required this.title,
    this.actions,
    this.showLogo = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: showLogo
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Z',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(Strings.appName),
              ],
            )
          : Text(title),
      actions: [
        if (actions != null) ...actions!,
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          color: AppTheme.primary,
          onPressed: () {},
        ),
        IconButton(
          icon: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.amber.shade200,
            child: const Icon(Icons.person_rounded, color: Colors.black87),
          ),
          onPressed: () {},
        ),
      ],
    );
  }
}
