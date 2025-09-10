import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key});

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  static const String apiUrl = "http://localhost:3000/api/channel";

  List<Map<String, dynamic>> channels = []; // 用 map 存 channel_id & channel_name
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 一開始不顯示任何列表
    channels = [];
  }

  // 取得頻道列表或搜尋
  Future<void> fetchChannels({String? query}) async {
    final url = query != null && query.isNotEmpty
        ? "$apiUrl?name=$query"
        : "$apiUrl?name=";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse["success"] == true) {
        setState(() {
          if (query != null && query.isNotEmpty) {
            // 後端搜尋只回傳 searchId，用 query 當名稱
            channels = [
              {
                "channel_id": jsonResponse["data"]["searchId"],
                "channel_name": query
              }
            ];
          } else {
            // 一開始不顯示列表
            channels = [];
          }
        });
      }
    } else {
      throw Exception('Failed to load channels');
    }
  }

  // 新增頻道（只需名稱）
  Future<void> addChannel(String name) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"name": name}),
    );

    if (response.statusCode == 200) {
      fetchChannels(query: searchQuery);
    } else {
      throw Exception('Failed to add channel');
    }
  }

  // 刪除頻道
  Future<void> deleteChannel(int id) async {
    final response = await http.delete(Uri.parse("$apiUrl/$id"));

    if (response.statusCode == 200) {
      fetchChannels(query: searchQuery);
    } else {
      throw Exception('Failed to delete channel');
    }
  }

  // 彈出新增頻道輸入框
  Future<void> showAddDialog() async {
    String input = "";
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("新增頻道"),
          content: TextField(
            autofocus: true,
            onChanged: (value) => input = value,
            decoration: const InputDecoration(hintText: "輸入頻道名稱"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, input),
              child: const Text("新增"),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      await addChannel(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("頻道管理"),
      ),
      body: Column(
        children: [
          // 搜尋列
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "搜尋頻道",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    searchQuery = "";
                    channels = [];
                    setState(() {});
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                searchQuery = value;
                if (value.isNotEmpty) {
                  fetchChannels(query: searchQuery);
                } else {
                  setState(() {
                    channels = [];
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 5),
          // 頻道列表
          Expanded(
            child: channels.isEmpty
                ? const Center(child: Text("沒有頻道資料"))
                : ListView.builder(
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return ListTile(
                  title: Text(channel['channel_name']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () =>
                        deleteChannel(channel['channel_id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
