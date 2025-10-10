import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 👉 Lấy arguments (có thể null nếu không truyền)
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final user = args?['user'] as Map<String, dynamic>? ?? {};

    // Thông tin user
    final username = user['username']?.toString() ?? "Chưa có";
    final fullname = user['fullname']?.toString() ?? "Chưa cập nhật";
    final email = user['email']?.toString() ?? "Chưa cập nhật";
    final avatarUrl = user['avatar']?.toString();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6D83F2), Color(0xFF8EC5FC),],
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

                // ✅ Avatar
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
                      child: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? Image.network(
                        avatarUrl,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person,
                              size: 60, color: Colors.white);
                        },
                      )
                          : const Icon(Icons.person,
                          size: 60, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Thông tin user
                _buildInfoCard(Icons.account_circle, username, "Tên đăng nhập"),
                _buildInfoCard(Icons.badge, fullname, "Họ tên"),
                _buildInfoCard(Icons.email, email, "Email"),

                const SizedBox(height: 30),

                // 👉 Nút cập nhật thông tin
                _buildActionButton(
                  context,
                  label: "Cập nhật thông tin",
                  icon: Icons.edit,
                  color: theme.colorScheme.primary,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/update_profile',
                      arguments: {'user': user},
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 👉 Nút đổi mật khẩu
                _buildActionButton(
                  context,
                  label: "Đổi mật khẩu",
                  icon: Icons.lock_reset,
                  outlined: true,
                  onPressed: () {
                    if (user['id'] != null) {
                      Navigator.pushNamed(
                        context,
                        '/update_password',
                        arguments: {'userId': user['id']},
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("⚠️ Không tìm thấy userId")),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                // 👉 Nút về trang chính
                _buildActionButton(
                  context,
                  label: "Về trang chính (Ôn tập)",
                  icon: Icons.school,
                  color: Colors.indigo,
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/topics',
                      arguments: {'user': user},
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 👉 Nút đăng xuất
                _buildActionButton(
                  context,
                  label: "Đăng xuất",
                  icon: Icons.logout,
                  outlined: true,
                  color: Colors.red,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                          (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // helper widget: card thông tin user
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
        title: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(label, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  // helper button
  Widget _buildActionButton(
      BuildContext context, {
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 5,
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
