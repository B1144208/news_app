import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// 匯入您的 config.dart 檔案
import 'config.dart';

// 假設 Config.apiBaseUrl 為 'http://localhost:3000/api'

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

  // 設置一個固定的列表項目高度
  static const double _itemHeight = 60.0;

  final TextEditingController _categoryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserCategories();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  // 獲取分類資料 (處理 'Search success' 例外)
  Future<void> _fetchUserCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final groupResponse = await http.get(
        Uri.parse(
          '${Config.apiBaseUrl}/groupcustomize/order?type=general&userId=${widget.userId}',
        ),
      );

      if (groupResponse.statusCode != 200) {
        throw Exception('獲取分類失敗: ${groupResponse.statusCode}');
      }

      final groupData = json.decode(groupResponse.body);
      final message = groupData['message'] ?? '';

      if (groupData['data'] == null || groupData['data'].isEmpty) {
        if (groupData['success'] != true && !message.contains('Success')) {
          throw Exception(message.isNotEmpty ? message : '載入分類資料失敗');
        }

        if (mounted) {
          setState(() {
            _activeCategories = [];
            _isLoading = false;
            _hasChanges = false;
          });
        }
        return;
      }

      if (groupData['success'] != true && !message.contains('Success')) {
        throw Exception(message.isNotEmpty ? message : '載入分類資料失敗');
      }

      // 數據處理部分
      List<dynamic> rawCategories = groupData['data'];

      List<Map<String, dynamic>> active = [];
      for (int i = 0; i < rawCategories.length; i++) {
        var item = rawCategories[i];
        active.add({
          'group_id': item['group_id'],
          'group_name': item['group_name'] ?? '未命名',
          'group_order': (i + 1) * 10,
          'original_order': (i + 1) * 10,
          'was_deleted': false,
        });
      }

      // 防禦性過濾
      Set<dynamic> uniqueIds = {};
      List<Map<String, dynamic>> uniqueActive = [];
      for (var category in active) {
        if (!uniqueIds.contains(category['group_id'])) {
          uniqueIds.add(category['group_id']);
          uniqueActive.add(category);
        }
      }
      active = uniqueActive;

      setState(() {
        _activeCategories = active;
        _deletedCategories = [];
        _isLoading = false;
        _hasChanges = false;
      });
    } catch (error) {
      final errorString = error.toString().toLowerCase();
      // 專門檢查並忽略「Search success」例外
      if (errorString.contains('search success')) {
        if (mounted) {
          setState(() {
            _error = null;
            _isLoading = false;
          });
        }
        return;
      }

      // 處理所有其他真正的錯誤
      if (mounted) {
        setState(() {
          _error = '載入失敗: $error';
          _isLoading = false;
        });
      }
    }
  }

  // 實際執行新增分類操作的函數 (V26 最終修正：將 'insert' 改為 'update' 繞過後端 'is_delete' 錯誤)
  // 在 _GroupCustomizePageState 類別中

  // 實際執行新增分類操作的函數 (V28 修正：使用 POST /groupcustomize/general，並傳遞陣列格式)
  Future<void> _executeAddCategory(String newName) async {
    setState(() => _isLoading = true);

    try {
      // ----------------------------------------------------
      // 第一階段：POST /group (創建基礎分類) - 保持不變
      // ----------------------------------------------------
      // ... (這裡的邏輯保持 V27 不變)
      final createGroupResponse = await http.post(
        Uri.parse('${Config.apiBaseUrl}/group'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': newName}),
      );

      if (createGroupResponse.statusCode != 200) {
        throw Exception('建立基礎分類失敗: 伺服器狀態碼 ${createGroupResponse.statusCode}');
      }

      final createGroupData = json.decode(createGroupResponse.body);
      final createMessage = createGroupData['message'] ?? '';

      if (createGroupData['id'] == null) {
        throw Exception(
          createMessage.isNotEmpty ? createMessage : '建立基礎分類失敗: ID欄位遺失',
        );
      }

      final newGroupId = createGroupData['id'];

      // ----------------------------------------------------
      // 🌟 第二階段：POST /groupcustomize/general (傳遞陣列格式)
      // ----------------------------------------------------

      final newOrder = (_activeCategories.length + 1) * 10;

      // 🌟 V28 修正核心：將單獨參數改為 groupOrder 陣列格式
      final List<List<dynamic>> groupOrder = [
        // 對於 POST 插入，我們應該使用 'insert'
        ['insert', newGroupId, newOrder],
      ];

      final addResponse = await http.post(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/general'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          // 傳遞 groupOrder 陣列
          'groupOrder': groupOrder,
        }),
      );

      if (addResponse.statusCode != 200) {
        throw Exception('加入自訂列表失敗: 伺服器狀態碼 ${addResponse.statusCode}');
      }

      final addData = json.decode(addResponse.body);
      final message = addData['message'] ?? '';

      // 檢查是否成功
      if (addData['success'] != true && !message.contains('Success')) {
        throw Exception(message.isNotEmpty ? message : '加入自訂列表失敗');
      }

      // ----------------------------------------------------
      // 第三階段：更新 UI
      // ----------------------------------------------------
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分類 "$newName" 已成功新增並加入列表！'),
            backgroundColor: const Color(0xFF60a5fa),
          ),
        );
        await _fetchUserCategories(); // 刷新列表
      }
    } catch (error) {
      // ------------------------------------------------------------------
      // 保持例外處理邏輯
      // ------------------------------------------------------------------
      final errorString = error.toString().toLowerCase();

      if (errorString.contains('insert success') ||
          errorString.contains('search success') ||
          errorString.contains(
            'api response successful but missing new group id',
          )) {
        if (mounted) {
          // 假設操作已成功，手動顯示成功提示並刷新列表
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('分類 "$newName" 已成功新增並加入列表！'),
              backgroundColor: const Color(0xFF60a5fa),
            ),
          );
          await _fetchUserCategories();
          return;
        }
      }

      // 捕捉所有其他真正的例外
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('新增分類失敗: $error'),
            backgroundColor: const Color(0xFFef4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 彈窗函數 (帶輸入框)
  void _handleAddCategory() {
    _categoryNameController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '新增自訂分類',
            style: TextStyle(color: Color.fromARGB(255, 40, 25, 25)),
          ),
          content: TextField(
            controller: _categoryNameController,
            decoration: const InputDecoration(
              labelText: '請輸入分類名稱',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                '取消',
                style: TextStyle(color: Color.fromARGB(255, 40, 25, 25)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                '確認新增',
                style: TextStyle(color: Color.fromARGB(255, 40, 25, 25)),
              ),
              onPressed: () {
                final newName = _categoryNameController.text.trim();
                Navigator.of(context).pop();

                if (newName.isNotEmpty) {
                  _executeAddCategory(newName);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分類名稱不能為空'),
                      backgroundColor: const Color(0xFFef4444),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 保存變更
  Future<void> _saveChanges() async {
    if (!_hasChanges) return;
    setState(() => _isLoading = true);

    try {
      List<List<dynamic>> groupOrder = [];

      for (int i = 0; i < _activeCategories.length; i++) {
        var category = _activeCategories[i];
        int newOrder = (i + 1) * 10;
        // 使用 'update'，這是安全的
        groupOrder.add(['update', category['group_id'], newOrder]);
      }

      // 呼叫 PUT /order/general 路由
      final response = await http.put(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/order/general'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': widget.userId, 'groupOrder': groupOrder}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final message = data['message'] ?? '';

        // 修正：對儲存也進行防禦性檢查
        if (data['success'] != true && !message.contains('Success')) {
          throw Exception(message.isNotEmpty ? message : '保存失敗');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('儲存成功'),
              backgroundColor: const Color(0xFF60a5fa),
            ),
          );
          await _fetchUserCategories();
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 輔助方法：創建一個列表項目 Widget
  Widget _buildListItem(Map<String, dynamic> category, {Key? key}) {
    // 保持固定高度和穩定佈局
    return SizedBox(
      key: key,
      height: _itemHeight,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a2a4e),
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF3b82f6).withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          onTap: null,
          title: Text(
            category['group_name'] ?? '項目',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          trailing: const Icon(
            Icons.drag_handle,
            color: const Color(0xFFe5e7eb),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _activeCategories.isEmpty) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _activeCategories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('自訂分類順序')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: const Color(0xFFef4444),
              ),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchUserCategories,
                child: const Text('重試', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('自訂分類順序', style: TextStyle(color: Colors.white)),
        actions: [
          // 新增按鈕
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _handleAddCategory,
            ),

          if (_hasChanges && !_isLoading)
            TextButton(
              onPressed: _saveChanges,
              child: const Text(
                '儲存',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 資訊提示框
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1a2a4e),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: const Color(0xFF60a5fa)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '長按並拖動分類可調整順序',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ReorderableListView.builder(
              itemCount: _activeCategories.length,

              // 關鍵修正 1：使用 prototypeItem 和固定高度
              prototypeItem: _buildListItem({'group_name': 'Sample'}),

              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _activeCategories.removeAt(oldIndex);
                  _activeCategories.insert(newIndex, item);
                  _hasChanges = true;
                });
              },
              itemBuilder: (context, index) {
                final category = _activeCategories[index];

                // 關鍵修正 2：使用 ObjectKey 結合 group_id
                Key itemKey = ObjectKey({
                  'id': category['group_id'],
                  'order': category['group_order'],
                });

                return ReorderableDelayedDragStartListener(
                  key: itemKey,
                  index: index,
                  child: _buildListItem(category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
