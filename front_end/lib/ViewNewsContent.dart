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
    _fetchNewsDetail();
  }

  // 使用 POST 請求獲取新聞詳細內容
  Future<void> _fetchNewsDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 使用 POST 請求，mode 設為 'complex' 來獲取完整的新聞內容
      final uri = Uri.parse('http://localhost:3000/api/news').replace(
        queryParameters: {
          'mode': 'complex',    // 獲取詳細內容（包含 newsBody）
          'order': 'general',
          'limit': '1',
        },
      );

      // 建立 POST 請求
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': [widget.newsData['id']], // 指定要查詢的新聞 ID
        }),
      );

      print('新聞詳細內容回應狀態碼: ${response.statusCode}');
      print('新聞詳細內容回應內容: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final complexList = responseData['data']['complexList'];

          if (complexList != null && complexList.isNotEmpty) {
            final newsData = complexList[0];

            setState(() {
              // 保存新聞基本資料
              _newsDetail = {
                'news_id': newsData['newsId'],
                'news_title': newsData['newsTitle'],
                'channel_name': newsData['channelName'],
                'cover_image_url': newsData['coverImageUrl'],
                'cover_image_alt': newsData['coverImageAlt'],
                'publish_date': newsData['publishDate'],
              };

              // 解析 newsBody 資料
              if (newsData['newsBody'] != null) {
                _newsBody = _parseNewsBody(newsData['newsBody']);
              }

              _isLoading = false;
            });
          } else {
            throw Exception('找不到對應的新聞資料');
          }
        } else {
          throw Exception(responseData['message'] ?? '獲取新聞失敗');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('獲取新聞詳情失敗: $error');
      setState(() {
        _error = '載入新聞詳情時發生錯誤: $error';
        _isLoading = false;

        // 如果API調用失敗，使用傳入的基本資料
        _newsDetail = {
          'news_id': widget.newsData['id'],
          'news_title': widget.newsData['title'],
          'channel_name': widget.newsData['channel'] ?? '未知頻道',
          'publish_date': widget.newsData['news_date'],
        };
      });
    }
  }

  // 解析 newsBody 資料
  List<Map<String, dynamic>> _parseNewsBody(List<dynamic> newsBody) {
    List<Map<String, dynamic>> parsedBody = [];
    int order = 0;

    for (var item in newsBody) {
      order += 10;

      if (item['text'] != null) {
        // 文字內容
        parsedBody.add({
          'body_order': order,
          'body_type': 'text',
          'body_text': item['text'],
          'body_image': null,
        });
      } else if (item['img'] != null) {
        // 圖片內容
        parsedBody.add({
          'body_order': order,
          'body_type': 'image',
          'body_text': item['img']['alt'],
          'body_image': item['img']['src'],
        });
      }
    }

    return parsedBody;
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
                    channelName: _newsDetail?['channel_name'] ?? widget.newsData['channel'] ?? '新聞台',
                    channelDescription: null,
                  ),
                ),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.tv, size: 20, color: Colors.black54),
            ),
          ),

          const SizedBox(width: 8),

          // 新聞台名稱
          Expanded(
            child: Text(
              _newsDetail?['channel_name'] ?? widget.newsData['channel'] ?? '新聞台',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 新聞內容區域
  Widget _buildNewsContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchNewsDetail,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題區域
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 新聞標題
                Text(
                  _newsDetail?['news_title'] ?? widget.newsData['title'] ?? '無標題',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 12),

                // 發布時間
                Text(
                  _formatDateTime(_newsDetail?['publish_date']),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 新聞內容主體
          ..._buildNewsBodyContent(),
        ],
      ),
    );
  }

  // 建立新聞內容主體
  List<Widget> _buildNewsBodyContent() {
    if (_newsBody.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '暫無新聞內容',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    return _newsBody.map((bodyItem) {
      if (bodyItem['body_type'] == 'text') {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            bodyItem['body_text'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        );
      } else if (bodyItem['body_type'] == 'image') {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 圖片
              if (bodyItem['body_image'] != null)
                Image.network(
                  bodyItem['body_image'],
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    );
                  },
                ),
              // 圖片說明
              if (bodyItem['body_text'] != null && bodyItem['body_text'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    bodyItem['body_text'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }).toList();
  }

  // 右側垂直按鈕欄
  Widget _buildRightButtonPanel() {
    return Positioned(
      right: 8,
      top: 20,
      bottom: 20,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 收藏按鈕
          _buildRightButton(
            icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
            label: '收藏',
            onTap: () {
              setState(() {
                isFavorite = !isFavorite;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isFavorite ? '已加入收藏' : '已取消收藏'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // 留言按鈕
          _buildRightButton(
            icon: Icons.comment,
            label: '${_comments.length}',
            onTap: () {
              setState(() {
                showComments = true;
              });
            },
          ),

          const SizedBox(height: 16),

          // 分享按鈕
          _buildRightButton(
            icon: Icons.share,
            label: '分享',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('分享功能開發中'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 右側按鈕組件
  Widget _buildRightButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // AI 聊天按鈕
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showChatBox = !showChatBox;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.smart_toy, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI 助手',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
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

  // 留言覆蓋層
  Widget _buildCommentsOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            showComments = false;
          });
        },
        child: Container(
          color: Colors.black,
          child: GestureDetector(
            onTap: () {}, // 防止點擊內容區域時關閉
            child: Column(
              children: [
                const Spacer(),
                // 留言面板
                Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 標題欄
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
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
          ),
        ),
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