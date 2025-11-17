import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        queryParameters: {
          'mode': 'complex',
          'order': 'general',
          'limit': '1',
        },
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

  // ========== 修改：開始朗讀 - 根據不同模式播放不同內容 ==========
  Future<void> _startReading(String mode) async {
    setState(() {
      _selectedReadMode = mode;
      _showReadModes = false;
      _isPlayerVisible = true;
    });

    // 根據不同模式播放不同內容
    if (mode == '一般朗讀') {
      await _playGeneralMode();
    } else if (mode == '新聞播報') {
      await _playReporterMode();
    } else if (mode == '對話模式') {
      // 對話模式先不做
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('對話模式開發中')),
        );
      }
      _closePlayer();
    }
  }

  // ========== 新增：一般朗讀模式 - 播放從資料庫抓取的文本 ==========
  Future<void> _playGeneralMode() async {
    if (generalPlaymodeTexts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有可朗讀的內容')),
        );
      }
      _closePlayer();
      return;
    }

    // 將所有文本段落合併成一段完整的文本
    String fullText = generalPlaymodeTexts.join('\n\n');
    await _playTextWithTTS(fullText);
  }

  // ========== 新增：新聞播報模式 - 播放預設的播報稿 ==========
  Future<void> _playReporterMode() async {
    if (reporterPlaymode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('播報稿為空')),
        );
      }
      _closePlayer();
      return;
    }

    await _playTextWithTTS(reporterPlaymode);
  }

  // ========== 新增：使用 TTS API 將文本轉換成語音並播放 ==========
  Future<void> _playTextWithTTS(String text) async {
    try {
      print('🎵 準備播放文本: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');

      // 呼叫 TTS API
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/tts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'voiceId': '9lHjugDhwqoxA5MhX0az', // ANNA_SU - Taiwan, social media
          'stability': 0.5,
          'similarity_boost': 0.75,
        }),
      );

      if (response.statusCode == 200) {
        // 獲取音訊 bytes
        final Uint8List bytes = response.bodyBytes;

        print('✅ 收到音訊數據: ${bytes.length} bytes');

        // 停止當前播放
        await _audioPlayer.stop();

        // 轉換為 base64 data URL
        final String base64Audio = base64Encode(bytes);
        final String dataUrl = 'data:audio/mpeg;base64,$base64Audio';

        print('🔄 轉換為 data URL, 長度: ${dataUrl.length}');

        // 設定播放速度
        await _audioPlayer.setPlaybackRate(_playbackSpeed);

        // 使用 UrlSource 播放 data URL
        await _audioPlayer.play(UrlSource(dataUrl));

        setState(() {
          _isPlaying = true;
        });

        print('🎵 正在播放 $_selectedReadMode 模式');
      } else {
        print('❌ TTS API 錯誤: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('語音合成失敗: ${response.statusCode}')),
          );
        }
        _closePlayer();
      }
    } catch (e) {
      print('❌ 播放錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放錯誤: $e')),
        );
      }
      _closePlayer();
    }
  }

  // ========== 新增：音訊播放完成回調 ==========
  void _onAudioComplete() {
    print('✅ 播放完成');
    _closePlayer();
  }

  // ========== 修改：切換播放/暫停 - 使用 audioplayers ==========
  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.resume();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  // ========== 修改：調整播放倍速 - 使用 audioplayers ==========
  Future<void> _adjustPlaybackSpeed() async {
    setState(() {
      if (_playbackSpeed == 0.5) {
        _playbackSpeed = 1.0;
      } else if (_playbackSpeed == 1.0) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 0.5;
      }
    });

    // 更新 AudioPlayer 的播放速度
    await _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  // ========== 修改：關閉播放器 - 使用 audioplayers ==========
  Future<void> _closePlayer() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlayerVisible = false;
      _isPlaying = false;
      _selectedReadMode = '';
    });
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
                _buildCustomAppBar(),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 60),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNewsContent(),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                      _buildRightButtonPanel(),
                    ],
                  ),
                ),
                _buildBottomActionBar(),
              ],
            ),

            if (showComments) _buildCommentsOverlay(),
            if (showChatBox) _buildChatOverlay(),
            if (_isPlayerVisible) _buildReadingPlayer(),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          // AI朗讀模式選擇按鈕
          _buildRightButton(
            icon: Icons.play_arrow,
            label: 'AI朗讀',
            onTap: () {
              setState(() {
                _showReadModes = !_showReadModes;
              });
            },
          ),

          // 延伸的朗讀模式選項
          if (_showReadModes) ...[
            const SizedBox(height: 8),
            _buildReadModeButton('一般朗讀'),
            const SizedBox(height: 8),
            _buildReadModeButton('新聞播報'),
            const SizedBox(height: 8),
            _buildReadModeButton('對話模式'),
          ],

          const SizedBox(height: 16),

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

  // 朗讀模式按鈕
  Widget _buildReadModeButton(String mode) {
    return GestureDetector(
      onTap: () => _startReading(mode),
      child: Container(
        width: 48,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.blue, width: 1),
        ),
        child: Text(
          mode,
          style: TextStyle(
            fontSize: 9,
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // AI 聊天按鈕（圓形置中）
          GestureDetector(
            onTap: () {
              setState(() {
                showChatBox = !showChatBox;
              });
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 朗讀播放器
  Widget _buildReadingPlayer() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左側資訊
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.volume_up, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _selectedReadMode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _newsDetail?['news_title'] ?? widget.newsData['title'] ?? '無標題',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 右側控制按鈕
            Row(
              mainAxisSize: MainAxisSize.min,
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    _commentController.dispose();
    _chatController.dispose();
    super.dispose();
  }
}