import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  int _resendCountdown = 0;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('UserEmail');
    if (savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
      });
    }
  }

  Future<void> _sendVerificationCode() async {
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = '請輸入郵箱地址');
      return;
    }

    if (!_emailController.text.contains('@')) {
      setState(() => _errorMessage = '請輸入有效的郵箱地址');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID');

      if (userId == null) {
        setState(() => _errorMessage = '未登錄');
        return;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'action': 'send-email-code',
          'email': _emailController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _codeSent = true;
              _successMessage = data['message'] ?? '驗證碼已發送';
              _resendCountdown = 60;
              _startCountdown();
            });
          }
        } else {
          if (mounted) {
            setState(() => _errorMessage = data['message'] ?? '發送失敗');
          }
        }
      } else {
        if (mounted) {
          setState(() => _errorMessage = '伺服器錯誤');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '網路錯誤: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendCountdown--;
        });
      }
      return _resendCountdown > 0;
    });
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.isEmpty) {
      _showError('請輸入驗證碼');
      return;
    }

    _clearMessages();
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID');

      if (userId == null) {
        _showError('未登錄');
        return;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'action': 'verify-email-code',
          'email': _emailController.text,
          'code': _codeController.text,
        }),
      );

      print('【驗證碼驗證】');
      print('狀態碼: ${response.statusCode}');
      print('響應: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('success: ${data['success']}');
        print('message: ${data['message']}');

        if (data['success'] == true) {
          await prefs.setString('UserEmail', _emailController.text);
          await prefs.setBool('EmailVerified', true);
          _showSuccess('郵箱驗證成功！');

          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          // ❌ 驗證失敗 - 立即顯示錯誤
          String message = data['message'] ?? '驗證失敗';
          print('【錯誤訊息】: $message');

          if (message.contains('不正確') ||
              message.contains('錯誤') ||
              message.contains('次數')) {
            _showError('❌ 驗證碼錯誤！請重新輸入');
          } else {
            _showError(message);
          }
        }
      } else {
        _showError('伺服器錯誤 (${response.statusCode})');
      }
    } catch (e) {
      print('【異常】: $e');
      _showError('網路錯誤: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 輔助方法：立即顯示錯誤（強制刷新）
  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _successMessage = null;
      });
      print('【UI 更新】顯示錯誤: $message');
    }
  }

  // 輔助方法：立即顯示成功
  void _showSuccess(String message) {
    if (mounted) {
      setState(() {
        _successMessage = message;
        _errorMessage = null;
      });
      print('【UI 更新】顯示成功: $message');
    }
  }

  // 輔助方法：清除所有訊息
  void _clearMessages() {
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _successMessage = null;
      });
    }
  }

  // 輔助方法：設置加載狀態
  void _setLoading(bool isLoading) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        title: const Text(
          '郵箱驗證',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1a2a4e),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2a4e),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3b82f6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '驗證您的郵箱',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '驗證郵箱以加強帳號安全性，並接收重要通知',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '郵箱地址',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: '請輸入您的郵箱地址',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Color(0xFF6366f1).withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Color(0xFF6366f1).withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF3b82f6),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0a1428),
                      prefixIcon: Icon(Icons.mail, color: Color(0xFF60a5fa)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading || (_codeSent && _resendCountdown > 0)
                    ? null
                    : _sendVerificationCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a2a4e),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _codeSent && _resendCountdown > 0
                      ? '重新發送 ($_resendCountdown秒)'
                      : _isLoading
                      ? '發送中...'
                      : '發送驗證碼',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (_codeSent)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a2a4e),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6366f1).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '驗證碼',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: '請輸入6位驗證碼',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Color(0xFF6366f1).withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Color(0xFF6366f1).withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF3b82f6),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0a1428),
                        prefixIcon: Icon(
                          Icons.vpn_key,
                          color: Color(0xFF60a5fa),
                        ),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '驗證碼已發送到 ${_emailController.text}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            if (_codeSent)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10b981),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _isLoading ? '驗證中...' : '確認驗證',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ✅ 錯誤提示 - 立即顯示
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a2a4e),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFef4444)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFFef4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Color(0xFFef4444),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ✅ 成功提示 - 立即顯示
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a2a4e),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10b981)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF10b981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(
                          color: Color(0xFF10b981),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
