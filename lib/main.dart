import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // để debug log

import 'db/db_helper.dart'; // Quản lý SQLite
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/update_profile_screen.dart';
import 'screens/figures_list_screen.dart'; // 📜 Danh sách nhân vật
// import 'screens/figure_detail_screen.dart'; // KHÔNG CẦN định tuyến ở đây

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Chỉ cho phép dọc
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ✅ Chuẩn bị database SQLite từ assets
  try {
    await DBHelper.prepareDatabaseFromAssets();
    if (kDebugMode) {
      debugPrint("✅ Database đã copy thành công từ assets/in_old_days.db!");
    }

    // 🔍 Debug: In ra 20 đường dẫn ảnh đầu tiên trong DB (tùy chọn)
    await DBHelper.debugPrintAllImages();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint("❌ Lỗi khi chuẩn bị DB: $e");
      debugPrintStack(stackTrace: st);
    }
  }

  runApp(const InOldDaysApp());
}

class InOldDaysApp extends StatelessWidget {
  const InOldDaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'In Old Days',
      theme: ThemeData(
        // Đặt seedColor thành màu nâu để phù hợp với theme lịch sử/cổ kính hơn
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),

      // ✅ Mặc định khởi động ở màn hình đăng nhập
      initialRoute: '/login',

      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/update_profile': (context) => const UpdateProfileScreen(), // ✅ Route cập nhật

        // 📜 Trang danh sách nhân vật
        '/figures': (context) => const FiguresListScreen(),
        // KHÔNG CẦN '/figure-detail' vì nó được gọi bằng Navigator.push và truyền tham số.
      },

      // Tắt bàn phím khi chạm ra ngoài
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: child,
        );
      },
    );
  }
}