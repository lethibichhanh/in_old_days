// lib/models/user_model.dart

class UserModel {
  // ✅ Tên trường id trong Dart
  final int? id;
  final String username; // Giữ lại username
  final String? fullname;
  final String email;
  final String? avatar;
  final String passwordHash;

  UserModel({
    this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.fullname,
    this.avatar,
  });

  // 1. ✅ Tạo từ Map (database)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      // 💡 SỬA: Đọc từ 'user_id' thay vì 'id'
      id: map['user_id'] is int ? map['user_id'] : int.tryParse(map['user_id'].toString()),

      // 💡 THÊM: Nếu bạn dùng 'username' trong app nhưng DB không có,
      // có thể tạm thời lấy từ 'email' hoặc giữ lại như cũ nếu bạn xử lý 'username' trong code DB.
      // Tuy nhiên, dựa trên DB schema, không có cột 'username' -> giữ nguyên logic nếu nó không phải là cột DB.
      username: map['username'] ?? map['email'].split('@').first,

      // 💡 SỬA: Đọc từ 'full_name' thay vì 'fullname'
      fullname: map['full_name'],

      email: map['email'] ?? '',

      // 💡 SỬA: Đọc từ 'avatar_url' thay vì 'avatar'
      avatar: map['avatar_url'],

      passwordHash: map['password_hash'] ?? '',
    );
  }

  // 2. ✅ Chuyển sang Map (để insert/update)
  Map<String, dynamic> toMap() {
    return {
      // 💡 SỬA: Ghi vào 'user_id'
      'user_id': id,
      // Giả định bạn cần trường này cho một số logic ứng dụng (không phải cột DB)
      'username': username,

      // 💡 SỬA: Ghi vào 'full_name'
      'full_name': fullname,

      'email': email,

      // 💡 SỬA: Ghi vào 'avatar_url'
      'avatar_url': avatar,

      'password_hash': passwordHash,

      // Có thể thêm 'role' hoặc các trường mặc định khác nếu cần insert
    };
  }

  // 3. ✅ Copy (giữ nguyên, chỉ cập nhật tên trường nếu cần)
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