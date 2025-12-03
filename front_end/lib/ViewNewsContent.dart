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
  final List<int>? newsIdList; // 新增：接收新聞 ID 列表

  const ViewNewsContent({
    super.key,
    required this.newsData,
    this.newsIdList,
  });

  @override
  State<ViewNewsContent> createState() => _ViewNewsContentState();
}

class _ViewNewsContentState extends State<ViewNewsContent> {
  bool isFavorite = false;
  int? _bookmarkId; // 儲存bookmark_id用於刪除
  bool showComments = false;
  final TextEditingController _commentController = TextEditingController();

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

  // ========== 新增：getScript 相關變數 ==========
  List<int> _newsIdList = []; // 儲存新聞 ID 列表
  List<Map<String, dynamic>> _scriptList = []; // 儲存完整的 script 串列
  int _currentScriptIndex = 0; // 目前播放的新聞索引
  Map<String, dynamic>? _currentScript; // 目前的新聞腳本數據

  // ========== 新增：播放模式相關變數 ==========
  int _playMode = 0; // 0:一般, 1:播報, 2:對話
  int _currentTextIndex = 0; // 當前播放的文本索引
  List<String> _currentPlaylist = []; // 當前播放清單

  // ========== 新增：後台文本串列輸入區塊 ==========
  List<String> generalPlaymodeTexts = [];

  // ========== 新增：對話模式的語音ID ==========
  final String voiceA = '9lHjugDhwqoxA5MhX0az'; // ANNA_SU - 主持人 (女聲)
  final String voiceB = 'pNInz6obpgDQGcFmaJgB'; // Adam - 評論員 (男聲)

