import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/user_model.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_user == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        final rawUser = args['user'];

        if (rawUser is UserModel) {
          _user = rawUser;
        } else if (rawUser is Map<String, dynamic>) {
          try {
            _user = UserModel.fromMapArguments(rawUser);
          } catch (e) {
            debugPrint("⚠️ Lỗi chuyển đổi Map sang UserModel: $e");
          }
        }
      }
    }
  }

  /// 🔹 Làm mới thông tin người dùng từ DB (dựa vào ID)
  Future<void> _refreshUserData() async {
    if (_user?.id == null) return;
    final refreshed = await DBHelper.getUserById(_user!.id!);
    if (refreshed != null) {
      setState(() => _user = refreshed);
    }
  }

  /// 🔹 Điều hướng sang trang cập nhật thông tin
  Future<void> _navigateToUpdateProfile() async {
    if (_user == null) return;

    final updatedUser = await Navigator.pushNamed(
      context,
      '/update_profile',
      arguments: {'user': _user},
    );

    if (updatedUser is UserModel) {
      setState(() => _user = updatedUser);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Thông tin người dùng đã được cập nhật!")),
      );
    } else {
      await _refreshUserData(); // reload lại nếu quay về mà có thể DB đã thay đổi
    }
  }

  /// 🔹 Đăng xuất và quay lại màn hình login
  void _logout() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Thông tin cá nhân")),
        body: const Center(
          child: Text("⚠️ Không thể tải thông tin người dùng."),
        ),
      );
    }

    final id = _user!.id ?? 0;
    final username = _user!.username;
    final fullname = _user!.fullname?.isNotEmpty == true ? _user!.fullname! : "Chưa cập nhật";
    final email = _user!.email;
    final avatar = _user!.avatar;
    final role = _user!.role;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông tin cá nhân"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUserData,
            tooltip: "Làm mới dữ liệu",
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6D83F2), Color(0xFF8EC5FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // 🖼️ Avatar người dùng
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.white, Colors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.indigo.shade200,
                    child: ClipOval(
                      child: (avatar != null && avatar.isNotEmpty)
                          ? Image.network(
                        avatar,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 60, color: Colors.white),
                      )
                          : const Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 🧾 Thông tin cơ bản
                _buildInfoCard(Icons.account_circle, username, "Tên đăng nhập"),
                _buildInfoCard(Icons.badge, fullname, "Họ và tên"),
                _buildInfoCard(Icons.email, email, "Email"),


                const SizedBox(height: 30),

                // ✏️ Cập nhật thông tin
                _buildActionButton(
                  label: "Cập nhật thông tin",
                  icon: Icons.edit,
                  color: theme.colorScheme.primary,
                  onPressed: _navigateToUpdateProfile,
                ),
                const SizedBox(height: 12),

                // 🔐 Đổi mật khẩu
                _buildActionButton(
                  label: "Đổi mật khẩu",
                  icon: Icons.lock_reset,
                  outlined: true,
                  onPressed: () {
                    if (id > 0) {
                      Navigator.pushNamed(
                        context,
                        '/update_password',
                        arguments: {'userId': id},
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("⚠️ Không tìm thấy ID người dùng")),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                // 📚 Về trang chính (Ôn tập)
                _buildActionButton(
                  label: "Về trang chính (Ôn tập)",
                  icon: Icons.school,
                  color: Colors.indigo,
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/topics',
                      arguments: {'user': _user},
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 🚪 Đăng xuất
                _buildActionButton(
                  label: "Đăng xuất",
                  icon: Icons.logout,
                  color: Colors.red,
                  outlined: true,
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🧩 Widget hiển thị thông tin người dùng
  Widget _buildInfoCard(IconData icon, String value, String label) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      shadowColor: Colors.indigo.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: Icon(icon, color: Colors.indigo),
        ),
        title: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(label, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  /// 🧩 Nút hành động chung
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    bool outlined = false,
  }) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color ?? Colors.indigo),
            foregroundColor: color ?? Colors.indigo,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(icon),
          label: Text(label),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 5,
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
