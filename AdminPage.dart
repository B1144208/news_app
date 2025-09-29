import 'package:flutter/material.dart';
import 'PermissionHelper.dart';

// 連接頁面
import 'config.dart';
import 'DataManagePage.dart';
import 'UserManagePage.dart';
import 'ErrorlogPage.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _userLevel = 0;
  String _levelName = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final level = await PermissionHelper.getUserLevel();
    setState(() {
      _userLevel = level;
      _levelName = PermissionHelper.getLevelName(level);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('管理員頁面 - $_levelName'),
        backgroundColor: PermissionHelper.getLevelColor(_userLevel),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              // 登出功能 - 回到首頁
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.logout),
            tooltip: '登出',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.blue[100]!],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 歡迎標題
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: 60,
                        color: PermissionHelper.getLevelColor(_userLevel),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        '歡迎使用管理員系統',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '請選擇要管理的項目',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // 管理選項卡片 - 根據權限顯示
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    // 數據管理 - 需要 Level 6+ (manage_data 權限)
                    if (_userLevel >= 6)
                      _buildManageCard(
                        context: context,
                        title: '數據管理',
                        subtitle: 'Data Management',
                        icon: Icons.storage,
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DataManagePage(),
                            ),
                          );
                        },
                      ),

                    // 用戶管理 - 需要 Level 7+ (add_manager 權限)
                    if (_userLevel >= 7)
                      _buildManageCard(
                        context: context,
                        title: '用戶管理',
                        subtitle: 'User Management',
                        icon: Icons.people,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserManagePage(),
                            ),
                          );
                        },
                      ),

                    // 錯誤日誌管理 - Level 5+ 即可查看
                    if (_userLevel >= 5)
                      _buildManageCard(
                        context: context,
                        title: '錯誤日誌',
                        subtitle: 'Error Log',
                        icon: Icons.error_outline,
                        color: Colors.red,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ErrorlogPage(),
                            ),
                          );
                        },
                      ),

                    // 如果權限不足，顯示提示
                    if (_userLevel == 5)
                      Container(
                        width: 180,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.grey[400]!,
                            width: 2,
                            style: BorderStyle.none,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 15),
                            Text(
                              '更多功能',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '需要更高權限',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 40),

                // 系統狀態信息 - 加入權限等級顯示
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Text(
                            '系統運行正常',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PermissionHelper.getLevelColor(
                            _userLevel,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: PermissionHelper.getLevelColor(_userLevel),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '您的權限等級: Level $_userLevel',
                          style: TextStyle(
                            fontSize: 12,
                            color: PermissionHelper.getLevelColor(_userLevel),
                            fontWeight: FontWeight.bold,
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

  Widget _buildManageCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
