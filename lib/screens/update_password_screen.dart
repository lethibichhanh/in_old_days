import 'dart:math';
import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  double _strength = 0;
  String _generatedPassword = "";
  bool _showAdvanced = false;

  // Advanced options
  int _length = 12;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;

  int? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _userId = args?['userId'] as int?;
  }

  void _checkStrength(String password) {
    double strength = 0;
    if (password.isEmpty) {
      strength = 0;
    } else {
      if (password.length >= 8) strength += 0.25;
      if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
      if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
      if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
        strength += 0.25;
      }
    }
    setState(() => _strength = strength);
  }

  String _generatePassword() {
    String chars = "";
    if (_includeLowercase) chars += "abcdefghijklmnopqrstuvwxyz";
    if (_includeUppercase) chars += "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    if (_includeNumbers) chars += "0123456789";
    if (_includeSymbols) chars += "!@#\$%^&*()_+-=[]{}|;:,.<>?";
    if (chars.isEmpty) chars = "abcdefghijklmnopqrstuvwxyz";

    final rnd = Random.secure();
    return List.generate(_length, (index) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Không tìm thấy userId")),
      );
      return;
    }
    final newPassword = _passwordController.text.trim();
    try {
      final rows = await DBHelper.instance.update(
        "users",
        {"password": newPassword},
        where: "id = ?",
        whereArgs: [_userId],
      );
      if (rows > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Đổi mật khẩu thành công")),
          );
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Không tìm thấy người dùng")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Lỗi cập nhật mật khẩu: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Cập nhật mật khẩu"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 30),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.lock),
                            labelText: "Mật khẩu mới",
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          onChanged: _checkStrength,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Vui lòng nhập mật khẩu";
                            }
                            if (value.length < 8) {
                              return "Mật khẩu tối thiểu 8 ký tự";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.check_circle),
                            labelText: "Xác nhận mật khẩu",
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return "Mật khẩu không khớp";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _strength,
                            minHeight: 10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _strength < 0.3
                                  ? Colors.red
                                  : _strength < 0.7
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                            backgroundColor: Colors.grey[300],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _strength < 0.3
                              ? "🔴 Rất yếu"
                              : _strength < 0.7
                              ? "🟠 Trung bình"
                              : "🟢 Mạnh",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _strength < 0.3
                                ? Colors.red
                                : _strength < 0.7
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Nút sinh mật khẩu ngẫu nhiên
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _generatedPassword = _generatePassword();
                      _passwordController.text = _generatedPassword;
                      _confirmController.text = _generatedPassword;
                      _checkStrength(_generatedPassword);
                    });
                  },
                  icon: const Icon(Icons.password),
                  label: const Text("Sinh mật khẩu ngẫu nhiên"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),

                if (_generatedPassword.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    "🔑 $_generatedPassword",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],

                const SizedBox(height: 16),

                // Advanced options
                TextButton(
                  onPressed: () =>
                      setState(() => _showAdvanced = !_showAdvanced),
                  child: Text(
                    _showAdvanced
                        ? "Ẩn tuỳ chọn nâng cao"
                        : "Hiện tuỳ chọn nâng cao",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_showAdvanced)
                  Card(
                    margin: const EdgeInsets.only(top: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text("Độ dài:"),
                              Expanded(
                                child: Slider(
                                  value: _length.toDouble(),
                                  min: 8,
                                  max: 20,
                                  divisions: 12,
                                  label: "$_length",
                                  onChanged: (val) =>
                                      setState(() => _length = val.toInt()),
                                ),
                              ),
                            ],
                          ),
                          CheckboxListTile(
                            value: _includeLowercase,
                            onChanged: (val) => setState(
                                    () => _includeLowercase = val ?? true),
                            title: const Text("Chữ thường (abc)"),
                          ),
                          CheckboxListTile(
                            value: _includeUppercase,
                            onChanged: (val) => setState(
                                    () => _includeUppercase = val ?? true),
                            title: const Text("Chữ hoa (ABC)"),
                          ),
                          CheckboxListTile(
                            value: _includeNumbers,
                            onChanged: (val) => setState(
                                    () => _includeNumbers = val ?? true),
                            title: const Text("Số (123)"),
                          ),
                          CheckboxListTile(
                            value: _includeSymbols,
                            onChanged: (val) => setState(
                                    () => _includeSymbols = val ?? true),
                            title: const Text("Ký tự đặc biệt (@#\$)"),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Nút cập nhật mật khẩu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Cập nhật mật khẩu",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
