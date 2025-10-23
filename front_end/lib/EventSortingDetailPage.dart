import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 確保路徑正確
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

  // 💥 NEW: 儲存從 EventSorting API 獲取的分數數據
  int _totalScore = 0;
  int _totalRater = 0;
  // 💥 NEW: 計算平均分數 (四捨五入到小數點後一位)
  double get _averageScore => _totalRater > 0 ? (_totalScore / _totalRater) : 0.0;


  final String _userActionBaseUrl = '$baseUrl';
  final String _eventSortingUrl = '$baseUrl/EventSorting';
  final String _imageUrl = '$baseUrl/image';
  // 新聞 API URL，用於第二層 API 呼叫
  final String _newsUrl = '$baseUrl/news';

  late Future<Map<String, dynamic>> _eventDetailsAndImagesFuture;

  List<dynamic> _allImages = [];

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      // 確保在 _loadUserId 完成後才開始 fetch data
      _eventDetailsAndImagesFuture = _fetchEventDetailsAndImages();
      // 記錄 view action
      _insertUserAction('view', 'eventsorting');
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 注意：這裡使用 'UserID' 與您的程式碼保持一致
      _currentUserId = prefs.getInt('UserID');
      print('EventSortingDetailPage - Loaded UserID: $_currentUserId');
    });
  }

  // 💥 NEW: 重新獲取事件詳情，用於評分或留言後更新 UI
  Future<void> _refreshEventDetails() async {
    // 設置新的 Future，並觸發 UI 刷新
    setState(() {
      _eventDetailsAndImagesFuture = _fetchEventDetailsAndImages();
    });
  }

  // 修正後的 _fetchNewsDetails 函數：增強 JSON 數據結構的容錯性
  Future<Map<String, dynamic>> _fetchNewsDetails(List<int> newsIds) async {
    List<dynamic> timeline = [];

    // 使用 Future.wait 進行併發請求，提高效率
    final newsPromises = newsIds.map((id) {
      final newsUri = Uri.parse('$_newsUrl/$id');
      print('Fetching news details for ID $id from: $newsUri');

      return http.get(newsUri).then((response) {
        if (response.statusCode == 200) {
          try {
            // ** 修正：使用 utf8.decode 確保中文字元正確解析 **
            final data = json.decode(utf8.decode(response.bodyBytes));
            dynamic newsItem;

            // 1. 處理 { "data": [newsItem] } 格式 (陣列)
            if (data['data'] is List && data['data'].isNotEmpty) {
              newsItem = data['data'][0]; // 取出陣列的第一個元素
            }
            // 2. 處理 { "data": newsItem } 格式 (單一物件)
            else if (data['data'] is Map<String, dynamic>) {
              newsItem = data['data'];
            }

            // 確保 newsItem 是一個有效的 Map
            if (newsItem != null && newsItem is Map<String, dynamic>) {
              // 格式化數據以匹配 UI 需要的欄位名稱
              return {
                'id': newsItem['news_id'] as int? ?? id,
                'title': newsItem['news_title'] ?? '無標題',
                'time': newsItem['news_published_at'] ?? '未知時間',
                'source': newsItem['news_source'] ?? '未知來源',
                'image': newsItem['news_image'] as int? ?? -1, // 假設這是圖片ID
              };
            } else {
              print('Warning: News ID $id returned 200 but data format is invalid or missing.');
            }
          } catch (e) {
            print('Error: Failed to decode JSON for News ID $id. $e');
          }
        } else {
          print('Error: News ID $id API Failed with status ${response.statusCode}');
        }
        return null; // 獲取失敗或數據格式錯誤
      }).catchError((e) {
        print('Fatal Error: Failed to fetch news ID $id via API due to exception: $e');
        return null;
      });
    }).toList();

    // 等待所有新聞詳情請求完成
    timeline = (await Future.wait(newsPromises)).where((item) => item != null).toList();

    // 依據時間倒序排列 (最新的在前)
    // 這裡假設 'time' 欄位是可比較的字串格式 (如 ISO 8601)
    timeline.sort((a, b) => (b['time'] as String).compareTo(a['time'] as String));

    return {'eventsorting_timeline': timeline};
  }

  // 修正後的 _fetchEventDetailsAndImages 函數（修復 JSON 解碼錯誤）
  Future<Map<String, dynamic>> _fetchEventDetailsAndImages() async {
    final eventUri = Uri.parse(_eventSortingUrl).replace(queryParameters: {'id': widget.id.toString()});
    final imagesUri = Uri.parse(_imageUrl);

    try {
      final eventResponse = await http.get(eventUri);
      final imagesResponse = await http.get(imagesUri);

      if (eventResponse.statusCode != 200) {
        throw Exception('Failed to load event details: ${eventResponse.statusCode}');
      }

      // ** 修正：使用 utf8.decode 確保中文字元正確解析 **
      if (imagesResponse.statusCode == 200) {
        final imagesData = json.decode(utf8.decode(imagesResponse.bodyBytes));
        _allImages = imagesData['data'] is List ? imagesData['data'] : [];
      } else {
        print('Warning: Failed to load all images. Status code: ${imagesResponse.statusCode}');
        _allImages = [];
      }

      // ** 修正：使用 utf8.decode 確保中文字元正確解析 **
      final eventData = json.decode(utf8.decode(eventResponse.bodyBytes));
      Map<String, dynamic>? event;

      // 處理後端返回單一物件或單元素列表的情況
      if (eventData['data'] is List && eventData['data'].isNotEmpty) {
        event = eventData['data'][0];
      } else if (eventData['data'] is Map<String, dynamic>) {
        event = eventData['data'];
      }

      if (event == null) {
        throw Exception('Event not found or data format invalid');
      }

      // 💥 NEW: 獲取並保存分數數據
      if (mounted) {
        setState(() {
          // 假設 API 欄位為 'total_score' 和 'total_rater'
          _totalScore = event!['total_score'] as int? ?? 0;
          _totalRater = event!['total_rater'] as int? ?? 0;
          print('Fetched Score: Total Score $_totalScore, Total Rater $_totalRater');
        });
      }

      // 2. 關鍵修正：從 'vertical_news' 欄位中提取新聞 ID 列表 (陣列格式)
      final dynamic rawNewsIds = event['vertical_news'];
      List<int> newsIds = [];

      if (rawNewsIds is List) {
        // 確保列表中的元素都是 int
        // 使用 map().where().toList() 確保類型安全
        newsIds = rawNewsIds.map((e) => e is int ? e : (e is String ? int.tryParse(e) : null)).where((e) => e != null).cast<int>().toList();
      }

      // 處理 horizontal_events 欄位，確保其為 List<int>
      final dynamic rawHorizontalIds = event['horizontal_events'];
      if (rawHorizontalIds is List) {
        // 同樣確保類型安全
        event['horizontal_events'] = rawHorizontalIds.map((e) => e is int ? e : (e is String ? int.tryParse(e) : null)).where((e) => e != null).cast<int>().toList();
      } else {
        event['horizontal_events'] = [];
      }

      // 3. 呼叫 _fetchNewsDetails 取得新聞脈絡詳情
      final timelineResult = await _fetchNewsDetails(newsIds);

      // 4. 組合主事件數據和新聞脈絡數據
      return {
        ...event,
        ...timelineResult, // 包含 'eventsorting_timeline'
      };

    } catch (e) {
      // 這裡會捕獲所有 API 連線或資料解析錯誤，並向上拋出
      throw Exception('Failed to connect to API or process data: $e');
    }
  }

  // 💥 NEW: 導航至 CommentsPage 的函式，傳遞分數和回調
  void _navigateToCommentsPage() {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入以使用評分/留言功能')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsPage(
          dataId: widget.id,
          currentUserId: _currentUserId,
          dataType: 'eventsorting',
          insertUserAction: _insertUserAction,
          // 💥 NEW: 傳遞目前的分數數據和更新回調
          totalScore: _totalScore,
          totalRater: _totalRater,
          onParentDataUpdated: _refreshEventDetails, // 傳遞回調函式
        ),
      ),
    );
  }

  // 以下為保持不變的輔助函數和 UI 結構 (已包含您提供的所有函式)

  String _findImageUrlById(int imageId) {
    if (_allImages.isEmpty || imageId <= 0) {
      return '';
    }
    try {
      final image = _allImages.firstWhere(
            (img) => img['image_id'] == imageId,
        // orElse: () => null 已在 Flutter 3.0+ 中棄用，這裡使用 {} 並檢查
        orElse: () => null,
      );
      // 確保回傳一個非 null 的字串
      return image?['image_origin_url'] ?? '';
    } catch (e) {
      print('Error finding image with ID $imageId: $e');
      return '';
    }
  }

  // 通用 API 函式：處理所有用戶行為 (view, share, bookmark, comment, score)
  Future<void> _insertUserAction(String actionType, String dataType, {String? text, int? score}) async {
    // 保持您的原始 API 結構
    final url = '$_userActionBaseUrl/user/$actionType/$dataType';

    final body = <String, dynamic>{
      'userId': _currentUserId,
      'dataId': widget.id,
      if (text != null && text.isNotEmpty) 'text': text,
      if (score != null) 'score': score,
    };

    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1';
      body.remove('userId');
    }

    body.removeWhere((key, value) => value == null);

    print('Sending API to: $url');
    print('Request Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print('Action $actionType recorded successfully! Response: ${response.body}');

        // 💥 NEW: 如果是 score 或 comment 成功，嘗試更新父頁面數據
        if (actionType == 'score' || actionType == 'comment') {
          // 由於 _fetchEventDetailsAndImages 會自動更新分數狀態，
          // 這裡只需在用戶操作成功後重新載入數據
          _refreshEventDetails();
        }

      } else {
        print('Failed to record action $actionType. Status: ${response.statusCode}, Body: ${response.body}');
        if (actionType != 'view') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失敗: ${response.statusCode} - ${json.decode(response.body)['message'] ?? '伺服器錯誤'}')),
          );
        }
      }
    } catch (e) {
      print('Error recording action: $e');
      if (actionType != 'view') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('連線錯誤: $e')),
        );
      }
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
        title: FutureBuilder<Map<String, dynamic>>(
          future: _eventDetailsAndImagesFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              // 注意：這裡使用 'eventsorting_title' 與您的程式碼保持一致
              return Text(
                snapshot.data!['eventsorting_title'] ?? '事件整理',
                style: const TextStyle(color: Colors.black, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              );
            }
            return const Text('事件整理', style: TextStyle(color: Colors.black));
          },
        ),
        actions: [
          Switch(
            value: !_isEventSortingMode,
            onChanged: (bool value) {
              if (value) {
                // 切換到多角度頁面
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
            // 顯示載入失敗的錯誤訊息
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  '資料載入失敗: \n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16, height: 1.5),
                ),
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(child: Text('找不到事件資料。'));
          } else {
            final event = snapshot.data!;
            // 🚨 從組合後的數據中獲取 timeline data
            final List timelineItems = event['eventsorting_timeline'] ?? [];

            final mainImageId = event['eventsorting_image'] as int? ?? -1;
            final mainImageUrl = _findImageUrlById(mainImageId);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDisclaimer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: _buildMainImage(mainImageUrl, context),
                    ),
                  ),
                  // 注意：這裡使用 'eventsorting_summary' 與您的程式碼保持一致
                  _buildSummaryCard(event['eventsorting_summary'] ?? '無摘要內容。'),
                  // 💥 NEW: 顯示目前分數
                  _buildScoreCard(),
                  _buildTimelineSection(timelineItems),
                  const SizedBox(height: 50),
                ],
              ),
            );
          }
        },
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  // --- 輔助 Widget 函式 ---

  // 💥 NEW: 顯示分數的 Widget
  Widget _buildScoreCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          Text(
            // 格式化分數，保留一位小數
            '${_averageScore.toStringAsFixed(1)} / 5.0',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Text(
            '來自 $_totalRater 位使用者評分',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMainImage(String? imageUrl, BuildContext context) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: MediaQuery.of(context).size.width,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage(MediaQuery.of(context).size.width, 220);
        },
      );
    }
    return _buildPlaceholderImage(MediaQuery.of(context).size.width, 220);
  }

  Widget _buildSummaryCard(String summary) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
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
            const Divider(height: 20),
            Text(summary, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSection(List items) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('新聞脈絡整理', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('無相關新聞脈絡資料。'),
            ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            final timelineImageId = item['image'] as int? ?? -1;
            final timelineImageUrl = _findImageUrlById(timelineImageId);

            final isLast = index == items.length - 1;

            return _buildTimelineItem(
                item['time'] ?? '',
                item['title'] ?? '',
                item['source'] ?? '',
                timelineImageUrl,
                isLast
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String time, String title, String source, String imageUrl, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(source, style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
                  ],
                ),
              ),
            ),
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
    // 如果 URL 為空，顯示黑色佔位符
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

  Widget _buildPlaceholderImage(double width, double height) {
    // 專門為新聞脈絡的小圖 (60x60) 使用黑色背景
    if (width == 60 && height == 60) {
      return Container(
        width: width,
        height: height,
        color: Colors.black, // 小圖片使用黑色佔位符
      );
    }
    // 主圖使用灰色背景
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
          // 💥 MODIFIED: 評分/留言
          _buildActionIcon(
              icon: Icons.message, // 保留留言圖標，但功能包含評分
              label: '評分/留言',
              onTap: _navigateToCommentsPage // 呼叫統一的導航函式
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