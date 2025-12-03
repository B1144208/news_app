import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart'; // ✅ 新增：分享插件

// 假設這些檔案和配置存在於您的專案中
import 'CommentsPage.dart';
import 'MultiplePerspectivesDetailPage.dart';
import 'config.dart'; // 確保這裡有定義 baseUrl
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
  double get _averageScore =>
      _totalRater > 0 ? (_totalScore / _totalRater) : 0.0;

  // 假設 _userActionBaseUrl, _eventSortingUrl, _imageUrl, _newsUrl 來自 config.dart
  // 為方便演示，這裡使用字串插值
  final String _userActionBaseUrl = '$baseUrl';
  final String _eventSortingUrl = '$baseUrl/EventSorting';
  final String _imageUrl = '$baseUrl/image';
  final String _newsUrl = '$baseUrl/news';

  late Future<Map<String, dynamic>> _eventDetailsAndImagesFuture;

  // 儲存水平關聯事件的資料，用於確定箭頭導航目標
  List<Map<String, dynamic>> _horizontalEventsDetails = [];

  // 此列表用於儲存所有圖片的 ID -> URL 映射 (已棄用，但保留為兼容性)
  List<dynamic> _allImages = [];

  Map<String, dynamic>? get _nextEventDetails {
    if (_horizontalEventsDetails.isNotEmpty) {
      final event = _horizontalEventsDetails[0];
      final eventId = event['id'] as int?;
      final eventTitle = event['title'] as String?;

      if (eventId != null &&
          eventId > 0 &&
          eventTitle != null &&
          eventTitle.isNotEmpty) {
        return event;
      }
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
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getInt('UserID');
        print('EventSortingDetailPage - Loaded UserID: $_currentUserId');
      });
    }
  }

  Future<void> _refreshEventDetails() async {
    if (mounted) {
      setState(() {
        _eventDetailsAndImagesFuture = _fetchEventDetailsAndImages();
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchSingleEventDetails(int eventId) async {
    final eventUri = Uri.parse(
      _eventSortingUrl,
    ).replace(queryParameters: {'id': eventId.toString()});
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

  Future<void> _fetchHorizontalEventsDetails(List<int> eventIds) async {
    List<Future<Map<String, dynamic>?>> futures =
        eventIds.map((id) async {
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

    final results =
        (await Future.wait(
          futures,
        )).where((item) => item != null).cast<Map<String, dynamic>>().toList();

    if (mounted) {
      setState(() {
        _horizontalEventsDetails = results;
      });
    }
  }

  /// 根據新聞 ID 列表，逐一向後端 /news/search 路由獲取新聞詳情。
  /// 💥 修正: 使用 'simple' 模式，並逐一發送 POST 請求。
  Future<Map<String, dynamic>> _fetchNewsDetails(List<int> newsIds) async {
    List<dynamic> timeline = [];

    // 1. 檢查是否有 ID 需要查詢
    if (newsIds.isEmpty) return {'eventsorting_timeline': []};

    // 2. 設定正確的 POST URL
    final newsUri = Uri.parse('$_newsUrl/search');

    // 3. 逐一發送 POST 請求
    final newsPromises =
        newsIds.map((id) {
          // 構造 POST 請求的 Body：只傳遞單個 newsId，並要求 'simple' 模式
          final body = json.encode({
            'id': [id],
            'mode': 'simple', // 💥 修正為 'simple'
          });

          return http
              .post(
                newsUri,
                headers: {'Content-Type': 'application/json'},
                body: body,
              )
              .then((response) {
                if (response.statusCode == 200) {
                  try {
                    final data = json.decode(utf8.decode(response.bodyBytes));

                    // 💥 注意: 現在讀取的是 'simpleList'
                    final List<dynamic>? simpleList =
                        data['data']?['simpleList'];

                    if (simpleList?.isNotEmpty == true) {
                      final newsItem = simpleList![0] as Map<String, dynamic>;

                      // 從 simpleList 的結果中提取所需欄位
                      return {
                        'id': newsItem['newsId'] as int? ?? id,
                        'title': newsItem['newsTitle'] ?? '無標題',
                        'time': newsItem['publishDate'] ?? '未知時間',
                        'source': newsItem['channelName'] ?? '未知來源',

                        // 輔助欄位：使用 coverImageUrl 替代 image_id
                        'image': -1, // 廢棄：不再使用 image_id
                        'cover_image_url': newsItem['coverImageUrl'] ?? '',

                        // 舊的欄位，保留兼容性
                        'channel_id': -1,
                        'channel': newsItem['channelName'] ?? '未知來源',
                        'news_date': newsItem['publishDate'] ?? '未知時間',
                        'comments': 0,
                        'cover_image': -1,

                        // 儲存 newsItem 供 ViewNewsContent 使用
                        'newsData': newsItem,
                      };
                    } else {
                      print(
                        'Warning: Search API returned empty for single ID: $id (simpleList is empty)',
                      );
                    }
                  } catch (e) {
                    print(
                      'Error: Failed to decode JSON or map for News ID $id. $e',
                    );
                  }
                } else {
                  print(
                    'API Error (Status ${response.statusCode}) for News ID $id. Response: ${response.body}',
                  );
                }
                return null;
              })
              .catchError((e) {
                print(
                  'Fatal Error: Failed to fetch news ID $id via API due to exception: $e',
                );
                return null;
              });
        }).toList();

    // 4. 等待所有請求完成，並過濾掉失敗的 (null) 項目
    timeline =
        (await Future.wait(
          newsPromises,
        )).where((item) => item != null).toList();

    // 5. 排序
    timeline.sort(
      (a, b) => (b['time'] as String).compareTo(a['time'] as String),
    );

    return {'eventsorting_timeline': timeline};
  }

  Future<Map<String, dynamic>> _fetchEventDetailsAndImages() async {
    final eventUri = Uri.parse(
      _eventSortingUrl,
    ).replace(queryParameters: {'id': widget.id.toString()});
    final imagesUri = Uri.parse(_imageUrl);

    try {
      final eventResponse = await http.get(eventUri);
      final imagesResponse = await http.get(imagesUri);

      if (eventResponse.statusCode != 200) {
        throw Exception(
          'Failed to load event details: ${eventResponse.statusCode}',
        );
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
        newsIds =
            rawNewsIds
                .map(
                  (e) => e is int ? e : (e is String ? int.tryParse(e) : null),
                )
                .where((e) => e != null)
                .cast<int>()
                .toList();
      }

      final dynamic rawHorizontalIds = event['horizontal_events'];
      List<int> horizontalIds = [];
      if (rawHorizontalIds is List) {
        horizontalIds =
            rawHorizontalIds
                .map(
                  (e) => e is int ? e : (e is String ? int.tryParse(e) : null),
                )
                .where((e) => e != null)
                .cast<int>()
                .toList();
      }

      if (horizontalIds.isNotEmpty) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入以使用評分/留言功能')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CommentsPage(
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

  // ✅ 新增：分享功能 - 使用share_plus
  Future<void> _handleShareTap() async {
    try {
      // 構建分享文本
      final shareText =
          '事件整理分析 - ID: ${widget.id}\n\n'
          '平均評分: ${_averageScore.toStringAsFixed(1)}/10 (${_totalRater}人評分)\n'
          '留言數量: $_commentCount\n\n'
          '分享自新聞聚合平台';

      // 深鏈接
      final shareUrl = 'eventsorting://details/${widget.id}';

      final fullShareText = '$shareText\n$shareUrl';

      await Share.share(fullShareText, subject: '事件整理分析');

      print('✅ 分享成功: ID ${widget.id}');
    } catch (e) {
      print('❌ 分享失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分享失敗: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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

  // 💥 由於我們不再依賴 image_id，此函式已不再用於 Timeline 圖片查找
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
    String dataType, {
    String? text,
    int? score,
    String? anonymous,
  }) async {
    final url = '$_userActionBaseUrl/user/$actionType/$dataType';

    final body = <String, dynamic>{'dataId': widget.id};
    if (_currentUserId != null) {
      body['userId'] = _currentUserId;
    }

    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1';
      body.remove('userId');
    } else {
      if (text != null && text.isNotEmpty) body['text'] = text;
      if (score != null) body['score'] = score;
      if (anonymous != null)
        body['anonymous'] = anonymous; // ✅ 修正：int型不能調用isNotEmpty

      if (_currentUserId == null) {
        print('Error: Action $actionType requires a logged-in user.');
        return;
      }
    }

    if (actionType == 'bookmark') {
      if (mounted) {
        setState(() {
          isFavorite = !isFavorite;
        });
      }

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
            SnackBar(
              content: Text(
                '操作失敗: ${response.statusCode} - ${json.decode(response.body)['message'] ?? '伺服器錯誤'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (actionType != 'view' && actionType != 'bookmark') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('連線錯誤: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a2a4e),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              );
            }
            return const Text('事件整理', style: TextStyle(color: Colors.white));
          },
        ),
        actions: [
          // 模式切換開關 - 已註解
          /* Switch(
            value: !_isEventSortingMode,
            onChanged: (bool value) {
              if (value) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            MultiplePerspectivesDetailPage(id: widget.id),
                  ),
                );
              }
            },
            activeColor: Colors.blue,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
          ),
          const SizedBox(width: 16), */
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
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    height: 1.5,
                  ),
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

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDisclaimer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: _buildMainImage(mainImageUrl, context),
                    ),
                  ),
                  _buildSummaryCard(event['eventsorting_summary'] ?? '無摘要內容。'),
                  _buildScoreCard(),
                  // 新聞脈絡整理部分
                  _buildTimelineSection(timelineItems),

                  // 💥 呼叫新的包裹函式
                  if (_nextEventDetails != null)
                    _buildNextEventSection(_nextEventDetails!),

                  const SizedBox(height: 50), // 留出底部空間
                ],
              ),
            );
          }
        },
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  // 💥 新增的函式，用於包裹卡片並添加標題
  Widget _buildNextEventSection(Map<String, dynamic> nextEvent) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0), // 在整個部分上方留出空間
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💥 新增大標題
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '相關事件：',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          // 呼叫原有的卡片 Widget
          _buildNextEventCard(nextEvent),
        ],
      ),
    );
  }

  // 保持不變，只負責構建卡片本身
  Widget _buildNextEventCard(Map<String, dynamic> nextEvent) {
    final int nextId = nextEvent['id'] as int? ?? -1;
    final String title = nextEvent['title'] as String? ?? '未知事件';

    if (nextId <= 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        _navigateToEventSortingDetailPage(nextId);
      },
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                // 💥 修正: 這裡將 '下一事件：' 改回 '事件標題'，因為標題在上方 Section 已經有了
                '$title',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

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
                const Text(
                  '重點摘要',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                const Text(
                  '16篇 • 摘要使用AI技術協助',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
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

  // 💥 修正: _buildTimelineSection
  Widget _buildTimelineSection(List items) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '新聞脈絡整理',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('無相關新聞脈絡資料。'),
            ),
          ...items.asMap().entries.map((entry) {
            final item = entry.value;

            final isLast = entry.key == items.length - 1;

            return _buildTimelineItem(
              item, // 💥 只傳遞 newsItem Map
              isLast,
            );
          }).toList(),
        ],
      ),
    );
  }

  // 💥 修正 _buildTimelineItem 函式簽名和邏輯
  Widget _buildTimelineItem(Map<String, dynamic> newsItem, bool isLast) {
    final int newsId = newsItem['id'] as int? ?? -1;
    final String time = newsItem['time'] ?? '';
    final String title = newsItem['title'] ?? '';
    final String source = newsItem['source'] ?? '';

    // 💥 從 newsItem 中直接獲取 URL
    final String timelineImageUrl =
        newsItem['cover_image_url'] as String? ?? '';

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
              onTap:
                  newsId != -1
                      ? () => _navigateToNewsContentPage(newsItem)
                      : null,
              borderRadius: BorderRadius.circular(12),
              child: Card(
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  source,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: _buildImage(
                              timelineImageUrl,
                            ), // 💥 使用 timelineImageUrl
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
          const Text(
            "使用AI技術協助",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.info_outline, size: 14, color: Colors.grey),
          const Spacer(),
          const Text(
            "資訊若有失真狀況，一概不負法律責任",
            style: TextStyle(color: Colors.red, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(double width, double height) {
    if (width == 60 && height == 60) {
      return Container(width: width, height: height, color: Colors.black);
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

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2a4e), // 星空深藍卡片
        border: Border(
          top: BorderSide(color: const Color(0xFF6366f1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 留言按鈕
          _buildBottomButton(
            icon: Icons.comment,
            label: '$_commentCount',
            onTap: _navigateToCommentsPage,
          ),

          // 機器人按鈕 - 已註解
          /* _buildBottomButton(
            icon: Icons.smart_toy,
            label: 'AI',
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
          ), */

          // 收藏按鈕
          _buildBottomButton(
            icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
            label: '收藏',
            onTap: () {
              if (_currentUserId != null) {
                _insertUserAction('bookmark', 'eventsorting');
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('請先登入以使用收藏功能')));
              }
            },
          ),

          // 分享按鈕
          _buildBottomButton(
            icon: Icons.share,
            label: '分享',
            onTap: () {
              _insertUserAction('share', 'eventsorting');
              _handleShareTap();
            },
          ),
        ],
      ),
    );
  }

  // ViewNewsContent 風格的底部按鈕
  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2a3a5e), // 深藍背景
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6366f1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF60a5fa)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFd1d5db),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
