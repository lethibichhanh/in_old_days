import 'package:sqflite/sqflite.dart'; // Chỉ cần nếu dùng cho type checking

class UserModel {
  final int? id;
  final String username;
  final String email;
  final String passwordHash;
  final String? fullname;
  final String? avatar;
  final String role;
  final String? createdAt;
  final String? updatedAt;

  UserModel({
    this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    this.fullname,
    this.avatar,
    this.role = 'user',
    this.createdAt,
    this.updatedAt,
  });

  // ✅ 1. Chuyển đổi từ Map (Database Column Names)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    final emailValue = map['email']?.toString() ?? '';
    final usernameValue = map['username']?.toString() ??
        (emailValue.isNotEmpty ? emailValue.split('@').first : 'unknown');

    return UserModel(
      id: map['user_id'] is int ? map['user_id'] as int : int.tryParse('${map['user_id']}'),
      username: usernameValue,
      fullname: map['full_name']?.toString(),
      email: emailValue,
      avatar: map['avatar_url']?.toString(),
      passwordHash: map['password_hash']?.toString() ?? '',
      role: map['role']?.toString() ?? 'user',
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  // ✅ 2. Chuyển đổi từ Map (Flutter Arguments)
  factory UserModel.fromMapArguments(Map<String, dynamic> map) {
    final emailValue = map['email']?.toString() ?? '';
    final usernameValue = map['username']?.toString() ??
        (emailValue.isNotEmpty ? emailValue.split('@').first : 'unknown');

    return UserModel(
      id: (map['id'] ?? map['user_id']) is int
          ? (map['id'] ?? map['user_id'])
          : int.tryParse('${map['id'] ?? map['user_id']}'),
      username: usernameValue,
      fullname: map['fullname']?.toString() ?? map['full_name']?.toString(),
      email: emailValue,
      avatar: map['avatar']?.toString() ?? map['avatar_url']?.toString(),
      passwordHash: map['password_hash']?.toString() ??
          map['passwordHash']?.toString() ??
          '',
      role: map['role']?.toString() ?? 'user',
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  // ✅ 3. Map để ghi vào DB
  Map<String, dynamic> toDbMap() {
    return {
      'user_id': id,
      'full_name': fullname,
      'email': email,
      'avatar_url': avatar,
      'password_hash': passwordHash,
      'role': role,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // ✅ 4. Copy
  UserModel copyWith({
    int? id,
    String? username,
    String? fullname,
    String? email,
    String? avatar,
    String? passwordHash,
    String? role,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullname: fullname ?? this.fullname,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
