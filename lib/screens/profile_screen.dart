import 'dart:io';
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/user_model.dart';
import '../l10n/app_localizations.dart';

// --- Khai báo màu sắc Pastel Tươi sáng (Đồng bộ) ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  late AppLocalizations tr;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    tr = AppLocalizations.of(context)!;

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
      if (mounted) {
        setState(() => _user = refreshed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.translate('profile_data_refreshed'))),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.translate('profile_data_refresh_error'))),
        );
      }
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
      if (mounted) {
        setState(() => _user = updatedUser);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.translate('profile_update_success'))),
        );

        // ✅ THAY ĐỔI QUAN TRỌNG: TRUYỀN USER MỚI NGƯỢC VỀ HOMESCREEN
        // Điều này giúp Drawer trong HomeScreen cập nhật ngay lập tức.
        Navigator.pop(context, updatedUser);
      }
    }
  }

  /// 🔹 Đăng xuất và quay lại màn hình login
  void _logout() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ========================================================
  // 🖼️ XỬ LÝ HIỂN THỊ AVATAR (Hỗ trợ Local File và Network)
  // ========================================================
  Widget _buildAvatar() {
    final avatarPath = _user!.avatar ?? '';
    ImageProvider? imageProvider;

    if (avatarPath.isNotEmpty && !avatarPath.startsWith('http')) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        imageProvider = FileImage(file);
      }
    }
    else if (avatarPath.startsWith('http')) {
      imageProvider = NetworkImage(avatarPath);
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [kCardColor, kPrimaryColor.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: CircleAvatar(
        radius: 65,
        backgroundColor: kPrimaryColor.withOpacity(0.2),
        child: ClipOval(
          child: (imageProvider != null)
              ? Image(
            image: imageProvider,
            width: 130,
            height: 130,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 60, color: kAppBarColor),
          )
              : const Icon(Icons.person, size: 60, color: kAppBarColor),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // ✅ Lấy chuỗi dịch cho UI
    final screenTitle = tr.translate('profile_screen_title');
    final loadingError = tr.translate('profile_loading_error');
    final notUpdated = tr.translate('profile_not_updated_text');
    final refreshTooltip = tr.translate('profile_refresh_tooltip');

    final labelUsername = tr.translate('profile_label_username');
    final labelFullname = tr.translate('profile_label_fullname');
    final labelEmail = tr.translate('profile_label_email');

    final buttonUpdateInfo = tr.translate('profile_button_update_info');
    final buttonChangePassword = tr.translate('profile_button_change_password');
    final buttonLogout = tr.translate('profile_button_logout');
    final errorNoId = tr.translate('profile_error_no_id');


    if (_user == null) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(title: Text(screenTitle, style: const TextStyle(color: Colors.white))),
        body: Center(
          child: Text(loadingError, style: const TextStyle(color: kSubtextColor)),
        ),
      );
    }

    final id = _user!.id ?? 0;
    final username = _user!.username;
    final fullname = _user!.fullname?.isNotEmpty == true ? _user!.fullname! : notUpdated;
    final email = _user!.email;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(screenTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: kAppBarColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshUserData,
            tooltip: refreshTooltip,
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // 🖼️ Avatar người dùng
              _buildAvatar(),

              const SizedBox(height: 30),

              // 🧾 Thông tin cơ bản
              _buildInfoCard(Icons.account_circle, labelUsername, username),
              _buildInfoCard(Icons.badge, labelFullname, fullname),
              _buildInfoCard(Icons.email, labelEmail, email),


              const SizedBox(height: 30),

              // ✏️ Cập nhật thông tin
              _buildActionButton(
                label: buttonUpdateInfo,
                icon: Icons.edit,
                color: kPrimaryColor,
                onPressed: _navigateToUpdateProfile,
              ),
              const SizedBox(height: 15),

              // 🔐 Đổi mật khẩu
              _buildActionButton(
                label: buttonChangePassword,
                icon: Icons.lock_reset,
                color: kAccentColor,
                outlined: false,
                onPressed: () {
                  if (id > 0) {
                    Navigator.pushNamed(
                      context,
                      '/update_password',
                      // ✅ Tối ưu hóa: Truyền ID trực tiếp (int) hoặc Map đơn giản
                      // Bạn có thể giữ arguments: {'userId': id} nếu màn hình đích đang dùng Map
                      arguments: {'userId': id},
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errorNoId)),
                    );
                  }
                },
              ),
              const SizedBox(height: 25),


              // 🚪 Đăng xuất
              _buildActionButton(
                label: buttonLogout,
                icon: Icons.logout,
                color: Colors.red,
                outlined: true,
                onPressed: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🧩 Widget hiển thị thông tin người dùng
  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Card(
      color: kCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kPrimaryColor.withOpacity(0.3), width: 1),
      ),
      elevation: 4,
      shadowColor: kPrimaryColor.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kPrimaryColor.withOpacity(0.1),
          child: Icon(icon, color: kAppBarColor), // Icon màu Mint đậm
        ),
        // ✅ Nhãn (Label) nằm ở Title, font nhỏ hơn
        title: Text(label, style: const TextStyle(fontSize: 14, color: kSubtextColor)),
        // ✅ Giá trị (Value) nằm ở Subtitle, font đậm hơn
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTitleTextColor)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
    );
  }

  /// 🧩 Nút hành động chung (Pastel Style)
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    bool outlined = false,
  }) {
    final effectiveColor = color ?? kPrimaryColor;
    const padding = EdgeInsets.symmetric(vertical: 16);

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    const labelStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: effectiveColor, width: 2),
            foregroundColor: effectiveColor,
            padding: padding,
            shape: shape,
          ),
          icon: Icon(icon),
          label: Text(label, style: labelStyle),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveColor,
          foregroundColor: Colors.white,
          padding: padding,
          shape: shape,
          elevation: 6,
        ),
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: labelStyle),
      ),
    );
  }
}