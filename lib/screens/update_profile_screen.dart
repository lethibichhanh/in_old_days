import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  UserModel? _user;
  final _fullnameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _localImagePath;
  bool _isLoading = false;

  late AppLocalizations tr;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    tr = AppLocalizations.of(context)!;

    if (_user == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null && args['user'] is UserModel) {
        _user = args['user'] as UserModel;
        _fullnameController.text = _user?.fullname ?? '';
        _emailController.text = _user?.email ?? '';
      }
    }
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ========================================================
  // 📸 CHỌN ẢNH TỪ THƯ VIỆN
  // ========================================================
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (mounted) {
        setState(() {
          _localImagePath = image.path;
        });
      }
    }
  }


  /// 🔹 Hàm cập nhật thông tin người dùng
  Future<void> _updateProfile() async {
    // Lấy chuỗi dịch cho thông báo
    final fillInfo = tr.translate('update_profile_fill_info');
    final invalidEmail = tr.translate('update_profile_invalid_email');
    final success = tr.translate('update_profile_success');
    final noChange = tr.translate('update_profile_no_change');
    final errorUpdate = tr.translate('update_profile_error_update');

    if (_user == null || _user!.id == null) return;

    final fullname = _fullnameController.text.trim();
    final email = _emailController.text.trim();

    String newAvatarPath = _localImagePath ?? _user!.avatar ?? '';

    if (fullname.isEmpty || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fillInfo)),
        );
      }
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(invalidEmail)),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedUser = _user!.copyWith(
        fullname: fullname,
        email: email,
        avatar: newAvatarPath,
        updatedAt: DateTime.now().toIso8601String(),
      );

      final rows = await DBHelper.updateUser(updatedUser);

      if (rows > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success)),
          );
          // ✅ Dòng này truyền Avatar mới về ProfileScreen
          Navigator.pop(context, updatedUser);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(noChange)),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi cập nhật: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errorUpdate: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========================================================
  // 🖼️ XỬ LÝ HIỂN THỊ AVATAR VÀ NÚT CHỌN ẢNH (STACK)
  // ========================================================
  Widget _buildAvatarWithPicker() {
    ImageProvider? imageProvider;
    String currentAvatarPath = _localImagePath ?? _user?.avatar ?? '';

    // 1. Nếu có ảnh local mới được chọn
    if (_localImagePath != null && File(_localImagePath!).existsSync()) {
      imageProvider = FileImage(File(_localImagePath!));
    }
    // 2. Nếu là ảnh network URL cũ
    else if (currentAvatarPath.startsWith('http')) {
      imageProvider = NetworkImage(currentAvatarPath);
    }
    // 3. Nếu là đường dẫn local path cũ (cần logic lưu trữ tốt hơn trong thực tế)
    else if (currentAvatarPath.isNotEmpty) {
      if (File(currentAvatarPath).existsSync()) {
        imageProvider = FileImage(File(currentAvatarPath));
      } else {
        imageProvider = null; // Fallback nếu file local cũ không còn
      }
    }

    // ✅ Sử dụng STACK để chồng Avatar và Nút nhỏ lên nhau
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Avatar chính
        CircleAvatar(
          radius: 60,
          backgroundColor: kPrimaryColor.withOpacity(0.2),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? const Icon(Icons.person, size: 60, color: kAppBarColor)
              : null,
        ),

        // 2. Nút nhỏ (IconButton) ở góc dưới bên phải
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: kAccentColor, // Màu Coral/Hồng Đào
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(1, 1),
                    ),
                  ]
              ),
              child: const Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildTextField (Giữ nguyên logic)
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
        labelStyle: const TextStyle(color: kSubtextColor),
        prefixIcon: Icon(icon, color: kPrimaryColor),
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

  @override
  Widget build(BuildContext context) {
    // Lấy chuỗi dịch cho UI
    final screenTitle = tr.translate('update_profile_screen_title');
    final userNotFound = tr.translate('update_profile_user_not_found');
    final updateProfileHeader = tr.translate('update_profile_header');
    final labelFullname = tr.translate('update_profile_label_fullname');
    final labelEmail = tr.translate('update_profile_label_email');
    final saveButton = tr.translate('update_profile_save_button');

    if (_user == null) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(child: Text("❌ $userNotFound")),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(screenTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: kAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
                // 🖼️ Avatar và Nút Chọn Ảnh
                _buildAvatarWithPicker(),

                const SizedBox(height: 16),
                Text(
                  updateProfileHeader,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: kTitleTextColor
                  ),
                ),
                const SizedBox(height: 24),

                // Fullname
                _buildTextField(
                  controller: _fullnameController,
                  label: labelFullname,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 16),

                // Email
                _buildTextField(
                  controller: _emailController,
                  label: labelEmail,
                  icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 30),

                // Nút Lưu thay đổi
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
                        : const Icon(Icons.save, color: Colors.white),
                    label: Text(
                      saveButton,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
      // Xử lý loading
      floatingActionButton: _isLoading
          ? Container(
        color: Colors.black.withOpacity(0.1),
        child: const Center(child: CircularProgressIndicator(color: kAccentColor)),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}