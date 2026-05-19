import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/auth_storage.dart';
import '../core/seller_preferences.dart';
import '../core/api_client.dart';
import '../core/api_http.dart';
import '../core/desktop_runtime.dart';
import '../services/api_service.dart';
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
        if (mounted) setState(() {
          _isLoading = false;
          _errorMessage = Strings.loginYokiParolNotogri;
        });
        return;
      }
      await saveAuth(token: token, companyId: companyId, email: login);
      await _saveLoginData(companyId, login, password);
      await syncSellerNameFromApi(force: true);
      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onLoginSuccess?.call();
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } on SocketException catch (e) {
      ApiHttp.resetClient();
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = Platform.isWindows
            ? windowsNetworkHelpText(detail: e.message)
            : 'Serverga ulanib bo\'lmadi. Internet yoki firewall sozlamalarini tekshiring.\n(${e.message})';
      });
    } on HandshakeException catch (e) {
      ApiHttp.resetClient();
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = Platform.isWindows
            ? '${windowsNetworkHelpText(detail: e.message)}\n\nSSL / sertifikat xatosi.'
            : 'Xavfsiz ulanish (SSL) xatosi. Internetni tekshiring.';
      });
    } on TlsException catch (e) {
      ApiHttp.resetClient();
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = Platform.isWindows
            ? windowsNetworkHelpText(detail: e.message)
            : 'Xavfsiz ulanish (SSL) xatosi. Internetni tekshiring.';
      });
    } on http.ClientException catch (e) {
      ApiHttp.resetClient();
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = Platform.isWindows
            ? windowsNetworkHelpText(detail: e.message)
            : 'Tarmoq xatosi: ${e.message}';
      });
    } on TimeoutException {
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = 'Server javob bermadi (vaqt tugadi). Keyinroq qayta urinib ko\'ring.';
      });
    } on FormatException catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = 'Server noto‘g‘ri javob qaytardi. API manzilini yoki proksini tekshiring.\n(${e.message})';
      });
    } catch (e, st) {
      ApiHttp.resetClient();
      if (kDebugMode) {
        debugPrint('[Login] $e\n$st');
      }
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = Platform.isWindows
            ? windowsNetworkHelpText(detail: e.toString())
            : (kDebugMode
                ? 'Tarmoq xatosi: $e'
                : 'Tarmoq xatosi. Internetni tekshiring.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            const Text(
                              Strings.appName,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
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
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
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
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
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
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.red.shade200, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(Strings.kirish),
                        ),
                      ),
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
}
