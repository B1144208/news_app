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
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a2a4e),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF60a5fa)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '返回主頁',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF6366f1).withOpacity(0.1),
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Logo 區域
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366f1),
                        const Color(0xFF60a5fa),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366f1).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.login, color: Colors.white, size: 56),
                ),

                const SizedBox(height: 32),

                // 標題
                const Text(
                  '登入帳號',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 12),

                // 副標題
                Text(
                  '歡迎回來',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 40),

                // 帳號輸入框
                // 帳號輸入框
                TextFormField(
                  controller: accountController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: '帳號',
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    hintText: '輸入您的帳號',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF6366f1).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF6366f1).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366f1),
                        width: 2,
                      ),
                    ),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366f1).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF60a5fa),
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1a2a4e),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請輸入帳號';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 密碼輸入框
                // 密碼輸入框
                TextFormField(
                  controller: passwordController,
                  obscureText: _obscureText,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: '密碼',
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    hintText: '輸入您的密碼',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF6366f1).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF6366f1).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366f1),
                        width: 2,
                      ),
                    ),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366f1).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Color(0xFF60a5fa),
                        size: 20,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF60a5fa),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscureText = !_obscureText);
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1a2a4e),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請輸入密碼';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 錯誤提示
                // 錯誤提示
                if (PromptMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFef4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFef4444),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error,
                          color: Color(0xFFef4444),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            PromptMessage,
                            style: const TextStyle(
                              color: Color(0xFFef4444),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 登入按鈕
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366f1),
                        const Color(0xFF60a5fa),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366f1).withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoggingIn ? null : _login,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        alignment: Alignment.center,
                        child:
                            _isLoggingIn
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      '登入中...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                )
                                : const Text(
                                  '登入',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // 註冊連結
                // 註冊連結
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '沒有帳號？',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SignupPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '立即註冊',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF60a5fa),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
