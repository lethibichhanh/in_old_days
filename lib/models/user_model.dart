// lib/models/user_model.dart

class UserModel {
  final int? id;
  final String username;
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

  // ✅ Tạo từ Map (database)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()),
      username: map['username'] ?? '',
      fullname: map['fullname'],
      email: map['email'] ?? '',
      avatar: map['avatar'],
      passwordHash: map['password_hash'] ?? '',
    );
  }

  // ✅ Chuyển sang Map (để insert/update)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'fullname': fullname,
      'email': email,
      'avatar': avatar,
      'password_hash': passwordHash,
    };
  }

  // ✅ Copy (để cập nhật field cụ thể)
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
