import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/auth_storage.dart';
import '../core/session_reset.dart';
import '../core/seller_preferences.dart';
import '../core/api_client.dart';
import '../core/api_http.dart';
import '../core/desktop_runtime.dart';
import '../services/api_service.dart';
import '../utils/platform_layout.dart';
import '../widgets/liquid_glass.dart';

const String _keyCompanyId = 'alfapos_login_companyId';
const String _keyLogin = 'alfapos_login_login';
const String _keyPassword = 'alfapos_login_password';
const String _keyLoggedIn = 'alfapos_logged_in';

/// API: `token`, `data.token`, `success.token`
String? _extractToken(Map<String, dynamic> res) {
  final direct = res['token'];
  if (direct is String && direct.isNotEmpty) return direct;
  final data = res['data'];
  if (data is Map) {
    final t = data['token'];
    if (t is String && t.isNotEmpty) return t;
  }
  final success = res['success'];
  if (success is Map) {
    final t = success['token'];
    if (t is String && t.isNotEmpty) return t;
  }
  return null;
}

class LoginScreen extends StatefulWidget {
  /// Login muvaffaqiyatli bo'lganda chaqiriladi — dastur asosiy oynaga o'tadi (avtomatik kirish davom etadi).
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyIdController = TextEditingController();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString(_keyCompanyId);
    final login = prefs.getString(_keyLogin);
    final password = prefs.getString(_keyPassword);
    if (companyId != null) _companyIdController.text = companyId;
    if (login != null) _loginController.text = login;
    if (password != null) _passwordController.text = password;
    if (mounted) setState(() {});
  }

  Future<void> _saveLoginData(String companyId, String login, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCompanyId, companyId);
    await prefs.setString(_keyLogin, login);
    await prefs.setString(_keyPassword, password);
    await prefs.setBool(_keyLoggedIn, true);
  }

  @override
  void dispose() {
    _companyIdController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final companyId = _companyIdController.text.trim();
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (companyId.isEmpty || login.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = Strings.kompaniyaIdKiriting;
        if (login.isEmpty) _errorMessage = Strings.loginniKiriting;
        if (password.isEmpty) _errorMessage = Strings.parolniKiriting;
        _isLoading = false;
      });
      return;
    }

    try {
      if (Platform.isWindows) {
        final reachErr = await ApiHttp.reachabilityDetail();
        if (reachErr != null && mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Serverga ulanib bo\'lmadi.\n\n${windowsNetworkHelpText(detail: reachErr)}';
          });
          return;
        }
      }

      final res = await AuthApi.login(login, password, companyId);
      String? token = _extractToken(res);
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = Strings.loginYokiParolNotogri;
          });
        }
        return;
      }
      await resetAppSessionForAccountChange();
      await saveAuth(token: token, companyId: companyId, email: login);
      await _saveLoginData(companyId, login, password);
      await syncSellerNameFromApi(force: true);
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onLoginSuccess?.call();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } on SocketException catch (e) {
      ApiHttp.resetClient();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = Platform.isWindows
              ? windowsNetworkHelpText(detail: e.message)
              : 'Serverga ulanib bo\'lmadi. Internet yoki firewall sozlamalarini tekshiring.\n(${e.message})';
        });
      }
    } on HandshakeException catch (e) {
      ApiHttp.resetClient();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = Platform.isWindows
              ? '${windowsNetworkHelpText(detail: e.message)}\n\nSSL / sertifikat xatosi.'
              : 'Xavfsiz ulanish (SSL) xatosi. Internetni tekshiring.';
        });
      }
    } on TlsException catch (e) {
      ApiHttp.resetClient();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = Platform.isWindows
              ? windowsNetworkHelpText(detail: e.message)
              : 'Xavfsiz ulanish (SSL) xatosi. Internetni tekshiring.';
        });
      }
    } on http.ClientException catch (e) {
      ApiHttp.resetClient();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = Platform.isWindows
              ? windowsNetworkHelpText(detail: e.message)
              : 'Tarmoq xatosi: ${e.message}';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server javob bermadi (vaqt tugadi). Keyinroq qayta urinib ko\'ring.';
        });
      }
    } on FormatException catch (e) {
      ApiHttp.resetClient();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = Platform.isWindows
              ? 'Server JSON emas javob qaytardi. Windows proksi / antivirus (HTTPS scanning) / VPN ni o‘chirib qayta urinib ko‘ring.\n(${e.message})'
              : 'Server noto‘g‘ri javob qaytardi. API manzilini yoki proksini tekshiring.\n(${e.message})';
        });
      }
    } catch (e, st) {
      ApiHttp.resetClient();
      if (kDebugMode) {
        debugPrint('[Login] $e\n$st');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = Platform.isWindows
              ? windowsNetworkHelpText(detail: e.toString())
              : (kDebugMode ? 'Tarmoq xatosi: $e' : 'Tarmoq xatosi. Internetni tekshiring.');
        });
      }
    }
  }

  InputDecoration _desktopFieldDecoration({
    required String label,
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      labelStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(fontSize: 14, color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton({double height = 52}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(Strings.kirish),
      ),
    );
  }

  Widget _buildDesktopLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 280,
              height: 64,
              child: ClipRect(
                child: Image.asset(
                  'Untitled-1-03.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const Text(
                    'alfapos',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          TextFormField(
            controller: _companyIdController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: _desktopFieldDecoration(
              label: 'Tashkilot ID',
              hint: 'Tashkilot ID kiriting',
            ),
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _loginController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: _desktopFieldDecoration(
              label: 'Login kiriting',
              hint: 'E-pochta kiriting',
            ),
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            onFieldSubmitted: (_) => _submit(),
            decoration: _desktopFieldDecoration(
              label: 'Parol kiriting',
              hint: '••••••••',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          _buildErrorBanner(),
          const SizedBox(height: 8),
          _buildSubmitButton(height: 58),
        ],
      ),
    );
  }

  Widget _buildDesktopLogin() {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Image.asset(
              'Untitled-3-01.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1E3A8A),
                child: const Center(
                  child: Icon(Icons.storefront_rounded, size: 120, color: Colors.white54),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 550,
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 462),
                    child: _buildDesktopLoginForm(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLogin() {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 220,
                              height: 52,
                              child: ClipRect(
                                child: Image.asset(
                                  'Untitled-1-03.png',
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  errorBuilder: (_, __, ___) => const Text(
                                    'alfapos',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Tizimga kirish",
                              style: TextStyle(
                                fontSize: 15,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      LiquidGlass(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              Strings.kirish,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _companyIdController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: Strings.kompaniyaId,
                                hintText: '1',
                                prefixIcon: Icon(
                                  Icons.business_rounded,
                                  color: AppTheme.primary,
                                ),
                              ),
                              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _loginController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: Strings.login,
                                hintText: 'admin',
                                prefixIcon: Icon(
                                  Icons.person_rounded,
                                  color: AppTheme.primary,
                                ),
                              ),
                              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: Strings.parol,
                                hintText: '••••••',
                                prefixIcon: const Icon(
                                  Icons.lock_rounded,
                                  color: AppTheme.primary,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    color: AppTheme.textSecondary,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              _buildErrorBanner(),
                            ],
                            const SizedBox(height: 28),
                            _buildSubmitButton(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktopPosLayout) {
      return _buildDesktopLogin();
    }
    return _buildMobileLogin();
  }
}
