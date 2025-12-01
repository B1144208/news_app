import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 連接頁面
import 'config.dart';
import 'LoginPage.dart';

Future<bool> insertUser(String account, String password) async {
  final url = '$baseUrl/user/signup';

  // 根據 insertUser 函數，後端期望 'account' 和 'password'
  final Map<String, String> body = {
    'account': account, // 不是 user_account
    'password': password, // 不是 user_password
  };

  print('註冊API URL: $url');
  print('註冊請求內容: $body');

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    print('註冊回應狀態碼: ${response.statusCode}');
    print('註冊回應內容: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // 根據 insertUser 的回傳格式
      if (data['success'] == true) {
        print(
          'User added Successfully, insertId: ${data['data']?['insertId']}',
        );
        return true;
      } else {
        print('註冊失敗: ${data['message']}');
        return false;
      }
    } else {
      try {
        final errorResponse = jsonDecode(response.body);
        print('Error: ${errorResponse['message'] ?? errorResponse['error']}');
      } catch (e) {
        print('Error: ${response.body}');
      }
      return false;
    }
  } catch (e) {
    print('註冊請求異常: $e');
    return false;
  }
}

// 檢查帳號是否存在 - 這個函數需要後端支援，或者可以先簡化
Future<bool> checkAccountExist(String username) async {
  // 暫時總是返回 false，讓註冊流程繼續
  // 實際的重複檢查會在後端進行
  return false;
}

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController accountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController password2Controller = TextEditingController();

  bool _obscureText = true;
  bool _obscureText2 = true;
  String promptMessage = "";
  bool _isChecking = false; // 防止重複檢查
  bool _isRegistering = false; // 註冊進行中

  @override
  void initState() {
    super.initState();

    // 修正帳號監聽器
    accountController.addListener(() async {
      if (_isChecking) return;
      _isChecking = true;

      final account = accountController.text.trim();

      if (account.isEmpty) {
        setState(() {
          promptMessage = "";
        });
        _isChecking = false;
        return;
      }

      // 檢查是否為管理員格式
      if (_isAdminFormat(account)) {
        setState(() {
          promptMessage = "此帳號格式為系統保留，請使用其他帳號";
        });
        _isChecking = false;
        return;
      }

      // 檢查帳號是否已存在
      final exists = await checkAccountExist(account);
      setState(() {
        if (exists) {
          promptMessage = "該帳號已經存在！";
        } else {
          promptMessage = "";
        }
      });
      _isChecking = false;
    });

    // 密碼確認監聽器
    passwordController.addListener(_checkPasswordMatch);
    password2Controller.addListener(_checkPasswordMatch);
  }

  void _checkPasswordMatch() {
    if (passwordController.text.isNotEmpty &&
        password2Controller.text.isNotEmpty) {
      setState(() {
        if (passwordController.text != password2Controller.text) {
          promptMessage = "密碼不一致！";
        } else {
          promptMessage = "";
        }
      });
    }
  }

  // 檢查是否為管理員帳號格式
  bool _isAdminFormat(String account) {
    final accountLower = account.toLowerCase();
    // 檢查是否為 admin 或 admin + 數字格式
    if (accountLower == 'admin') return true;
    final adminPattern = RegExp(r'^admin\d+$');
    return adminPattern.hasMatch(accountLower);
  }

  // 驗證帳號
  Future<bool> _validateAccount() async {
    final account = accountController.text.trim();

    // 檢查是否為空
    if (account.isEmpty) {
      setState(() {
        promptMessage = "帳號不能為空！";
      });
      return false;
    }

    // 檢查帳號長度
    if (account.length < 3) {
      setState(() {
        promptMessage = "帳號至少需要3個字元！";
      });
      return false;
    }

    // 檢查是否為管理員格式
    if (_isAdminFormat(account)) {
      setState(() {
        promptMessage = "此帳號格式為系統保留，請使用其他帳號";
      });
      return false;
    }

    // 檢查帳號是否已存在
    final exists = await checkAccountExist(account);
    if (exists) {
      setState(() {
        promptMessage = "該帳號已經存在！";
      });
      return false;
    }

    return true;
  }

  // 執行註冊
  Future<void> _performSignup() async {
    if (!_formKey.currentState!.validate()) return;

    // 帳號密碼不能為空
    if (accountController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        password2Controller.text.isEmpty) {
      setState(() {
        promptMessage = "帳號、密碼不能為空！";
      });
      return;
    }

    // 密碼一致性檢查
    if (passwordController.text != password2Controller.text) {
      setState(() {
        promptMessage = "密碼不一致！";
      });
      return;
    }

    // 密碼長度檢查
    if (passwordController.text.length < 6) {
      setState(() {
        promptMessage = "密碼至少需要6個字元！";
      });
      return;
    }

    // 驗證帳號
    final isValidAccount = await _validateAccount();
    if (!isValidAccount) return;

    // 清除錯誤訊息
    setState(() {
      promptMessage = "註冊中...";
      _isRegistering = true;
    });

    // 執行註冊
    try {
      final success = await insertUser(
        accountController.text.trim(),
        passwordController.text,
      );

      if (success) {
        setState(() {
          promptMessage = "成功註冊!";
        });

        await Future.delayed(Duration(seconds: 2));

        if (mounted) {
          // 顯示成功訊息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '註冊成功！請使用新帳號登入',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF34d399),
              duration: Duration(seconds: 3),
            ),
          );

          // 返回登入頁面
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      } else {
        setState(() {
          promptMessage = "註冊失敗，請重試";
          _isRegistering = false;
        });
      }
    } catch (e) {
      print('異常: $e');
      setState(() {
        promptMessage = "發生錯誤: $e";
        _isRegistering = false;
      });
    }
  }

  // 帳號類型指示器
  Widget _buildAccountTypeIndicator() {
    final account = accountController.text.trim();
    if (account.isEmpty) return SizedBox.shrink();

    if (_isAdminFormat(account)) {
      return Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '此為系統保留帳號格式',
          style: TextStyle(color: const Color(0xFFf59e0b), fontSize: 12),
        ),
      );
    }

    return SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: const Color(0xFF60a5fa)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0a1428),
              const Color(0xFF0a1428).withOpacity(0.95),
              const Color(0xFF0f1e3d),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo or Header
                Container(
                  width: 90,
                  height: 90,
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
                  child: const Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: 48,
                  ),
                ),

                const SizedBox(height: 32),

                // 標題
                Text(
                  '建立帳號',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 12),

                // 副標題
                Text(
                  '加入我們，享受更多新聞資訊',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 48),

                // 表單
                Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0a0e27),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF6366f1).withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366f1).withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 帳號輸入框
                        _buildFormField(
                          controller: accountController,
                          label: '帳號',
                          icon: Icons.person,
                          hintText: '請輸入您的帳號（至少3個字元）',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '請輸入帳號';
                            }
                            if (value.trim().length < 3) {
                              return '帳號至少需要3個字元';
                            }
                            return null;
                          },
                          additionalWidget: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFf59e0b),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFf59e0b)!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: const Color(0xFF6366f1),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '帳號一旦設定，之後無法更改',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: const Color(0xFF6366f1),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildAccountTypeIndicator(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 密碼輸入框
                        _buildFormField(
                          controller: passwordController,
                          label: '密碼',
                          icon: Icons.lock,
                          hintText: '請輸入密碼（至少6個字元）',
                          obscureText: _obscureText,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF94a3b8),
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
                            if (value.length < 6) {
                              return '密碼至少需要6個字元';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // 確認密碼輸入框
                        _buildFormField(
                          controller: password2Controller,
                          label: '確認密碼',
                          icon: Icons.lock_outline,
                          hintText: '請再次輸入密碼',
                          obscureText: _obscureText2,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText2
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF94a3b8),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText2 = !_obscureText2;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '請確認密碼';
                            }
                            if (value != passwordController.text) {
                              return '密碼不一致';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 顯示訊息
                if (promptMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color:
                          promptMessage == "成功註冊!"
                              ? const Color(0xFF34d399).withOpacity(0.15)
                              : promptMessage == "註冊中..."
                              ? const Color(0xFF60a5fa).withOpacity(0.15)
                              : const Color(0xFFef4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            promptMessage == "成功註冊!"
                                ? const Color(0xFF34d399)
                                : promptMessage == "註冊中..."
                                ? const Color(0xFF60a5fa)
                                : const Color(0xFFef4444),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          promptMessage == "成功註冊!"
                              ? Icons.check_circle
                              : promptMessage == "註冊中..."
                              ? Icons.hourglass_empty
                              : Icons.error,
                          color:
                              promptMessage == "成功註冊!"
                                  ? const Color(0xFF34d399)
                                  : promptMessage == "註冊中..."
                                  ? const Color(0xFF60a5fa)
                                  : const Color(0xFFef4444),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            promptMessage,
                            style: TextStyle(
                              color:
                                  promptMessage == "成功註冊!"
                                      ? const Color(0xFF34d399)
                                      : promptMessage == "註冊中..."
                                      ? const Color(0xFF60a5fa)
                                      : const Color(0xFFef4444),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 註冊按鈕
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
                      onTap: _isRegistering ? null : _performSignup,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        alignment: Alignment.center,
                        child:
                            _isRegistering
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      '正在註冊...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                                : const Text(
                                  '建立帳號',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 登入連結
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '已經有帳號了？',
                      style: TextStyle(color: const Color(0xFF94a3b8)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),
                        );
                      },
                      child: Text(
                        '立即登入',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF60a5fa),
                        ),
                      ),
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    Widget? additionalWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
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
              borderSide: const BorderSide(color: Color(0xFF6366f1), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFef4444), width: 1),
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366f1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF60a5fa), size: 20),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF1a2a4e),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        if (additionalWidget != null) ...[
          const SizedBox(height: 10),
          additionalWidget,
        ],
      ],
    );
  }
}
