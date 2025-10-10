import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _newPassword; // hiển thị mật khẩu mới (nếu reset thành công)

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Vui lòng nhập email")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final exists = await DBHelper.checkUserExists(email);
      if (!exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Không tìm thấy tài khoản với email này.")),
        );
        setState(() => _loading = false);
        return;
      }

      final newPass = await DBHelper.resetPassword(email);
      setState(() => _newPassword = newPass);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Mật khẩu đã được đặt lại!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quên mật khẩu")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              "Nhập email bạn đã dùng để đăng ký. Ứng dụng sẽ tạo mật khẩu mới cho bạn.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _resetPassword,
                icon: const Icon(Icons.refresh),
                label: _loading
                    ? const Text("Đang xử lý...")
                    : const Text("Đặt lại mật khẩu"),
              ),
            ),

            const SizedBox(height: 30),

            if (_newPassword != null) ...[
              const Text(
                "🔑 Mật khẩu mới của bạn là:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _newPassword!,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "(Hãy ghi lại mật khẩu này và đăng nhập lại bằng tài khoản của bạn)",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
