import 'package:flutter/material.dart';

// 連接頁面
import 'HomePage.dart';

void main(){
  runApp(const MyApp());
}

// 主應用程式根元件
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: '視角交錯',
      theme: ThemeData(
        primarySwatch: Colors.blue, // 主色調
        primaryColor: Colors.red,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: Colors.green,
          ),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.green),
      ),
      home: const HomePage(),
    );
  }
}

