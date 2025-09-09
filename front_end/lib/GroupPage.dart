import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GroupPage extends StatefulWidget {
  const GroupPage({super.key});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {

  static const String apiUrl = "http://localhost:3000/api/group"; // TODO:  API

  List<dynamic> groups = [];

  // 搜尋群組
  Future<void> fetchGroups() async {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      setState(() {
        groups = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load groups');
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
      fetchGroups();
    } else {
      throw Exception('Failed to add group');
    }
  }

  // 刪除群組
  Future<void> deleteGroup(int id) async {
    final response = await http.delete(Uri.parse("$apiUrl/$id"));
    if (response.statusCode == 200) {
      fetchGroups();
    } else {
      throw Exception('Failed to delete group');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("群組管理")),
      body: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return ListTile(
            title: Text(group['name']),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteGroup(group['id']),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 假設這裡先寫死名稱，之後可以換成 TextField 輸入
          await addGroup("新群組");
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
