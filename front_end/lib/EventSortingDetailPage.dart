import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 確保路徑正確
import 'CommentsPage.dart';
import 'MultiplePerspectivesDetailPage.dart';
import 'config.dart';
import 'ViewnewsContent.dart';

// 請確保您的 config.dart 中定義了 baseUrl
// final String baseUrl = 'YOUR_BASE_URL';

class EventSortingDetailPage extends StatefulWidget {
  final int id;
  const EventSortingDetailPage({super.key, required this.id});

  @override
  State<EventSortingDetailPage> createState() => _EventSortingDetailPageState();
}

class _EventSortingDetailPageState extends State<EventSortingDetailPage> {
  int? _currentUserId;
  bool _isEventSortingMode = true;

  // 儲存從 EventSorting API 獲取的分數數據
  int _totalScore = 0;
  int _totalRater = 0;

  // 儲存實際的留言人數 (從 total_comment 欄位獲取)
  int _commentCount = 0;

  // 模擬收藏狀態
  bool isFavorite = false;

  // 計算平均分數 (四捨五入到小數點後一位)
  double get _averageScore => _totalRater > 0 ? (_totalScore / _totalRater) : 0.0;


  final String _userActionBaseUrl = '$baseUrl';
  final String _eventSortingUrl = '$baseUrl/EventSorting';
  final String _imageUrl = '$baseUrl/image';
  // 新聞 API URL，用於第二層 API 呼叫
  final String _newsUrl = '$baseUrl/news';

  late Future<Map<String, dynamic>> _eventDetailsAndImagesFuture;

  // 💥 保留: 儲存水平關聯事件的資料，用於確定箭頭導航目標
  List<Map<String, dynamic>> _horizontalEventsDetails = [];

  List<dynamic> _allImages = [];

