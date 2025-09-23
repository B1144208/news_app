import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  // 定義 API 基礎 URL
  final String _eventSortingUrl = '$baseUrl/api/EventSorting';
  final String _userActionUrl = '$baseUrl/api/user_action';
  final String _imageUrl = '$baseUrl/api/image'; // 這裡使用取得所有圖片的API

  late Future<Map<String, dynamic>> _eventDetailsAndImagesFuture;

  // 儲存所有圖片資料的列表，以便比對
  List<dynamic> _allImages = [];

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      _eventDetailsAndImagesFuture = _fetchEventDetailsAndImages();
      _insertUserAction('view', 'eventsorting');
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('userId');
    });
  }

  // 新增的合併資料獲取函式
  Future<Map<String, dynamic>> _fetchEventDetailsAndImages() async {
    final eventUri = Uri.parse(_eventSortingUrl).replace(queryParameters: {'id': widget.id.toString()});
    final imagesUri = Uri.parse(_imageUrl);

    try {
      // 1. 同時發送兩個 API 請求
      final eventResponse = await http.get(eventUri);
      final imagesResponse = await http.get(imagesUri);

      // 檢查事件資料的回應
      if (eventResponse.statusCode != 200) {
        throw Exception('Failed to load event details');
      }

      // 檢查圖片資料的回應
      if (imagesResponse.statusCode == 200) {
        final imagesData = json.decode(imagesResponse.body);
        _allImages = imagesData['data'] ?? [];
      } else {
        print('Warning: Failed to load all images. Status code: ${imagesResponse.statusCode}');
        _allImages = []; // 確保即使失敗也能繼續執行
      }

      final eventData = json.decode(eventResponse.body);
      if (eventData['data'].isNotEmpty) {
        return eventData['data'][0];
      } else {
        throw Exception('Event not found');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  // 根據 ID 找到對應的圖片 URL
  String _findImageUrlById(int imageId) {
    if (_allImages.isEmpty) {
      return '';
    }
    try {
      final image = _allImages.firstWhere(
            (img) => img['image_id'] == imageId,
        // 如果找不到，返回一個空地圖或 null
        orElse: () => null,
      );
      return image?['image_origin_url'] ?? '';
    } catch (e) {
      print('Error finding image with ID $imageId: $e');
      return '';
    }
  }

  // 原有的使用者行為記錄函式不變
  Future<void> _insertUserAction(String actionType, String dataType, {String? text, int? score}) async {
    final url = '$_userActionUrl/$actionType/$dataType';
    final body = {
      'userId': _currentUserId,
      'dataId': widget.id,
      'text': text,
      'score': score,
    };

    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1';
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
      // ... (省略不變的 Scaffold 和 AppBar 部分)
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
              setState(() {
                _isEventSortingMode = !value;
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
            final mainImageId = event['eventsorting_image'];

            // 根據 ID 找到對應的 URL
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
                      child: _buildMainImage(mainImageUrl), // 直接傳入 URL 字串
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

  // 由於現在直接傳入 URL，_buildMainImage 和 _buildImage 函式需要調整
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
          // 處理新聞脈絡中的圖片 ID
          final timelineImageId = item['image'];
          final timelineImageUrl = _findImageUrlById(timelineImageId is int ? timelineImageId : -1);

          return _buildTimelineItem(
              item['time'] ?? '',
              item['title'] ?? '',
              item['description'] ?? '',
              item['source'] ?? '',
              timelineImageUrl // 傳入 URL
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
            child: _buildImage(imageUrl), // 直接傳入 URL 字串
          ),
        ],
      ),
    );
  }

  // 處理新聞脈絡圖片的輔助函式
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

  // 剩下的函式 (例如 _buildDisclaimer, _buildSummaryCard 等) 保持不變
  // ... (此處省略以保持程式碼簡潔)

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