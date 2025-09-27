import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ChannelDetailPage.dart';

class ViewNewsContent extends StatefulWidget {
  final Map<String, dynamic> newsData;

  const ViewNewsContent({super.key, required this.newsData});

  @override
  State<ViewNewsContent> createState() => _ViewNewsContentState();
}

class _ViewNewsContentState extends State<ViewNewsContent> {
  bool isFavorite = false;
  bool showComments = false;
  bool showChatBox = false;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  // 從API獲取的詳細資料
  Map<String, dynamic>? _newsDetail;
  List<Map<String, dynamic>> _newsBody = [];
  Map<int, String> _imageUrls = {}; // 存儲圖片URL映射
  Map<int, String> _imageTexts = {}; // 存儲圖片說明文字
  bool _isLoading = false;
  String? _error;

  // 模擬留言數據
  final List<Map<String, dynamic>> _comments = [
    {'user': '用戶A', 'content': '這個新聞很有意思！', 'time': '2小時前', 'avatar': 'A'},
    {'user': '用戶B', 'content': '感謝分享這個重要資訊', 'time': '3小時前', 'avatar': 'B'},
    {'user': '用戶C', 'content': '希望能有更多這樣的報導', 'time': '5小時前', 'avatar': 'C'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeNewsDetail();
  }

  // 初始化新聞詳情 - 依序獲取各種資料
  Future<void> _initializeNewsDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. 先獲取圖片資料
      await _fetchImages();
      // 2. 獲取新聞詳情
      await _fetchNewsDetail();
      // 3. 獲取新聞內容
      await _fetchNewsBody();
    } catch (error) {
      setState(() {
        _error = '載入新聞詳情時發生錯誤: $error';
        _isLoading = false;
      });
    }
  }

  // 獲取圖片資料
  Future<void> _fetchImages() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/image'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> images = responseData['data'];
          for (var image in images) {
            _imageUrls[image['image_id']] = image['image_origin_url'] ?? '';
            _imageTexts[image['image_id']] = image['image_text'] ?? '';
          }
        }
      }
    } catch (error) {
      print('獲取圖片資料失敗: $error');
    }
  }

  // 獲取新聞詳情 - 使用現有的 /api/news 端點
  Future<void> _fetchNewsDetail() async {
    try {
      // 如果API支援通過參數查詢特定新聞
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/news?news_id=${widget.newsData['id']}'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> newsList = responseData['data'];
          // 找到對應的新聞
          final matchedNews = newsList.firstWhere(
                (news) => news['news_id'] == widget.newsData['id'],
            orElse: () => null,
          );

          if (matchedNews != null) {
            setState(() {
              _newsDetail = matchedNews;
            });
          } else {
            throw Exception('找不到對應的新聞');
          }
        }
      }
    } catch (error) {
      print('獲取新聞詳情失敗: $error');
      // 如果API調用失敗，使用傳入的基本資料
      setState(() {
        _newsDetail = {
          'news_id': widget.newsData['id'],
          'news_title': widget.newsData['title'],
          'channel_id': widget.newsData['channel_id'],
          'news_date': widget.newsData['news_date'],
          'total_comment': widget.newsData['comments'],
        };
      });
    }
  }

  // 獲取新聞內容 - 嘗試從相關API獲取 news_body 資料
  Future<void> _fetchNewsBody() async {
    try {
      // 假設可以通過某個端點獲取新聞內容
      // 這裡需要根據您實際的API結構調整

      // 如果有專門的 news body API，可以這樣調用：
      // final response = await http.get(
      //   Uri.parse('http://localhost:3000/api/news/${widget.newsData['id']}/body'),
      // );

      // 暫時使用模擬邏輯，如果您有實際的 news_body API，請替換這部分
      await Future.delayed(const Duration(milliseconds: 500)); // 模擬網路延遲

      // 模擬從資料庫獲取的 news_body 資料
      setState(() {
        _newsBody = [
          {
            'body_order': 20,
            'body_type': 'text',
            'body_text': '這是新聞的主要內容。由於目前API結構限制，這裡顯示的是示例內容。實際內容需要根據後端API的具體實現來調整。',
            'body_image': null,
          },
          {
            'body_order': 30,
            'body_type': 'image',
            'body_text': null,
            'body_image': _newsDetail?['cover_image'],
          },
          {
            'body_order': 40,
            'body_type': 'text',
            'body_text': '新聞的後續內容會在這裡顯示。當後端API完善後，這些內容將從資料庫動態載入。',
            'body_image': null,
          },
        ];
        _isLoading = false;
      });
    } catch (error) {
      print('獲取新聞內容失敗: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 格式化日期時間
  String _formatDateTime(String? dateString) {
    if (dateString == null) return '未知時間';

    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.year}年${date.month}月${date.day}日 '
          '週${_getWeekday(date.weekday)} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '未知時間';
    }
  }

  String _getWeekday(int weekday) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return weekdays[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 自定義AppBar
                _buildCustomAppBar(),

                // 主要內容區域
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 60), // 為右側按鈕預留空間
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 新聞主要內容
                            _buildNewsContent(),

                            // 底部留白
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),

                      // 右側垂直按鈕欄
                      _buildRightButtonPanel(),
                    ],
                  ),
                ),

                // 底部操作欄
                _buildBottomActionBar(),
              ],
            ),

            // 留言覆蓋層
            if (showComments) _buildCommentsOverlay(),

            // 聊天框覆蓋層
            if (showChatBox) _buildChatOverlay(),
          ],
        ),
      ),
    );
  }

  // 自定義AppBar
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Color(0xFFC9BDFF),
      child: Row(
        children: [
          // 返回按鈕
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),

          const SizedBox(width: 8),

          // 新聞台小圖片 - 可點擊跳轉到頻道詳細頁面
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChannelDetailPage(
                    channelId: widget.newsData['channel_id'] ?? 1,
                    channelName: widget.newsData['channel'] ?? '新聞台',
                    channelDescription: null,
                    channelUrl: null,
                  ),
                ),
              );
            },
            child: Container(
              width: 120,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.blue,
                ), // 添加邊框提示可點擊
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '頻道圖片',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 12,
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

  // 新聞主要內容
  Widget _buildNewsContent() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeNewsDetail,
                child: const Text('重新載入'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 新聞標題 - 讀取 news_data.sql 的 news_title 欄位
          Text(
            _newsDetail?['news_title'] ?? widget.newsData['title'] ?? '無標題',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          // 報導時間 - 讀取 news_data.sql 的 news_date 欄位
          Text(
            _formatDateTime(_newsDetail?['news_date'] ?? widget.newsData['news_date']),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),

          const SizedBox(height: 20),

          // 新聞內容 - 讀取 news_body.sql 中相同 news_id 的內容
          ..._buildNewsBodyContent(),
        ],
      ),
    );
  }

  // 建立新聞內容區塊 - 從 news_body.sql 讀取資料
  List<Widget> _buildNewsBodyContent() {
    List<Widget> widgets = [];

    // 根據 body_order 排序
    final sortedBody = _newsBody.toList()
      ..sort((a, b) => (a['body_order'] as int).compareTo(b['body_order'] as int));

    for (final body in sortedBody) {
      if (body['body_type'] == 'text') {
        // 文字內容 - 讀取 body_text 欄位
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              body['body_text'] ?? '',
              style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
            ),
          ),
        );
      } else if (body['body_type'] == 'image') {
        // 圖片內容 - 讀取 body_image 欄位並透過外鍵連結 image_data.sql
        widgets.add(_buildImageContent(body));
      }
    }

    return widgets;
  }

  // 建立圖片內容區塊
  Widget _buildImageContent(Map<String, dynamic> imageBody) {
    final imageId = imageBody['body_image'];
    final imageUrl = _imageUrls[imageId];
    final imageText = _imageTexts[imageId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 新聞圖片 - 使用 image_origin_url
        Container(
          width: double.infinity,
          height: 200,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.image,
                  color: Colors.grey,
                  size: 50,
                );
              },
            )
                : const Icon(Icons.image, color: Colors.grey, size: 50),
          ),
        ),

        // 圖片說明 - 使用 image_text
        if (imageText != null && imageText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    imageText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 右側垂直按鈕欄
  Widget _buildRightButtonPanel() {
    return Positioned(
      right: 8,
      top: 100,
      child: Column(
        children: [
          _buildRightButton(Icons.play_circle_outline, 'AI朗讀', Colors.blue),
          const SizedBox(height: 12),
          _buildRightButton(Icons.library_books_outlined, '事件整理', Colors.green),
          const SizedBox(height: 12),
          _buildRightButton(Icons.download_outlined, '下載', Colors.orange),
          const SizedBox(height: 12),
          _buildRightButton(Icons.flag_outlined, '檢舉', Colors.red),
        ],
      ),
    );
  }

  // 右側單個按鈕
  Widget _buildRightButton(IconData icon, String tooltip, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 24),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$tooltip 功能開發中'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        tooltip: tooltip,
      ),
    );
  }

  // 底部操作欄
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 留言按鈕
          InkWell(
            onTap: () {
              setState(() {
                showComments = !showComments;
              });
            },
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
                    '${_comments.length}則',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // 機器人圖示
          InkWell(
            onTap: () {
              setState(() {
                showChatBox = !showChatBox;
              });
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
          ),

          const Spacer(),

          // 右側按鈕組
          Row(
            children: [
              // 收藏按鈕
              InkWell(
                onTap: () {
                  setState(() {
                    isFavorite = !isFavorite;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isFavorite ? '已加入收藏' : '已移除收藏'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                    color: isFavorite ? Colors.blue : Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),

              // 分享按鈕
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分享功能開發中'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.share_outlined,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 留言覆蓋層
  Widget _buildCommentsOverlay() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showComments = false;
                });
              },
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 留言標題欄
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '留言',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_comments.length}則',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            showComments = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 留言列表
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _comments.length,
                    separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return _buildCommentItem(comment);
                    },
                  ),
                ),

                // 留言輸入框
                _buildCommentInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 聊天覆蓋層
  Widget _buildChatOverlay() {
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'AI 助手',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      showChatBox = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: '請問有什麼要詢問的呢？',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () {
                    if (_chatController.text.trim().isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AI 功能開發中'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      _chatController.clear();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 單個留言項目
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 頭像
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue[100],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              comment['avatar'],
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 留言內容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment['user'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    comment['time'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                comment['content'],
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 留言輸入框
  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: '請輸入文字',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _submitComment,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _submitComment() {
    if (_commentController.text.trim().isNotEmpty) {
      setState(() {
        _comments.insert(0, {
          'user': '我',
          'content': _commentController.text.trim(),
          'time': '剛剛',
          'avatar': '我',
        });
      });
      _commentController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('留言已發送'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _chatController.dispose();
    super.dispose();
  }
}