  // 💥 NEW: 獲取下一個導航事件的 ID
  int? get _nextEventId {
    // 這裡假設浮動箭頭是用來導航到列表中的第一個相關事件
    if (_horizontalEventsDetails.isNotEmpty) {
      // 確保 id 存在且是 int
      return _horizontalEventsDetails[0]['id'] as int? ?? -1;
    }
    return null;
  }

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
      _currentUserId = prefs.getInt('UserID');
      print('EventSortingDetailPage - Loaded UserID: $_currentUserId');
    });
  }

  Future<void> _refreshEventDetails() async {
    setState(() {
      _eventDetailsAndImagesFuture = _fetchEventDetailsAndImages();
    });
  }

  // 💥 保留: 獲取單個 EventSorting 的詳情 (用於 horizontal_events)
  Future<Map<String, dynamic>?> _fetchSingleEventDetails(int eventId) async {
    final eventUri = Uri.parse(_eventSortingUrl).replace(queryParameters: {'id': eventId.toString()});
    try {
      final eventResponse = await http.get(eventUri);

      if (eventResponse.statusCode == 200) {
        final eventData = json.decode(utf8.decode(eventResponse.bodyBytes));
        if (eventData['data'] is List && eventData['data'].isNotEmpty) {
          return eventData['data'][0] as Map<String, dynamic>;
        } else if (eventData['data'] is Map<String, dynamic>) {
          return eventData['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print('Error fetching single event $eventId: $e');
    }
    return null;
  }

  // 💥 保留: 獲取所有 horizontal_events 的詳情 (現在只用於填充 _horizontalEventsDetails)
  Future<void> _fetchHorizontalEventsDetails(List<int> eventIds) async {
    List<Future<Map<String, dynamic>?>> futures = eventIds.map((id) async {
      final details = await _fetchSingleEventDetails(id);
      if (details != null) {
        return {
          'id': id,
          'title': details['eventsorting_title'] ?? '未知事件',
          'image': details['eventsorting_image'] as int? ?? -1,
        };
      }
      return null;
    }).toList();

    final results = (await Future.wait(futures)).where((item) => item != null).cast<Map<String, dynamic>>().toList();

    if (mounted) {
      setState(() {
        _horizontalEventsDetails = results;
      });
    }
  }


  Future<Map<String, dynamic>> _fetchNewsDetails(List<int> newsIds) async {
    List<dynamic> timeline = [];

    final newsPromises = newsIds.map((id) {
      final newsUri = Uri.parse('$_newsUrl/$id');

      return http.get(newsUri).then((response) {
        if (response.statusCode == 200) {
          try {
            final data = json.decode(utf8.decode(response.bodyBytes));
            dynamic newsItem;

            if (data['data'] is List && data['data'].isNotEmpty) {
              newsItem = data['data'][0];
            }
            else if (data['data'] is Map<String, dynamic>) {
              newsItem = data['data'];
            }

            if (newsItem != null && newsItem is Map<String, dynamic>) {
              return {
                'id': newsItem['news_id'] as int? ?? id,
                'title': newsItem['news_title'] ?? '無標題',
                'time': newsItem['news_published_at'] ?? '未知時間',
                'source': newsItem['news_source'] ?? '未知來源',
                'image': newsItem['news_image'] as int? ?? -1,

                // 確保 ViewNewsContent 所需的欄位也存在
                'channel_id': newsItem['channel_id'] as int? ?? 1,
                'channel': newsItem['news_source'] ?? '未知來源',
                'news_date': newsItem['news_published_at'] ?? '未知時間',
                'comments': newsItem['total_comment'] as int? ?? 0,
                'cover_image': newsItem['news_image'] as int? ?? -1,
              };
            }
          } catch (e) {
            print('Error: Failed to decode JSON for News ID $id. $e');
          }
        }
        return null;
      }).catchError((e) {
        print('Fatal Error: Failed to fetch news ID $id via API due to exception: $e');
        return null;
      });
    }).toList();

    timeline = (await Future.wait(newsPromises)).where((item) => item != null).toList();
    timeline.sort((a, b) => (b['time'] as String).compareTo(a['time'] as String));

    return {'eventsorting_timeline': timeline};
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
        final imagesData = json.decode(utf8.decode(imagesResponse.bodyBytes));
        _allImages = imagesData['data'] is List ? imagesData['data'] : [];
      } else {
        _allImages = [];
      }

      final eventData = json.decode(utf8.decode(eventResponse.bodyBytes));
      Map<String, dynamic>? event;

      if (eventData['data'] is List && eventData['data'].isNotEmpty) {
        event = eventData['data'][0];
      } else if (eventData['data'] is Map<String, dynamic>) {
        event = eventData['data'];
      }

      if (event == null) {
        throw Exception('Event not found or data format invalid');
      }

      if (mounted) {
        setState(() {
          _totalScore = event!['total_score'] as int? ?? 0;
          _totalRater = event!['total_rater'] as int? ?? 0;
          _commentCount = event!['total_comment'] as int? ?? 0;
        });
      }

      final dynamic rawNewsIds = event['vertical_news'];
      List<int> newsIds = [];
      if (rawNewsIds is List) {
        newsIds = rawNewsIds.map((e) => e is int ? e : (e is String ? int.tryParse(e) : null)).where((e) => e != null).cast<int>().toList();
      }

      // 2. 處理 horizontal_events 並觸發詳情獲取
      final dynamic rawHorizontalIds = event['horizontal_events'];
      List<int> horizontalIds = [];
      if (rawHorizontalIds is List) {
        horizontalIds = rawHorizontalIds.map((e) => e is int ? e : (e is String ? int.tryParse(e) : null)).where((e) => e != null).cast<int>().toList();
      }

      if (horizontalIds.isNotEmpty) {
        // 異步獲取水平事件詳情，用於浮動箭頭的導航目標
        _fetchHorizontalEventsDetails(horizontalIds);
      } else {
        if (mounted) {
          setState(() {
            _horizontalEventsDetails = [];
          });
        }
      }

      final timelineResult = await _fetchNewsDetails(newsIds);

      return {
        ...event,
        ...timelineResult, // 包含 'eventsorting_timeline'
      };

    } catch (e) {
      throw Exception('Failed to connect to API or process data: $e');
    }
  }

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
          currentUserId: _currentUserId!,
          dataType: 'eventsorting',
          insertUserAction: _insertUserAction,
          totalScore: _totalScore,
          totalRater: _totalRater,
          onParentDataUpdated: _refreshEventDetails,
        ),
      ),
    );
  }

  void _navigateToEventSortingDetailPage(int newId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventSortingDetailPage(id: newId),
      ),
    );
  }

  void _navigateToNewsContentPage(Map<String, dynamic> newsData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewNewsContent(newsData: newsData),
      ),
    );
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
      return image?['image_origin_url'] ?? '';
    } catch (e) {
      print('Error finding image with ID $imageId: $e');
      return '';
    }
  }

  Future<void> _insertUserAction(
      String actionType,
      String dataType,
      {
        String? text,
        int? score,
        String? anonymous,
      }
      ) async {
    final url = '$_userActionBaseUrl/user/$actionType/$dataType';

    final body = <String, dynamic>{
      'dataId': widget.id,
    };
    if (_currentUserId != null) {
      body['userId'] = _currentUserId;
    }

    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1';
      body.remove('userId');
    } else {
      if (text != null && text.isNotEmpty) body['text'] = text;
      if (score != null) body['score'] = score;
      if (anonymous != null && anonymous.isNotEmpty) body['anonymous'] = anonymous;

      if (_currentUserId == null) {
        print('Error: Action $actionType requires a logged-in user.');
        return;
      }
    }

    if (actionType == 'bookmark') {
      setState(() {
        isFavorite = !isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite ? '已加入收藏' : '已移除收藏'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    body.removeWhere((key, value) => value == null);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        if (['score', 'comment'].contains(actionType)) {
          _refreshEventDetails();
        }

      } else {
        if (actionType != 'view' && actionType != 'bookmark') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失敗: ${response.statusCode} - ${json.decode(response.body)['message'] ?? '伺服器錯誤'}')),
          );
        }
      }
    } catch (e) {
      if (actionType != 'view' && actionType != 'bookmark') {
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
            final List timelineItems = event['eventsorting_timeline'] ?? [];

            final mainImageId = event['eventsorting_image'] as int? ?? -1;
            final mainImageUrl = _findImageUrlById(mainImageId);

            // 💥 MODIFIED: 使用 Stack 包裹 SingleChildScrollView 和浮動箭頭
            return Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDisclaimer(),
                      // 💥 移除 _buildHorizontalEvents 相關的 UI

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: _buildMainImage(mainImageUrl, context),
                        ),
                      ),
                      _buildSummaryCard(event['eventsorting_summary'] ?? '無摘要內容。'),
                      _buildScoreCard(),
                      _buildTimelineSection(timelineItems),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
                // 💥 NEW: 浮動箭頭
                if (_nextEventId != null && (_nextEventId! > 0)) // 確保有有效的導航 ID
                  _buildFloatingRightArrow(context),
              ],
            );
          }
        },
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  // 💥 NEW: 畫面右側浮動箭頭 Widget
  Widget _buildFloatingRightArrow(BuildContext context) {
    final int? nextId = _nextEventId;

    // 再次檢查，以防萬一
    if (nextId == null || nextId <= 0) return const SizedBox.shrink();

    return Positioned(
      right: 10, // 距離右側邊緣 10 單位
      top: MediaQuery.of(context).size.height * 0.4, // 垂直置中偏上
      child: GestureDetector(
        onTap: () {
          _navigateToEventSortingDetailPage(nextId);
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.75), // 半透明藍色
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  // 💥 REMOVED: 移除了 _buildHorizontalEvents 和 _buildHorizontalEventCard

  Widget _buildScoreCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          Text(
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
            final item = entry.value;

            final timelineImageId = item['image'] as int? ?? -1;
            final timelineImageUrl = _findImageUrlById(timelineImageId);

            final isLast = entry.key == items.length - 1;

            return _buildTimelineItem(
                item,
                timelineImageUrl,
                isLast
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> newsItem, String imageUrl, bool isLast) {
    final int newsId = newsItem['id'] as int? ?? -1;
    final String time = newsItem['time'] ?? '';
    final String title = newsItem['title'] ?? '';
    final String source = newsItem['source'] ?? '';

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
            child: InkWell(
              onTap: newsId != -1
                  ? () => _navigateToNewsContentPage(newsItem)
                  : null,
              borderRadius: BorderRadius.circular(12),
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

  Widget _buildPlaceholderImage(double width, double height) {
    if (width == 60 && height == 60) {
      return Container(
        width: width,
        height: height,
        color: Colors.black,
      );
    }
    if (width == 150 && height == 50) {
      return Container(
        width: width,
        height: height,
        color: Colors.blueGrey.shade100,
        child: const Icon(Icons.image_not_supported, color: Colors.blueGrey),
      );
    }
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  // --- 底部操作欄位 (Bottom Actions) ---

  Widget _buildCommentAndRatingButton() {
    return InkWell(
      onTap: _navigateToCommentsPage,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 20,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              '${_commentCount}則',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionRobotButton() {
    return InkWell(
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
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.4),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCommentAndRatingButton(),

          const Spacer(),

          _buildFloatingActionRobotButton(),

          const Spacer(),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionIcon(
                icon: isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                label: '收藏',
                iconColor: isFavorite ? Colors.blue : Colors.grey.shade600!,
                onTap: () {
                  if (_currentUserId != null) {
                    _insertUserAction('bookmark', 'eventsorting');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請先登入以使用收藏功能')),
                    );
                  }
                },
              ),

              _buildActionIcon(
                icon: Icons.share_outlined,
                label: '分享',
                iconColor: Colors.grey.shade600!,
                onTap: () {
                  _insertUserAction('share', 'eventsorting');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分享功能已啟用')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}