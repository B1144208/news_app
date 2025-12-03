import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'universal_template.dart';

class GroupPage extends StatefulWidget {
  const GroupPage({super.key});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  static const String apiUrl = "http://localhost:3000/api/group";
  Map<int, Map<String, List<Map<String, dynamic>>>> groupedData = {};
  Map<int, Map<String, List<Map<String, dynamic>>>> filteredData = {};

  bool isLoading = false;
  String searchQuery = "";
  final TextEditingController _addGroupController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchGroups();
  }

  @override
  void dispose() {
    _addGroupController.dispose();
    super.dispose();
  }

  // 讀取所有群組與細項
  Future<void> fetchGroups() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];

        Map<int, Map<String, List<Map<String, dynamic>>>> tempGrouped = {};

        for (var item in data) {
          final id = item['group_id'];
          final name = item['group_name'];
          final detail = {
            "id": item['group_detail_id'],
            "name": item['group_detail_name'],
          };

          if (!tempGrouped.containsKey(id)) {
            tempGrouped[id] = {name: []};
          }
          tempGrouped[id]![name]!.add(detail);
        }

        setState(() {
          groupedData = tempGrouped;
          filteredData = tempGrouped; // 預設顯示全部
        });
      } else {
        _showErrorMessage('載入群組失敗: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Failed to fetch groups: $e");
      _showErrorMessage('網路連接錯誤');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 新增群組
  Future<void> addGroup(String name) async {
    if (name.trim().isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"group_name": name}),
      );

      if (response.statusCode == 200) {
        _addGroupController.clear();
        _showSuccessMessage('群組新增成功');
        await fetchGroups(); // 重新載入
      } else {
        _showErrorMessage('新增失敗: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Failed to add group: $e");
      _showErrorMessage('網路連接錯誤');
    }
  }

  // 搜尋群組（依 group_name）
  void searchGroup(String keyword) {
    setState(() {
      searchQuery = keyword;
    });

    if (keyword.isEmpty) {
      setState(() {
        filteredData = groupedData;
      });
      return;
    }

    Map<int, Map<String, List<Map<String, dynamic>>>> temp = {};
    groupedData.forEach((id, map) {
      final groupName = map.keys.first;
      if (groupName.toLowerCase().contains(keyword.toLowerCase())) {
        temp[id] = map;
      }
    });

    setState(() {
      filteredData = temp;
    });
  }

  // 主要內容區域
  Widget _buildGroupContent() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('載入中...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (filteredData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isEmpty ? Icons.group : Icons.group_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isEmpty ? '沒有找到群組' : '沒有符合搜尋條件的群組',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '點擊新增按鈕創建第一個群組',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜尋結果標題
        if (searchQuery.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  '搜尋結果: "$searchQuery" (${filteredData.length}個)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
          ),

        // 群組列表
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredData.entries.length,
          itemBuilder: (context, index) {
            final entry = filteredData.entries.elementAt(index);
            return _buildGroupCard(entry);
          },
        ),
      ],
    );
  }

  // 群組卡片
  Widget _buildGroupCard(
    MapEntry<int, Map<String, List<Map<String, dynamic>>>> entry,
  ) {
    final groupId = entry.key;
    final groupName = entry.value.keys.first;
    final details = entry.value[groupName]!;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToGroupDetail(groupId, groupName, details),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 群組圖標
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group, color: Colors.teal, size: 28),
              ),
              const SizedBox(width: 16),

              // 群組資訊
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $groupId',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),

                    // 細項數量標籤
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.list_alt,
                            size: 16,
                            color: Colors.teal[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${details.length} 個項目',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.teal[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 箭頭圖標
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 導航到詳細頁面
  void _navigateToGroupDetail(
    int groupId,
    String groupName,
    List<Map<String, dynamic>> details,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => GroupDetailPage(
              groupId: groupId,
              groupName: groupName,
              details: details,
              onRefresh: fetchGroups,
            ),
      ),
    );
  }

  // 新增群組對話框
  void _showAddDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.group_add, color: Colors.teal),
                const SizedBox(width: 8),
                const Text('新增群組'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _addGroupController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '群組名稱',
                    hintText: '請輸入群組名稱',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.teal[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '新增群組後可以點擊進入管理群組項目',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal[700],
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
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = _addGroupController.text.trim();
                  if (name.isNotEmpty) {
                    addGroup(name);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('新增'),
              ),
            ],
          ),
    );
  }

  // 訊息顯示方法
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 主 Widget
  @override
  Widget build(BuildContext context) {
    return UniversalManagePage(
      // 頁面基本資訊
      pageTitle: '群組管理',
      pageDescription: '管理用戶群組和權限設定',
      pageIcon: Icons.group,
      themeColor: Colors.teal,

      // 搜尋功能配置
      searchHint: '輸入群組名稱搜尋...',
      onSearch: (query) {
        searchGroup(query);
      },

      // 新增按鈕配置
      onAddPressed: _showAddDialog,

      // 主要內容區域
      contentWidget: _buildGroupContent(),
    );
  }
}

class GroupDetailPage extends StatefulWidget {
  final int groupId;
  final String groupName;
  final List<Map<String, dynamic>> details;
  final VoidCallback onRefresh;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.details,
    required this.onRefresh,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  late List<Map<String, dynamic>> details;
  final TextEditingController _addDetailController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    details = List.from(widget.details);
  }

  @override
  void dispose() {
    _addDetailController.dispose();
    super.dispose();
  }

  // 新增 group_detail
  Future<void> addGroupDetail(String name) async {
    if (name.trim().isEmpty) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${_GroupPageState.apiUrl}/detail"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "group_id": widget.groupId,
          "group_detail_name": name,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          details.add({
            "id": DateTime.now().millisecondsSinceEpoch,
            "name": name,
          });
        });
        _addDetailController.clear();
        _showSuccessMessage('群組項目新增成功');
        widget.onRefresh(); // 回到上一頁時刷新
      } else {
        _showErrorMessage('新增失敗: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Failed to add group detail: $e");
      _showErrorMessage('網路連接錯誤');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          // 群組資訊卡片
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.groupName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '群組 ID: ${widget.groupId}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${details.length} 個項目',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 新增群組細項區域
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addDetailController,
                    decoration: const InputDecoration(
                      hintText: "輸入細項名稱新增",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_circle_outline),
                    ),
                    enabled: !isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : () {
                            final name = _addDetailController.text.trim();
                            if (name.isNotEmpty) addGroupDetail(name);
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('新增'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 細項列表
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child:
                  details.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.list_alt,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '此群組暫無項目',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '使用上方輸入框新增第一個項目',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: details.length,
                        itemBuilder: (context, index) {
                          final detail = details[index];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal,
                                radius: 20,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.teal[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                detail['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'ID: ${detail['id']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "選中 ${detail['name']} (ID=${detail['id']})",
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
