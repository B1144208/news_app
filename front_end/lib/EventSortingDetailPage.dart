import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 確保路徑正確，以便引入 CommentsPage.dart
import 'CommentsPage.dart';
import 'MultiplePerspectivesDetailPage.dart';
import 'config.dart';

class EventSortingDetailPage extends StatefulWidget {
  final int id;
  const EventSortingDetailPage({super.key, required this.id});

  @override
  State<EventSortingDetailPage> createState() => _EventSortingDetailPageState();
}

class _EventSortingDetailPageState extends State<EventSortingDetailPage> {
  int? _currentUserId;
  bool _isEventSortingMode = true;

  // 💥 修正 API URL 基礎路徑：
  // 設置為 $baseUrl，在 _insertUserAction 中手動添加 /user/，以匹配後端 Router
  final String _userActionBaseUrl = '$baseUrl';

  final String _eventSortingUrl = '$baseUrl/EventSorting';
  final String _imageUrl = '$baseUrl/image';

  late Future<Map<String, dynamic>> _eventDetailsAndImagesFuture;

  List<dynamic> _allImages = [];

  @override
  void initState() {
    super.initState();
    // 優先載入 UserID，確保後續 API 呼叫能包含用戶資訊
    _loadUserId().then((_) {
      // 確保在記錄 view 動作前，userId 已經載入
      _eventDetailsAndImagesFuture = _fetchEventDetailsAndImages();
      _insertUserAction('view', 'eventsorting');
    });
  }

