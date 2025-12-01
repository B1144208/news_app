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
            backgroundColor: const Color(0xFF0a0e27),
            title: const Text('選擇語言', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text(
                    '繁體中文',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: 'zh_TW',
                  groupValue: _language,
                  activeColor: const Color(0xFF60a5fa),
                  onChanged: (value) {
                    setState(() => _language = value!);
                    _saveSetting('language', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text(
                    '簡體中文',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: 'zh_CN',
                  groupValue: _language,
                  activeColor: const Color(0xFF60a5fa),
                  onChanged: (value) {
                    setState(() => _language = value!);
                    _saveSetting('language', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text(
                    'English',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: 'en',
                  groupValue: _language,
                  activeColor: const Color(0xFF60a5fa),
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
            backgroundColor: const Color(0xFF0a0e27),
            title: const Text('選擇字體大小', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text(
                    '小',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  value: 'small',
                  groupValue: _fontSize,
                  activeColor: const Color(0xFF60a5fa),
                  onChanged: (value) {
                    setState(() => _fontSize = value!);
                    _saveSetting('font_size', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text(
                    '中',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  value: 'medium',
                  groupValue: _fontSize,
                  activeColor: const Color(0xFF60a5fa),
                  onChanged: (value) {
                    setState(() => _fontSize = value!);
                    _saveSetting('font_size', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text(
                    '大',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  value: 'large',
                  groupValue: _fontSize,
                  activeColor: const Color(0xFF60a5fa),
                  onChanged: (value) {
                    setState(() => _fontSize = value!);
                    _saveSetting('font_size', value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text(
                    '超大',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  value: 'extra_large',
                  groupValue: _fontSize,
                  activeColor: const Color(0xFF60a5fa),
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
            backgroundColor: const Color(0xFF0a0e27),
            title: const Text('清除快取', style: TextStyle(color: Colors.white)),
            content: const Text(
              '確定要清除應用快取嗎？這將清除暫存的圖片和資料。',
              style: TextStyle(color: Color(0xFF94a3b8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '取消',
                  style: TextStyle(color: Color(0xFF60a5fa)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('快取已清除'),
                      backgroundColor: Color(0xFF34d399),
                    ),
                  );
                },
                child: const Text(
                  '確定',
                  style: TextStyle(color: Color(0xFF60a5fa)),
                ),
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
        return '未知';
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
        return '未知';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        title: const Text('設置'),
        backgroundColor: const Color(0xFF0a1428),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF6366f1).withOpacity(0.1),
            height: 1,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0a1428),
          border: Border(
            top: BorderSide(
              color: const Color(0xFF6366f1).withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ========== 帳號驗證 ==========
            _buildSectionHeader('帳號安全'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0e27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366f1).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    tileColor: Colors.transparent,
                    title: const Text(
                      '電子郵件驗證',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _emailVerified ? '已驗證' : '未驗證',
                      style: TextStyle(
                        color:
                            _emailVerified
                                ? const Color(0xFF34d399)
                                : const Color(0xFF94a3b8),
                      ),
                    ),
                    trailing: Icon(
                      _emailVerified
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          _emailVerified
                              ? const Color(0xFF34d399)
                              : const Color(0xFF94a3b8),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmailVerificationPage(),
                        ),
                      ).then((_) => _loadUserInfo());
                    },
                  ),
                  Divider(
                    height: 1,
                    color: const Color(0xFF6366f1).withOpacity(0.1),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    title: const Text(
                      '電話驗證',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _phoneVerified ? '已驗證' : '未驗證',
                      style: TextStyle(
                        color:
                            _phoneVerified
                                ? const Color(0xFF34d399)
                                : const Color(0xFF94a3b8),
                      ),
                    ),
                    trailing: Icon(
                      _phoneVerified
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          _phoneVerified
                              ? const Color(0xFF34d399)
                              : const Color(0xFF94a3b8),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PhoneVerificationPage(),
                        ),
                      ).then((_) => _loadUserInfo());
                    },
                  ),
                  Divider(
                    height: 1,
                    color: const Color(0xFF6366f1).withOpacity(0.1),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    title: const Text(
                      '更改密碼',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '更新您的帳號密碼',
                      style: TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF60a5fa).withOpacity(0.6),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ========== 通知設定 ==========
            _buildSectionHeader('通知設定'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0e27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366f1).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    tileColor: Colors.transparent,
                    activeColor: const Color(0xFF60a5fa),
                    title: const Text(
                      '啟用通知',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '接收應用通知',
                      style: TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() => _notificationsEnabled = value);
                      _saveSetting('notifications_enabled', value);
                    },
                  ),
                  Divider(
                    height: 1,
                    color: const Color(0xFF6366f1).withOpacity(0.1),
                  ),
                  SwitchListTile(
                    tileColor: Colors.transparent,
                    activeColor: const Color(0xFF60a5fa),
                    title: const Text(
                      '推播通知',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '接收推播通知',
                      style: TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    value: _pushNotificationsEnabled && _notificationsEnabled,
                    onChanged:
                        _notificationsEnabled
                            ? (value) {
                              setState(() => _pushNotificationsEnabled = value);
                              _saveSetting('push_notifications_enabled', value);
                            }
                            : null,
                  ),
                  Divider(
                    height: 1,
                    color: const Color(0xFF6366f1).withOpacity(0.1),
                  ),
                  SwitchListTile(
                    tileColor: Colors.transparent,
                    activeColor: const Color(0xFF60a5fa),
                    title: const Text(
                      '電子郵件通知',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '接收電子郵件通知',
                      style: TextStyle(color: Color(0xFF94a3b8)),
                    ),
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
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0e27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366f1).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    tileColor: Colors.transparent,
                    activeColor: const Color(0xFF60a5fa),
                    title: const Text(
                      '深色模式',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '使用深色主題',
                      style: TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    value: _darkModeEnabled,
                    onChanged: (value) {
                      setState(() => _darkModeEnabled = value);
                      Provider.of<ThemeManager>(
                        context,
                        listen: false,
                      ).toggleTheme();
                    },
                  ),
                  Divider(
                    height: 1,
                    color: const Color(0xFF6366f1).withOpacity(0.1),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    title: const Text(
                      '字體大小',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _getFontSizeDisplayName(_fontSize),
                      style: const TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF60a5fa).withOpacity(0.6),
                    ),
                    onTap: _showFontSizeDialog,
                  ),
                  Divider(
                    height: 1,
                    color: const Color(0xFF6366f1).withOpacity(0.1),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    title: const Text(
                      '語言',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _getLanguageDisplayName(_language),
                      style: const TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF60a5fa).withOpacity(0.6),
                    ),
                    onTap: _showLanguageDialog,
                  ),
                ],
              ),
            ),

            // ========== 媒體設定 ==========
            _buildSectionHeader('媒體設定'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0e27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366f1).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: SwitchListTile(
                tileColor: Colors.transparent,
                activeColor: const Color(0xFF60a5fa),
                title: const Text(
                  '自動播放影片',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  '在行動網路下自動播放影片',
                  style: TextStyle(color: Color(0xFF94a3b8)),
                ),
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
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0e27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366f1).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ListTile(
                tileColor: Colors.transparent,
                title: const Text(
                  '清除快取',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  '清除暫存的圖片和資料',
                  style: TextStyle(color: Color(0xFF94a3b8)),
                ),
                leading: const Icon(
                  Icons.cleaning_services,
                  color: Color(0xFFf59e0b),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: const Color(0xFF60a5fa).withOpacity(0.6),
                ),
                onTap: _clearCache,
              ),
            ),

            // ========== 關於 ==========
            _buildSectionHeader('關於'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0e27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366f1).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    tileColor: Colors.transparent,
                    title: const Text(
                      '關於應用',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '版本資訊與開發團隊',
                      style: TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    leading: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF60a5fa),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF60a5fa).withOpacity(0.6),
                    ),
                    onTap: _showAboutDialog,
                  ),
                  Divider(
                    height: 1,
                    color: const Color(0xFF6366f1).withOpacity(0.1),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    title: const Text(
                      '隱私政策',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '查看隱私政策',
                      style: TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    leading: const Icon(
                      Icons.privacy_tip_outlined,
                      color: Color(0xFF34d399),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF60a5fa).withOpacity(0.6),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('隱私政策頁面開發中')),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: const Color(0xFF6366f1).withOpacity(0.1),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    title: const Text(
                      '服務條款',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '查看服務條款',
                      style: TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    leading: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFF6366f1),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF60a5fa).withOpacity(0.6),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('服務條款頁面開發中')),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: const Color(0xFF6366f1).withOpacity(0.1),
                  ),
                  ListTile(
                    tileColor: Colors.transparent,
                    title: const Text(
                      '意見反饋',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '提供意見或回報問題',
                      style: TextStyle(color: Color(0xFF94a3b8)),
                    ),
                    leading: const Icon(
                      Icons.feedback_outlined,
                      color: Color(0xFF34d399),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF60a5fa).withOpacity(0.6),
                    ),
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
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF94a3b8),
        ),
      ),
    );
  }
}
