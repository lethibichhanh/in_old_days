import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

// --- Khai báo màu sắc Pastel Tươi sáng (Đồng bộ) ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ

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

  // --- Hàm hỗ trợ Input Decoration (Đã thay đổi) ---
  InputDecoration _buildInputDecoration(IconData icon, String labelText, {Color? iconColor}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: kSubtextColor),
      prefixIcon: Icon(icon, color: iconColor ?? kPrimaryColor), // Icon màu Mint
      filled: true,
      fillColor: kPrimaryColor.withOpacity(0.05), // Nền field Pastel nhẹ
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kPrimaryColor.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kPrimaryColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAppBarColor, width: 2), // Viền focus màu Mint đậm
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccentColor, width: 2), // Lỗi dùng màu Coral
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccentColor, width: 2),
      ),
    );
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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(tr.translate('register_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kAppBarColor, // Màu Mint đậm
        foregroundColor: Colors.white,
        elevation: 0,
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
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Card(
            elevation: 6,
            color: kCardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              // Viền nhẹ đồng bộ
              side: BorderSide(color: kPrimaryColor.withOpacity(0.2), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    tr.translate('register_title'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: kAppBarColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Username
                  TextFormField(
                    controller: _usernameController,
                    decoration: _buildInputDecoration(
                        Icons.person_outline, tr.translate('username_optional')),
                  ),
                  const SizedBox(height: 16),

                  // Password
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
                      Icons.lock_outline,
                      tr.translate('password'),
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePwd ? Icons.visibility_off : Icons.visibility,
                          color: kPrimaryColor, // Icon ẩn/hiện màu Mint
                        ),
                        onPressed: () =>
                            setState(() => _obscurePwd = !_obscurePwd),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Fullname
                  TextFormField(
                    controller: _fullnameController,
                    decoration: _buildInputDecoration(
                        Icons.badge_outlined, tr.translate('fullname_optional')),
                  ),
                  const SizedBox(height: 16),

                  // Email
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
                    _buildInputDecoration(Icons.email_outlined, tr.translate('email')),
                  ),
                  const SizedBox(height: 30),

                  // Register button (Màu Coral)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: kAccentColor, // Hồng Đào
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
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
                        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Have an account
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      tr.translate('have_account'),
                      style: const TextStyle(color: kAppBarColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}