import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/user_model.dart';

class UpdateProfileScreen extends StatefulWidget {
  final UserModel? user;

  const UpdateProfileScreen({super.key, this.user});

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

    if (_user == null) {
      // 1️⃣ Lấy user từ arguments khi Navigator.pushNamed
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['user'] is UserModel) {
        _user = args['user'] as UserModel;
      }

      // 2️⃣ Nếu chưa có, lấy từ widget.user
      _user ??= widget.user;

      // 3️⃣ Gán dữ liệu cho TextField
      if (_user != null && _fullnameController.text.isEmpty) {
        _fullnameController.text = _user!.fullname ?? '';
        _emailController.text = _user!.email;
        _avatarController.text = _user!.avatar ?? '';
      }
    }
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  /// 🔹 Gọi DBHelper.updateUser() để cập nhật vào SQLite
  Future<void> _updateProfile() async {
    if (_user == null || _user!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Không tìm thấy thông tin người dùng")),
      );
      return;
    }

    final fullname = _fullnameController.text.trim();
    final email = _emailController.text.trim();
    final avatar = _avatarController.text.trim();

    if (fullname.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Vui lòng nhập đầy đủ thông tin")),
      );
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Email không hợp lệ")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Tạo bản sao user mới đã cập nhật
      final updatedUser = _user!.copyWith(
        fullname: fullname,
        email: email,
        avatar: avatar,
      );

      // ✅ Gọi DBHelper để update trong SQLite
      final rows = await DBHelper.updateUser(updatedUser);

      if (rows > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Cập nhật thông tin thành công!")),
          );
          Navigator.pop(context, updatedUser); // 🔙 Trả về user mới cho ProfileScreen
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ Không có dòng nào được cập nhật")),
          );
        }
      }
    } catch (e, st) {
      debugPrint("❌ Lỗi cập nhật: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi cập nhật: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text("❌ Không tìm thấy user để cập nhật.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cập nhật thông tin"),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D83F2), Color(0xFF8EC5FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
              shadowColor: Colors.black.withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _avatarController.text.isNotEmpty
                          ? NetworkImage(_avatarController.text)
                          : null,
                      child: _avatarController.text.isEmpty
                          ? const Icon(Icons.person, size: 55, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(_fullnameController, "Họ và tên", Icons.badge),
                    const SizedBox(height: 16),
                    _buildTextField(_emailController, "Email", Icons.email,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _buildTextField(_avatarController, "Avatar URL", Icons.image,
                        onChanged: (_) => setState(() {})),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                            : const Icon(Icons.save),
                        label: const Text(
                          "Lưu thay đổi",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType? keyboardType,
        ValueChanged<String>? onChanged,
      }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