  @override
  void initState() {
    super.initState();
    _loadUserAiMode();

    // ========== 新增：初始化 newsIdList ==========
    if (widget.newsIdList != null && widget.newsIdList!.isNotEmpty) {
      _newsIdList = widget.newsIdList!;
      print('📋 已接收 newsIdList，共 ${_newsIdList.length} 個 ID');
      print('📍 ID 列表: $_newsIdList');
    } else {
      print('⚠️ 未接收到 newsIdList，將使用當前新聞 ID');
      // 如果沒有 ID 列表，至少加入當前新聞的 ID
      final currentId = widget.newsData['id'];
      if (currentId != null) {
        _newsIdList = [currentId];
      }
    }

    _fetchNewsDetail();
    _checkBookmarkStatus();
    _cleanExpiredCache(); // ========== 新增：清理過期快取 ==========
    _loadComments(); // ========== 新增：載入留言 ==========

    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return; // 檢查 widget 是否還在樹中
      _onAudioComplete();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return; // 檢查 widget 是否還在樹中

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
            if (!mounted) return;
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
    if (!mounted) return;
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

          if (!mounted) return;
          setState(() {
            _comments =
                commentsData.map((comment) {
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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _selectedAiMode = userAiMode;
      });
      print('📱 已登入用戶,載入AI模式: $_selectedAiMode');
    } else {
      if (!mounted) return;
      setState(() {
        _selectedAiMode = 1;
      });
      print('📱 未登入用戶,使用預設模式: 一般(1)');
    }
  }

  // ========== 新增：從 API 獲取腳本數據 ==========
  Future<void> _fetchScriptData() async {
    try {
      print('📡 呼叫 getScript API');
      print('   使用 idList: $_newsIdList');

      if (_newsIdList.isEmpty) {
        print('❌ newsIdList 為空');
        return;
      }

      final url = Uri.parse(
        '${Config.apiBaseUrl}/script/general?idList=${json.encode(_newsIdList)}',
      );

      print('📡 API URL: $url');

      final response = await http.get(url);

      print('📡 API 響應狀態碼: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ getScript API 呼叫成功');

        // ========== 處理 SSE 格式 ==========
        List<Map<String, dynamic>> scriptList = [];

        final rawBody = response.body;

        // 按行分割
        final lines = rawBody.split('\n');
        print('📄 總共 ${lines.length} 行');

        for (var line in lines) {
          line = line.trim();

          // 跳過空行
          if (line.isEmpty) continue;

          // 處理 SSE 格式：data: {...}
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6); // 移除 "data: " 前綴

            try {
              final jsonData = json.decode(jsonStr);

              // 檢查類型
              if (jsonData is Map) {
                final type = jsonData['type'];

                if (type == 'item') {
                  // 這是一則新聞
                  scriptList.add(Map<String, dynamic>.from(jsonData));
                  print('✅ 解析新聞: ${jsonData['newsId']} - ${jsonData['title']}');
                } else if (type == 'done') {
                  // 結束標記
                  print('✅ 收到結束標記');
                }
              }
            } catch (e) {
              print('❌ 解析 JSON 失敗: $e');
            }
          }
        }

        print('📋 接收到 ${scriptList.length} 則新聞腳本');

        if (scriptList.isNotEmpty) {
          setState(() {
            _scriptList = scriptList;
            _currentScriptIndex = 0;
            _currentScript = _scriptList[0];
          });

          print('✅ 已設置 _currentScript');
          print('📰 newsId: ${_currentScript?['newsId']}');
          print('📰 title: ${_currentScript?['title']}');
          print('📰 reporter 長度: ${_currentScript?['reporter']?.toString().length ?? 0}');
          print('📰 chat 數量: ${(_currentScript?['chat'] as List?)?.length ?? 0}');
        }
      } else {
        print('❌ getScript API 呼叫失敗: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 呼叫 getScript API 發生錯誤: $error');
    }
  }

  Future<void> _fetchNewsDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${Config.apiBaseUrl}/news/search').replace(
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

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final complexList = responseData['data']['complexList'];

          if (complexList != null && complexList.isNotEmpty) {
            final newsData = complexList[0];

            if (!mounted) return;
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
      if (!mounted) return;
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
          if (!mounted) return;
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
            if (!mounted) return;
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
          SnackBar(content: Text('操作失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ========== 新增：根據新聞 ID 獲取內文 ==========
  Future<void> _fetchNewsBodyById(int newsId) async {
    try {
      print('📡 獲取新聞內文 - newsId: $newsId');

      final url = Uri.parse('${Config.apiBaseUrl}/news/$newsId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['news_body'] != null) {
          final newsBody = data['news_body'] as List;

          // 清空並重新填充 generalPlaymodeTexts
          generalPlaymodeTexts.clear();

          for (var bodyPart in newsBody) {
            if (bodyPart['text'] != null && bodyPart['text'].toString().isNotEmpty) {
              generalPlaymodeTexts.add(bodyPart['text'].toString());
            }
          }

          print('✅ 已獲取新聞內文，共 ${generalPlaymodeTexts.length} 段');
        }
      } else {
        print('❌ 獲取新聞內文失敗: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 獲取新聞內文錯誤: $error');
    }
  }

  // ========== 新增：準備播放清單 ==========
  void _preparePlaylist() {
    _currentPlaylist.clear();
    _currentTextIndex = 0;

    if (_playMode == 0) {
      // 一般模式：使用原本的 generalPlaymodeTexts（從新聞內文獲取）
      // 這部分不需要從 _currentScript 獲取，因為已經在 _fetchNewsDetail 中填充
      print('📝 一般模式：使用原本的新聞內文 TTS');
      print('📝 generalPlaymodeTexts 長度: ${generalPlaymodeTexts.length}');
      // 不需要修改 _currentPlaylist，直接使用 generalPlaymodeTexts
    } else if (_playMode == 1) {
      // 播報模式：播放 reporter
      print('🎙️ 播報模式：準備播放 reporter 文本');
      print('🎙️ _currentScript 是否為 null: ${_currentScript == null}');

      if (_currentScript != null) {
        final reporter = _currentScript?['reporter'];
        print('🎙️ reporter 內容: $reporter');
        print('🎙️ reporter 類型: ${reporter.runtimeType}');
        print('🎙️ reporter 是否為空: ${reporter == null || reporter.toString().isEmpty}');

        if (reporter != null && reporter.toString().isNotEmpty) {
          _currentPlaylist.add(reporter.toString());
          print('✅ 已添加 reporter 到播放清單');
        } else {
          print('⚠️ reporter 為空或 null');
        }
      } else {
        print('⚠️ _currentScript 為 null，無法取得 reporter');
      }

      print('🎙️ _currentPlaylist 長度: ${_currentPlaylist.length}');
    } else if (_playMode == 2) {
      // 對話模式：播放 chat
      print('🎭 對話模式：準備播放 chat');

      if (_currentScript != null) {
        final chatList = _currentScript?['chat'] as List?;
        if (chatList != null && chatList.isNotEmpty) {
          for (var chat in chatList) {
            final speaker = chat['speaker'] ?? 'A';
            final text = chat['text'] ?? '';
            if (text.isNotEmpty) {
              _currentPlaylist.add('$speaker:$text');
            }
          }
        }
      }
      print('🎭 對話模式：準備播放 ${_currentPlaylist.length} 段對話');
    }
  }

  // ========== 新增：播放下一則新聞 ==========
  Future<void> _playNextNews() async {
    print('⏭️ 點擊下一則按鈕');
    print('   _scriptList 長度: ${_scriptList.length}');
    print('   _currentScriptIndex: $_currentScriptIndex');

    if (_scriptList.isEmpty) {
      print('⚠️ 沒有新聞串列，嘗試獲取...');

      // 顯示載入狀態
      setState(() {
        _isTtsLoading = true;
      });

      await _fetchScriptData();

      // 檢查是否成功獲取
      if (_scriptList.isEmpty) {
        if (mounted) {
          setState(() {
            _isTtsLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('無法載入新聞列表，請重試')),
          );
        }
        return;
      }
    }

    if (_currentScriptIndex >= _scriptList.length - 1) {
      print('⚠️ 已經是最後一則新聞');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已經是最後一則新聞')),
        );
      }
      return;
    }

    // 停止當前播放
    await _audioPlayer.stop();

    // 移動到下一則
    setState(() {
      _currentScriptIndex++;
      _currentScript = _scriptList[_currentScriptIndex];
      _isPlaying = false;
      _isTtsLoading = true;
    });

    print('⏭️ 切換到下一則新聞: ${_currentScript?['title']}');
    print('⏭️ 新聞 ID: ${_currentScript?['newsId']}');

    // 如果是一般模式，需要獲取新新聞的內文
    if (_playMode == 0) {
      final nextNewsId = _currentScript?['newsId'];
      if (nextNewsId != null) {
        await _fetchNewsBodyById(nextNewsId);
      }
    }

    // 準備新的播放清單
    _preparePlaylist();

    // 開始播放
    await _startPlayingCurrentMode();
  }

  Future<void> _startReading() async {
    if (!mounted) return;

    // ========== 重要：每次點擊播放都要檢查並修正為當前頁面的新聞 ==========
    final currentPageNewsId = widget.newsData['id'];
    final playingNewsId = _currentScript?['newsId'];

    print('🎯 檢查新聞 ID:');
    print('   當前頁面新聞 ID: $currentPageNewsId');
    print('   播放器新聞 ID: $playingNewsId');

    // 如果播放器的新聞 ID 與當前頁面不同，需要重置
    if (playingNewsId != currentPageNewsId) {
      print('⚠️ 新聞 ID 不同，重置播放器...');

      // 重置播放器狀態
      setState(() {
        _currentScriptIndex = 0;
        _currentScript = null;
        _isPlayerVisible = true;
        _isTtsLoading = true;
      });

      // 重新獲取數據
      await _fetchScriptData();

      // 檢查是否成功獲取數據
      if (_currentScript == null) {
        // 如果是一般模式，即使沒有 scriptData 也可以繼續（只是沒有標題）
        if (_playMode != 0) {
          if (mounted) {
            setState(() {
              _isTtsLoading = false;
              _isPlayerVisible = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('無法載入腳本數據，請稍後再試')),
            );
          }
          return;
        } else {
          print('⚠️ 一般模式下無法獲取 scriptData，繼續播放但標題可能不正確');
        }
      }
    } else if (_currentScript == null) {
      // 如果 _currentScript 為 null，先獲取數據（任何模式都需要以顯示標題）
      print('📡 _currentScript 為 null，先獲取數據...');

      setState(() {
        _isPlayerVisible = true;
        _isTtsLoading = true;
      });

      await _fetchScriptData();

      // 檢查是否成功獲取數據
      if (_currentScript == null) {
        // 如果是一般模式，即使沒有 scriptData 也可以繼續（只是沒有標題）
        if (_playMode != 0) {
          if (mounted) {
            setState(() {
              _isTtsLoading = false;
              _isPlayerVisible = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('無法載入腳本數據，請稍後再試')),
            );
          }
          return;
        } else {
          print('⚠️ 一般模式下無法獲取 scriptData，繼續播放但標題可能不正確');
        }
      }
    } else {
      print('✅ 新聞 ID 相同，繼續播放');
    }

    // 準備播放清單
    _preparePlaylist();

    // 檢查是否有可播放內容
    if (_playMode == 0) {
      // 一般模式：檢查 generalPlaymodeTexts
      if (generalPlaymodeTexts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('沒有可播放的內容')),
          );
        }
        return;
      }
    } else {
      // 播報和對話模式：檢查 _currentPlaylist
      if (_currentPlaylist.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('沒有可播放的內容')),
          );
        }
        return;
      }
    }

    setState(() {
      _isPlayerVisible = true;
      _isTtsLoading = true;
    });

    await _startPlayingCurrentMode();
  }

  // ========== 新增：根據當前模式開始播放 ==========
  Future<void> _startPlayingCurrentMode() async {
    if (_playMode == 0) {
      // 一般模式
      await _playGeneralModeNew();
    } else if (_playMode == 1) {
      // 播報模式
      await _playReporterModeNew();
    } else if (_playMode == 2) {
      // 對話模式
      await _playDialogueModeNew();
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

  // ========== 新增：取得播放模式名稱 ==========
  String _getPlayModeName(int mode) {
    switch (mode) {
      case 0:
        return '一般';
      case 1:
        return '播報';
      case 2:
        return '對話';
      default:
        return '一般';
    }
  }

  // ========== 修改：一般模式（使用原本的 generalPlaymodeTexts）==========
  Future<void> _playGeneralModeNew() async {
    if (generalPlaymodeTexts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有可朗讀的內容')),
        );
      }
      _closePlayer();
      return;
    }

    // 使用原本的方式：將所有文本合併後 TTS
    String fullText = generalPlaymodeTexts.join('\n\n');
    await _playTextWithTTS(fullText, voiceId: '9lHjugDhwqoxA5MhX0az');
  }

  // ========== 新增：播報模式（使用 reporter）==========
  Future<void> _playReporterModeNew() async {
    if (_currentPlaylist.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('播報稿為空')),
        );
      }
      _closePlayer();
      return;
    }

    await _playTextWithTTS(_currentPlaylist[0], voiceId: '9lHjugDhwqoxA5MhX0az');
  }

  // ========== 新增：對話模式（使用 chat 的 speaker 區分聲音）==========
  Future<void> _playDialogueModeNew() async {
    if (_currentPlaylist.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('對話稿為空')),
        );
      }
      _closePlayer();
      return;
    }

    await _playDialogueSequenceNew();
  }

  // 對話模式的當前播放索引
  int _dialoguePlayIndex = 0;
  List<String> _dialogueAudioPaths = [];

  // ========== 新增：播放對話序列（新版 - 逐個播放）==========
  Future<void> _playDialogueSequenceNew() async {
    try {
      print('🎭 開始播放對話模式，共 ${_currentPlaylist.length} 句');

      _dialogueAudioPaths = [];
      _dialoguePlayIndex = 0;

      for (int i = 0; i < _currentPlaylist.length; i++) {
        final dialogue = _currentPlaylist[i];

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

        // 生成快取鍵值
        final newsId = _currentScript?['newsId'] ?? widget.newsData['id'];
        final cacheKey = 'tts_${newsId}_dialogue_${i}_$speaker';

        // 檢查快取
        final cachedPath = await _getCachedAudio(cacheKey);

        if (cachedPath != null) {
          print('✅ 使用快取[$i]: $speaker');
          _dialogueAudioPaths.add(cachedPath);
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
            _dialogueAudioPaths.add(savedPath);
            print('💾 已儲存快取[$i]: $savedPath');
          } else {
            print('❌ TTS API 錯誤[$i]: ${response.statusCode}');
            throw Exception('TTS API 錯誤: ${response.statusCode}');
          }
        }
      }

      print('🎵 準備播放 ${_dialogueAudioPaths.length} 段對話');

      // 開始播放第一段
      if (_dialogueAudioPaths.isNotEmpty) {
        await _playNextDialogue();
      } else {
        throw Exception('沒有可播放的音訊');
      }
    } catch (e) {
      print('❌ 對話模式播放錯誤: $e');
      if (!mounted) return;
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

  // ========== 新增：播放下一段對話 ==========
  Future<void> _playNextDialogue() async {
    if (_dialoguePlayIndex >= _dialogueAudioPaths.length) {
      print('✅ 對話播放完成');
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _isTtsLoading = false;
      });
      return;
    }

    try {
      final audioPath = _dialogueAudioPaths[_dialoguePlayIndex];
      print('🎵 播放對話[$_dialoguePlayIndex]: $audioPath');

      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
      await _audioPlayer.play(DeviceFileSource(audioPath));

      if (!mounted) return;
      setState(() {
        _isPlaying = true;
        _isTtsLoading = false;
      });
    } catch (e) {
      print('❌ 播放對話錯誤: $e');
      // 嘗試播放下一段
      _dialoguePlayIndex++;
      await _playNextDialogue();
    }
  }

  Future<void> _playTextWithTTS(String text, {String? voiceId}) async {
    try {
      print(
        '🎵 準備播放文本: ${text.substring(0, text.length > 50 ? 50 : text.length)}...',
      );

      final useVoiceId = voiceId ?? '9lHjugDhwqoxA5MhX0az';

      // ========== 前端快取系統 ==========
      final newsId = _currentScript?['newsId'] ?? widget.newsData['id'];
      final cacheKey = 'tts_${newsId}_mode${_playMode}_${useVoiceId}';

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
          'voiceId': useVoiceId,
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
        if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _isTtsLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('播放錯誤: $e')));
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
  Future<String> _saveAudioToCache(
      String cacheKey,
      Uint8List audioBytes,
      ) async {
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

    if (!mounted) return;
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

    // 如果是對話模式，播放下一段
    if (_playMode == 2 && _dialogueAudioPaths.isNotEmpty) {
      _dialoguePlayIndex++;
      if (_dialoguePlayIndex < _dialogueAudioPaths.length) {
        print('⏭️ 自動播放下一段對話');
        _playNextDialogue();
        return;
      }
    }

    // 其他模式或對話播放完成，關閉播放器
    _closePlayer();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.resume();
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
      });
    }
  }

  Future<void> _adjustPlaybackSpeed() async {
    if (!mounted) return;
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
    if (!mounted) return;
    setState(() {
      _isPlayerVisible = false;
      _isPlaying = false;
      _isTtsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428), // 星空深藍背景
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildCustomAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNewsContent(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 底部按鈕面板（新增）
            _buildBottomButtonPanel(),

            if (showComments) _buildCommentsOverlay(),
            if (_isPlayerVisible) _buildReadingPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1a2a4e), // 星空深藍卡片色
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF60a5fa)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ChannelDetailPage(
                    channelId: widget.newsData['channel_id'] ?? 1,
                    channelName:
                    _newsDetail?['channel_name'] ??
                        widget.newsData['channel'] ??
                        '新聞台',
                    channelDescription: null,
                  ),
                ),
              );
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2a3a5e), // 深藍背景
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF6366f1),
                  width: 1,
                ),
              ),
              child: const Icon(Icons.tv, size: 20, color: Color(0xFF60a5fa)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _newsDetail?['channel_name'] ??
                  widget.newsData['channel'] ??
                  '新聞台',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFd1d5db), // 淡灰文字
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
      color: const Color(0xFF1a2a4e), // 星空深藍卡片
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _newsDetail?['news_title'] ??
                      widget.newsData['title'] ??
                      '無標題',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: Color(0xFFd1d5db), // 淡灰文字
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDateTime(_newsDetail?['publish_date']),
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF6366f1),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: const Color(0xFF6366f1)),
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
          child: Text('暫無新聞內容', style: TextStyle(color: Color(0xFF6366f1))),
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
              color: Color(0xFFd1d5db), // 淡灰文字
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
                      color: const Color(0xFF2a3a5e),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Color(0xFF6366f1),
                        ),
                      ),
                    );
                  },
                ),
              if (bodyItem['body_text'] != null &&
                  bodyItem['body_text'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    bodyItem['body_text'],
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF6366f1),
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

  Widget _buildBottomButtonPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1a2a4e), // 星空深藍卡片
          border: Border(
            top: BorderSide(
              color: const Color(0xFF6366f1),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomButton(
              icon: Icons.play_arrow,
              label: 'AI朗讀',
              onTap: _startReading,
            ),
            _buildBottomButton(
              icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
              label: '收藏',
              onTap: _handleBookmarkTap,
            ),
            _buildBottomButton(
              icon: Icons.comment,
              label: _comments.length.toString(),
              showLabel: true,
              onTap: () {
                setState(() {
                  showComments = true;
                });
              },
            ),
            _buildBottomButton(
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
        child:
        showLabel
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

  // 新增：底部按鈕樣式（星空主題）
  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showLabel = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2a3a5e), // 深藍背景
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6366f1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.volume_up,
                          color: Colors.blue,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isTtsLoading
                            ? '載入中...'
                            : '${_getPlayModeName(_playMode)}朗讀',
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
                    _currentScript?['title'] ??
                        _newsDetail?['news_title'] ??
                        widget.newsData['title'] ??
                        '無標題',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 模式切換按鈕
                GestureDetector(
                  onTap:
                  _isTtsLoading
                      ? null
                      : () async {
                    // 切換模式
                    final oldMode = _playMode;
                    setState(() {
                      _playMode = (_playMode + 1) % 3; // 0 -> 1 -> 2 -> 0
                    });
                    print('🔄 切換播放模式: ${_getPlayModeName(_playMode)}');

                    // 停止當前音訊播放（但不關閉播放器）
                    await _audioPlayer.stop();
                    setState(() {
                      _isPlaying = false;
                      _isTtsLoading = true;
                    });

                    // 如果切換到播報或對話模式，且 _currentScript 為 null，先獲取數據
                    if ((_playMode == 1 || _playMode == 2) && _currentScript == null) {
                      print('📡 需要腳本數據，先獲取...');
                      await _fetchScriptData();

                      // 檢查是否成功獲取數據
                      if (_currentScript == null) {
                        if (mounted) {
                          setState(() {
                            _isTtsLoading = false;
                            _playMode = oldMode; // 恢復原模式
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('無法載入腳本數據，請稍後再試')),
                          );
                        }
                        return;
                      }
                    }

                    // 重新準備播放清單
                    _preparePlaylist();

                    // 開始播放新模式
                    await _startPlayingCurrentMode();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isTtsLoading ? Colors.grey[200] : Colors.blue[50],
                      border: Border.all(
                        color: _isTtsLoading ? Colors.grey : Colors.blue,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getPlayModeName(_playMode),
                      style: TextStyle(
                        fontSize: 12,
                        color: _isTtsLoading ? Colors.grey : Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 內文跳轉按鈕
                IconButton(
                  onPressed:
                  _isTtsLoading
                      ? null
                      : () async {
                    // 取得當前播放中的新聞ID
                    final currentNewsId = _currentScript?['newsId'] ?? widget.newsData['id'];

                    print('📰 跳轉到新聞ID: $currentNewsId');

                    // 停止播放
                    await _audioPlayer.stop();
                    setState(() {
                      _isPlayerVisible = false;
                      _isPlaying = false;
                    });

                    // 導航到該新聞的內頁
                    if (mounted) {
                      // 如果當前新聞ID與widget的新聞ID相同，不需要跳轉
                      if (currentNewsId == widget.newsData['id']) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已經在此新聞頁面'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      } else {
                        // 需要跳轉到新的新聞頁面
                        // 先找到對應的新聞資料
                        Map<String, dynamic>? targetNewsData;

                        // 從 scriptList 中尋找
                        if (_scriptList.isNotEmpty) {
                          for (var script in _scriptList) {
                            if (script['newsId'] == currentNewsId) {
                              // 構建新聞資料
                              targetNewsData = {
                                'id': script['newsId'],
                                'title': script['title'],
                                // 保留其他必要欄位
                                'channel': widget.newsData['channel'],
                                'channel_id': widget.newsData['channel_id'],
                              };
                              break;
                            }
                          }
                        }

                        if (targetNewsData != null) {
                          // 重新構建 newsIdList，讓目標新聞 ID 在第一位
                          List<int> newIdList = [currentNewsId];
                          for (var id in _newsIdList) {
                            if (id != currentNewsId) {
                              newIdList.add(id);
                            }
                          }

                          print('📋 重新構建 newsIdList:');
                          print('   舊順序: $_newsIdList');
                          print('   新順序: $newIdList');

                          // 替換當前頁面，傳遞重新排序的 newsIdList
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewNewsContent(
                                newsData: targetNewsData!,
                                newsIdList: newIdList,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('找不到對應的新聞資料'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: Icon(
                    Icons.article_outlined,
                    color: _isTtsLoading ? Colors.grey : Colors.black87,
                  ),
                  iconSize: 24,
                ),

                // 倍速按鈕
                GestureDetector(
                  onTap: _isTtsLoading ? null : _adjustPlaybackSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isTtsLoading ? Colors.grey[300]! : Colors.grey,
                      ),
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

                // 播放/暫停按鈕
                IconButton(
                  onPressed: _isTtsLoading ? null : _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 28,
                  color: _isTtsLoading ? Colors.grey : Colors.black87,
                ),

                // 下一則按鈕
                IconButton(
                  onPressed: _isTtsLoading ? null : _playNextNews,
                  icon: Icon(
                    Icons.skip_next,
                    color: _isTtsLoading ? Colors.grey : Colors.black87,
                  ),
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

  Widget _buildCommentsOverlay() {
    return Positioned.fill(
      child: Column(
        children: [
          // 上半部分：半透明背景,點擊關閉留言區
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showComments = false;
                });
              },
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),
          // 下半部分:白色留言區
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // 頂部拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 標題列
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '留言 (${_comments.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                Divider(height: 1, color: Colors.grey[300]),
                // 留言列表
                Expanded(
                  child:
                  _isLoadingComments
                      ? const Center(child: CircularProgressIndicator())
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
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 16),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
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
    super.dispose();
  }
}