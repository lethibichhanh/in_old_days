import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/user_model.dart';
// import 'password_strength_generator.dart'; // (Nếu bạn có thêm tính năng này)

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  UserModel? _user;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // LƯU Ý: Argument được truyền vào là Map<String, dynamic>
    // và chứa 'user' là một UserModel object (từ UpdateProfileScreen).
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // Kiểm tra và gán UserModel object
    if (args != null && args['user'] is UserModel) {
      _user = args['user'] as UserModel;
    }
    // KHÔNG cần dùng UserModel.fromMapArguments vì bạn đã truyền object UserModel.
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// 🔹 Hàm cập nhật mật khẩu
  Future<void> _updatePassword() async {
    // Đảm bảo user và id tồn tại
    if (_user == null || _user!.id == null) {
      _showSnackBar("❌ Thông tin người dùng không hợp lệ.");
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 1. Kiểm tra rỗng và độ dài
    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar("⚠️ Vui lòng nhập đầy đủ 3 trường mật khẩu.");
      return;
    }
    if (newPassword.length < 6) {
      _showSnackBar("❌ Mật khẩu mới phải có ít nhất 6 ký tự.");
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar("❌ Mật khẩu mới và Xác nhận mật khẩu không khớp.");
      return;
    }

    // 2. Kiểm tra mật khẩu hiện tại có đúng không
    // 💡 KHẮC PHỤC LỖI: Sử dụng trường passwordHash.
    // LƯU Ý QUAN TRỌNG: Đây là so sánh **PlainText** với **Hash**.
    // Trong ứng dụng thực tế, bạn PHẢI HASH 'currentPassword'
    // và so sánh chuỗi hash đó với '_user!.passwordHash'.
    if (currentPassword != _user!.passwordHash) {
      // Giả định đơn giản: nếu _user!.passwordHash là chuỗi đã được hash,
      // thì so sánh này sẽ LUÔN SAI trừ khi bạn hash 'currentPassword' trước.
      // Dùng logic sau để so sánh hash bảo mật:
      // if (!await Hasher.verify(currentPassword, _user!.passwordHash))

      // Tạm thời, tôi giữ logic đơn giản để tránh lỗi biên dịch:
      if (currentPassword != _user!.passwordHash) {
        _showSnackBar("❌ Mật khẩu hiện tại không đúng.");
        return;
      }
    }


    setState(() => _isLoading = true);

    try {
      // ✅ Hash mật khẩu mới trước khi lưu vào DB!
      // Giả định bạn có một hàm hash. Ví dụ: String hashedNewPassword = await Hasher.hash(newPassword);
      String hashedNewPassword = newPassword; // ⚠️ Thay bằng Hashing thực tế!

      // ✅ Tạo đối tượng mới với HASH mật khẩu đã cập nhật
      final updatedUser = _user!.copyWith(
        passwordHash: hashedNewPassword, // ✅ Dùng đúng tên trường 'passwordHash'
      );

      // ✅ Cập nhật DB
      final rows = await DBHelper.updateUser(updatedUser);

      if (rows > 0) {
        if (mounted) {
          _showSnackBar("✅ Đổi mật khẩu thành công!");
          // 👉 Trả UserModel mới về ProfileScreen
          Navigator.pop(context, updatedUser);
        }
      } else {
        _showSnackBar("⚠️ Không có thay đổi nào được lưu.");
      }
    } catch (e) {
      debugPrint("❌ Lỗi cập nhật mật khẩu: $e");
      _showSnackBar("❌ Lỗi cập nhật: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text("❌ Không tìm thấy thông tin người dùng.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Đổi mật khẩu"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D83F2), Color(0xFF8EC5FC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.lock_reset, size: 80, color: Colors.indigo),
                    const SizedBox(height: 24),

                    // Mật khẩu hiện tại
                    _buildPasswordField(
                      controller: _currentPasswordController,
                      label: "Mật khẩu hiện tại",
                      icon: Icons.lock_outline,
                      isVisible: _isCurrentPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isCurrentPasswordVisible = !_isCurrentPasswordVisible);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Mật khẩu mới
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: "Mật khẩu mới",
                      icon: Icons.lock,
                      isVisible: _isNewPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isNewPasswordVisible = !_isNewPasswordVisible);
                      },
                    ),
                    // TODO: Thêm Password Strength Bar ở đây theo hình mẫu
                    const SizedBox(height: 16),

                    // Xác nhận mật khẩu mới
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: "Xác nhận mật khẩu mới",
                      icon: Icons.check_circle_outline,
                      isVisible: _isConfirmPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                      },
                    ),

                    const SizedBox(height: 30),

                    // Nút Đổi Mật Khẩu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updatePassword,
                        icon: _isLoading
                            ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Icon(Icons.security_update),
                        label: const Text(
                          "Đổi Mật Khẩu",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // Widget riêng để xây dựng trường nhập mật khẩu (có thể ẩn/hiện)
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.indigo),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}