import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'PermissionHelper.dart';

class UserLevelManagePage extends StatefulWidget {
  const UserLevelManagePage({super.key});

  @override
  State<UserLevelManagePage> createState() => _UserLevelManagePageState();
}

class _UserLevelManagePageState extends State<UserLevelManagePage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  int _currentUserLevel = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoadData();
  }

  // 檢查權限並載入數據
  Future<void> _checkPermissionAndLoadData() async {
    final level = await PermissionHelper.getUserLevel();

    // 只有 7 級以上（高級管理員）才能訪問此頁面
    if (level < PermissionHelper.LEVEL_SENIOR_ADMIN) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('權限不足：需要高級管理員權限（Level 7+）'),
            backgroundColor: const Color(0xFFef4444),
          ),
        );
      }
      return;
    }

    setState(() {
      _currentUserLevel = level;
    });

    await _loadUsers();
  }

  // 載入用戶列表
  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      // 獲取所有用戶
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> users = [];

        if (data['success'] == true && data['data'] is List) {
          users = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          users = List<Map<String, dynamic>>.from(data);
        }

        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('載入用戶列表失敗: $e');
      setState(() => _isLoading = false);
    }
  }

  // 更新用戶等級
  Future<void> _updateUserLevel(
    String userId,
    String account,
    int newLevel,
  ) async {
    // 權限檢查
    if (_currentUserLevel < PermissionHelper.LEVEL_SENIOR_ADMIN) {
      _showMessage('權限不足', isError: true);
      return;
    }

    // 只有超級管理員可以設置 10 級
    if (newLevel == 10 &&
        _currentUserLevel < PermissionHelper.LEVEL_SUPER_ADMIN) {
      _showMessage('只有超級管理員可以設置其他超級管理員', isError: true);
      return;
    }

    // 高級管理員只能設置到 6 級
    if (_currentUserLevel == PermissionHelper.LEVEL_SENIOR_ADMIN &&
        newLevel > 6) {
      _showMessage('高級管理員只能設置用戶等級到 6 級', isError: true);
      return;
    }

    // 確認對話框
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0a0e27),
            title: Text('確認修改權限'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('用戶: $account'),
                SizedBox(height: 8),
                Text(
                  '新等級: ${PermissionHelper.getLevelName(newLevel)} (Level $newLevel)',
                ),
                SizedBox(height: 16),
                if (newLevel == 10)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFef4444),
                      border: Border.all(color: const Color(0xFFef4444)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: const Color(0xFFef4444),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '警告：授予超級管理員權限後，該用戶將擁有所有系統權限',
                            style: TextStyle(
                              color: const Color(0xFFef4444),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      newLevel == 10
                          ? const Color(0xFFef4444)
                          : const Color(0xFF60a5fa),
                ),
                child: Text('確認'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    // 這裡需要後端支援，暫時使用模擬
    // 實際應該調用: PUT /api/user/$userId/level
    try {
      // 模擬 API 調用
      await Future.delayed(Duration(seconds: 1));

      // 更新本地列表
      setState(() {
        final index = _users.indexWhere(
          (u) => u['user_id'].toString() == userId,
        );
        if (index != -1) {
          _users[index]['user_level'] = newLevel;
        }
      });

      _showMessage('權限等級已更新');

      // 如果是繼承超級管理員，顯示特殊提示
      if (newLevel == 10) {
        _showInheritanceDialog(account);
      }
    } catch (e) {
      _showMessage('更新失敗: $e', isError: true);
    }
  }

  // 顯示繼承對話框
  void _showInheritanceDialog(String account) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF0a0e27),
            title: Row(
              children: [
                Icon(Icons.stars, color: Colors.amber),
                SizedBox(width: 8),
                Text('權限繼承成功'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$account 已成為新的超級管理員'),
                SizedBox(height: 16),
                Text('提醒：', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('• 系統現在有多個超級管理員'),
                Text('• 請確保權限管理的安全性'),
                Text('• 建議定期審核管理員列表'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('確定'),
              ),
            ],
          ),
    );
  }

  // 顯示訊息
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFef4444) : const Color(0xFF34d399),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('用戶等級管理'),
        backgroundColor: PermissionHelper.getLevelColor(_currentUserLevel),
        foregroundColor: const Color(0xFF0a1428),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: '重新載入',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // 搜尋欄
                  Container(
                    padding: EdgeInsets.all(16),
                    color: const Color(0xFF0a0e27),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜尋用戶帳號...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0a1428),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),

                  // 用戶列表
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final account = user['user_account'] ?? '';

                        // 搜尋過濾
                        if (_searchController.text.isNotEmpty &&
                            !account.toLowerCase().contains(
                              _searchController.text.toLowerCase(),
                            )) {
                          return SizedBox.shrink();
                        }

                        return _buildUserCard(user);
                      },
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = user['user_id']?.toString() ?? '0';
    final account = user['user_account'] ?? '';
    final name = user['user_name'] ?? '';
    final currentLevel = user['user_level'] ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 用戶頭像
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: PermissionHelper.getLevelColor(currentLevel),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      account.isNotEmpty ? account[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: const Color(0xFF0a0e27),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // 用戶資訊
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            account,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: PermissionHelper.getLevelColor(
                                currentLevel,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              PermissionHelper.getLevelName(currentLevel),
                              style: TextStyle(
                                color: const Color(0xFF0a0e27),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ID: $userId | 名稱: $name',
                        style: TextStyle(
                          color: const Color(0xFF94a3b8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // 等級選擇器
                _buildLevelSelector(userId, account, currentLevel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelSelector(String userId, String account, int currentLevel) {
    // 可選等級列表
    List<int> availableLevels = [0, 1, 5, 6];

    // 高級管理員可以設置 7 級
    if (_currentUserLevel >= PermissionHelper.LEVEL_SENIOR_ADMIN) {
      availableLevels.add(7);
    }

    // 超級管理員可以設置 10 級
    if (_currentUserLevel >= PermissionHelper.LEVEL_SUPER_ADMIN) {
      availableLevels.add(10);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: currentLevel,
        underline: SizedBox(),
        isDense: true,
        items:
            availableLevels.map((level) {
              return DropdownMenuItem(
                value: level,
                child: Text(
                  'Lv.$level',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: level == 10 ? const Color(0xFFef4444) : null,
                  ),
                ),
              );
            }).toList(),
        onChanged: (newLevel) {
          if (newLevel != null && newLevel != currentLevel) {
            _updateUserLevel(userId, account, newLevel);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
