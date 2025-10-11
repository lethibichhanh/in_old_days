import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/user_model.dart';

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

  // 🔹 Chuyển ngôn ngữ (fix cú pháp switch expression)
  void _changeLanguage(AppLanguage newLanguage) {
    String code = 'en'; // Mặc định tiếng Anh

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
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context);

    if (tr == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr.translate('language')),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            icon: const Icon(Icons.language, color: Colors.white),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor:
                      theme.colorScheme.primary.withOpacity(0.15),
                      child: Icon(
                        Icons.lock_outline,
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tr.translate('welcome'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        labelText: tr.translate('email'),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePwd,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        labelText: tr.translate('password'),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePwd
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePwd = !_obscurePwd),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          tr.translate('login_button'),
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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
                        style: const TextStyle(color: Colors.grey),
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
                        const TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
