import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key});

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  final String apiUrl = "http://localhost:3000/api/channel"; // TODO:  API
  List<dynamic> _channels = [];
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchChannels();
  }

  // 搜尋頻道
  Future<void> _fetchChannels() async {
    try {
      var response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          _channels = json.decode(response.body);
        });
      }
    } catch (e) {
      print("載入頻道失敗: $e");
    }
  }

  // 新增頻道
  Future<void> _addChannel(String name) async {
    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _nameController.clear();
        _fetchChannels(); // 刷新列表
      }
    } catch (e) {
      print("新增頻道失敗: $e");
    }
  }

  // 刪除頻道
  Future<void> _deleteChannel(int id) async {
    try {
      var response = await http.delete(Uri.parse("$apiUrl/$id"));
      if (response.statusCode == 200) {
        _fetchChannels(); // 刷新列表
      }
    } catch (e) {
      print("刪除頻道失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("頻道管理")),
      body: Column(
        children: [
          // 新增頻道區
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "新增頻道名稱",
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isNotEmpty) {
                      _addChannel(name);
                    }
                  },
                  child: const Text("新增"),
                ),
              ],
            ),
          ),
          const Divider(),
          // 頻道列表
          Expanded(
            child: _channels.isEmpty
                ? const Center(child: Text("目前沒有頻道"))
                : ListView.builder(
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final channel = _channels[index];
                return ListTile(
                  title: Text(channel['name'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteChannel(channel['id']),
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
