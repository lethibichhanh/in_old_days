import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/user_model.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  UserModel? _user;
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _avatarController = TextEditingController();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && args['user'] is UserModel) {
      _user = args['user'] as UserModel;
      _fullnameController.text = _user?.fullname ?? '';
      _emailController.text = _user?.email ?? '';
      _avatarController.text = _user?.avatar ?? '';
    }
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  /// 🔹 Hàm cập nhật thông tin người dùng
  Future<void> _updateProfile() async {
    if (_user == null || _user!.id == null) return;

    final fullname = _fullnameController.text.trim();
    final email = _emailController.text.trim();
    final avatar = _avatarController.text.trim();

    if (fullname.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Vui lòng nhập đầy đủ thông tin.")),
      );
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Email không hợp lệ.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Tạo đối tượng mới với thông tin đã chỉnh sửa
      final updatedUser = _user!.copyWith(
        fullname: fullname,
        email: email,
        avatar: avatar,
      );

      // ✅ Cập nhật DB
      final rows = await DBHelper.updateUser(updatedUser);

      if (rows > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Cập nhật thành công!")),
          );
          // 👉 Trả dữ liệu về ProfileScreen
          Navigator.pop(context, updatedUser);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Không có thay đổi nào được lưu.")),
        );
      }
    } catch (e) {
      debugPrint("❌ Lỗi cập nhật: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi cập nhật: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text("Cập nhật thông tin"),
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
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.indigo.shade100,
                      backgroundImage: _avatarController.text.isNotEmpty
                          ? NetworkImage(_avatarController.text)
                          : null,
                      child: _avatarController.text.isEmpty
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _fullnameController,
                      label: "Họ và tên",
                      icon: Icons.badge,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: "Email",
                      icon: Icons.email,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _avatarController,
                      label: "Avatar URL",
                      icon: Icons.image,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateProfile,
                        icon: _isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.save),
                        label: const Text(
                          "Lưu thay đổi",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.indigo),
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
