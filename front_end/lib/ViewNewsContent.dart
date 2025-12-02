import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io'; // ========== 新增：檔案操作 ==========
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart'; // ========== 新增：取得快取目錄 ==========
import 'package:crypto/crypto.dart'; // ========== 新增：生成hash ==========
import 'ChannelDetailPage.dart';

class ViewNewsContent extends StatefulWidget {
  final Map<String, dynamic> newsData;

  const ViewNewsContent({super.key, required this.newsData});

  @override
  State<ViewNewsContent> createState() => _ViewNewsContentState();
}

class _ViewNewsContentState extends State<ViewNewsContent> {
  bool isFavorite = false;
  int? _bookmarkId; // 儲存bookmark_id用於刪除
  bool showComments = false;
  bool showChatBox = false;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  // 從API獲取的詳細資料
  Map<String, dynamic>? _newsDetail;
  List<Map<String, dynamic>> _newsBody = [];
  bool _isLoading = false;
  String? _error;

  // 真實留言數據
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = false;

  // AI朗讀模式相關變數
  bool _showReadModes = false;
  bool _isPlayerVisible = false;
  bool _isPlaying = false;
  bool _isTtsLoading = false; // ========== 新增：TTS載入狀態 ==========
  int _selectedAiMode = 1;
  double _playbackSpeed = 1.0;

  // ========== 新增：TTS AudioPlayer ==========
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ========== 新增：後台文本串列輸入區塊 ==========
  List<String> generalPlaymodeTexts = [];

  String reporterPlaymode = '''
各位觀眾大家好,歡迎收看今日新聞快報。

接下來為您播報今天的頭條新聞。

本新聞由我們的記者團隊精心採訪編輯,為您帶來最新、最準確的資訊。

感謝您的收看,我們下次見。
''';

  // ========== 新增：對話模式文本 ==========
  // 格式: [ "A:對話內容", "B:對話內容", "A:對話內容", ... ]
  List<String> dialoguePlaymode = [
    "A:歡迎收聽今日新聞對話節目,我是主持人小美。",
    "B:大家好,我是評論員大明。",
    "A:今天我們要討論的是這則重要新聞。大明,你對這則新聞有什麼看法?",
    "B:這是一個非常值得關注的議題。從多個角度來看,這個事件反映了社會的變化。",
    "A:沒錯,那麼對於普通民眾來說,這件事會帶來什麼影響呢?",
    "B:我認為民眾應該保持理性的態度,持續關注後續發展。",
    "A:感謝大明的精彩分析。各位聽眾,我們下次節目再見。",
    "B:再見。",
  ];

  // ========== 新增：對話模式的語音ID ==========
  final String voiceA = '9lHjugDhwqoxA5MhX0az'; // ANNA_SU - 主持人 (女聲)
  final String voiceB = 'pNInz6obpgDQGcFmaJgB'; // Adam - 評論員 (男聲)

