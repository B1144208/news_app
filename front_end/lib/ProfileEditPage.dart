import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'UserService.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailCodeController = TextEditingController();
  final TextEditingController _phoneCodeController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _userAccount = '';
  int _userId = 0;

  // 郵箱驗證狀態
  bool _emailCodeSent = false;
  bool _emailVerifying = false;
  bool _emailVerified = false; // ✅ 添加：郵箱驗證完成標記
  String? _emailErrorMessage;
  String? _emailSuccessMessage;
  int _emailResendCountdown = 0;

  // 手機驗證狀態
  bool _phoneCodeSent = false;
  bool _phoneVerifying = false;
  bool _phoneVerified = false; // ✅ 添加：手機驗證完成標記
  String? _phoneErrorMessage;
  String? _phoneSuccessMessage;
  int _phoneResendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _nameController.dispose();
    _birthdayController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emailCodeController.dispose();
    _phoneCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();

      final account = prefs.getString('Account') ?? '';
      final userId = prefs.getInt('UserID') ?? 0;
      final name = prefs.getString('UserName') ?? '';
      final email = prefs.getString('UserEmail') ?? '';
      final phone = prefs.getString('UserPhone') ?? '';

      // ✅ 時區終極修復 - 使用 toLocal() 轉換
      var birthday = prefs.getString('UserBirthday') ?? '';
      if (birthday.isNotEmpty) {
        try {
          // 先解析為 UTC DateTime
          final utcDateTime = DateTime.parse(birthday);
          // 轉換為本地時區
          final localDateTime = utcDateTime.toLocal();
          // 提取日期部分
          birthday = localDateTime.toIso8601String().substring(0, 10);

          print('🔍 生日時區轉換調試:');
          print('   原始數據: ${prefs.getString('UserBirthday')}');
          print('   UTC DateTime: $utcDateTime');
          print('   Local DateTime: $localDateTime');
          print('   最終格式: $birthday');
        } catch (e) {
          // 如果解析失敗，直接截取前 10 個字符
          var rawBirthday = prefs.getString('UserBirthday') ?? '';
          if (rawBirthday.length >= 10) {
            birthday = rawBirthday.substring(0, 10);
          }
          print('❌ 生日解析失敗，使用 substring: $e');
        }
      }

      setState(() {
        _userAccount = account;
        _userId = userId;
        _accountController.text = account;
        _nameController.text = name;
        _birthdayController.text = birthday;
        _emailController.text = email;
        _phoneController.text = phone;
        // ✅ 根據已保存的數據初始化驗證狀態
        _emailVerified = email.isNotEmpty;
        _phoneVerified = phone.isNotEmpty;
        _isLoading = false;
      });

      print('✅ 載入完成');
      print('   Account: $account');
      print('   Name: $name');
      print('   Birthday: $birthday');
      print('   Email: $email');
      print('   Phone: $phone');
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ 載入失敗: $e');
    }
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = picked.toString().split(' ')[0];
      });
    }
  }

  // 使用 UserService 發送郵箱驗證碼
  Future<void> _sendEmailCode() async {
    if (_emailController.text.isEmpty) {
      setState(() => _emailErrorMessage = '請輸入郵箱地址');
      return;
    }

    setState(() {
      _emailVerifying = true;
      _emailErrorMessage = null;
      _emailSuccessMessage = null;
    });

    try {
      final result = await _userService.sendEmailVerification(
        _emailController.text,
      );

      if (result['success'] == true) {
        setState(() {
          _emailCodeSent = true;
          _emailSuccessMessage = result['message'] ?? '驗證碼已發送';
          _emailResendCountdown = 60;
          _startEmailCountdown();
        });
        print('✅ 郵箱驗證碼已發送');
      } else {
        setState(() => _emailErrorMessage = result['message'] ?? '發送失敗');
      }
    } catch (e) {
      setState(() => _emailErrorMessage = '網路錯誤: $e');
      print('❌ 發送郵箱驗證碼失敗: $e');
    } finally {
      setState(() => _emailVerifying = false);
    }
  }

  void _startEmailCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _emailResendCountdown--;
        });
      }
      return _emailResendCountdown > 0;
    });
  }

  // 使用 UserService 驗證郵箱
  Future<void> _verifyEmail() async {
    if (_emailCodeController.text.isEmpty) {
      setState(() => _emailErrorMessage = '請輸入驗證碼');
      return;
    }

    setState(() {
      _emailVerifying = true;
      _emailErrorMessage = null;
    });

    try {
      final result = await _userService.verifyEmail(
        email: _emailController.text,
        code: _emailCodeController.text,
      );

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('UserEmail', _emailController.text);

        setState(() {
          _emailVerified = true; // ✅ 設置驗證完成標記
          _emailSuccessMessage = '郵箱驗證成功！';
          _emailCodeController.text = '';
          _emailCodeSent = false;
        });

        print('✅ 郵箱驗證成功');

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('郵箱驗證成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _emailErrorMessage = result['message'] ?? '驗證失敗');
      }
    } catch (e) {
      setState(() => _emailErrorMessage = '網路錯誤: $e');
      print('❌ 郵箱驗證失敗: $e');
    } finally {
      setState(() => _emailVerifying = false);
    }
  }

  // 使用 UserService 發送手機驗證碼
  Future<void> _sendPhoneCode() async {
    if (_phoneController.text.isEmpty) {
      setState(() => _phoneErrorMessage = '請輸入手機號碼');
      return;
    }

    setState(() {
      _phoneVerifying = true;
      _phoneErrorMessage = null;
      _phoneSuccessMessage = null;
    });

    try {
      final result = await _userService.sendPhoneVerification(
        _phoneController.text,
      );

      if (result['success'] == true) {
        setState(() {
          _phoneCodeSent = true;
          _phoneSuccessMessage = result['message'] ?? '驗證碼已發送';
          _phoneResendCountdown = 60;
          _startPhoneCountdown();
        });
        print('✅ 手機驗證碼已發送');
      } else {
        setState(() => _phoneErrorMessage = result['message'] ?? '發送失敗');
      }
    } catch (e) {
      setState(() => _phoneErrorMessage = '網路錯誤: $e');
      print('❌ 發送手機驗證碼失敗: $e');
    } finally {
      setState(() => _phoneVerifying = false);
    }
  }

  void _startPhoneCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _phoneResendCountdown--;
        });
      }
      return _phoneResendCountdown > 0;
    });
  }

  // 使用 UserService 驗證手機
  Future<void> _verifyPhone() async {
    if (_phoneCodeController.text.isEmpty) {
      setState(() => _phoneErrorMessage = '請輸入驗證碼');
      return;
    }

    setState(() {
      _phoneVerifying = true;
      _phoneErrorMessage = null;
    });

    try {
      final result = await _userService.verifyPhone(
        phone: _phoneController.text,
        code: _phoneCodeController.text,
      );

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('UserPhone', _phoneController.text);

        setState(() {
          _phoneVerified = true; // ✅ 設置驗證完成標記
          _phoneSuccessMessage = '手機驗證成功！';
          _phoneCodeController.text = '';
          _phoneCodeSent = false;
        });

        print('✅ 手機驗證成功');

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('手機驗證成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _phoneErrorMessage = result['message'] ?? '驗證失敗');
      }
    } catch (e) {
      setState(() => _phoneErrorMessage = '網路錯誤: $e');
      print('❌ 手機驗證失敗: $e');
    } finally {
      setState(() => _phoneVerifying = false);
    }
  }

  void _showEmailVerificationDialog() {
    _emailCodeSent = false;
    _emailCodeController.text = '';
    _emailErrorMessage = null;
    _emailSuccessMessage = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, dialogSetState) => AlertDialog(
                  title: const Text('郵箱驗證'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_emailErrorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _emailErrorMessage!,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (_emailSuccessMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _emailSuccessMessage!,
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Text(
                          '驗證碼已發送到: ${_emailController.text}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailCodeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          onChanged: (value) {
                            dialogSetState(() {});
                          },
                          decoration: const InputDecoration(
                            labelText: '請輸入驗證碼',
                            border: OutlineInputBorder(),
                            hintText: '6位數字',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _emailResendCountdown > 0
                                ? '${_emailResendCountdown}秒後可重新發送'
                                : '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('取消'),
                    ),
                    if (!_emailCodeSent)
                      ElevatedButton(
                        onPressed:
                            _emailVerifying
                                ? null
                                : () async {
                                  await _sendEmailCode();
                                  dialogSetState(() {});
                                },
                        child: Text(_emailVerifying ? '發送中...' : '發送驗證碼'),
                      ),
                    if (_emailCodeSent && _emailCodeController.text.length == 6)
                      ElevatedButton(
                        onPressed:
                            _emailVerifying
                                ? null
                                : () async {
                                  await _verifyEmail();
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: Text(_emailVerifying ? '驗證中...' : '確認驗證'),
                      ),
                  ],
                ),
          ),
    );
  }

  void _showPhoneVerificationDialog() {
    _phoneCodeSent = false;
    _phoneCodeController.text = '';
    _phoneErrorMessage = null;
    _phoneSuccessMessage = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, dialogSetState) => AlertDialog(
                  title: const Text('手機驗證'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_phoneErrorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _phoneErrorMessage!,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (_phoneSuccessMessage != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _phoneSuccessMessage!,
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Text(
                          '驗證碼已發送到: ${_phoneController.text}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneCodeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          onChanged: (value) {
                            dialogSetState(() {});
                          },
                          decoration: const InputDecoration(
                            labelText: '請輸入驗證碼',
                            border: OutlineInputBorder(),
                            hintText: '6位數字',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _phoneResendCountdown > 0
                                ? '${_phoneResendCountdown}秒後可重新發送'
                                : '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('取消'),
                    ),
                    if (!_phoneCodeSent)
                      ElevatedButton(
                        onPressed:
                            _phoneVerifying
                                ? null
                                : () async {
                                  await _sendPhoneCode();
                                  dialogSetState(() {});
                                },
                        child: Text(_phoneVerifying ? '發送中...' : '發送驗證碼'),
                      ),
                    if (_phoneCodeSent && _phoneCodeController.text.length == 6)
                      ElevatedButton(
                        onPressed:
                            _phoneVerifying
                                ? null
                                : () async {
                                  await _verifyPhone();
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: Text(_phoneVerifying ? '驗證中...' : '確認驗證'),
                      ),
                  ],
                ),
          ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final newName = _nameController.text.trim();
      final newBirthday = _birthdayController.text.trim();

      final result = await _userService.updateProfile(
        name: newName,
        email: _emailController.text,
        birthday: newBirthday,
      );

      if (result['success'] == true) {
        await prefs.setString('UserName', newName);
        if (newBirthday.isNotEmpty) {
          await prefs.setString('UserBirthday', newBirthday);
        }

        print('✅ 個人資料更新成功');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('個人資料更新成功'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '更新失敗'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ 更新資料異常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新時發生錯誤: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      appBar: AppBar(
        title: const Text('編輯個人資料'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && !_isSaving)
            TextButton(
              onPressed: _saveProfile,
              child: const Text('儲存', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 用戶頭像
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                              child: Center(
                                child: Text(
                                  _userAccount.isNotEmpty
                                      ? _userAccount[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'ID: $_userId',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 帳號
                      _buildTextField('帳號', _accountController, false),
                      const SizedBox(height: 16),

                      // 姓名
                      _buildTextField('姓名', _nameController, true),
                      const SizedBox(height: 16),

                      // 生日
                      _buildBirthdayField(),
                      const SizedBox(height: 16),

                      // 郵箱
                      _buildVerificationField(
                        title: '電子郵件',
                        controller: _emailController,
                        onVerifyPressed: _showEmailVerificationDialog,
                        isVerified: _emailVerified, // ✅ 改為使用驗證完成標記
                      ),
                      const SizedBox(height: 16),

                      // 手機
                      _buildVerificationField(
                        title: '手機號碼',
                        controller: _phoneController,
                        onVerifyPressed: _showPhoneVerificationDialog,
                        isVerified: _phoneVerified, // ✅ 改為使用驗證完成標記
                      ),
                      const SizedBox(height: 32),

                      // 儲存按鈕
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child:
                              _isSaving
                                  ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
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
                                      SizedBox(width: 12),
                                      Text('儲存中...'),
                                    ],
                                  )
                                  : const Text(
                                    '儲存變更',
                                    style: TextStyle(fontSize: 16),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    bool enabled,
  ) {
    return Container(
      width: double.infinity,
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
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: enabled,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              filled: !enabled,
              fillColor: !enabled ? Colors.grey[100] : Colors.white,
            ),
            validator: (value) {
              if (enabled && (value == null || value.trim().isEmpty)) {
                return '請輸入$label';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayField() {
    return Container(
      width: double.infinity,
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
            '生日',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _birthdayController,
            readOnly: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: '請選擇生日',
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _selectBirthday,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationField({
    required String title,
    required TextEditingController controller,
    required VoidCallback onVerifyPressed,
    required bool isVerified,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        // ✅ 為郵箱和手機添加格式檢查
        bool isEmailField = title == '電子郵件';
        bool isPhoneField = title == '手機號碼';
        String _getPhoneErrorMessage(String phone) {
          final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

          if (phone != digits) {
            return '不能包含非數字字符';
          }

          if (digits.length < 8) {
            return '至少需要 10 位數字';
          }

          if (digits.length > 15) {
            return '最多 15 位數字';
          }

          return '格式不正確';
        }

        // 郵箱驗証：必須包含 @ 和 .
        bool emailValid =
            !isEmailField ||
            (controller.text.contains('@') && controller.text.contains('.'));

        // 手機驗証：必須是 8-15 位純數字
        bool phoneValid =
            !isPhoneField ||
            (controller.text.replaceAll(RegExp(r'[^\d]'), '').length >= 10 &&
                controller.text.replaceAll(RegExp(r'[^\d]'), '').length <= 15 &&
                controller.text.replaceAll(RegExp(r'[^\d]'), '') ==
                    controller.text);

        bool hasValidFormat = emailValid && phoneValid;

        return Container(
          width: double.infinity,
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
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isVerified)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Text(
                          '已認證',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Text(
                          '未認證',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      enabled: true,
                      onChanged: (value) {
                        setState(() {}); // ✅ 實時檢查格式
                      },
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '請輸入',
                        // ✅ 只為郵箱添加格式錯誤提示
                        errorText:
                            isEmailField &&
                                    controller.text.isNotEmpty &&
                                    !emailValid
                                ? '格式不正確'
                                : (isPhoneField &&
                                        controller.text.isNotEmpty &&
                                        !phoneValid
                                    ? _getPhoneErrorMessage(controller.text)
                                    : null),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    // ✅ 修改：手機沒有格式限制，郵箱需要格式正確
                    onPressed:
                        controller.text.isEmpty || !hasValidFormat
                            ? null
                            : onVerifyPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          controller.text.isEmpty || !hasValidFormat
                              ? Colors.grey
                              : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isVerified ? '已認證' : '認證',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