  // 🐛 關鍵修復：確保讀取登入頁面存儲的 'UserID' (大寫)
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('UserID'); // 使用 'UserID'
      print('EventSortingDetailPage - Loaded UserID: $_currentUserId'); // 偵錯用
    });
  }

  Future<Map<String, dynamic>> _fetchEventDetailsAndImages() async {
    final eventUri = Uri.parse(_eventSortingUrl).replace(queryParameters: {'id': widget.id.toString()});
    final imagesUri = Uri.parse(_imageUrl);

    try {
      final eventResponse = await http.get(eventUri);
      final imagesResponse = await http.get(imagesUri);

      if (eventResponse.statusCode != 200) {
        throw Exception('Failed to load event details: ${eventResponse.statusCode}');
      }

      if (imagesResponse.statusCode == 200) {
        final imagesData = json.decode(imagesResponse.body);
        _allImages = imagesData['data'] is List ? imagesData['data'] : [];
      } else {
        print('Warning: Failed to load all images. Status code: ${imagesResponse.statusCode}');
        _allImages = [];
      }

      final eventData = json.decode(eventResponse.body);
      if (eventData['data'] is List && eventData['data'].isNotEmpty) {
        return eventData['data'][0];
      } else {
        throw Exception('Event not found or data format invalid');
      }
    } catch (e) {
      throw Exception('Failed to connect to API or process data: $e');
    }
  }

  String _findImageUrlById(int imageId) {
    if (_allImages.isEmpty || imageId <= 0) {
      return '';
    }
    try {
      final image = _allImages.firstWhere(
            (img) => img['image_id'] == imageId,
        orElse: () => null,
      );
      // 確保回傳一個非 null 的字串
      return image?['image_origin_url'] ?? '';
    } catch (e) {
      print('Error finding image with ID $imageId: $e');
      return '';
    }
  }

  // 💥 通用 API 函式：處理所有用戶行為 (view, share, bookmark, comment, score)
  Future<void> _insertUserAction(String actionType, String dataType, {String? text, int? score}) async {
    // 💥 構造正確的 URL： $baseUrl/user/:actionType/:dataType
    final url = '$_userActionBaseUrl/user/$actionType/$dataType';

    final body = <String, dynamic>{
      'userId': _currentUserId, // 初始包含 userId (如果非 null)
      'dataId': widget.id,
      if (text != null && text.isNotEmpty) 'text': text,
      if (score != null) 'score': score, // 只有非 null 才傳遞
    };

    // 根據後端邏輯，view 和 share 需移除 userId, 改傳 clientIp
    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1'; // 提供 clientIp
      body.remove('userId'); // 移除 userId
    }

    // 最終移除 body 中 value 為 null 的鍵
    body.removeWhere((key, value) => value == null);

    print('Sending API to: $url');
    print('Request Body: ${json.encode(body)}'); // 偵錯用

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print('Action $actionType recorded successfully! Response: ${response.body}');
      } else {
        print('Failed to record action $actionType. Status: ${response.statusCode}, Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失敗: ${response.statusCode} - ${json.decode(response.body)['message'] ?? '伺服器錯誤'}')),
        );
      }
    } catch (e) {
      print('Error recording action: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('連線錯誤: $e')),
      );
    }
  }

  // 評分對話框函式保持不變
  Future<void> _showRatingDialog() async {
    int? selectedScore;

    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入以使用評分功能')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('為此事件整理評分'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('請給予 1 到 5 分 (5 分為最高)：'),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final score = index + 1;
                      return IconButton(
                        icon: Icon(
                          score <= (selectedScore ?? 0) ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedScore = score;
                          });
                        },
                      );
                    }),
                  );
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('確定'),
              onPressed: () {
                if (selectedScore != null && selectedScore! >= 1 && selectedScore! <= 5) {
                  // 呼叫 API 記錄評分
                  _insertUserAction('score', 'eventsorting', score: selectedScore);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('感謝您的 $selectedScore 分評分!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請選擇有效的分數 (1-5)！')),
                  );
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('事件整理', style: TextStyle(color: Colors.black)),
        actions: [
          Switch(
            value: !_isEventSortingMode,
            onChanged: (bool value) {
              if (value) {
                // 假設 MultiplePerspectivesDetailPage 也在同一個 id 上操作
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MultiplePerspectivesDetailPage(id: widget.id)),
                );
              }
            },
            activeColor: Colors.blue,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _eventDetailsAndImagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('載入失敗: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('找不到事件資料。'));
          } else {
            final event = snapshot.data!;
            final List timelineItems = event['eventsorting_background'] ?? [];

            final mainImageId = event['eventsorting_image'] as int? ?? -1;
            final mainImageUrl = _findImageUrlById(mainImageId);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDisclaimer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            event['eventsorting_title'] ?? '',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: _buildMainImage(mainImageUrl),
                    ),
                  ),
                  _buildSummaryCard(event['eventsorting_summary'] ?? ''),
                  _buildTimelineSection(timelineItems),
                ],
              ),
            );
          }
        },
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  // --- 輔助 Widget 函式 (保持不變) ---

  Widget _buildMainImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage(400, 200);
        },
      );
    }
    return _buildPlaceholderImage(400, 200);
  }

  Widget _buildTimelineSection(List items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('新聞脈絡整理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('無相關新聞脈絡資料。'),
          ),
        ...items.map((item) {
          final timelineImageId = item['image'] as int? ?? -1;
          final timelineImageUrl = _findImageUrlById(timelineImageId);

          return _buildTimelineItem(
              item['time'] ?? '',
              item['title'] ?? '',
              item['description'] ?? '',
              item['source'] ?? '',
              timelineImageUrl
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTimelineItem(String time, String title, String description, String source, String imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(time, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (description.isNotEmpty) Text(description, style: const TextStyle(fontSize: 14)),
                Text(source, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: _buildImage(imageUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage(60, 60);
        },
      );
    }
    return _buildPlaceholderImage(60, 60);
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text("使用AI技術協助", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.info_outline, size: 14, color: Colors.grey),
          const Spacer(),
          const Text("資訊若有失真狀況，一概不負法律責任", style: TextStyle(color: Colors.red, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String summary) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('重點摘要', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                const Text('16篇 • 摘要使用AI技術協助', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 4),
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(summary, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  // --- 底部操作欄位 (Bottom Actions) ---

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 💥 留言按鈕：導航到通用 CommentsPage
          _buildActionIcon(
              icon: Icons.message,
              label: '留言',
              onTap: () {
                if (_currentUserId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommentsPage(
                        dataId: widget.id, // 傳遞事件 ID
                        currentUserId: _currentUserId,
                        dataType: 'eventsorting', // 傳遞數據類型
                        insertUserAction: _insertUserAction, // 傳遞 API 函式
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請先登入以使用留言功能')),
                  );
                }
              }
          ),

          _buildActionIcon(
              icon: Icons.chat_bubble_outline,
              label: '聊天機器人',
              onTap: () {
                if (_currentUserId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('點擊了聊天機器人，待實作導航')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請先登入以使用聊天機器人')),
                  );
                }
              }
          ),

          // 評分按鈕
          _buildActionIcon(
              icon: Icons.star,
              label: '評分',
              onTap: _showRatingDialog
          ),

          // 收藏按鈕
          _buildActionIcon(
              icon: Icons.bookmark,
              label: '收藏',
              onTap: () {
                if (_currentUserId != null) {
                  _insertUserAction('bookmark', 'eventsorting');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已收藏此事件')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請先登入以使用收藏功能')),
                  );
                }
              }
          ),

          // 分享按鈕
          _buildActionIcon(
              icon: Icons.share,
              label: '分享',
              onTap: () {
                _insertUserAction('share', 'eventsorting');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分享功能已啟用')),
                );
              }
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey.shade700),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ],
      ),
    );
  }
}