  @override
  void initState() {
    super.initState();
    _loadUserAiMode();
    _fetchNewsDetail();
    _checkBookmarkStatus();
    _cleanExpiredCache(); // ========== 新增：清理過期快取 ==========
    _loadComments(); // ========== 新增：載入留言 ==========

    _audioPlayer.onPlayerComplete.listen((event) {
      _onAudioComplete();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        setState(() {
          _isPlaying = true;
          _isTtsLoading = false;
        });
      } else if (state == PlayerState.paused || state == PlayerState.stopped) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  // ========== 新增：檢查收藏狀態 ==========
  Future<void> _checkBookmarkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('IsLogin') ?? false;

    if (!isLoggedIn) return;

    final userId = prefs.getInt('UserID');
    if (userId == null) return;

    try {
      // 使用正確的API路徑
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/user/bookmark/news?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final bookmarks = data['data'] as List;
          final newsId = widget.newsData['id'];

          // 查找是否已收藏此新聞
          final bookmark = bookmarks.firstWhere(
                (b) => b['news_id'] == newsId,
            orElse: () => null,
          );

          if (bookmark != null) {
            setState(() {
              isFavorite = true;
              _bookmarkId = bookmark['bookmark_id'];
            });
            print('✅ 已找到收藏記錄: bookmark_id=${bookmark['bookmark_id']}');
          }
        }
      }
    } catch (e) {
      print('❌ 檢查收藏狀態失敗: $e');
    }
  }

  // ========== 新增：載入留言資料 ==========
  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
    });

    try {
      final newsId = widget.newsData['id'];
      // 修改為正確的 API 路徑
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/user/comment/news?dataId=$newsId'),
      );

      print('📝 載入留言回應狀態碼: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final commentsData = responseData['data'] as List;

          setState(() {
            _comments = commentsData.map((comment) {
              return {
                'comment_id': comment['comment_id'],
                'user_id': comment['user_id'],
                'user': comment['display_name'] ?? '訪客',
                'content': comment['comment_text'] ?? '',
                'time': _formatCommentTime(comment['created_at']),
                'avatar': _getAvatarText(comment['display_name'] ?? '訪客'),
                'is_anonymous': comment['is_anonymous'] ?? false,
              };
            }).toList();
            _isLoadingComments = false;
          });

          print('✅ 成功載入 ${_comments.length} 則留言');
        } else {
          throw Exception(responseData['message'] ?? '載入留言失敗');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 載入留言失敗: $error');
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  // ========== 新增：格式化留言時間 ==========
  String _formatCommentTime(String? createdAt) {
    if (createdAt == null) return '未知時間';

    try {
      final commentTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(commentTime);

      if (difference.inMinutes < 1) {
        return '剛剛';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}分鐘前';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}小時前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}天前';
      } else {
        return '${commentTime.year}/${commentTime.month}/${commentTime.day}';
      }
    } catch (e) {
      return '未知時間';
    }
  }

  // ========== 新增：取得頭像文字 ==========
  String _getAvatarText(String displayName) {
    if (displayName.isEmpty) return '?';
    return displayName.substring(0, 1).toUpperCase();
  }

  // ========== 新增：載入用戶AI模式設定 ==========
  Future<void> _loadUserAiMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('IsLogin') ?? false;

    if (isLoggedIn) {
      final userAiMode = prefs.getInt('UserAiMode') ?? 1;
      setState(() {
        _selectedAiMode = userAiMode;
      });
      print('📱 已登入用戶,載入AI模式: $_selectedAiMode');
    } else {
      setState(() {
        _selectedAiMode = 1;
      });
      print('📱 未登入用戶,使用預設模式: 一般(1)');
    }
  }

  Future<void> _fetchNewsDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${Config.apiBaseUrl}/news/search').replace(
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

  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('IsLogin') ?? false;
  }

  // ========== 修改：處理收藏按鈕點擊 - 使用API ==========
  Future<void> _handleBookmarkTap() async {
    final isLoggedIn = await _checkLoginStatus();

    if (!isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('請登入後再操作'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('UserID');

    if (userId == null) {
      print('❌ 無法獲取用戶ID');
      return;
    }

    try {
      if (isFavorite && _bookmarkId != null) {
        // 取消收藏 - DELETE /api/user/bookmark/{bookmarkId}
        print('🗑️ 取消收藏: bookmark_id=$_bookmarkId');

        final response = await http.delete(
          Uri.parse('${Config.apiBaseUrl}/user/bookmark/$_bookmarkId'),
        );

        print('📡 取消收藏回應: ${response.statusCode}');

        if (response.statusCode == 200) {
          setState(() {
            isFavorite = false;
            _bookmarkId = null;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已取消收藏'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        } else {
          throw Exception('取消收藏失敗: ${response.statusCode}');
        }
      } else {
        // 新增收藏 - POST /api/user/bookmark/news
        print('➕ 新增收藏: userId=$userId, newsId=${widget.newsData['id']}');

        final response = await http.post(
          Uri.parse('${Config.apiBaseUrl}/user/bookmark/news'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': userId,
            'dataId': widget.newsData['id'],
          }),
        );

        print('📡 新增收藏回應: ${response.statusCode}');
        print('📡 回應內容: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['success'] == true || data['insertId'] != null) {
            setState(() {
              isFavorite = true;
              _bookmarkId = data['insertId'];
            });

            print('✅ 收藏成功: bookmark_id=${data['insertId']}');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已加入收藏'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          } else {
            throw Exception('收藏失敗: ${data['message'] ?? '未知錯誤'}');
          }
        } else {
          throw Exception('收藏失敗: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ 收藏操作失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startReading() async {
    setState(() {
      _isPlayerVisible = true;
      _isTtsLoading = true; // ========== 開始載入 ==========
    });

    if (_selectedAiMode == 1) {
      await _playGeneralMode();
    } else if (_selectedAiMode == 2) {
      await _playReporterMode();
    } else if (_selectedAiMode == 3) {
      // 對話模式
      await _playDialogueMode();
    }
  }

  void _switchAiMode(int newMode) {
    setState(() {
      _selectedAiMode = newMode;
    });
    print('🔄 切換AI模式: $newMode');
  }

  String _getModeName(int mode) {
    switch (mode) {
      case 1:
        return '一般';
      case 2:
        return '播報';
      case 3:
        return '對話';
      default:
        return '一般';
    }
  }

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

    String fullText = generalPlaymodeTexts.join('\n\n');
    await _playTextWithTTS(fullText);
  }

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

  // ========== 修改：使用前端快取的TTS播放 ==========


  // ========== 新增：對話模式 - 播放對話列表 ==========
  Future<void> _playDialogueMode() async {
    if (dialoguePlaymode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('對話稿為空')),
        );
      }
      _closePlayer();
      return;
    }

    // 對話模式需要逐句處理,每句有不同的voiceId
    await _playDialogueSequence();
  }

  // ========== 新增：播放對話序列 ==========
  Future<void> _playDialogueSequence() async {
    try {
      print('🎭 開始播放對話模式,共 ${dialoguePlaymode.length} 句');

      // 檢查或生成所有對話片段的快取
      List<String> audioFilePaths = [];

      for (int i = 0; i < dialoguePlaymode.length; i++) {
        final dialogue = dialoguePlaymode[i];

        // 解析對話 "A:文本" 或 "B:文本"
        if (!dialogue.contains(':')) {
          print('❌ 格式錯誤: $dialogue');
          continue;
        }

        final parts = dialogue.split(':');
        final speaker = parts[0].trim();
        final text = parts.sublist(1).join(':').trim();

        if (text.isEmpty) continue;

        // 選擇對應的 voiceId
        final voiceId = (speaker == 'A') ? voiceA : voiceB;

        // 生成快取鍵值 (包含索引確保順序)
        final newsId = widget.newsData['id'];
        final cacheKey = 'tts_${newsId}_dialogue_${i}_${speaker}';

        // 檢查快取
        final cachedPath = await _getCachedAudio(cacheKey);

        if (cachedPath != null) {
          print('✅ 使用快取[$i]: $speaker');
          audioFilePaths.add(cachedPath);
        } else {
          // 調用TTS API
          print('📡 生成音訊[$i]: $speaker - ${text.substring(0, text.length > 20 ? 20 : text.length)}...');

          final response = await http.post(
            Uri.parse('${Config.apiBaseUrl}/tts'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'voiceId': voiceId,
              'stability': 0.5,
              'similarity_boost': 0.75,
            }),
          );

          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            final savedPath = await _saveAudioToCache(cacheKey, bytes);
            audioFilePaths.add(savedPath);
            print('💾 已儲存快取[$i]: $savedPath');
          } else {
            print('❌ TTS API 錯誤[$i]: ${response.statusCode}');
            throw Exception('TTS API 錯誤: ${response.statusCode}');
          }
        }
      }

      // 合併所有音訊檔案
      if (audioFilePaths.isNotEmpty) {
        await _playMergedDialogue(audioFilePaths);
      } else {
        throw Exception('沒有可播放的音訊');
      }

    } catch (e) {
      print('❌ 對話模式播放錯誤: $e');
      setState(() {
        _isTtsLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('對話播放錯誤: $e')),
        );
      }
      _closePlayer();
    }
  }

  // ========== 新增：合併並播放對話音訊 ==========
  Future<void> _playMergedDialogue(List<String> audioFilePaths) async {
    try {
      print('🎵 準備播放 ${audioFilePaths.length} 段對話');

      // 讀取所有音訊bytes
      List<int> mergedBytes = [];
      for (final path in audioFilePaths) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        mergedBytes.addAll(bytes);
      }

      // 轉換為 base64 data URL
      final String base64Audio = base64Encode(Uint8List.fromList(mergedBytes));
      final String dataUrl = 'data:audio/mpeg;base64,$base64Audio';

      print('🔄 對話總長度: ${mergedBytes.length} bytes');

      // 播放
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
      await _audioPlayer.play(UrlSource(dataUrl));

      setState(() {
        _isPlaying = true;
        _isTtsLoading = false;
      });

      print('🎭 正在播放對話模式');

    } catch (e) {
      print('❌ 合併播放錯誤: $e');
      throw e;
    }
  }

  Future<void> _playTextWithTTS(String text) async {
    try {
      print('🎵 準備播放文本: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');

      // ========== 前端快取系統 ==========
      final newsId = widget.newsData['id'];
      final cacheKey = 'tts_${newsId}_mode${_selectedAiMode}';

      // 1. 檢查本地快取
      final cachedAudioPath = await _getCachedAudio(cacheKey);

      if (cachedAudioPath != null) {
        print('✅ 使用快取音訊: $cachedAudioPath');
        await _playAudioFromFile(cachedAudioPath);
        return;
      }

      // 2. 快取不存在,調用TTS API
      print('📡 快取不存在,調用TTS API...');
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/tts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'voiceId': '9lHjugDhwqoxA5MhX0az',
          'stability': 0.5,
          'similarity_boost': 0.75,
        }),
      );

      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        print('✅ 收到音訊數據: ${bytes.length} bytes');

        // 3. 儲存到快取
        final savedPath = await _saveAudioToCache(cacheKey, bytes);
        print('💾 已儲存快取: $savedPath');

        // 4. 播放音訊
        await _playAudioFromFile(savedPath);

      } else {
        print('❌ TTS API 錯誤: ${response.statusCode}');
        setState(() {
          _isTtsLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('語音合成失敗: ${response.statusCode}')),
          );
        }
        _closePlayer();
      }
    } catch (e) {
      print('❌ 播放錯誤: $e');
      setState(() {
        _isTtsLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放錯誤: $e')),
        );
      }
      _closePlayer();
    }
  }

  // ========== 新增：取得快取目錄路徑 ==========
  Future<String> _getCacheDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/tts_cache');

    // 確保快取目錄存在
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir.path;
  }

  // ========== 新增：檢查快取是否存在且未過期 ==========
  Future<String?> _getCachedAudio(String cacheKey) async {
    try {
      final cachePath = await _getCacheDirectory();
      final file = File('$cachePath/$cacheKey.mp3');

      // 檢查檔案是否存在
      if (!await file.exists()) {
        return null;
      }

      // 檢查檔案是否過期(7天)
      final fileStat = await file.stat();
      final now = DateTime.now();
      final difference = now.difference(fileStat.modified);

      if (difference.inDays > 7) {
        print('⏰ 快取已過期: $cacheKey (${difference.inDays}天前)');
        await file.delete();
        return null;
      }

      print('✅ 找到有效快取: $cacheKey (${difference.inDays}天前)');
      return file.path;

    } catch (e) {
      print('❌ 檢查快取失敗: $e');
      return null;
    }
  }

  // ========== 新增：儲存音訊到快取 ==========
  Future<String> _saveAudioToCache(String cacheKey, Uint8List audioBytes) async {
    final cachePath = await _getCacheDirectory();
    final file = File('$cachePath/$cacheKey.mp3');

    await file.writeAsBytes(audioBytes);

    return file.path;
  }

  // ========== 新增：從檔案播放音訊 ==========
  Future<void> _playAudioFromFile(String filePath) async {
    await _audioPlayer.stop();
    await _audioPlayer.setPlaybackRate(_playbackSpeed);

    // 使用 DeviceFileSource 播放本地檔案
    await _audioPlayer.play(DeviceFileSource(filePath));

    setState(() {
      _isPlaying = true;
      _isTtsLoading = false;
    });

    print('🎵 正在播放 ${_getModeName(_selectedAiMode)} 模式');
  }

  // ========== 新增：清理過期快取(啟動時執行) ==========
  Future<void> _cleanExpiredCache() async {
    try {
      final cachePath = await _getCacheDirectory();
      final cacheDir = Directory(cachePath);

      if (!await cacheDir.exists()) {
        return;
      }

      final now = DateTime.now();
      int deletedCount = 0;

      // 遍歷所有快取檔案
      await for (var entity in cacheDir.list()) {
        if (entity is File && entity.path.endsWith('.mp3')) {
          final fileStat = await entity.stat();
          final difference = now.difference(fileStat.modified);

          // 刪除超過7天的檔案
          if (difference.inDays > 7) {
            await entity.delete();
            deletedCount++;
            print('🗑️ 已刪除過期快取: ${entity.path.split('/').last}');
          }
        }
      }

      if (deletedCount > 0) {
        print('✅ 清理完成: 刪除了 $deletedCount 個過期快取檔案');
      }

    } catch (e) {
      print('❌ 清理快取失敗: $e');
    }
  }

  void _onAudioComplete() {
    print('✅ 播放完成');
    _closePlayer();
  }

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

    await _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  Future<void> _closePlayer() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlayerVisible = false;
      _isPlaying = false;
      _isTtsLoading = false;
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

  Widget _buildRightButtonPanel() {
    return Positioned(
      right: 8,
      top: 20,
      bottom: 20,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRightButton(
            icon: Icons.play_arrow,
            label: 'AI朗讀',
            onTap: _startReading,
          ),

          const SizedBox(height: 16),

          _buildRightButton(
            icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
            label: '收藏',
            onTap: _handleBookmarkTap,
          ),

          const SizedBox(height: 16),

          _buildRightButton(
            icon: Icons.comment,
            label: '${_comments.length}',
            showLabel: true, // 顯示留言數
            onTap: () {
              // 修改：未登入也能打開留言區查看留言
              setState(() {
                showComments = true;
              });
            },
          ),

          const SizedBox(height: 16),

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

  Widget _buildRightButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showLabel = false, // 新增參數控制是否顯示標籤
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: showLabel ? 56 : 48, // 有標籤時增加高度
        decoration: BoxDecoration(
          color: Colors.white,
          shape: showLabel ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: showLabel ? BorderRadius.circular(24) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: showLabel
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        )
            : Icon(icon, size: 24, color: Colors.black87),
      ),
    );
  }

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

  // ========== 修改：朗讀播放器 - 加入載入狀態顯示 ==========
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // ========== 新增：載入中顯示 ==========
                      if (_isTtsLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        )
                      else
                        const Icon(Icons.volume_up, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isTtsLoading ? '載入中...' : '${_getModeName(_selectedAiMode)}朗讀',
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

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _isTtsLoading ? null : () {
                    int nextMode = (_selectedAiMode % 3) + 1;
                    _switchAiMode(nextMode);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isTtsLoading ? Colors.grey[200] : Colors.blue[50],
                      border: Border.all(color: _isTtsLoading ? Colors.grey : Colors.blue),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getModeName(_selectedAiMode),
                      style: TextStyle(
                        fontSize: 12,
                        color: _isTtsLoading ? Colors.grey : Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed: _isTtsLoading ? null : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('內文跳轉功能開發中'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.article_outlined,
                    color: _isTtsLoading ? Colors.grey : Colors.black87,
                  ),
                  iconSize: 24,
                ),

                GestureDetector(
                  onTap: _isTtsLoading ? null : _adjustPlaybackSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: _isTtsLoading ? Colors.grey[300]! : Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_playbackSpeed}x',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isTtsLoading ? Colors.grey : Colors.black87,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed: _isTtsLoading ? null : _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 28,
                  color: _isTtsLoading ? Colors.grey : Colors.black87,
                ),

                IconButton(
                  onPressed: _isTtsLoading ? null : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('下一篇功能開發中'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.skip_next,
                    color: _isTtsLoading ? Colors.grey : Colors.black87,
                  ),
                  iconSize: 24,
                ),

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
                        child: _isLoadingComments
                            ? const Center(
                          child: CircularProgressIndicator(),
                        )
                            : _comments.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.comment_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '還沒有留言',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '成為第一個留言的人吧！',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.separated(
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

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final isAnonymous = comment['is_anonymous'] ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isAnonymous ? Colors.grey[300] : Colors.blue[100],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              comment['avatar'],
              style: TextStyle(
                color: isAnonymous ? Colors.grey[700] : Colors.blue[700],
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
                  if (isAnonymous) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '匿名',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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

  // ========== 修改：留言輸入 - 檢查登入狀態 ==========
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

  // ========== 修改：送出留言 - 呼叫後端 API ==========
  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('IsLogin') ?? false;

    if (!isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('請登入後再操作'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final userId = prefs.getInt('UserID');
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('無法取得用戶資訊'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final commentText = _commentController.text.trim();
    _commentController.clear();

    try {
      final newsId = widget.newsData['id'];
      // 修改為正確的 API 路徑
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/user/comment/news'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'dataId': newsId,
          'text': commentText,
        }),
      );

      print('📤 送出留言回應狀態碼: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('留言已發送'),
                duration: Duration(seconds: 1),
                backgroundColor: Colors.green,
              ),
            );
          }

          // 重新載入留言列表
          await _loadComments();
        } else {
          throw Exception(responseData['message'] ?? '發送留言失敗');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 發送留言失敗: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('留言發送失敗: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
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