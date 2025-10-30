import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'ChangePasswordPage.dart';
import 'EmailVerificationPage.dart';
import 'PhoneVerificationPage.dart';
import 'DeleteAccountPage.dart';
import 'main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  bool _darkModeEnabled = false;
  bool _autoPlayVideo = true;
  String _fontSize = 'medium';
  String _language = 'zh_TW';

  // 帳號驗證狀態
  String? _userEmail;
  String? _userPhone;
  bool _emailVerified = false;
  bool _phoneVerified = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserInfo();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _pushNotificationsEnabled =
          prefs.getBool('push_notifications_enabled') ?? true;
      _emailNotificationsEnabled =
          prefs.getBool('email_notifications_enabled') ?? false;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      _autoPlayVideo = prefs.getBool('auto_play_video') ?? true;
      _fontSize = prefs.getString('font_size') ?? 'medium';
      _language = prefs.getString('language') ?? 'zh_TW';
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userEmail = prefs.getString('UserEmail');
        _userPhone = prefs.getString('UserPhone');
        _emailVerified = prefs.getBool('EmailVerified') ?? false;
        _phoneVerified = prefs.getBool('PhoneVerified') ?? false;
      });
    } catch (e) {
      print('載入用戶信息錯誤: $e');
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '新聞應用',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 新聞應用開發團隊',
      children: const [
        Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('這是一個功能豐富的新聞閱讀應用，提供最新的新聞資訊和個人化的閱讀體驗。'),
        ),
      ],
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('選擇語言'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('繁體中文'),
                  value: 'zh_TW',
                  groupValue: _language,
                  onChanged: (value) {
                    setState(() => _language = value!);
                    _saveSetting('language', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('簡體中文'),
                  value: 'zh_CN',
                  groupValue: _language,
                  onChanged: (value) {
                    setState(() => _language = value!);
                    _saveSetting('language', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'en',
                  groupValue: _language,
                  onChanged: (value) {
                    setState(() => _language = value!);
                    _saveSetting('language', value);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('選擇字體大小'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('小', style: TextStyle(fontSize: 12)),
                  value: 'small',
                  groupValue: _fontSize,
                  onChanged: (value) {
                    setState(() => _fontSize = value!);
                    _saveSetting('font_size', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('中', style: TextStyle(fontSize: 14)),
                  value: 'medium',
                  groupValue: _fontSize,
                  onChanged: (value) {
                    setState(() => _fontSize = value!);
                    _saveSetting('font_size', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('大', style: TextStyle(fontSize: 16)),
                  value: 'large',
                  groupValue: _fontSize,
                  onChanged: (value) {
                    setState(() => _fontSize = value!);
                    _saveSetting('font_size', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('超大', style: TextStyle(fontSize: 18)),
                  value: 'extra_large',
                  groupValue: _fontSize,
                  onChanged: (value) {
                    setState(() => _fontSize = value!);
                    _saveSetting('font_size', value);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('清除快取'),
            content: const Text('確定要清除應用快取嗎？這將清除暫存的圖片和資料。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('快取已清除'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('確定'),
              ),
            ],
          ),
    );
  }

  String _getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'zh_TW':
        return '繁體中文';
      case 'zh_CN':
        return '簡體中文';
      case 'en':
        return 'English';
      default:
        return '繁體中文';
    }
  }

  String _getFontSizeDisplayName(String fontSize) {
    switch (fontSize) {
      case 'small':
        return '小';
      case 'medium':
        return '中';
      case 'large':
        return '大';
      case 'extra_large':
        return '超大';
      default:
        return '中';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ========== 通知設定 ==========
            _buildSectionHeader('通知設定'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  SwitchListTile(
                    title: const Text('啟用通知'),
                    subtitle: const Text('接收應用通知'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() => _notificationsEnabled = value);
                      _saveSetting('notifications_enabled', value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('推送通知'),
                    subtitle: const Text('接收即時推送通知'),
                    value: _pushNotificationsEnabled && _notificationsEnabled,
                    onChanged:
                        _notificationsEnabled
                            ? (value) {
                              setState(() => _pushNotificationsEnabled = value);
                              _saveSetting('push_notifications_enabled', value);
                            }
                            : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('電子郵件通知'),
                    subtitle: const Text('接收電子郵件通知'),
                    value: _emailNotificationsEnabled && _notificationsEnabled,
                    onChanged:
                        _notificationsEnabled
                            ? (value) {
                              setState(
                                () => _emailNotificationsEnabled = value,
                              );
                              _saveSetting(
                                'email_notifications_enabled',
                                value,
                              );
                            }
                            : null,
                  ),
                ],
              ),
            ),

            // ========== 顯示設定 ==========
            _buildSectionHeader('顯示設定'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  SwitchListTile(
                    title: const Text('深色模式'),
                    subtitle: const Text('使用深色主題'),
                    value: _darkModeEnabled,
                    onChanged: (value) {
                      // 1. 更新本地狀態（用於顯示開關狀態）
                      setState(() => _darkModeEnabled = value);

                      // 2. 使用 Provider 更新全局主題狀態
                      // ✅ 改為 ThemeManager（與 main.dart 一致）
                      // ✅ 使用 toggleTheme() 方法
                      Provider.of<ThemeManager>(
                        context,
                        listen: false,
                      ).toggleTheme();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('字體大小'),
                    subtitle: Text(_getFontSizeDisplayName(_fontSize)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showFontSizeDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('語言'),
                    subtitle: Text(_getLanguageDisplayName(_language)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showLanguageDialog,
                  ),
                ],
              ),
            ),

            // ========== 媒體設定 ==========
            _buildSectionHeader('媒體設定'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              child: SwitchListTile(
                title: const Text('自動播放影片'),
                subtitle: const Text('在行動網路下自動播放影片'),
                value: _autoPlayVideo,
                onChanged: (value) {
                  setState(() => _autoPlayVideo = value);
                  _saveSetting('auto_play_video', value);
                },
              ),
            ),

            // ========== 儲存與快取 ==========
            _buildSectionHeader('儲存與快取'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              child: ListTile(
                title: const Text('清除快取'),
                subtitle: const Text('清除暫存的圖片和資料'),
                leading: Icon(Icons.cleaning_services, color: Colors.orange),
                trailing: const Icon(Icons.chevron_right),
                onTap: _clearCache,
              ),
            ),

            // ========== 關於 ==========
            _buildSectionHeader('關於'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  ListTile(
                    title: const Text('關於應用'),
                    subtitle: const Text('版本資訊與開發團隊'),
                    leading: Icon(Icons.info_outline, color: Colors.blue),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showAboutDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('隱私政策'),
                    subtitle: const Text('查看隱私政策'),
                    leading: Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.green,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('隱私政策頁面開發中')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('服務條款'),
                    subtitle: const Text('查看服務條款'),
                    leading: Icon(
                      Icons.description_outlined,
                      color: Colors.purple,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('服務條款頁面開發中')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('意見反饋'),
                    subtitle: const Text('提供意見或回報問題'),
                    leading: Icon(Icons.feedback_outlined, color: Colors.teal),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('意見反饋功能開發中')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
