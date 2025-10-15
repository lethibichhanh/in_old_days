import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/user_model.dart';

// --- Khai báo màu sắc Pastel Tươi sáng (Đồng bộ với HomeScreen) ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ

enum AppLanguage { vi, en, zh }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePwd = true;
  bool _isLoading = false;

  String _getText(String key) {
    return AppLocalizations.of(context)?.translate(key) ?? key;
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getText('snack_empty'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userMap = await DBHelper.authenticateUser(email, password);

      if (userMap != null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getText('snack_success'))),
        );

        Navigator.pushReplacementNamed(
          context,
          '/home',
          arguments: {'user': userMap},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getText('snack_error_auth'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${_getText('snack_error_general')} $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔹 Chuyển ngôn ngữ
  void _changeLanguage(AppLanguage newLanguage) {
    String code = 'en';

    switch (newLanguage) {
      case AppLanguage.vi:
        code = 'vi';
        break;
      case AppLanguage.en:
        code = 'en';
        break;
      case AppLanguage.zh:
        code = 'zh';
        break;
    }

    InOldDaysApp.setLocale(context, Locale(code));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);

    if (tr == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // Nền chính sử dụng màu Pastel
      backgroundColor: kBackgroundColor,

      // AppBar trong suốt
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Điều chỉnh màu icon cho nền sáng
        iconTheme: const IconThemeData(color: kTitleTextColor),
        actions: [
          PopupMenuButton<AppLanguage>(
            onSelected: _changeLanguage,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: AppLanguage.vi,
                child: Text('🇻🇳 Tiếng Việt'),
              ),
              PopupMenuItem(
                value: AppLanguage.en,
                child: Text('🇺🇸 English'),
              ),
              PopupMenuItem(
                value: AppLanguage.zh,
                child: Text('🇨🇳 中文'),
              ),
            ],
            // Điều chỉnh màu icon cho nền sáng
            icon: const Icon(Icons.language, color: kAppBarColor),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            // Card màu trắng, bo góc lớn
            color: kCardColor,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              // Thêm viền nhẹ đồng bộ
              side: BorderSide(color: kPrimaryColor.withOpacity(0.2), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  // Icon Lớn (Sử dụng màu Mint)
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: kPrimaryColor.withOpacity(0.15),
                    child: const Icon(
                      Icons.history_edu_outlined, // Đổi icon cho liên quan hơn
                      size: 55,
                      color: kPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    tr.translate('welcome'),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: kTitleTextColor,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Email Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email_outlined, color: kPrimaryColor),
                      labelText: tr.translate('email'),
                      labelStyle: const TextStyle(color: kSubtextColor),
                      filled: true,
                      fillColor: kPrimaryColor.withOpacity(0.05), // Nền field Pastel
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePwd,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, color: kPrimaryColor),
                      labelText: tr.translate('password'),
                      labelStyle: const TextStyle(color: kSubtextColor),
                      filled: true,
                      fillColor: kPrimaryColor.withOpacity(0.05), // Nền field Pastel
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kPrimaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePwd ? Icons.visibility_off : Icons.visibility,
                          color: kPrimaryColor,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePwd = !_obscurePwd),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Login button (Màu Coral)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor, // Hồng Đào
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : Text(
                        tr.translate('login_button'),
                        style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Forgot password
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                            Text(tr.translate('snack_forgot_dev'))),
                      );
                    },
                    child: Text(
                      tr.translate('forgot_password'),
                      style: TextStyle(color: kSubtextColor, fontWeight: FontWeight.w600),
                    ),
                  ),

                  // Register
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: Text(
                      tr.translate('no_account'),
                      style:
                      const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}