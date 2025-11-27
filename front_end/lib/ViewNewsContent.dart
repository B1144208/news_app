import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart'; // ✅ 新增：分享插件
import 'ChannelDetailPage.dart';
import 'LoginPage.dart';

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
    {'user': '用戶A', 'content': '這個新聞很有意思!', 'time': '2小時前', 'avatar': 'A'},
    {'user': '用戶B', 'content': '感謝分享這個重要資訊', 'time': '3小時前', 'avatar': 'B'},
    {'user': '用戶C', 'content': '希望能有更多這樣的報導', 'time': '5小時前', 'avatar': 'C'},
  ];

  // AI朗讀模式相關變數
  bool _showReadModes = false;
  bool _isPlayerVisible = false;
  bool _isPlaying = false;
  String _selectedReadMode = '';
  double _playbackSpeed = 1.0;

  // ========== 新增：TTS AudioPlayer ==========
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ========== 新增：後台文本串列輸入區塊 ==========
  // 一般朗讀模式的文本 - 從資料庫中的 news_body 抓取 body_type 為 text 的 body_text
  List<String> generalPlaymodeTexts = [];

  // 新聞播報模式的文本 - 手動輸入的播報稿
  String reporterPlaymode = '''
各位觀眾大家好,歡迎收看今日新聞快報。

接下來為您播報今天的頭條新聞。

本新聞由我們的記者團隊精心採訪編輯,為您帶來最新、最準確的資訊。

感謝您的收看,我們下次見。
''';

  @override
  void initState() {
    super.initState();
    _fetchNewsDetail();

    // ========== 新增：監聽音訊播放事件 ==========
    _audioPlayer.onPlayerComplete.listen((event) {
      _onAudioComplete();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        setState(() {
          _isPlaying = true;
        });
      } else if (state == PlayerState.paused || state == PlayerState.stopped) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  // 使用 POST 請求獲取新聞詳細內容
  Future<void> _fetchNewsDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('http://localhost:3000/api/news/search').replace(
        queryParameters: {'mode': 'complex', 'order': 'general', 'limit': '1'},
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': [widget.newsData['id']],
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
              _newsDetail = {
                'news_id': newsData['newsId'],
                'news_title': newsData['newsTitle'],
                'channel_name': newsData['channelName'],
                'cover_image_url': newsData['coverImageUrl'],
                'cover_image_alt': newsData['coverImageAlt'],
                'publish_date': newsData['publishDate'],
              };

              if (newsData['newsBody'] != null) {
                _newsBody = _parseNewsBody(newsData['newsBody']);
                // ========== 新增：提取文本內容到 generalPlaymodeTexts ==========
                _extractTextFromNewsBody();
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
        parsedBody.add({
          'body_order': order,
          'body_type': 'text',
          'body_text': item['text'],
          'body_image': null,
        });
      } else if (item['img'] != null) {
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

  // ========== 新增：從 news_body 中提取所有 body_type 為 'text' 的 body_text ==========
  void _extractTextFromNewsBody() {
    generalPlaymodeTexts.clear();

    for (var body in _newsBody) {
      if (body['body_type'] == 'text' && body['body_text'] != null) {
        String text = body['body_text'].trim();
        if (text.isNotEmpty) {
          generalPlaymodeTexts.add(text);
        }
      }
    }

    print('📝 已提取 ${generalPlaymodeTexts.length} 段文本用於一般朗讀模式');
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

  // 檢查登入狀態
  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('IsLogin') ?? false;
  }

  // 處理收藏按鈕點擊
  Future<void> _handleBookmarkTap() async {
    final isLoggedIn = await _checkLoginStatus();

    if (!isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('請先登入以使用收藏功能'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
      return;
    }

    setState(() {
      isFavorite = !isFavorite;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite ? '已加入收藏' : '已取消收藏'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ✅ 新增：分享功能 - 使用share_plus
  Future<void> _handleShareTap() async {
    try {
      final title = _newsDetail?['news_title'] ?? '分享新聞';
      final channel = _newsDetail?['channel_name'] ?? '';
      final newsId = _newsDetail?['news_id'] ?? '';

      // 構建分享文本
      final shareText = '$title\n\n來自: $channel\n\n分享自新聞聚合平台';

      // 如果有新聞ID，可以添加深鏈接
      final shareUrl = newsId.isNotEmpty ? 'news://details/$newsId' : '';

      final fullShareText =
          shareUrl.isNotEmpty ? '$shareText\n$shareUrl' : shareText;

      await Share.share(fullShareText, subject: title);

      print('✅ 分享成功: $title');
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

  // ========== 修改：開始朗讀 - 根據不同模式播放不同內容 ==========
  Future<void> _startReading(String mode) async {
    setState(() {
      _selectedReadMode = mode;
      _showReadModes = false;
      _isPlayerVisible = true;
    });
  }

  void _adjustPlaybackSpeed() {
    setState(() {
      if (_playbackSpeed >= 2.0) {
        _playbackSpeed = 0.5;
      } else {
        _playbackSpeed += 0.5;
      }
    });
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
  }

  void _onAudioComplete() {
    setState(() {
      _isPlaying = false;
      _isPlayerVisible = false;
    });
  }

  void _closePlayer() {
    _audioPlayer.stop();
    setState(() {
      _isPlayerVisible = false;
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 主要內容區域
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面圖片
                if (_newsDetail != null &&
                    _newsDetail!['cover_image_url'] != null)
                  Image.network(
                    _newsDetail!['cover_image_url'],
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 300,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),

                // 返回和標題區域
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 返回按鈕
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_back, color: Colors.black),
                            const SizedBox(width: 8),
                            Text(
                              '返回',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 標題
                      if (_newsDetail != null)
                        Text(
                          _newsDetail!['news_title'] ?? '未知標題',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.4,
                          ),
                        ),

                      const SizedBox(height: 12),

                      // 頻道和時間
                      if (_newsDetail != null)
                        Row(
                          children: [
                            Text(
                              _newsDetail!['channel_name'] ?? '未知頻道',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _formatDateTime(_newsDetail!['publish_date']),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 16),

                      // AI朗讀模式選擇
                      if (!_isPlayerVisible)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.record_voice_over,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: const Text(
                                  '點擊下方按鈕進行AI朗讀',
                                  style: TextStyle(color: Colors.blue),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 新聞內容
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _newsBody.map((body) {
                          if (body['body_type'] == 'text') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                body['body_text'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          } else if (body['body_type'] == 'image') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Image.network(
                                body['body_image'] ?? '',
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: double.infinity,
                                    height: 200,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                    ),
                                  );
                                },
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }).toList(),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // 右側浮動按鈕組
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 收藏按鈕
                _buildRightButton(
                  icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  label: '收藏',
                  onTap: _handleBookmarkTap,
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

                // ✅ 修改：分享按鈕 - 調用實際分享功能
                _buildRightButton(
                  icon: Icons.share,
                  label: '分享',
                  onTap: _handleShareTap,
                ),
              ],
            ),
          ),

          // AI朗讀播放器覆蓋層
          if (_isPlayerVisible) _buildPlayerOverlay(),

          // 留言覆蓋層
          if (showComments) _buildCommentsOverlay(),

          // 聊天覆蓋層
          if (showChatBox) _buildChatOverlay(),
        ],
      ),
    );
  }

  // 播放器覆蓋層
  Widget _buildPlayerOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          children: [
            // 內文跳轉按鈕
            IconButton(
              onPressed: () {
                // TODO: 實作內文跳轉功能
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('內文跳轉功能開發中'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.article_outlined),
              iconSize: 24,
            ),

            // 調整倍速按鈕
            GestureDetector(
              onTap: _adjustPlaybackSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_playbackSpeed}x',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 播放/暫停按鈕
            IconButton(
              onPressed: _togglePlayPause,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 28,
            ),

            // 下一篇按鈕
            IconButton(
              onPressed: () {
                // TODO: 實作下一篇功能
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('下一篇功能開發中'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.skip_next),
              iconSize: 24,
            ),

            // 關閉按鈕
            IconButton(
              onPressed: _closePlayer,
              icon: const Icon(Icons.close),
              iconSize: 20,
            ),
          ],
        ),
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
            onTap: () {},
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
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
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
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
                      SizedBox(
                        height: 300,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          separatorBuilder:
                              (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            return _buildCommentItem(comment);
                          },
                        ),
                      ),
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
                hintText: '請問有什麼要詢問的呢?',
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
              style: const TextStyle(fontSize: 10, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _commentController.dispose();
    _chatController.dispose();
    super.dispose();
  }
}
