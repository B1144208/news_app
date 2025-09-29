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
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

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
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      } else {
        setState(() {
          promptMessage = "註冊失敗，請稍後再試！";
        });
      }
    } catch (e) {
      setState(() {
        promptMessage = "註冊發生錯誤：$e";
      });
    } finally {
      setState(() {
        _isRegistering = false;
      });
    }
  }

  Widget _buildAccountTypeIndicator() {
    final account = accountController.text.trim().toLowerCase();
    if (account.isEmpty) return Container();

    bool isAdminFormat = _isAdminFormat(account);

    if (isAdminFormat) {
      return Container(
        margin: EdgeInsets.only(top: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 16, color: Colors.red),
            SizedBox(width: 6),
            Text(
              '系統保留格式',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container();
  }

  @override
  void dispose() {
    accountController.dispose();
    passwordController.dispose();
    password2Controller.dispose();
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '註冊',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
            child: const Text('已有帳號？登入', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  SizedBox(height: 20),

                  // 標題區域
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.green[400]!, Colors.green[600]!],
                            ),
                          ),
                          child: Icon(
                            Icons.person_add,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '建立新帳號',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '請填寫以下資訊完成註冊',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 表單區域
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: Offset(0, 2),
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
                          additionalWidget: _buildAccountTypeIndicator(),
                        ),

                        const SizedBox(height: 20),

                        // 姓名輸入框（可選）
                        _buildFormField(
                          controller: nameController,
                          label: '姓名（可選）',
                          icon: Icons.badge,
                          hintText: '請輸入您的姓名',
                        ),

                        const SizedBox(height: 20),

                        // 電子郵件輸入框（可選）
                        _buildFormField(
                          controller: emailController,
                          label: '電子郵件（可選）',
                          icon: Icons.email,
                          hintText: '請輸入您的電子郵件',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return '請輸入有效的電子郵件格式';
                              }
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

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
                            if (value.length < 6) {
                              return '密碼至少需要6個字元';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

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
                              color: Colors.grey[600],
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

                  const SizedBox(height: 20),

                  // 顯示訊息
                  if (promptMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color:
                            promptMessage == "成功註冊!"
                                ? Colors.green[50]
                                : promptMessage == "註冊中..."
                                ? Colors.blue[50]
                                : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              promptMessage == "成功註冊!"
                                  ? Colors.green
                                  : promptMessage == "註冊中..."
                                  ? Colors.blue
                                  : Colors.red,
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
                                    ? Colors.green[700]
                                    : promptMessage == "註冊中..."
                                    ? Colors.blue[700]
                                    : Colors.red[700],
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              promptMessage,
                              style: TextStyle(
                                color:
                                    promptMessage == "成功註冊!"
                                        ? Colors.green[700]
                                        : promptMessage == "註冊中..."
                                        ? Colors.blue[700]
                                        : Colors.red[700],
                                fontWeight: FontWeight.w500,
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
                    child: ElevatedButton(
                      onPressed: _isRegistering ? null : _performSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                      child:
                          _isRegistering
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    '註冊中...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                              : Text(
                                '註冊',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 登入連結
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '已經有帳號了？',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginPage(),
                            ),
                          );
                        },
                        child: Text(
                          '立即登入',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
            prefixIcon: Container(
              margin: EdgeInsets.all(8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue, size: 20),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
        if (additionalWidget != null) additionalWidget,
      ],
    );
  }
}
