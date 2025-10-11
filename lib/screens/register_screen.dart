import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _obscurePwd = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final tr = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final fullname = _fullnameController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    try {
      // 🔍 Kiểm tra email đã tồn tại
      final exists = await DBHelper.rawQuery(
        "SELECT user_id FROM users WHERE email = ?",
        [email],
      );

      if (exists.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr.translate('error_email_exists'))),
          );
        }
      } else {
        // ✅ Thêm người dùng mới
        await DBHelper.insert("users", {
          "email": email,
          "password_hash": password,
          "full_name": fullname,
          "avatar_url": null,
          "role": "user",
          "created_at": DateTime.now().toIso8601String(),
          "updated_at": DateTime.now().toIso8601String(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.translate('register_success'))),
        );

        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${tr.translate('register_error')}: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: Text(tr.translate('register_title')),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<Locale>(
            onSelected: (locale) {
              InOldDaysApp.setLocale(context, locale);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: Locale('vi'),
                child: Text('🇻🇳 Tiếng Việt'),
              ),
              PopupMenuItem(
                value: Locale('en'),
                child: Text('🇺🇸 English'),
              ),
              PopupMenuItem(
                value: Locale('zh'),
                child: Text('🇨🇳 中文'),
              ),
            ],
            icon: const Icon(Icons.language, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _usernameController,
                    decoration: _buildInputDecoration(
                        Icons.person, tr.translate('username_optional')),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePwd,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 6) {
                        return tr.translate('password_min_length');
                      }
                      return null;
                    },
                    decoration: _buildInputDecoration(
                      Icons.lock,
                      tr.translate('password'),
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePwd
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePwd = !_obscurePwd),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _fullnameController,
                    decoration: _buildInputDecoration(
                        Icons.badge, tr.translate('fullname_optional')),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return tr.translate('email_required');
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return tr.translate('email_invalid');
                      }
                      return null;
                    },
                    decoration:
                    _buildInputDecoration(Icons.email, tr.translate('email')),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.app_registration,
                          color: Colors.white),
                      label: Text(
                        tr.translate('register_button'),
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      tr.translate('have_account'),
                      style: TextStyle(color: theme.colorScheme.secondary),
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

  InputDecoration _buildInputDecoration(IconData icon, String labelText) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: Colors.brown),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.brown.shade400, width: 2),
      ),
    );
  }
}
