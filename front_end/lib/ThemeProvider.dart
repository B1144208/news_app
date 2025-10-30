import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主題提供者 - 管理應用的深色模式狀態
class ThemeProvider extends ChangeNotifier {
  bool _darkModeEnabled = false;

  bool get darkModeEnabled => _darkModeEnabled;

  ThemeProvider() {
    _loadDarkModeSetting();
  }

  /// 從 SharedPreferences 加載深色模式設定
  Future<void> _loadDarkModeSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      notifyListeners();
    } catch (e) {
      print('Error loading dark mode setting: $e');
    }
  }

  /// 設定深色模式並保存到 SharedPreferences
  Future<void> setDarkMode(bool enabled) async {
    try {
      _darkModeEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode_enabled', enabled);
      notifyListeners();
    } catch (e) {
      print('Error setting dark mode: $e');
    }
  }

  /// 淺色主題
  ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }

  /// 深色主題
  ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: const Color(0xFF1F1F1F),
      ),
    );
  }
}
