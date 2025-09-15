import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GroupPage extends StatefulWidget {
  const GroupPage({super.key});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  static const String apiUrl = "http://localhost:3000/api/group"; // API

  // 分組後的資料結構： { group_id: { group_name: [ group_detail... ] } }
  Map<int, Map<String, List<Map<String, dynamic>>>> groupedData = {};
  Map<int, Map<String, List<Map<String, dynamic>>>> filteredData = {};

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addGroupController = TextEditingController();

  // 讀取所有群組與細項
  Future<void> fetchGroups() async {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['data'];

      Map<int, Map<String, List<Map<String, dynamic>>>> tempGrouped = {};

      for (var item in data) {
        final id = item['group_id'];
        final name = item['group_name'];
        final detail = {
          "id": item['group_detail_id'],
          "name": item['group_detail_name']
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
      throw Exception('Failed to fetch groups');
    }
  }

  // 新增群組
  Future<void> addGroup(String name) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"group_name": name}),
    );
    if (response.statusCode == 200) {
      _addGroupController.clear();
      fetchGroups(); // 重新載入
    } else {
      throw Exception('Failed to add group');
    }
  }

  // 搜尋群組（依 group_name）
  void searchGroup(String keyword) {
    if (keyword.isEmpty) {
      setState(() {
        filteredData = groupedData;
      });
      return;
    }

    Map<int, Map<String, List<Map<String, dynamic>>>> temp = {};
    groupedData.forEach((id, map) {
      final groupName = map.keys.first;
      if (groupName.contains(keyword)) {
        temp[id] = map;
      }
    });

    setState(() {
      filteredData = temp;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addGroupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("群組管理")),
      body: Column(
        children: [
          // 搜尋
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "輸入群組名稱搜尋",
                    ),
                    onChanged: searchGroup,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    searchGroup(_searchController.text.trim());
                  },
                ),
              ],
            ),
          ),
          // 新增群組
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addGroupController,
                    decoration: const InputDecoration(
                      hintText: "輸入群組名稱新增",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final name = _addGroupController.text.trim();
                    if (name.isNotEmpty) addGroup(name);
                  },
                ),
              ],
            ),
          ),
          // 群組列表
          Expanded(
            child: filteredData.isEmpty
                ? const Center(child: Text("沒有找到群組"))
                : ListView(
              children: filteredData.entries.map((entry) {
                final groupId = entry.key;
                final groupName = entry.value.keys.first;
                final details = entry.value[groupName]!;

                return ListTile(
                  title: Text(groupName),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailPage(
                          groupId: groupId,
                          groupName: groupName,
                          details: details,
                          onRefresh: fetchGroups,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
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

  @override
  void initState() {
    super.initState();
    details = List.from(widget.details);
  }

  // 新增 group_detail
  Future<void> addGroupDetail(String name) async {
    final response = await http.post(
      Uri.parse("${_GroupPageState.apiUrl}/detail"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"group_id": widget.groupId, "group_detail_name": name}),
    );
    if (response.statusCode == 200) {
      setState(() {
        details.add({"id": DateTime.now().millisecondsSinceEpoch, "name": name});
      });
      _addDetailController.clear();
      widget.onRefresh(); // 回到上一頁時刷新
    } else {
      throw Exception('Failed to add group detail');
    }
  }

  @override
  void dispose() {
    _addDetailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          // 新增群組細項
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addDetailController,
                    decoration: const InputDecoration(
                      hintText: "輸入細項名稱新增",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final name = _addDetailController.text.trim();
                    if (name.isNotEmpty) addGroupDetail(name);
                  },
                ),
              ],
            ),
          ),
          // 細項列表
          Expanded(
            child: ListView(
              children: details.map((d) {
                return ListTile(
                  title: Text(d['name']),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("選中 ${d['name']} (ID=${d['id']})")),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
