import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'HomePage.dart';
import 'LoginPage.dart';

// ============================================================
// 主題管理器 - 管理深色模式狀態
// ============================================================
class ThemeManager extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeManager() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  /// 完整的 ThemeData - 文字清晰版
  ThemeData getTheme() {
    if (_isDarkMode) {
      // ============================================================
      // 深色主題 - 完整配置
      // ============================================================
      return ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        primarySwatch: Colors.blue,
        primaryColor: Colors.red,

        // 背景色
        scaffoldBackgroundColor: const Color(0xFF121212),

        // 完整的文字主題（16 種）
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFFFFFFFF), fontSize: 57),
          displayMedium: TextStyle(color: Color(0xFFFFFFFF), fontSize: 45),
          displaySmall: TextStyle(color: Color(0xFFFFFFFF), fontSize: 36),
          headlineLarge: TextStyle(color: Color(0xFFFFFFFF), fontSize: 32),
          headlineMedium: TextStyle(color: Color(0xFFFFFFFF), fontSize: 28),
          headlineSmall: TextStyle(color: Color(0xFFFFFFFF), fontSize: 24),
          titleLarge: TextStyle(color: Color(0xFFFFFFFF), fontSize: 22),
          titleMedium: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
          titleSmall: TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          bodyLarge: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
          bodyMedium: TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          bodySmall: TextStyle(color: Color(0xFFCCCCCC), fontSize: 12),
          labelLarge: TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          labelMedium: TextStyle(color: Color(0xFFFFFFFF), fontSize: 12),
          labelSmall: TextStyle(color: Color(0xFFCCCCCC), fontSize: 11),
        ),

        // AppBar 樣式
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
          surfaceTintColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),

        // 卡片樣式
        cardColor: const Color(0xFF1E1E1E),
        cardTheme: const CardThemeData(color: Color(0xFF1E1E1E)),

        // ListTile 樣式（重要！）
        listTileTheme: const ListTileThemeData(
          textColor: Color(0xFFFFFFFF),
          titleTextStyle: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
          subtitleTextStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
          tileColor: Color(0xFF1E1E1E),
        ),

        // 輸入框樣式
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2F2F2F),
          labelStyle: const TextStyle(color: Color(0xFFBBBBBB)),
          hintStyle: const TextStyle(color: Color(0xFF888888)),
          helperStyle: const TextStyle(color: Color(0xFFBBBBBB)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3F3F3F)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3F3F3F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),

        // 按鈕樣式
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
          ),
        ),

        // 分隔線樣式
        dividerTheme: const DividerThemeData(color: Color(0xFF2F2F2F)),

        // Switch 樣式
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.green;
            }
            return Colors.grey;
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.green.withOpacity(0.5);
            }
            return Colors.grey.withOpacity(0.3);
          }),
        ),

        // 底部導航欄樣式
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1F1F1F),
          selectedItemColor: Colors.blue,
          unselectedItemColor: Color(0xFF888888),
        ),
      );
    } else {
      // ============================================================
      // 淺色主題 - 完整配置
      // ============================================================
      return ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        primarySwatch: Colors.blue,
        primaryColor: Colors.red,

        // 背景色
        scaffoldBackgroundColor: Colors.white,

        // 完整的文字主題（16 種）
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF000000), fontSize: 57),
          displayMedium: TextStyle(color: Color(0xFF000000), fontSize: 45),
          displaySmall: TextStyle(color: Color(0xFF000000), fontSize: 36),
          headlineLarge: TextStyle(color: Color(0xFF000000), fontSize: 32),
          headlineMedium: TextStyle(color: Color(0xFF000000), fontSize: 28),
          headlineSmall: TextStyle(color: Color(0xFF000000), fontSize: 24),
          titleLarge: TextStyle(color: Color(0xFF000000), fontSize: 22),
          titleMedium: TextStyle(color: Color(0xFF000000), fontSize: 16),
          titleSmall: TextStyle(color: Color(0xFF000000), fontSize: 14),
          bodyLarge: TextStyle(color: Color(0xFF000000), fontSize: 16),
          bodyMedium: TextStyle(color: Color(0xFF000000), fontSize: 14),
          bodySmall: TextStyle(color: Color(0xFF666666), fontSize: 12),
          labelLarge: TextStyle(color: Color(0xFF000000), fontSize: 14),
          labelMedium: TextStyle(color: Color(0xFF000000), fontSize: 12),
          labelSmall: TextStyle(color: Color(0xFF666666), fontSize: 11),
        ),

        // AppBar 樣式
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.blue,
        ),

        // 卡片樣式
        cardColor: Colors.white,
        cardTheme: const CardThemeData(color: Colors.white),

        // ListTile 樣式
        listTileTheme: const ListTileThemeData(
          textColor: Color(0xFF000000),
          titleTextStyle: TextStyle(color: Color(0xFF000000), fontSize: 16),
          subtitleTextStyle: TextStyle(color: Color(0xFF666666), fontSize: 14),
          tileColor: Colors.white,
        ),

        // 輸入框樣式
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          labelStyle: const TextStyle(color: Color(0xFF666666)),
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          helperStyle: const TextStyle(color: Color(0xFF666666)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),

        // 按鈕樣式
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
          ),
        ),

        // 分隔線樣式
        dividerTheme: const DividerThemeData(color: Color(0xFFEEEEEE)),

        // Switch 樣式
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue;
            }
            return Colors.grey;
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.withOpacity(0.5);
            }
            return Colors.grey.withOpacity(0.3);
          }),
        ),

        // 底部導航欄樣式
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      );
    }
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(create: (_) => ThemeManager(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return MaterialApp(
          title: '視角交錯',
          theme: themeManager.getTheme(),
          initialRoute: '/',
          routes: {
            '/': (context) => HomePage(),
            '/login': (context) => LoginPage(),
          },
          onUnknownRoute: (settings) {
            return MaterialPageRoute(
              builder:
                  (context) => Scaffold(
                    appBar: AppBar(
                      title: Text('頁面不存在'),
                      backgroundColor: Colors.red,
                    ),
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            '找不到頁面: ${settings.name}',
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed:
                                () => Navigator.of(
                                  context,
                                ).pushReplacementNamed('/'),
                            child: Text('返回首頁'),
                          ),
                        ],
                      ),
                    ),
                  ),
            );
          },
        );
      },
    );
  }
}
