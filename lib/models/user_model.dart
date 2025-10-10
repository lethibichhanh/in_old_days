import 'package:sqflite/sqflite.dart'; // Chỉ cần nếu dùng cho type checking

class UserModel {
  final int? id;
  // Giả định username là trường cần thiết cho Flutter, mặc dù thiếu trong schema SQL mới nhất.
  // Tôi thêm nó vào để code Flutter không bị lỗi.
  final String username;
  final String email;
  final String passwordHash;
  final String? fullname;
  final String? avatar;
  // 💡 CẬP NHẬT: Thay đổi từ INTEGER sang String để khớp với schema SQLite mới nhất
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

  // 1. Chuyển đổi từ Map (Database Column Names)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Phương thức này dùng khi đọc từ DB (DBHelper)
    return UserModel(
      id: map['user_id'] as int?,
      // Giả định username được tính toán nếu không có cột DB tương ứng
      username: map['username'] ?? map['email'].split('@').first,
      fullname: map['full_name'], // Tên cột DB
      email: map['email'] as String,
      avatar: map['avatar_url'], // Tên cột DB
      passwordHash: map['password_hash'] as String,
      role: map['role']?.toString() ?? 'user',
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  // 2. Chuyển đổi từ Map (Flutter Arguments/Legacy)
  factory UserModel.fromMapArguments(Map<String, dynamic> map) {
    // Phương thức này dùng khi đọc từ arguments (nếu arguments vẫn là Map)
    // Cần ánh xạ từ tên trường Dart sang tên trường truyền vào (có thể là tên cột DB)
    return UserModel(
      id: map['id'] ?? map['user_id'] as int?,
      username: map['username'] ?? map['email']?.split('@').first,
      fullname: map['fullname'] ?? map['full_name'],
      email: map['email'] as String,
      avatar: map['avatar'] ?? map['avatar_url'],
      passwordHash: map['password_hash'] ?? map['passwordHash'] ?? '',
      role: map['role']?.toString() ?? 'user',
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  // 3. Chuyển sang Map (để insert/update DB)
  Map<String, dynamic> toDbMap() {
    // Phương thức này dùng khi ghi vào DB (DBHelper)
    return {
      'user_id': id,
      // 'username' không đưa vào nếu không phải cột DB và DB không tự tính toán
      'full_name': fullname,
      'email': email,
      'avatar_url': avatar,
      'password_hash': passwordHash,
      'role': role,
      'created_at': createdAt,
      'updated_at': DateTime.now().toIso8601String(), // Cập nhật updated_at
    };
  }

  // 4. Copy (cho state management)
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