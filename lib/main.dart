import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'db/db_helper.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/update_profile_screen.dart';
import 'screens/update_password_screen.dart';
import 'screens/figures_list_screen.dart';

// =======================================================
// 🔹 STATE QUẢN LÝ NGÔN NGỮ TOÀN CỤC
// =======================================================
class AppLocaleNotifier extends ChangeNotifier {
  Locale _locale = const Locale('vi');
  Locale get locale => _locale;

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_language') ?? 'vi';
    _locale = Locale(savedLang);
    notifyListeners();
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale != newLocale) {
      _locale = newLocale;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', newLocale.languageCode);
      notifyListeners();
    }
  }
}

final AppLocaleNotifier localeNotifier = AppLocaleNotifier();

// =======================================================
// 🔹 HÀM MAIN
// =======================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await localeNotifier.loadSavedLocale();

  try {
    await DBHelper.prepareDatabaseFromAssets();
    if (kDebugMode) debugPrint("✅ Database đã copy thành công từ assets/in_old_days.db!");
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint("❌ Lỗi khi chuẩn bị DB: $e");
      debugPrintStack(stackTrace: st);
    }
  }

  runApp(const InOldDaysApp());
}

// =======================================================
// 🔹 ỨNG DỤNG CHÍNH
// =======================================================
class InOldDaysApp extends StatefulWidget {
  const InOldDaysApp({super.key});

  @override
  State<InOldDaysApp> createState() => _InOldDaysAppState();

  static void setLocale(BuildContext context, Locale newLocale) {
    localeNotifier.setLocale(newLocale);
  }
}

class _InOldDaysAppState extends State<InOldDaysApp> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeNotifier,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'In Old Days',

          // 🌐 ĐA NGÔN NGỮ
          locale: localeNotifier.locale,
          supportedLocales: const [
            Locale('vi'),
            Locale('en'),
            Locale('zh'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
            useMaterial3: true,
          ),

          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/home': (context) => const HomeScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/update_profile': (context) => const UpdateProfileScreen(),
            '/update_password': (context) => const UpdatePasswordScreen(),
            '/figures': (context) => const FiguresListScreen(),
          },

          builder: (context, child) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: child,
          ),
        );
      },
    );
  }
}
