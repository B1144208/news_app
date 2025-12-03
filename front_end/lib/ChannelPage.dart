import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'config.dart';
import 'ChannelDetailPage.dart';
import 'ViewNewsContent.dart';

class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key});

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  late String apiUrl;

  List<dynamic> channels = [];
  int? expandedChannelId;
  bool isLoading = false;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    apiUrl = '${Config.apiBaseUrl}/channel';
    fetchChannels();
  }

  // 取得頻道清單或搜尋
  Future<void> fetchChannels({String? name}) async {
    setState(() => isLoading = true);

    try {
      final url =
          (name != null && name.isNotEmpty) ? "$apiUrl?name=$name" : apiUrl;
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          channels =
              name != null && name.isNotEmpty
                  ? [
                    {
                      "channel_id": data["data"]["searchId"],
                      "channel_name": name,
                    },
                  ]
                  : data["data"];
          searchQuery = name ?? "";
        });
      } else {
        _showErrorMessage('載入頻道失敗: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("抓取頻道失敗: $e");
      _showErrorMessage('網路連接錯誤');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 展開/收合
  void toggleExpand(int channelId) {
    setState(() {
      expandedChannelId = (expandedChannelId == channelId) ? null : channelId;
    });
  }

  // 搜尋頻道
  void searchChannels(String keyword) {
    fetchChannels(name: keyword.trim());
  }

  // 新增頻道到資料庫
  Future<void> addChannelToDB(
    String name, {
    String? introduction,
    String? url,
  }) async {
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
        _showSuccessMessage('頻道新增成功');
        fetchChannels(); // 新增後重新抓取
      } else {
        _showErrorMessage('新增失敗: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("新增頻道失敗: $e");
      _showErrorMessage('網路連接錯誤');
    }
  }

  // 刪除頻道到資料庫
  Future<void> deleteChannelFromDB(int id) async {
    try {
      final response = await http.delete(Uri.parse("$apiUrl/$id"));

      if (response.statusCode == 200) {
        _showSuccessMessage('頻道刪除成功');
        fetchChannels(); // 刪除後重新抓取
      } else {
        _showErrorMessage('刪除失敗: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("刪除頻道失敗: $e");
      _showErrorMessage('網路連接錯誤');
    }
  }

  // 主要內容區域
  Widget _buildChannelContent() {
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

    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isEmpty ? Icons.tv : Icons.tv_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isEmpty ? '目前沒有頻道資料' : '未找到相關頻道',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '點擊新增按鈕創建第一個頻道',
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
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  '搜尋結果: "$searchQuery" (${channels.length}個)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
          ),

        // 頻道列表
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            return _buildChannelCard(channel);
          },
        ),
      ],
    );
  }

  // 頻道卡片
  Widget _buildChannelCard(dynamic channel) {
    final bool isExpanded = expandedChannelId == channel["channel_id"];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // 頻道基本資訊
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tv, color: Colors.purple, size: 24),
            ),
            title: Text(
              channel["channel_name"] ?? "未命名頻道",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle:
                channel["channel_introduction"] != null
                    ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        channel["channel_introduction"],
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                    : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red[600],
                  onPressed: () => _showDeleteConfirmDialog(channel),
                  tooltip: '刪除頻道',
                ),
                IconButton(
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () => toggleExpand(channel["channel_id"]),
                  tooltip: isExpanded ? '收合' : '展開',
                ),
              ],
            ),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ChannelDetailPage(
                          channelId: channel["channel_id"],
                          channelName: channel["channel_name"] ?? "未命名頻道",
                          channelDescription: channel["channel_introduction"],
                          channelUrl: channel["channel_url"],
                        ),
                  ),
                ),
          ),

          // 展開的詳細資訊
          if (isExpanded) _buildExpandedInfo(channel),
        ],
      ),
    );
  }

  // 展開資訊區域
  Widget _buildExpandedInfo(dynamic channel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本資訊
          _buildInfoSection('基本資訊', [
            _buildInfoRow('介紹', channel["channel_introduction"] ?? '無'),
            _buildInfoRow('網址', channel["channel_url"] ?? '無'),
            _buildInfoRow('建立時間', channel["created_at"] ?? '-'),
            _buildInfoRow('更新時間', channel["updated_at"] ?? '-'),
          ]),

          const SizedBox(height: 16),

          // 統計數據
          _buildInfoSection('統計數據', [
            _buildStatRow([
              _buildStatChip(
                '總觀看',
                '${channel["total_view"] ?? 0}',
                Icons.visibility,
              ),
              _buildStatChip(
                '總留言',
                '${channel["total_comment"] ?? 0}',
                Icons.comment,
              ),
            ]),
            const SizedBox(height: 8),
            _buildStatRow([
              _buildStatChip(
                '總收藏',
                '${channel["total_bookmark"] ?? 0}',
                Icons.bookmark,
              ),
              _buildStatChip(
                '總分享',
                '${channel["total_share"] ?? 0}',
                Icons.share,
              ),
            ]),
          ]),

          const SizedBox(height: 16),

          // 近期數據
          _buildInfoSection('近期數據', [
            _buildStatRow([
              _buildStatChip(
                '近期觀看',
                '${channel["total_recent_view"] ?? 0}',
                Icons.visibility_outlined,
              ),
              _buildStatChip(
                '近期留言',
                '${channel["total_recent_comment"] ?? 0}',
                Icons.comment_outlined,
              ),
            ]),
            const SizedBox(height: 8),
            _buildStatRow([
              _buildStatChip(
                '近期收藏',
                '${channel["total_recent_bookmark"] ?? 0}',
                Icons.bookmark_outline,
              ),
              _buildStatChip(
                '近期分享',
                '${channel["total_recent_share"] ?? 0}',
                Icons.share_outlined,
              ),
            ]),
          ]),

          const SizedBox(height: 16),

          // 熱度指標
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.whatshot, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  '總熱度',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.orange[700],
                  ),
                ),
                const Spacer(),
                Text(
                  '${channel["total_heat"] ?? 0}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.purple[700],
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(List<Widget> children) {
    return Row(
      children: children.map((child) => Expanded(child: child)).toList(),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 對話框和輔助方法

  // 新增頻道 Dialog（可輸入名稱、介紹、網址）
  void showAddDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController introController = TextEditingController();
    final TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.tv, color: Colors.purple),
                const SizedBox(width: 8),
                const Text("新增頻道"),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: "頻道名稱",
                      hintText: "請輸入頻道名稱",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tv),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: introController,
                    decoration: const InputDecoration(
                      labelText: "頻道介紹",
                      hintText: "請輸入頻道介紹",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: "頻道網址",
                      hintText: "請輸入頻道網址",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
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
                      introduction:
                          introController.text.isEmpty
                              ? null
                              : introController.text,
                      url:
                          urlController.text.isEmpty
                              ? null
                              : urlController.text,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text("新增"),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmDialog(dynamic channel) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[600]),
                const SizedBox(width: 8),
                const Text('確認刪除'),
              ],
            ),
            content: Text(
              '確定要刪除頻道 "${channel["channel_name"]}" 嗎？\n\n此操作無法復原。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  deleteChannelFromDB(channel["channel_id"]);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('刪除'),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        title: const Text('頻道管理'),
        backgroundColor: const Color(0xFF0a1428),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [_buildChannelContent(), const SizedBox(height: 80)],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        backgroundColor: const Color(0xFF60a5fa),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: '新增頻道',
      ),
    );
  }
}
