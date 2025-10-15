// lib/screens/forgot_password_screen.dart

import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../l10n/app_localizations.dart'; // ✅ THÊM IMPORT NGÔN NGỮ

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _newPassword; // hiển thị mật khẩu mới (nếu reset thành công)

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final tr = AppLocalizations.of(context)!;

    // Khai báo chuỗi dịch cho thông báo lỗi/thành công
    final pleaseEnterEmail = tr.translate('forgot_please_enter_email');
    final accountNotFound = tr.translate('forgot_account_not_found');
    final passwordResetSuccess = tr.translate('forgot_password_reset_success');
    final errorPrefix = tr.translate('error_prefix'); // Sử dụng khóa chung nếu có

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pleaseEnterEmail)), // ✅ Dịch
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final exists = await DBHelper.checkUserExists(email);
      if (!exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accountNotFound)), // ✅ Dịch
        );
        setState(() => _loading = false);
        return;
      }

      final newPass = await DBHelper.resetPassword(email);
      setState(() => _newPassword = newPass);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(passwordResetSuccess)), // ✅ Dịch
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorPrefix: $e')), // ✅ Dịch tiền tố lỗi
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    // ✅ KHAI BÁO CÁC CHUỖI DỊCH CHO UI
    final screenTitle = tr.translate('forgot_screen_title');
    final instructionText = tr.translate('forgot_instruction_text');
    final emailLabel = tr.translate('email_label'); // Khóa chung
    final loadingText = tr.translate('loading_text'); // Khóa chung
    final resetPasswordButton = tr.translate('forgot_reset_password_button');
    final newPasswordTitle = tr.translate('forgot_new_password_title');
    final newPasswordHint = tr.translate('forgot_new_password_hint');


    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)), // ✅ Dịch
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              instructionText, // ✅ Dịch
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: emailLabel, // ✅ Dịch
                prefixIcon: const Icon(Icons.email_outlined),
                border: const OutlineInputBorder(),
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
                    ? Text(loadingText) // ✅ Dịch: "Đang xử lý..."
                    : Text(resetPasswordButton), // ✅ Dịch: "Đặt lại mật khẩu"
              ),
            ),

            const SizedBox(height: 30),

            if (_newPassword != null) ...[
              Text(
                newPasswordTitle, // ✅ Dịch: "🔑 Mật khẩu mới của bạn là:"
                style: const TextStyle(fontWeight: FontWeight.bold),
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
              Text(
                newPasswordHint, // ✅ Dịch: "(Hãy ghi lại mật khẩu này...)"
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}