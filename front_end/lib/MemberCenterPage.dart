import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'UserService.dart';
import 'PermissionHelper.dart';
import 'LoginPage.dart';
import 'ProfileEditPage.dart';
import 'ChangePasswordPage.dart';
import 'HomePage.dart';

import 'DeleteAccountPage.dart';
import 'SettingsPage.dart';

class MemberCenterPage extends StatefulWidget {
  const MemberCenterPage({super.key});

  @override
  State<MemberCenterPage> createState() => _MemberCenterPageState();
}

class _MemberCenterPageState extends State<MemberCenterPage> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  String _userAccount = '';
  bool _isAdmin = false;
  int _userId = 0;
  Map<String, bool> _permissions = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final account = prefs.getString('Account') ?? '';
      final userId = prefs.getInt('UserID') ?? 0;
      final isManager = prefs.getInt('IsManager') ?? 0;

      // 管理員判斷
      bool isAdmin =
          isManager == 1 || account.toLowerCase().startsWith('admin');

      // 獲取權限
      final permissions = await PermissionHelper.getAllPermissions();

      setState(() {
        _userAccount = account;
        _userId = userId;
        _isAdmin = isAdmin;
        _permissions = permissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('載入用戶資料失敗')));
    }
  }

  Future<void> _logout() async {
    try {
      final result = await _userService.logout();
      if (result['success']) {
        // ⭐ 新增：明確清除 IsLogin 標誌
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('IsLogin', false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登出成功'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '登出失敗'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登出時發生錯誤'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteAccount() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeleteAccountPage()),
    ).then((_) => _loadUserData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        title: const Text(
          '會員中心',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF1a2a4e),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF6366f1).withOpacity(0.1),
            height: 1,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF60a5fa)),
              onPressed: _loadUserData,
              tooltip: '重新整理',
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildUserInfoCard(),
                    const SizedBox(height: 16),
                    _buildPermissionCard(),
                    const SizedBox(height: 16),
                    _buildMenuList(),
                  ],
                ),
              ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1a2a4e), const Color(0xFF0f1e3d)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366f1).withOpacity(0.3),
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
        children: [
          // 用戶頭像
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _isAdmin ? const Color(0xFFef4444) : const Color(0xFF6366f1),
                  _isAdmin ? const Color(0xFFf87171) : const Color(0xFF60a5fa),
                ],
              ),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                _userAccount.isNotEmpty ? _userAccount[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 用戶名稱
          Text(
            _userAccount,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // 用戶ID
          Text(
            'ID: $_userId',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // 用戶類型標籤
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    _isAdmin
                        ? [const Color(0xFFef4444), const Color(0xFFf87171)]
                        : [const Color(0xFF6366f1), const Color(0xFF60a5fa)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isAdmin
                          ? const Color(0xFFef4444)
                          : const Color(0xFF6366f1))
                      .withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAdmin ? Icons.admin_panel_settings : Icons.person,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAdmin ? '管理員' : '一般會員',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    final activePermissions =
        _permissions.entries.where((entry) => entry.value).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2a4e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366f1).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366f1).withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.green[400], size: 22),
              const SizedBox(width: 12),
              const Text(
                '您的權限',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                activePermissions
                    .map((entry) => _buildPermissionChip(entry.key))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionChip(String permission) {
    final Map<String, String> permissionNames = {
      'bookmark': '收藏',
      'comment': '評論',
      'score': '評分',
      'search': '搜尋',
      'view': '瀏覽',
      'share': '分享',
      'admin': '管理員',
      'manage': '管理',
      'delete': '刪除',
      'edit': '編輯',
    };

    final Map<String, IconData> permissionIcons = {
      'bookmark': Icons.bookmark,
      'comment': Icons.comment,
      'score': Icons.star,
      'search': Icons.search,
      'view': Icons.visibility,
      'share': Icons.share,
      'admin': Icons.admin_panel_settings,
      'manage': Icons.manage_accounts,
      'delete': Icons.delete,
      'edit': Icons.edit,
    };

    final isAdminPermission = [
      'admin',
      'manage',
      'delete',
      'edit',
    ].contains(permission);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAdminPermission ? Colors.red : Colors.blue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            permissionIcons[permission] ?? Icons.check_circle,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            permissionNames[permission] ?? permission,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.person,
          title: '編輯個人資料',
          subtitle: '修改個人資訊',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileEditPage()),
            ).then((_) => _loadUserData());
          },
        ),
        const SizedBox(height: 8),
        _buildMenuItem(
          icon: Icons.lock,
          title: '修改密碼',
          subtitle: '更改登入密碼',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangePasswordPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildMenuItem(
          icon: Icons.settings,
          title: '設定',
          subtitle: '應用程式設定',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          },
        ),
        if (_permissions['bookmark'] == true) ...[
          const SizedBox(height: 8),
          _buildMenuItem(
            icon: Icons.bookmark,
            title: '我的收藏',
            subtitle: '查看已收藏的內容',
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('收藏功能開發中')));
            },
          ),
        ],
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.logout,
          title: '登出',
          subtitle: '登出目前帳號',
          onTap: _logout,
          isDestructive: false,
        ),
        const SizedBox(height: 8),
        _buildMenuItem(
          icon: Icons.delete_forever,
          title: '刪除帳號',
          subtitle: '永久刪除帳號（無法復原）',
          onTap: _deleteAccount,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      width: double.infinity,
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
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: isDestructive ? Colors.red : Colors.blue),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.red : Colors.black,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
