import 'package:flutter/material.dart';
import '../db/db_helper.dart';

// Đảm bảo file chứa class UserModel được import
// import '../models/user_model.dart'; // Giả sử UserModel nằm ở đây

// Do bạn đã cung cấp class UserModel, tôi sẽ đặt nó ở đây tạm thời:
class UserModel {
  final int? id;
  final String username;
  final String? fullname;
  final String email;
  final String passwordHash;
  final String? avatar;

  UserModel({
    this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.fullname,
    this.avatar,
  });

  // Chuyển sang Map (để insert/update) - Dùng tên cột DB
  Map<String, dynamic> toDbMap() {
    return {
      'user_id': id,
      'full_name': fullname, // Tên cột DB
      'email': email,
      'avatar_url': avatar, // Tên cột DB
      'password_hash': passwordHash,
      // Lưu ý: 'username' không được đưa vào đây nếu nó không phải là cột DB
    };
  }

  // Copy (giữ nguyên, chỉ cập nhật tên trường nếu cần)
  UserModel copyWith({
    int? id,
    String? username,
    String? fullname,
    String? email,
    String? avatar,
    String? passwordHash,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullname: fullname ?? this.fullname,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }
}

// -----------------------------------------------------------

class UpdateProfileScreen extends StatefulWidget {
  // 💡 SỬA: UserModel user được truyền qua constructor hoặc arguments
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

    // 1. Lấy user từ arguments (Cách truyền phổ biến)
    if (_user == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['user'] is UserModel) {
        _user = args['user'] as UserModel;
      }
    }

    // 2. Lấy user từ constructor (Cách truyền tốt hơn)
    if (_user == null && widget.user != null) {
      _user = widget.user;
    }

    // Khởi tạo controllers sau khi có đối tượng _user
    if (_user != null && _fullnameController.text.isEmpty) {
      _fullnameController.text = _user!.fullname ?? '';
      _emailController.text = _user!.email;
      _avatarController.text = _user!.avatar ?? '';
    }
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    // Kiểm tra user và ID (bắt buộc)
    if (_user == null || _user!.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Lỗi hệ thống: Không có ID người dùng")),
        );
      }
      return;
    }

    final fullname = _fullnameController.text.trim();
    final email = _emailController.text.trim();
    final avatar = _avatarController.text.trim();

    // Kiểm tra tính hợp lệ của dữ liệu đầu vào
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
      // 💡 SỬA: Tạo đối tượng UserModel đã cập nhật
      final updatedUserModel = _user!.copyWith(
        fullname: fullname,
        email: email,
        avatar: avatar,
      );

      // 💡 SỬA: Chuyển đổi UserModel sang Map DB
      final updatedDbMap = updatedUserModel.toDbMap();

      // Chỉ giữ lại các trường cần UPDATE (loại bỏ id và username không cần thiết)
      updatedDbMap.remove('user_id');

      final rows = await DBHelper.instance.update(
        "users",
        updatedDbMap,
        where: "user_id = ?",
        whereArgs: [_user!.id],
      );

      if (rows > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Cập nhật thành công")),
          );
          // 💡 SỬA: Trả về đối tượng UserModel đã được cập nhật
          Navigator.pop(context, updatedUserModel);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ Cập nhật không thành công (0 dòng bị ảnh hưởng)")),
          );
        }
      }
    } catch (e, st) {
      debugPrint("❌ Lỗi cập nhật profile: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi cập nhật: ${e.toString()}")),
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
        body: Center(child: Text("❌ Không tìm thấy user để cập nhật. Vui lòng thử lại.")),
      );
    }

    // Phần giao diện giữ nguyên, chỉ sử dụng _user!
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: Card(
                elevation: 12,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
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
                            ? const Icon(Icons.person,
                            size: 55, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _fullnameController,
                        label: "Họ tên",
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
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 6,
                          ),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
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
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}