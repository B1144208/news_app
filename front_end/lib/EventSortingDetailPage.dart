import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'MultiplePerspectivesDetailPage.dart';

class EventSortingDetailPage extends StatefulWidget {
  final int id;
  const EventSortingDetailPage({super.key, required this.id});

  @override
  State<EventSortingDetailPage> createState() => _EventSortingDetailPageState();
}

class _EventSortingDetailPageState extends State<EventSortingDetailPage> {
  // 將模擬的使用者 ID 設為可空，並在 initState 中讀取
  int? _currentUserId;

  bool _isEventSortingMode = true;
  final String _baseUrl = 'http://localhost:3000/api/EventSorting';
  final String _userActionBaseUrl = 'http://localhost:3000/api/user_action';
  final String _imageBaseUrl = 'http://localhost:3000/images';
  late Future<dynamic> _eventDetailsFuture;

  @override
  void initState() {
    super.initState();
    // 優先載入使用者 ID，再執行其他資料抓取
    _loadUserId().then((_) {
      _eventDetailsFuture = _fetchEventDetails();
      setState(() {}); // 觸發 UI 更新
    });
  }

  // 新增函式: 從本機儲存中讀取使用者 ID
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('userId');
    });
  }

  // 取得事件資料的函式，包含圖片 URL 的兩階段獲取邏輯
  Future<dynamic> _fetchEventDetails() async {
    final eventUri = Uri.parse(_baseUrl).replace(queryParameters: {'id': widget.id.toString()});

    try {
      final eventResponse = await http.get(eventUri);

      if (eventResponse.statusCode == 200) {
        final eventData = json.decode(eventResponse.body);
        if (eventData['data'].isNotEmpty) {
          final event = eventData['data'][0];

          final imageId = event['eventsorting_image'];
          if (imageId is int) {
            final imageUri = Uri.parse(_imageBaseUrl).replace(queryParameters: {'id': imageId.toString()});
            final imageResponse = await http.get(imageUri);

            if (imageResponse.statusCode == 200) {
              final imageData = json.decode(imageResponse.body);
              if (imageData['data'] != null && imageData['data']['image_origin_url'] is String) {
                event['eventsorting_image_url'] = imageData['data']['image_origin_url'];
              }
            }
          }
          return event;
        } else {
          return null;
        }
      } else {
        throw Exception('Failed to load event details');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  // 新增使用者行為記錄的 API 呼叫函式
  Future<void> _insertUserAction(String actionType, String dataType, {String? text, int? score}) async {
    final url = '$_userActionBaseUrl/$actionType/$dataType';
    final body = {
      'userId': _currentUserId,
      'dataId': widget.id,
      'text': text,
      'score': score,
    };

    // 'view' 和 'share' 使用 clientIp，不需 userId
    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1'; // 請替換為真實 IP
      body.remove('userId');
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print('Action $actionType recorded successfully!');
      } else {
        print('Failed to record action $actionType: ${response.body}');
      }
    } catch (e) {
      print('Error recording action: $e');
    }
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
            value: _isEventSortingMode,
            onChanged: (bool value) {
              setState(() {
                _isEventSortingMode = value;
              });
              if (!_isEventSortingMode) {
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
      body: FutureBuilder(
        future: _eventDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('載入失敗: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('找不到事件資料。'));
          } else {
            final event = snapshot.data;
            final List timelineItems = event['eventsorting_background'] ?? [];
            final mainImageUrl = event['eventsorting_image_url'];

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
          return _buildTimelineItem(
              item['time'] ?? '',
              item['title'] ?? '',
              item['description'] ?? '',
              item['source'] ?? '',
              item['image'] ?? ''
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTimelineItem(String time, String title, String description, String source, dynamic imagePath) {
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
            child: _buildImage(imagePath),
          ),
        ],
      ),
    );
  }

  // 處理主圖圖片的輔助函式
  Widget _buildMainImage(dynamic imageValue) {
    String? imageUrl;
    if (imageValue is int) {
      // 如果回傳的是數字 (圖片 ID)，則拼接 URL
      imageUrl = '$_imageBaseUrl?id=$imageValue';
    } else if (imageValue is String) {
      // 如果回傳的是 URL 字串，直接使用
      imageUrl = imageValue;
    }

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage(400, 200);
        },
      );
    }
    // 如果值是 null 或其他無法處理的類型，顯示佔位圖片
    return _buildPlaceholderImage(400, 200);
  }

  // 處理新聞脈絡圖片的輔助函式
  Widget _buildImage(dynamic imagePath) {
    if (imagePath != null && imagePath is String) {
      if (imagePath.startsWith('http')) {
        return Image.network(
          imagePath,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage(60, 60);
          },
        );
      } else {
        return Image.asset(
          imagePath,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage(60, 60);
          },
        );
      }
    }
    return _buildPlaceholderImage(60, 60);
  }

  // 新增一個共用的佔位圖片函式
  Widget _buildPlaceholderImage(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

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
          _buildActionIcon(
              icon: Icons.message,
              label: '留言',
              onTap: () {
                if (_currentUserId != null) {
                  // TODO: 顯示留言輸入框並呼叫 _insertUserAction('comment', ...)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('留言功能已啟用')),
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
                // TODO: 點擊聊天機器人功能
              }
          ),
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
          _buildActionIcon(
              icon: Icons.share,
              label: '分享',
              onTap: () {
                _insertUserAction('share', 'eventsorting');
                // TODO: 觸發系統分享功能
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