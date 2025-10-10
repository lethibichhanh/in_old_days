import 'package:flutter/material.dart';
import '../db/db_helper.dart';

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
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final fullname = _fullnameController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    try {
      // 🔍 Kiểm tra xem email đã tồn tại chưa
      final exists = await DBHelper.rawQuery(
        "SELECT user_id FROM users WHERE email = ?",
        [email],
      );

      if (exists.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Email này đã được đăng ký")),
          );
        }
      } else {
        // ✅ Thêm người dùng mới (KHÔNG CHÈN user_id vì AUTOINCREMENT)
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
          const SnackBar(content: Text("🎉 Đăng ký thành công! Vui lòng đăng nhập.")),
        );

        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Lỗi đăng ký: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Đăng ký tài khoản"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
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
                  // Tên đăng nhập (không lưu trong DB)
                  TextFormField(
                    controller: _usernameController,
                    decoration: _buildInputDecoration(Icons.person, "Tên đăng nhập (Tùy chọn)"),
                  ),
                  const SizedBox(height: 16),

                  // Mật khẩu
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePwd,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự.';
                      }
                      return null;
                    },
                    decoration: _buildInputDecoration(Icons.lock, "Mật khẩu").copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePwd ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Họ và tên
                  TextFormField(
                    controller: _fullnameController,
                    decoration: _buildInputDecoration(Icons.badge, "Họ và tên (Tùy chọn)"),
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập Email.';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Email không hợp lệ.';
                      }
                      return null;
                    },
                    decoration: _buildInputDecoration(Icons.email, "Email"),
                  ),
                  const SizedBox(height: 30),

                  // Nút Đăng ký
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
                          : const Icon(Icons.app_registration, color: Colors.white),
                      label: const Text(
                        "Đăng ký",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Đã có tài khoản? Đăng nhập ngay!",
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
