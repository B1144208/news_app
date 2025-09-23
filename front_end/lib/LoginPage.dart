import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 連接頁面
import 'config.dart';
import 'SignupPage.dart';
import 'HomePage.dart';
import 'AdminPage.dart';


// 判斷登入帳號密碼是否正確
Future<int> checkUserLogin(String username, String password) async {
  final url = '$baseUrl/user/checkuser?account=$username&password=$password';
  
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['exists'];
  } else {
    print('Error checking username: ${response.body}');
    return 0;
  }
}



Future<void> StoreDataInSharedPrederences (int userId) async{

  final userInfoUrl = '$baseUrl/user?userid=$userId';
  final userInfoResponse = await http.get(Uri.parse(userInfoUrl));

  if(userInfoResponse.statusCode == 200) {
    final List<dynamic> userData = jsonDecode(userInfoResponse.body);

    if(userData.isNotEmpty){
      final user = userData[0];

      // 存入 SharedPrederences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('UserID', user['UserID']);
      await prefs.setString('Account', user['Account']);
      await prefs.setString('Password', user['Password']);
      await prefs.setInt('IsManager', user['IsManager']);
      await prefs.setBool('IsLogin', true);
    }
  }  
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  
  // 建立控制器來獲取輸入的值
  final TextEditingController accountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscureText = true;         // 控制密碼的顯示/隱藏
  String PromptMessage = "";

    Future<void> _checkManager() async {
    final prefs = await SharedPreferences.getInstance();
    final userID = prefs.getInt('UserID');

    /*if(userID != null){
      final isManager = prefs.getInt('IsManager') ?? 0;
      if (isManager==0) return;
    
      WidgetsBinding.instance.addPostFrameCallback((_) {
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminPage()),
        );
        
      });
    }*/
  }

  @override
  Widget build(BuildContext context){

    return Scaffold(
      appBar: AppBar(
        title: const Text('登入'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SignupPage()),
              );
            },
            child: const Text('註冊'),
          ),
        ],
      ),
      
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 帳號輸入框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                width: MediaQuery.of(context).size.width / 3,
                child: TextField(
                  controller: accountController,  // 綁定帳號控制器
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '輸入帳號',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 密碼輸入框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              
              child: Container(
                width: MediaQuery.of(context).size.width / 3,
                child: TextField(
                  controller: passwordController,  // 綁定密碼控制器
                  obscureText: _obscureText,  // 密碼框會顯示為星號
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '輸入密碼',
                    suffixIcon: IconButton(
                    icon: Icon(
                      // 根據 _obscureText 變數顯示眼睛圖示
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      // 切換 _obscureText 的狀態
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                  ),
                ),
              ),
            ),

            // 顯示狀態訊息
            if (PromptMessage.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  PromptMessage,
                  style: TextStyle(
                    color: PromptMessage == "成功登入!" ? Colors.green : Colors.red, // 根據訊息顯示顏色
                  ),
                ),
              ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: (){

                // 帳號密碼不能為空
                if(accountController.text == "" || passwordController.text == ""){
                  setState(() {
                    PromptMessage = "帳號、密碼不能為空！";
                  });
                  return;
                }

                // 檢查輸入帳號密碼是否正確
                final Future<int> addStatus = checkUserLogin(accountController.text, passwordController.text);
                addStatus.then((userId){
                  if(userId!=0){
                    setState(() {
                      PromptMessage = "成功登入!";
                      _checkManager();
                    });

                    // 儲存帳號資料至shared_preferences
                    StoreDataInSharedPrederences(userId);

                    Future.delayed(Duration(seconds: 1), () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                      );
                  });
                  }else{
                    setState(() {
                      PromptMessage = "帳號、密碼錯誤!";
                    });
                    return;
                  }
                });
              },
              child: const Text('登入'),
            )
          ],
        )
      )
    );
  }
}
