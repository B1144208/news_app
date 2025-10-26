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
  final url = '$baseUrl/user/login';

  print('登入API URL: $url');

  // 根據 userController.js,後端期望 'account' 和 'password'
  final requestBody = {
    'account': username, // 不是 user_account
    'password': password, // 不是 user_password
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    print('登入回應狀態碼: ${response.statusCode}');
    print('登入回應內容: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // 根據 userController.js,成功時回傳格式:
      // { success: true/false, data: { success: true, userId: user_id }, message: "..." }
      if (data['success'] == true) {
        // 檢查是否有 data 物件
        if (data['data'] != null && data['data']['success'] == true) {
          return data['data']['userId'] ?? 0;
        }
        // 或直接在根層級
        return data['userId'] ?? 0;
      } else {
        print('登入失敗: ${data['message']}');
        return 0;
      }
    } else {
      print('Error checking username: ${response.body}');
      return 0;
    }
  } catch (e) {
    print('登入請求異常: $e');
    return 0;
  }
}

// 儲存用戶資料到 SharedPreferences
Future<void> StoreDataInSharedPrederences(int userId) async {
  // 根據 searchUser 函數,使用 user_id 作為參數
  final userInfoUrl = '$baseUrl/user/$userId'; // 使用路徑參數

  print('用戶資料API URL: $userInfoUrl');

  try {
    final userInfoResponse = await http.get(Uri.parse(userInfoUrl));

    print('用戶資料回應狀態碼: ${userInfoResponse.statusCode}');
    print('用戶資料回應內容: ${userInfoResponse.body}');

    if (userInfoResponse.statusCode == 200) {
      final responseData = jsonDecode(userInfoResponse.body);

      // 根據 searchUser 的回傳格式
      if (responseData['success'] == true && responseData['data'] != null) {
        if (responseData['data'] is List &&
            (responseData['data'] as List).isNotEmpty) {
          await _storeUserPreferences(responseData['data'][0]);
        } else if (responseData['data'] is Map) {
          await _storeUserPreferences(responseData['data']);
        }
      }
    }
  } catch (e) {
    print('獲取用戶資料異常: $e');
  }
}

// ✅ 修復版：輔助函數:儲存用戶偏好設定 - 包含email和phone
Future<void> _storeUserPreferences(Map<String, dynamic> user) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final userId = user['user_id'] ?? 0;
    final account = user['user_account'] ?? '';
    final password = user['user_password'] ?? '';
    final userName = user['user_name'] ?? '';
    final userLevel = user['user_level'] ?? 0;
    final userEmail = user['user_email'] ?? '';
    final userPhone = user['user_phone'] ?? '';

    // ✅ 時區終極修復 - 使用 toLocal() 轉換
    String userBirthday = user['user_birthday'] ?? '';
    if (userBirthday.isNotEmpty) {
      try {
        // 先解析為 UTC DateTime
        final utcDateTime = DateTime.parse(userBirthday);
        // 轉換為本地時區
        final localDateTime = utcDateTime.toLocal();
        // 提取日期部分
        userBirthday = localDateTime.toIso8601String().substring(0, 10);

        print('🔍 生日時區轉換調試:');
        print('   原始數據: ${user['user_birthday']}');
        print('   UTC DateTime: $utcDateTime');
        print('   Local DateTime: $localDateTime');
        print('   最終格式: $userBirthday');
      } catch (e) {
        // 如果解析失敗，直接截取前 10 個字符
        if (userBirthday.length >= 10) {
          userBirthday = userBirthday.substring(0, 10);
        }
        print('❌ 生日解析失敗，使用 substring: $e');
      }
    }

    // 儲存資料
    await prefs.setInt('UserID', userId);
    await prefs.setString('Account', account);
    await prefs.setString('Password', password);
    await prefs.setInt('UserLevel', userLevel);
    await prefs.setString('UserName', userName);
    await prefs.setString('UserEmail', userEmail);
    await prefs.setString('UserPhone', userPhone);
    await prefs.setString('UserBirthday', userBirthday);
    await prefs.setBool('IsLogin', true);

    print('✅ 用戶資料已保存 - Birthday: $userBirthday');
  } catch (e) {
    print('❌ 儲存用戶偏好設定失敗: $e');
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // 控制器
  final TextEditingController accountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // 狀態變數
  bool _obscureText = true;
  String PromptMessage = "";
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    accountController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoggingIn = true);

    try {
      final userId = await checkUserLogin(
        accountController.text,
        passwordController.text,
      );

      if (userId == 0) {
        setState(() => PromptMessage = '帳號或密碼不正確');
        setState(() => _isLoggingIn = false);
        return;
      }

      // ✅ 儲存用戶資料
      await StoreDataInSharedPrederences(userId);

      if (mounted) {
        // ✅ 判斷用戶級別，導向不同頁面
        final prefs = await SharedPreferences.getInstance();
        final userLevel = prefs.getInt('UserLevel') ?? 0;

        if (userLevel == 1) {
          // 管理員 - 使用 Navigator.push 而不是 pushReplacementNamed
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminPage()),
          );
        } else {
          // 普通用戶 - 使用 Navigator.push 而不是 pushReplacementNamed
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      }
    } catch (e) {
      setState(() => PromptMessage = '登入失敗: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8E3FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('返回主頁'),
        foregroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  '登入',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: accountController,
                  decoration: InputDecoration(
                    labelText: '帳號',
                    hintText: '帳號',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請輸入帳號';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    labelText: '密碼',
                    hintText: '密碼',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscureText = !_obscureText);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請輸入密碼';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                if (PromptMessage.isNotEmpty)
                  Text(
                    PromptMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoggingIn ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child:
                        _isLoggingIn
                            ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            )
                            : const Text(
                              '登入',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('沒有帳號？'),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SignupPage(),
                          ),
                        );
                      },
                      child: const Text('註冊'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
