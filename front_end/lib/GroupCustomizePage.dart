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
        body: json.encode({
          'userId': widget.userId,
          'groupOrder': groupOrder,
        }),
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
              const SnackBar(content: Text('儲存成功'), backgroundColor: Colors.green),
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
      appBar: AppBar(
        title: const Text('自訂分類順序'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('儲存', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchUserCategories,
              child: const Text('重試'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text('長按並拖動分類可調整順序'),
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
                // ✅ 改善: 美化 UI - 移除拖動圖標,添加外框
                return Container(
                  key: ValueKey(category['group_id']),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    // ✅ 移除: 不再顯示拖動圖標
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            category['group_name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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
