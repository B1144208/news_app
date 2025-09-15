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

  List<dynamic> channels = [];
  int? expandedChannelId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchChannels();
  }

  // 取得頻道清單或搜尋
  Future<void> fetchChannels({String? name}) async {
    try {
      final url = (name != null && name.isNotEmpty)
          ? "$apiUrl?name=$name"
          : apiUrl;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          channels = name != null && name.isNotEmpty
              ? [
            {
              "channel_id": data["data"]["searchId"],
              "channel_name": name,
            }
          ]
              : data["data"];
        });
      }
    } catch (e) {
      debugPrint("抓取頻道失敗: $e");
    }
  }

  // 展開/收合
  void toggleExpand(int channelId) {
    setState(() {
      expandedChannelId = (expandedChannelId == channelId) ? null : channelId;
    });
  }

  // 搜尋
  void searchChannels(String keyword) {
    fetchChannels(name: keyword);
  }

  // 新增頻道到資料庫
  Future<void> addChannelToDB(String name,
      {String? introduction, String? url}) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "name": name,
          "introduce": introduction,
          "url": url,
        }),
      );
      if (response.statusCode == 200) {
        fetchChannels(); // 新增後重新抓取
      }
    } catch (e) {
      debugPrint("新增頻道失敗: $e");
    }
  }

  // 刪除頻道到資料庫
  Future<void> deleteChannelFromDB(int id) async {
    try {
      final response = await http.delete(Uri.parse("$apiUrl/$id"));
      if (response.statusCode == 200) {
        fetchChannels(); // 刪除後重新抓取
      }
    } catch (e) {
      debugPrint("刪除頻道失敗: $e");
    }
  }

  // 新增頻道 Dialog（可輸入名稱、介紹、網址）
  void showAddDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController introController = TextEditingController();
    final TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("新增頻道"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: "頻道名稱"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: introController,
                decoration: const InputDecoration(hintText: "頻道介紹"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(hintText: "頻道網址"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                addChannelToDB(
                  nameController.text,
                  introduction: introController.text,
                  url: urlController.text,
                );
              }
              Navigator.pop(context);
            },
            child: const Text("新增"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("頻道管理"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: searchChannels,
              decoration: InputDecoration(
                hintText: "搜尋頻道...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: channels.isEmpty
          ? const Center(child: Text("沒有頻道資料"))
          : ListView.builder(
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          final bool isExpanded =
              expandedChannelId == channel["channel_id"];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(channel["channel_name"] ?? "未命名頻道"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          deleteChannelFromDB(channel["channel_id"]),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
                onTap: () => toggleExpand(channel["channel_id"]),
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "介紹：${channel["channel_introduction"] ?? "無"}"),
                      Text("網址：${channel["channel_url"] ?? "無"}"),
                      Text("總觀看：${channel["total_view"] ?? 0}"),
                      Text("總留言：${channel["total_comment"] ?? 0}"),
                      Text("總收藏：${channel["total_bookmark"] ?? 0}"),
                      Text("總分享：${channel["total_share"] ?? 0}"),
                      Text(
                          "近期觀看：${channel["total_recent_view"] ?? 0}"),
                      Text(
                          "近期留言：${channel["total_recent_comment"] ?? 0}"),
                      Text(
                          "近期收藏：${channel["total_recent_bookmark"] ?? 0}"),
                      Text(
                          "近期分享：${channel["total_recent_share"] ?? 0}"),
                      Text("總熱度：${channel["total_heat"] ?? 0}"),
                      Text("建立時間：${channel["created_at"] ?? "-"}"),
                      Text("更新時間：${channel["updated_at"] ?? "-"}"),
                    ],
                  ),
                ),
              const Divider(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
