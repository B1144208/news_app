import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 連接頁面
import 'config.dart';
import 'LoginPage.dart';

Future<bool> insertUser(String account, String password) async{
  final url = '$baseUrl/user/insertUser';
  
  // Prepare the request body as a Map
  final Map<String, String> body = {
    'Account': account,
    'Password': password,
  };

  // Make the HTTP POST request
  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Content-Type': 'application/json', // Set the content type to JSON
    },
    body: jsonEncode(body), // Convert the Map to JSON
  );

  // Check the response status
  if(response.statusCode == 201){
    // Successfully added user
    print('User added Successfully: $response.body');
    return true;
  }else{
    // Failed to add user
    
    // 嘗試解析回應內容，如果不是有效的 JSON，顯示錯誤訊息
    try {
      final errorResponse = jsonDecode(response.body);
      print('Error: ${errorResponse['error']}');
    } catch (e) {
      // 如果回應不是有效的 JSON，顯示純文本錯誤
      print('Error: ${response.body}');
    }
    return false;
  }
}

// 判斷帳號是否存在
Future<bool> checkAccountExist(String username) async {
  final url = '$baseUrl/user/checkname?account=$username';
  
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // 假設返回的 JSON 會告訴我們帳號是否已存在
    return data['exists'];  // 返回帳號是否存在，true 或 false
  } else {
    print('Error checking username: ${response.body}');
    return false;  // 當請求失敗時，認為帳號不存在
  }
}


class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  
  // 建立控制器來獲取輸入的值
  final TextEditingController accountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController password2Controller = TextEditingController();

  bool _obscureText = true;         // 控制密碼的顯示/隱藏
  bool _obscureText2 = true;
  String PromptMessage = "";        // 存儲錯誤訊息

  @override
  void initState(){
    super.initState();

    accountController.addListener((){
      // 每次帳號輸入框變動時，檢查帳號是否已存在
      checkAccountExist(accountController.text).then((exists) {
        setState(() {
          if (exists) {
            PromptMessage = "該帳號已經存在！";
          } else {
            PromptMessage = "";  // 沒有錯誤
          }
        });
      });
    });

    // 註冊密碼確認輸入框監聽1
    passwordController.addListener(() {
      setState(() {
        if (passwordController.text != password2Controller.text) {
          PromptMessage = "密碼不一致！";
        } else {
          PromptMessage = "";
        }
      });
    });

    // 註冊密碼確認輸入框監聽2
    password2Controller.addListener(() {
      setState(() {
        if (passwordController.text != password2Controller.text) {
          PromptMessage = "密碼不一致！";
        } else {
          PromptMessage = "";
        }
      });
    });
  }

  @override
  Widget build(BuildContext context){

    return Scaffold(
      appBar: AppBar(
        title: const Text('註冊'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
            child: const Text('登入'),
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

            const SizedBox(height: 20),

            // 二次密碼輸入框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              
              child: Container(
                width: MediaQuery.of(context).size.width / 3,
                child: TextField(
                  controller: password2Controller,  // 綁定密碼控制器
                  obscureText: _obscureText2,  // 密碼框會顯示為星號
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '再次輸入密碼',
                    suffixIcon: IconButton(
                    icon: Icon(
                      // 根據 _obscureText 變數顯示眼睛圖示
                      _obscureText2 ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      // 切換 _obscureText 的狀態
                      setState(() {
                        _obscureText2 = !_obscureText2;
                      });
                    },
                  ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 顯示密碼不一致的錯誤訊息
            if (PromptMessage.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  PromptMessage,
                  //style: TextStyle(color: Colors.red),
                  style: TextStyle(
                    color: PromptMessage == "成功註冊!" ? Colors.green : Colors.red, // 根據訊息顯示顏色
                  ),
                ),
              ),
            const SizedBox(height: 30),

            // 註冊按鈕
            ElevatedButton(
              onPressed: (){

                // 帳號密碼不能為空
                if(accountController.text == "" || passwordController.text == "" || password2Controller.text == ""){
                  setState(() {
                    PromptMessage = "帳號、密碼不能為空！";
                  });
                  return;
                }

                // 密碼一致性檢查
                if (passwordController.text != password2Controller.text) {
                  setState(() {
                    PromptMessage = "密碼不一致！";
                  });
                  return;
                }

                // 清除錯誤訊息
                setState(() {
                  PromptMessage = "";
                });

                final Future<bool> addStatus = insertUser(accountController.text, passwordController.text);

                addStatus.then((status) {
                  if (status) {
                    setState(() {
                      PromptMessage = "成功註冊!";
                    });
                    Future.delayed(Duration(seconds: 1), () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    });
                  } else {
                    setState(() {
                      PromptMessage = "註冊失敗!";
                    });
                    return;
                  }
                });
              },
              child: const Text('註冊'),
            )
          ],
        )
      )
    );
  }
}