import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class GroupCustomizePage extends StatefulWidget {
  final int userId;

  const GroupCustomizePage({super.key, required this.userId});

  @override
  State<GroupCustomizePage> createState() => _GroupCustomizePageState();
}

class _GroupCustomizePageState extends State<GroupCustomizePage> {
  List<Map<String, dynamic>> _activeCategories = [];
  List<Map<String, dynamic>> _deletedCategories = [];
  bool _isLoading = false;
  String? _error;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _fetchUserCategories();
  }

  // ✅ 修復: 獲取分類資料 (不使用會報錯的 POST /groupcustomize/general)
  Future<void> _fetchUserCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔍 獲取用戶分類 - userId: ${widget.userId}');

      // 只使用 GET /group 獲取所有分類
      final groupResponse = await http.get(
        Uri.parse('${Config.apiBaseUrl}/group'),
      );

      if (groupResponse.statusCode != 200) {
        throw Exception('獲取分類失敗: ${groupResponse.statusCode}');
      }

      final groupData = json.decode(groupResponse.body);
      if (groupData['success'] != true || groupData['data'] == null) {
        throw Exception('分類資料格式錯誤');
      }

      print('📡 獲取到 ${groupData['data'].length} 個分類');

      List<Map<String, dynamic>> active = [];

      // 使用預設順序
      for (int i = 0; i < groupData['data'].length; i++) {
        var item = groupData['data'][i];
        active.add({
          'group_id': item['group_id'],
          'group_name': item['group_name'] ?? '未命名',
          'group_order': (i + 1) * 10,
          'original_order': (i + 1) * 10,
          'was_deleted': false,
        });
      }

      setState(() {
        _activeCategories = active;
        _deletedCategories = [];
        _isLoading = false;
      });

      print('✅ 載入完成: ${active.length} 個分類');
    } catch (error) {
      print('❌ 載入失敗: $error');
      setState(() {
        _error = '載入失敗: $error';
        _isLoading = false;
      });
    }
  }

  // ✅ 保存變更
  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    setState(() => _isLoading = true);

    try {
      List<List<dynamic>> groupOrder = [];

      // 活躍分類
      for (int i = 0; i < _activeCategories.length; i++) {
        var category = _activeCategories[i];
        int newOrder = (i + 1) * 10;

        if (category['was_deleted'] == true) {
          groupOrder.add(['insert', category['group_id'], newOrder]);
        } else {
          groupOrder.add(['update', category['group_id'], newOrder]);
        }
      }

      // 刪除的分類
      for (var category in _deletedCategories) {
        groupOrder.add(['delete', category['group_id'], null]);
      }

      final response = await http.put(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/order/general'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': widget.userId, 'groupOrder': groupOrder}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _hasChanges = false;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('儲存成功'),
                backgroundColor: Colors.green,
              ),
            );
            await _fetchUserCategories();
          }
        } else {
          throw Exception(data['message'] ?? '保存失敗');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        title: const Text(
          '自訂分類順序',
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
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              child: const Text(
                '儲存',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                ),
              )
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFef4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFef4444),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366f1),
                            const Color(0xFF60a5fa),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _fetchUserCategories,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: const Text(
                              '重試',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1a2a4e),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366f1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Color(0xFF60a5fa),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '長按並拖動分類可調整順序',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: _activeCategories.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          // ✅ 修復: 正確處理向上和向下拖動
                          if (oldIndex < newIndex) {
                            // 向下拖動
                            newIndex -= 1;
                          }
                          final item = _activeCategories.removeAt(oldIndex);
                          _activeCategories.insert(newIndex, item);
                          _hasChanges = true;
                        });
                      },
                      itemBuilder: (context, index) {
                        final category = _activeCategories[index];
                        return Container(
                          key: ValueKey(category['group_id']),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1a2a4e),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6366f1).withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF6366f1,
                                ).withOpacity(0.08),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              category['group_name'],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
