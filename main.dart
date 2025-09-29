import 'package:flutter/material.dart';

// 只導入確實存在的頁面
import 'HomePage.dart';
import 'LoginPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '視角交錯',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.red,
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.green)),
        buttonTheme: ButtonThemeData(buttonColor: Colors.green),
      ),
      // 設定初始路由
      initialRoute: '/',
      // 設定路由表 - 移除 const
      routes: {
        '/': (context) => HomePage(), // 移除 const
        '/login': (context) => LoginPage(),
      },
      // 處理未定義的路由
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
                            () =>
                                Navigator.of(context).pushReplacementNamed('/'),
                        child: Text('返回首頁'),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }
}
