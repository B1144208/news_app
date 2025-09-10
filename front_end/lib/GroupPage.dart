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

  List<Map<String, dynamic>> searchResult = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addController = TextEditingController();

  // 搜尋單筆群組
  Future<void> searchGroup(String name) async {
    final response = await http.get(Uri.parse("$apiUrl?name=$name"));
    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      setState(() {
        searchResult = [
          {
            'id': data['id'],
            'name': name, // 目前 API 沒回傳名稱，用輸入名稱代替
          }
        ];
      });
    } else {
      setState(() {
        searchResult = [];
      });
      throw Exception('Failed to search group');
    }
  }

  // 新增群組
  Future<void> addGroup(String name) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"name": name}),
    );
    if (response.statusCode == 200) {
      await searchGroup(name);
      _addController.clear();
    } else {
      throw Exception('Failed to add group');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addController.dispose();
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
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    final name = _searchController.text.trim();
                    if (name.isNotEmpty) searchGroup(name);
                  },
                ),
              ],
            ),
          ),
          // 新增
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: const InputDecoration(
                      hintText: "輸入群組名稱新增",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final name = _addController.text.trim();
                    if (name.isNotEmpty) addGroup(name);
                  },
                ),
              ],
            ),
          ),
          // 搜尋結果列表
          Expanded(
            child: ListView.builder(
              itemCount: searchResult.length,
              itemBuilder: (context, index) {
                final group = searchResult[index];
                return ListTile(
                  title: Text(group['name']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      // 刪除功能尚未實作
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('刪除功能尚未實作'),
                        ),
                      );
                    },
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
