// Trong lib/screens/update_password_screen.dart (code mới)
import 'dart:math';
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/user_model.dart';
import '../l10n/app_localizations.dart'; // ✅ THÊM IMPORT NGÔN NGỮ

// --- Khai báo màu sắc Pastel Tươi sáng (Đồng bộ) ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ


class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  UserModel? _user;
  int? _userIdFromArgs;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  String _passwordStrength = ""; // Sẽ được gán giá trị dịch trong build/checkStrength
  Color _strengthColor = Colors.red;

  late AppLocalizations tr; // Khai báo biến dịch

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    tr = AppLocalizations.of(context)!; // Khởi tạo biến dịch

    if (_user == null && _userIdFromArgs == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      debugPrint("📦 Arguments nhận được: $args");

      // 1. Lấy ID từ Arguments (Giữ nguyên logic tải ID)
      if (args is int) {
        _userIdFromArgs = args;
      } else if (args is UserModel) {
        _userIdFromArgs = args.id;
      } else if (args is Map<String, dynamic>) {
        _userIdFromArgs = args['userId'] is int ? args['userId'] : int.tryParse(args['userId']?.toString() ?? '');
      }

      // 2. Nếu có ID, tiến hành tải user từ DB
      if (_userIdFromArgs != null) {
        _loadUserById(_userIdFromArgs!);
      } else {
        // 3. Fallback
        debugPrint("❌ Không tìm thấy ID từ arguments, đang thử lấy từ DB...");
        _loadUserFromDatabase();
      }
    }
  }

  Future<void> _loadUserById(int id) async {
    final userNotFound = tr.translate('update_password_user_not_found');

    try {
      final user = await DBHelper.getUserById(id);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
        if (user != null) {
          debugPrint("✅ Đã nạp user theo ID: ${user.email}");
        } else {
          debugPrint("⚠️ Không tìm thấy user với ID: $id");
          _showSnackBar(userNotFound); // ✅ Dịch
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi tải user theo ID: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hàm Fallback (chỉ dùng khi không có ID)
  Future<void> _loadUserFromDatabase() async {
    final noLoggedInAccount = tr.translate('update_password_no_account');

    try {
      final users = await DBHelper.getAllUsers();
      if (mounted) {
        setState(() {
          _user = users.isNotEmpty ? users.first : null;
          _isLoading = false;
        });
        if (users.isNotEmpty) {
          debugPrint("✅ Đã nạp user từ DB (Fallback): ${_user!.email}");
        } else {
          debugPrint("⚠️ Không có người dùng nào trong DB!");
          _showSnackBar(noLoggedInAccount); // ✅ Dịch
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi tải user từ DB: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ================== 🔐 TẠO MẬT KHẨU NGẪU NHIÊN ==================
  void _generateRandomPassword() {
    final passwordGenerated = tr.translate('update_password_generated');

    const String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_-+=<>?';
    final rand = Random.secure();
    final password =
    List.generate(12, (index) => chars[rand.nextInt(chars.length)]).join();
    _newPasswordController.text = password;
    _confirmPasswordController.text = password;
    _checkPasswordStrength(password);
    _showSnackBar(passwordGenerated); // ✅ Dịch
  }

  // ================== 📊 KIỂM TRA ĐỘ MẠNH MẬT KHẨU ==================
  void _checkPasswordStrength(String password) {
    // Lấy chuỗi dịch cho độ mạnh
    final strengthWeak = tr.translate('password_strength_weak');
    final strengthMedium = tr.translate('password_strength_medium');
    final strengthStrong = tr.translate('password_strength_strong');

    int score = 0;

    if (password.length >= 6) score += 25;
    if (password.length >= 10) score += 25;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 15;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 15;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score += 20;

    if (score <= 30) {
      _passwordStrength = "$strengthWeak ($score/100)"; // ✅ Dịch
      _strengthColor = Colors.red;
    } else if (score <= 60) {
      _passwordStrength = "$strengthMedium ($score/100)"; // ✅ Dịch
      _strengthColor = Colors.orange;
    } else {
      _passwordStrength = "$strengthStrong ($score/100)"; // ✅ Dịch
      _strengthColor = Colors.green;
    }

    setState(() {});
  }

  // ================== 🧭 XỬ LÝ CẬP NHẬT MẬT KHẨU ==================
  Future<void> _updatePassword() async {
    // Lấy chuỗi dịch cho thông báo lỗi/thành công
    final userInvalid = tr.translate('update_password_user_invalid');
    final fillInfo = tr.translate('update_password_fill_info');
    final minLength = tr.translate('update_password_min_length');
    final notMatch = tr.translate('update_password_not_match');
    final wrongCurrentPass = tr.translate('update_password_wrong_current');
    final success = tr.translate('update_password_success');
    final noChange = tr.translate('update_password_no_change');
    final errorUpdate = tr.translate('update_password_error_update');


    if (_user == null || _user!.id == null) {
      _showSnackBar(userInvalid); // ✅ Dịch
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar(fillInfo); // ✅ Dịch
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar(minLength); // ✅ Dịch
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar(notMatch); // ✅ Dịch
      return;
    }

    // So sánh password hiện tại với hash trong DB
    final currentHash = _user!.passwordHash;
    if (currentHash.isEmpty || currentPassword != currentHash) {
      _showSnackBar(wrongCurrentPass); // ✅ Dịch
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedUser = _user!.copyWith(
        passwordHash: newPassword,
        updatedAt: DateTime.now().toIso8601String(),
      );

      final result = await DBHelper.updateUser(updatedUser);

      if (result > 0) {
        _showSnackBar(success); // ✅ Dịch
        Navigator.pop(context, updatedUser);
      } else {
        _showSnackBar(noChange); // ✅ Dịch
      }
    } catch (e) {
      debugPrint("❌ Lỗi cập nhật mật khẩu: $e");
      _showSnackBar('$errorUpdate: $e'); // ✅ Dịch
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Khởi động lại kiểm tra độ mạnh khi build để cập nhật ngôn ngữ
    if (_newPasswordController.text.isNotEmpty) {
      _checkPasswordStrength(_newPasswordController.text);
    } else if (!_isLoading) {
      // Thiết lập giá trị mặc định khi không loading và không có pass
      _passwordStrength = tr.translate('password_strength_very_weak'); // ✅ Dịch
      _strengthColor = Colors.red;
    }

    // ✅ KHAI BÁO CÁC CHUỖI DỊCH CHO UI
    final screenTitle = tr.translate('update_password_title');
    final loadingError = tr.translate('update_password_load_error'); // Khóa mới
    final changeSecurity = tr.translate('update_password_change_security');
    final labelCurrentPass = tr.translate('update_password_current_label');
    final labelNewPass = tr.translate('update_password_new_label');
    final labelConfirmPass = tr.translate('update_password_confirm_label');
    final strengthLabel = tr.translate('password_strength_label');
    final generatePassword = tr.translate('update_password_generate_button');
    final updateButton = tr.translate('update_password_update_button');


    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(screenTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), // ✅ Dịch
        backgroundColor: kAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _user == null
          ? Center(child: Text(loadingError)) // ✅ Dịch
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 8,
          color: kCardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: kPrimaryColor.withOpacity(0.3), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.lock_reset,
                    size: 80, color: kAppBarColor),
                const SizedBox(height: 16),
                Text(
                  changeSecurity, // ✅ Dịch
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: kTitleTextColor
                  ),
                ),
                const SizedBox(height: 24),

                // Mật khẩu hiện tại
                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: labelCurrentPass, // ✅ Dịch
                  icon: Icons.lock_outline,
                  isVisible: _isCurrentPasswordVisible,
                  onToggleVisibility: () {
                    setState(() => _isCurrentPasswordVisible =
                    !_isCurrentPasswordVisible);
                  },
                ),
                const SizedBox(height: 18),

                // Mật khẩu mới
                _buildPasswordField(
                  controller: _newPasswordController,
                  label: labelNewPass, // ✅ Dịch
                  icon: Icons.lock,
                  isVisible: _isNewPasswordVisible,
                  onToggleVisibility: () {
                    setState(() => _isNewPasswordVisible =
                    !_isNewPasswordVisible);
                  },
                  onChanged: _checkPasswordStrength,
                ),
                const SizedBox(height: 8),

                // Độ mạnh & Tạo mật khẩu
                Row(
                  children: [
                    Text('$strengthLabel:', // ✅ Dịch
                        style: TextStyle(color: kSubtextColor)),
                    const SizedBox(width: 8),
                    Text(
                      _passwordStrength, // Đã được dịch trong _checkPasswordStrength
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _strengthColor),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _generateRandomPassword,
                      icon: const Icon(Icons.refresh, color: kAppBarColor),
                      label: Text(generatePassword, style: TextStyle(color: kAppBarColor, fontWeight: FontWeight.w600)), // ✅ Dịch
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Xác nhận mật khẩu mới
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: labelConfirmPass, // ✅ Dịch
                  icon: Icons.check_circle_outline,
                  isVisible: _isConfirmPasswordVisible,
                  onToggleVisibility: () {
                    setState(() => _isConfirmPasswordVisible =
                    !_isConfirmPasswordVisible);
                  },
                ),
                const SizedBox(height: 30),

                // Nút Đổi Mật Khẩu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                    _isLoading ? null : _updatePassword,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.security_update, color: Colors.white),
                    label: Text(
                      updateButton, // ✅ Dịch
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Không cần FAB/Overlay nếu đã dùng _isLoading
    );
  }

  // Widget _buildPasswordField đã được tùy chỉnh
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      keyboardType: TextInputType.visiblePassword,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label, // ✅ Dịch label được truyền vào
        labelStyle: const TextStyle(color: kSubtextColor),
        prefixIcon: Icon(icon, color: kPrimaryColor),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: kPrimaryColor,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: kPrimaryColor.withOpacity(0.05),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kPrimaryColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAppBarColor, width: 2),
        ),
      ),
    );
  }
}