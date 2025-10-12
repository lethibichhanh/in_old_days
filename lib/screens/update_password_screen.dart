// Trong lib/screens/update_password_screen.dart (code mới)
import 'dart:math';
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/user_model.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  UserModel? _user;
  int? _userIdFromArgs; // Biến để lưu ID được truyền vào

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true; // Bắt đầu loading
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  String _passwordStrength = "Rất yếu (0/100)";
  Color _strengthColor = Colors.red;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_user == null && _userIdFromArgs == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      debugPrint("📦 Arguments nhận được: $args");

      // 1. Lấy ID từ Arguments (Dù là int trực tiếp hay Map)
      if (args is int) {
        _userIdFromArgs = args;
      } else if (args is UserModel) {
        _userIdFromArgs = args.id;
      } else if (args is Map<String, dynamic>) {
        // Nếu ProfileScreen truyền {'userId': id} như code cũ
        _userIdFromArgs = args['userId'] is int ? args['userId'] : int.tryParse(args['userId']?.toString() ?? '');
      }

      // 2. Nếu có ID, tiến hành tải user từ DB
      if (_userIdFromArgs != null) {
        _loadUserById(_userIdFromArgs!);
      } else {
        // 3. Fallback: Nếu không có ID, tải user đầu tiên (Ít tin cậy hơn)
        debugPrint("❌ Không tìm thấy ID từ arguments, đang thử lấy từ DB...");
        _loadUserFromDatabase();
      }
    }
  }

  Future<void> _loadUserById(int id) async {
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
          _showSnackBar("⚠️ Không tìm thấy tài khoản để đổi mật khẩu.");
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi tải user theo ID: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hàm Fallback (chỉ dùng khi không có ID)
  Future<void> _loadUserFromDatabase() async {
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
          _showSnackBar("⚠️ Không có tài khoản nào được đăng nhập.");
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
    const String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_-+=<>?';
    final rand = Random.secure();
    final password =
    List.generate(12, (index) => chars[rand.nextInt(chars.length)]).join();
    _newPasswordController.text = password;
    _confirmPasswordController.text = password;
    _checkPasswordStrength(password);
    _showSnackBar("🔑 Đã tạo mật khẩu ngẫu nhiên!");
  }

  // ================== 📊 KIỂM TRA ĐỘ MẠNH MẬT KHẨU ==================
  void _checkPasswordStrength(String password) {
    // ... (Giữ nguyên logic kiểm tra độ mạnh)
    int score = 0;

    if (password.length >= 6) score += 25;
    if (password.length >= 10) score += 25;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 15;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 15;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score += 20;

    if (score <= 30) {
      _passwordStrength = "Rất yếu ($score/100)";
      _strengthColor = Colors.red;
    } else if (score <= 60) {
      _passwordStrength = "Trung bình ($score/100)";
      _strengthColor = Colors.orange;
    } else {
      _passwordStrength = "Mạnh ($score/100)";
      _strengthColor = Colors.green;
    }

    setState(() {});
  }

  // ================== 🧭 XỬ LÝ CẬP NHẬT MẬT KHẨU ==================
  Future<void> _updatePassword() async {
    // Logic này được giữ nguyên, nó sẽ kiểm tra _user sau khi đã được tải
    if (_user == null || _user!.id == null) {
      _showSnackBar("❌ Thông tin người dùng không hợp lệ.");
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar("⚠️ Vui lòng nhập đầy đủ thông tin.");
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar("❌ Mật khẩu mới phải có ít nhất 6 ký tự.");
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar("❌ Mật khẩu mới và xác nhận không khớp.");
      return;
    }

    // ⚠️ So sánh password hiện tại với hash trong DB
    final currentHash = _user!.passwordHash;
    if (currentHash.isEmpty || currentPassword != currentHash) {
      _showSnackBar("❌ Mật khẩu hiện tại không đúng hoặc chưa được đặt.");
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
        _showSnackBar("✅ Đổi mật khẩu thành công!");
        Navigator.pop(context, updatedUser);
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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Đổi mật khẩu"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      // Thay đổi logic kiểm tra _user thành _isLoading
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
          ? const Center(child: Text("Không thể tải thông tin người dùng."))
          : Stack(
        children: [
          // ... (Phần UI Stack được giữ nguyên)
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
                    const Icon(Icons.lock_reset,
                        size: 80, color: Colors.indigo),
                    const SizedBox(height: 24),
                    _buildPasswordField(
                      controller: _currentPasswordController,
                      label: "Mật khẩu hiện tại",
                      icon: Icons.lock_outline,
                      isVisible: _isCurrentPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isCurrentPasswordVisible =
                        !_isCurrentPasswordVisible);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: "Mật khẩu mới",
                      icon: Icons.lock,
                      isVisible: _isNewPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isNewPasswordVisible =
                        !_isNewPasswordVisible);
                      },
                      onChanged: _checkPasswordStrength,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text("Độ mạnh:",
                            style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(width: 8),
                        Text(
                          _passwordStrength,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _strengthColor),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _generateRandomPassword,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Tạo mật khẩu"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: "Xác nhận mật khẩu mới",
                      icon: Icons.check_circle_outline,
                      isVisible: _isConfirmPasswordVisible,
                      onToggleVisibility: () {
                        setState(() => _isConfirmPasswordVisible =
                        !_isConfirmPasswordVisible);
                      },
                    ),
                    const SizedBox(height: 30),
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
                            : const Icon(Icons.security_update),
                        label: const Text(
                          "Đổi Mật Khẩu",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
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
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

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