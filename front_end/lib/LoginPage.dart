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

  final requestBody = {'account': username, 'password': password};

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

      // 檢查後端回應格式
      if (data['success'] == true && data['data']?['success'] == true) {
        return data['data']['userId']; // 返回用戶ID
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

Future<void> StoreDataInSharedPrederences(int userId) async {
  final userInfoUrl = '$baseUrl/user?userid=$userId';

  print('用戶資料API URL: $userInfoUrl');

  try {
    final userInfoResponse = await http.get(Uri.parse(userInfoUrl));

    print('用戶資料回應狀態碼: ${userInfoResponse.statusCode}');
    print('用戶資料回應內容: ${userInfoResponse.body}');

    if (userInfoResponse.statusCode == 200) {
      final responseData = jsonDecode(userInfoResponse.body);

      // 檢查回應格式
      if (responseData is Map<String, dynamic>) {
        // 如果是新的API格式 {success: true, data: [...]}
        if (responseData['success'] == true && responseData['data'] is List) {
          final List<dynamic> userData = responseData['data'];
          if (userData.isNotEmpty) {
            await _storeUserPreferences(userData[0]);
          }
        } else {
          print('用戶資料回應格式不正確: $responseData');
        }
      } else if (responseData is List<dynamic>) {
        // 如果是舊的API格式，直接是陣列
        final List<dynamic> userData = responseData;
        if (userData.isNotEmpty) {
          await _storeUserPreferences(userData[0]);
        }
      } else {
        print('未知的用戶資料格式: ${responseData.runtimeType}');
      }
    } else {
      print('獲取用戶資料失敗: ${userInfoResponse.statusCode}');
    }
  } catch (e) {
    print('獲取用戶資料異常: $e');
  }
}

// 輔助函數：儲存用戶偏好設定
Future<void> _storeUserPreferences(Map<String, dynamic> user) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // 根據實際的資料庫欄位名稱進行適配
    final userId = user['UserID'] ?? user['user_id'] ?? 0;
    final account = user['Account'] ?? user['user_account'] ?? '';
    final password = user['Password'] ?? user['user_password'] ?? '';
    final isManager = user['IsManager'] ?? user['is_manager'] ?? 0;

    await prefs.setInt('UserID', userId);
    await prefs.setString('Account', account);
    await prefs.setString('Password', password);
    await prefs.setInt('IsManager', isManager);
    await prefs.setBool('IsLogin', true);

    print(
      '用戶資料已存儲到SharedPreferences: UserID=$userId, Account=$account, IsManager=$isManager',
    );
  } catch (e) {
    print('存儲用戶資料到SharedPreferences失敗: $e');
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

  // 動畫控制器
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化動畫
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // 啟動動畫
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    accountController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 智能導航檢查
  Future<void> _navigateAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final account = prefs.getString('Account') ?? '';
    final isManager = prefs.getInt('IsManager') ?? 0;

    // 檢查是否為admin開頭的管理員帳號
    bool isAdminAccount = account.toLowerCase().startsWith('admin');

    // 管理員判斷：後端IsManager欄位為1 或 帳號以admin開頭
    if (isManager == 1 || isAdminAccount) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminPage()),
      );
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[400]!, Colors.blue[600]!, Colors.purple[400]!],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              height:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo 區域
                      Container(
                        margin: const EdgeInsets.only(bottom: 48),
                        child: Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    spreadRadius: 2,
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.newspaper,
                                size: 60,
                                color: Colors.blue[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '歡迎回來',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '請登入您的帳號',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 登入表單
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 0,
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // 帳號輸入框
                              _buildInputField(
                                controller: accountController,
                                label: '帳號',
                                hint: '請輸入您的帳號',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '請輸入帳號';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              // 密碼輸入框
                              _buildInputField(
                                controller: passwordController,
                                label: '密碼',
                                hint: '請輸入您的密碼',
                                icon: Icons.lock_outline,
                                obscureText: _obscureText,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureText
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureText = !_obscureText;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '請輸入密碼';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 32),

                              // 狀態訊息
                              if (PromptMessage.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        PromptMessage == "成功登入!"
                                            ? Colors.green[50]
                                            : PromptMessage == "登入中..."
                                            ? Colors.blue[50]
                                            : Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          PromptMessage == "成功登入!"
                                              ? Colors.green[300]!
                                              : PromptMessage == "登入中..."
                                              ? Colors.blue[300]!
                                              : Colors.red[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        PromptMessage == "成功登入!"
                                            ? Icons.check_circle_outline
                                            : PromptMessage == "登入中..."
                                            ? Icons.access_time
                                            : Icons.error_outline,
                                        size: 20,
                                        color:
                                            PromptMessage == "成功登入!"
                                                ? Colors.green[700]
                                                : PromptMessage == "登入中..."
                                                ? Colors.blue[700]
                                                : Colors.red[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        PromptMessage,
                                        style: TextStyle(
                                          color:
                                              PromptMessage == "成功登入!"
                                                  ? Colors.green[700]
                                                  : PromptMessage == "登入中..."
                                                  ? Colors.blue[700]
                                                  : Colors.red[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // 登入按鈕
                              Container(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoggingIn ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _isLoggingIn
                                            ? Colors.grey[400]
                                            : Colors.blue[600],
                                    foregroundColor: Colors.white,
                                    elevation: _isLoggingIn ? 0 : 8,
                                    shadowColor: Colors.blue.withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child:
                                      _isLoggingIn
                                          ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                '登入中...',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                          : const Text(
                                            '登入',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 註冊連結
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '還沒有帳號？',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                '立即註冊',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
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
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue[600], size: 20),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 開始登入流程
    setState(() {
      _isLoggingIn = true;
      PromptMessage = "登入中...";
    });

    try {
      // 檢查輸入帳號密碼是否正確
      final userId = await checkUserLogin(
        accountController.text,
        passwordController.text,
      );

      if (userId != 0) {
        setState(() {
          PromptMessage = "成功登入!";
        });

        // 儲存帳號資料至shared_preferences
        await StoreDataInSharedPrederences(userId);

        // 延遲1秒後智能導航
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          await _navigateAfterLogin();
        }
      } else {
        setState(() {
          PromptMessage = "帳號、密碼錯誤!";
          _isLoggingIn = false;
        });
      }
    } catch (e) {
      setState(() {
        PromptMessage = "登入失敗: $e";
        _isLoggingIn = false;
      });
    }
  }
}
