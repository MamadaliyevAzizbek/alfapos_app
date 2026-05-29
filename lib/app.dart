import 'package:flutter/material.dart';
import 'core/app_navigator.dart';
import 'core/theme.dart';
import 'core/auth_storage.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'widgets/connectivity_blocker.dart';

class AlfaposApp extends StatefulWidget {
  const AlfaposApp({super.key});

  @override
  State<AlfaposApp> createState() => _AlfaposAppState();
}

class _AlfaposAppState extends State<AlfaposApp> {
  bool _checked = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoggedIn();
  }

  Future<void> _checkLoggedIn() async {
    const timeout = Duration(seconds: 2);
    try {
      final loggedIn = await isLoggedIn().timeout(timeout);
      if (mounted) {
        setState(() {
          _checked = true;
          _isLoggedIn = loggedIn;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checked = true;
          _isLoggedIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'ALFAPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => ConnectivityBlocker(
        child: child ?? const SizedBox.shrink(),
      ),
      home: !_checked
          ? Scaffold(
              backgroundColor: AppTheme.surface,
              body: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Yuklanmoqda...',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _isLoggedIn
              ? MainShell(
                  onLogout: () async {
                    setState(() => _isLoggedIn = false);
                  },
                )
              : LoginScreen(
                  onLoginSuccess: () => setState(() => _isLoggedIn = true),
                ),
    );
  }
}
