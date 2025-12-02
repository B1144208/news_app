import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'config.dart';
import 'LoginPage.dart';
import 'AdminPage.dart';
import 'ViewNewsContent.dart';
import 'MapPage.dart';
import 'AIPage.dart';
import 'SearchPage.dart';
import 'BookmarkPage.dart';
import 'MemberCenterPage.dart';
import 'SignupPage.dart';
import 'GroupCustomizePage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;
  String _selectedCategory = '全部';
  int? _selectedGroupId; // 新增:選中的分類ID
  String _selectedSortType = '總熱度'; // 新增:排序方式

  List<Map<String, dynamic>> _categories = []; // 改為動態列表
  final List<String> _sortTypes = ['總熱度', '瀏覽數量', '分享數量', '收藏數量', '留言數量']; // 新增:排序選項

  // 下拉箭頭展開狀態
  Map<int, List<Map<String, dynamic>>> _categoryDetails = {}; // key: group_id, value: 詳細分類列表
  Map<int, GlobalKey> _arrowButtonKeys = {}; // key: group_id, value: 箭頭按鈕的 GlobalKey

  List<Map<String, dynamic>> _newsData = [];
  List<Map<String, dynamic>> _allNewsData = []; // 新增:儲存所有新聞資料
  bool _isLoading = false;
  bool _isLoadingMore = false; // 新增:載入更多資料的狀態
  String? _error;
  int _currentPage = 0; // 新增:當前頁碼
  final int _newsPerPage = 30; // 新增:每頁新聞數量
  final ScrollController _scrollController = ScrollController(); // 新增:滾動控制器

  // 快速播放相關變數
  bool _isPlayerVisible = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  //int _currentNewsIndex = 0;

  // 新增:AudioPlayer 實例
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 新增:後台文本串列
  int paragraphCount = 6;
  List<String> paragraphText = [
    "開始為您播放今日焦點新聞，第一篇是快新聞，北市中正一警局下通牒　黃國昌明天未到案就送北檢偵辦。",
    "第二篇是快新聞／好可怕！台南警匪追逐戰　歹徒持榔頭攻擊員警、所長被咬傷。",
    "第三篇是青少年受情緒困擾 兒盟調查：逾2成想過輕生。",
    "第四篇是喝咖啡讓人更長壽？　營養師：每天3至5杯效果最佳。",
    "第五篇是腸病毒重症已奪8命！伊科11型來勢洶洶　疾管署：幼童是高風險族群。",
    "接下來是各篇新聞的大致內容：「走讀活動」引發警方與民眾對峙，8名警員受傷，而主嫌黃國昌涉嫌違反《集會遊行法》及《聚眾妨害公務法》。台北市警局已通知黃國昌明早到案說服，如果他不來將送北檢處理。"
  ];
  int _currentParagraphIndex = 0; // 當前播放的文章索引

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // 先載入分類
    _scrollController.addListener(_onScroll); // 新增:監聽滾動事件

    // 監聽音訊播放完成事件
    _audioPlayer.onPlayerComplete.listen((event) {
      _onAudioComplete();
    });

    // 監聽音訊播放狀態
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

  // 新增:獲取分類列表
  Future<void> _fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID');
      final isLoggedIn = prefs.getBool('IsLogin') ?? false;

      print('🔍 _fetchCategories - 登入狀態: $isLoggedIn, UserID: $userId');

      List<Map<String, dynamic>> categories = [];

      // 先獲取所有 group_data
      final groupResponse = await http.get(
        Uri.parse('${Config.apiBaseUrl}/group'),
      );

      if (groupResponse.statusCode != 200) {
        throw Exception('獲取分類資料失敗');
      }

      final groupData = json.decode(groupResponse.body);
      if (groupData['success'] != true || groupData['data'] == null) {
        throw Exception('分類資料格式錯誤');
      }

      print('📡 獲取到 ${groupData['data'].length} 個分類');

      // 使用 Set 來追蹤已添加的 group_id,確保不重複
      Set<int> addedGroupIds = {};

      for (var item in groupData['data']) {
        int? groupId = item['group_id'];

        if (groupId != null && !addedGroupIds.contains(groupId)) {
          categories.add({
            'group_id': groupId,
            'group_name': item['group_name'] ?? '未命名',
          });
          addedGroupIds.add(groupId);
          print('   ✅ 添加: ${item['group_name']} (ID: $groupId)');
        } else {
          print('   ⚠️ 跳過重複: ${item['group_name']} (ID: $groupId)');
        }
      }

      // 按 group_id 排序
      categories.sort((a, b) => (a['group_id'] ?? 0).compareTo(b['group_id'] ?? 0));

      print('✅ 最終分類數量: ${categories.length}');
      print('✅ 分類 IDs: $addedGroupIds');

      setState(() {
        // 在最前面添加"全部"選項
        _categories = [
          {'group_id': null, 'group_name': '全部'},
          ...categories,
        ];
      });

      // 分類載入完成後再載入新聞
      _fetchNews();
    } catch (error) {
      print('❌ 獲取分類失敗: $error');
      setState(() {
        _categories = [
          {'group_id': null, 'group_name': '全部'},
        ];
      });
      _fetchNews();
    }
  }

  // 新增:獲取特定分類的詳細子分類
  Future<void> _fetchCategoryDetails(int groupId) async {
    // 如果已經加載過,直接返回
    if (_categoryDetails.containsKey(groupId)) {
      return;
    }

    try {
      print('🔍 獲取分類詳情 - groupId: $groupId');

      // 使用 /group 端點獲取所有分類和詳細分類的數據
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/group'),
      );

      print('📡 API 響應狀態碼: ${response.statusCode}');
      print('📡 API 響應內容: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> dataList = [];

        // 處理兩種可能的返回格式
        if (responseData is Map && responseData['data'] != null) {
          // 格式: {"success":true, "data": [...]}
          dataList = responseData['data'];
          print('📦 使用 Map 格式，data 長度: ${dataList.length}');
        } else if (responseData is List) {
          // 格式: [...]
          dataList = responseData;
          print('📦 使用 List 格式，長度: ${dataList.length}');
        }

        if (dataList.isNotEmpty) {
          List<Map<String, dynamic>> details = [];

          // 過濾出符合當前 groupId 的詳細分類
          for (var item in dataList) {
            print('🔍 檢查項目: group_id=${item['group_id']}, group_detail_name=${item['group_detail_name']}');

            if (item['group_id'] == groupId && item['group_detail_name'] != null) {
              details.add({
                'group_detail_id': item['group_detail_id'],
                'group_detail_name': item['group_detail_name'],
              });
              print('   ✅ 匹配! 添加: ${item['group_detail_name']}');
            }
          }

          print('✅ 獲取到 ${details.length} 個詳細分類 (groupId: $groupId)');

          setState(() {
            _categoryDetails[groupId] = details;
          });
        } else {
          print('⚠️ 沒有數據');
        }
      } else {
        print('❌ API 錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 獲取分類詳情失敗: $error');
      print('❌ 錯誤堆棧: ${StackTrace.current}');
    }
  }

  // 新增：滾動監聽
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore && _allNewsData.isNotEmpty) {
        _loadMoreNews();
      }
    }
  }

  // 新增：載入更多新聞
  Future<void> _loadMoreNews() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    // 模擬載入延遲
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      if (_newsData.length >= 60) {
        // 如果已有60個新聞，刪除前30個
        _newsData.removeRange(0, 30);
        _currentPage++;
      }

      // 載入接下來的30個新聞
      int startIndex = (_currentPage + 1) * _newsPerPage;
      int endIndex = startIndex + _newsPerPage;

      if (startIndex < _allNewsData.length) {
        endIndex = endIndex > _allNewsData.length ? _allNewsData.length : endIndex;
        _newsData.addAll(_allNewsData.sublist(startIndex, endIndex));
        _currentPage++;
      }

      _isLoadingMore = false;
    });
  }

  // 修復後的 _fetchNews() 方法
  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _newsData.clear();
      _allNewsData.clear();
    });

    try {
      http.Response response;

      if (_selectedGroupId != null) {
        // 查詢特定分類 - ✅ 修復: 使用 /search 端點
        print('🔡 查詢特定分類新聞 - groupId: $_selectedGroupId');

        response = await http.post(
          Uri.parse('${Config.apiBaseUrl}/news/search?mode=simple&order=general&limit=300'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'groupId': _selectedGroupId,
            'groupType': 'data',
          }),
        );

        print('🔡 特定分類回應: ${response.statusCode}');
      } else {
        // 查詢所有新聞 - ✅ 修復: 使用 /search 端點
        print('🔡 查詢所有新聞');

        response = await http.post(
          Uri.parse('${Config.apiBaseUrl}/news/search?mode=simple&order=general&limit=300'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({}),
        );

        print('🔡 所有新聞回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> newsList;

          if (responseData['data'] is List) {
            newsList = responseData['data'];
            print('📦 data 是 List 格式');
          } else if (responseData['data'] is Map) {
            newsList = responseData['data']['simpleList'] ?? [];
            print('📦 data 是 Map 格式,提取 simpleList');
          } else {
            newsList = [];
            print('⚠️ data 格式不明');
          }

          print('✅ 獲取到新聞數量: ${newsList.length}');

          if (newsList.isEmpty) {
            setState(() {
              _allNewsData = [];
              _newsData = [];
              _isLoading = false;
              _error = null;
            });
            return;
          }

          // 處理新聞數據
          List<Map<String, dynamic>> processedNews = newsList.map<Map<String, dynamic>>((news) {
            return {
              'id': news['newsId'],
              'title': news['newsTitle'] ?? '無標題',
              'channel': news['channelName'] ?? '未知頻道',
              'publish_date': _formatDate(news['publishDate']),
              'cover_img': news['coverImageUrl'],
              'cover_img_alt': news['coverImageAlt'] ?? '',
              'news_date': news['publishDate'],
              'comments': 0,
              'views': 0,
              'shares': 0,
              'bookmarks': 0,
            };
          }).toList();

          // 根據選擇的排序方式排序
          _sortNews(processedNews);

          setState(() {
            _allNewsData = processedNews;
            _newsData = _allNewsData.take(_newsPerPage).toList();
            _isLoading = false;
          });
        } else {
          throw Exception(responseData['message'] ?? '獲取新聞失敗');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 載入新聞錯誤: $error');
      setState(() {
        _error = '載入新聞時發生錯誤: $error';
        _isLoading = false;
      });
    }
  }

  // 新增：根據詳細分類篩選新聞
  Future<void> _fetchNewsByGroupDetail(int groupDetailId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _newsData.clear();
      _allNewsData.clear();
    });

    try {
      print('🔡 查詢詳細分類新聞 - groupDetailId: $groupDetailId');

      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/news/search?mode=simple&order=general&limit=300'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'groupId': groupDetailId,
          'groupType': 'detail', // 使用 detail 類型
        }),
      );

      print('🔡 詳細分類回應: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> newsList = responseData['data'] ?? [];
          print('📰 獲取到 ${newsList.length} 條詳細分類新聞');

          List<Map<String, dynamic>> processedNews = [];
          for (var news in newsList) {
            processedNews.add({
              'news_id': news['newsId'],
              'channel': news['channelName'] ?? '未知頻道',
              'cover_img': news['coverImageUrl'],
              'title': news['newsTitle'] ?? '無標題',
              'publish_date': news['publishDate'] ?? '未知時間',
              'comments': 0, // API 可能沒有返回評論數
            });
          }

          // 根據選擇的排序方式排序
          _sortNews(processedNews);

          setState(() {
            _allNewsData = processedNews;
            _newsData = _allNewsData.take(_newsPerPage).toList();
            _isLoading = false;
          });
        } else {
          throw Exception(responseData['message'] ?? '獲取詳細分類新聞失敗');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 載入詳細分類新聞錯誤: $error');
      setState(() {
        _error = '載入詳細分類新聞時發生錯誤: $error';
        _isLoading = false;
      });
    }
  }

  // 新增：根據排序方式排序新聞
  void _sortNews(List<Map<String, dynamic>> newsList) {
    switch (_selectedSortType) {
      case '瀏覽數量':
        newsList.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));
        break;
      case '分享數量':
        newsList.sort((a, b) => (b['shares'] as int).compareTo(a['shares'] as int));
        break;
      case '收藏數量':
        newsList.sort((a, b) => (b['bookmarks'] as int).compareTo(a['bookmarks'] as int));
        break;
      case '留言數量':
        newsList.sort((a, b) => (b['comments'] as int).compareTo(a['comments'] as int));
        break;
      case '總熱度':
      default:
      // 總熱度 = 瀏覽數 + 分享數*2 + 收藏數*3 + 留言數*2
        newsList.sort((a, b) {
          int heatA = (a['views'] as int) + (a['shares'] as int) * 2 +
              (a['bookmarks'] as int) * 3 + (a['comments'] as int) * 2;
          int heatB = (b['views'] as int) + (b['shares'] as int) * 2 +
              (b['bookmarks'] as int) * 3 + (b['comments'] as int) * 2;
          return heatB.compareTo(heatA);
        });
        break;
    }
  }

  // 獲取頻道資料
  Future<Map<int, String>> _fetchChannelData() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/channel'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> channels = responseData['data'];
          Map<int, String> channelMap = {};
          for (var channel in channels) {
            channelMap[channel['channel_id']] = channel['channel_name'] ?? '未知頻道';
          }
          return channelMap;
        }
      }
    } catch (error) {
      print('獲取頻道資料失敗: $error');
    }
    return {};
  }

  // 獲取圖片資料
  Future<Map<int, String>> _fetchImageData() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/image'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> images = responseData['data'];
          Map<int, String> imageMap = {};
          for (var image in images) {
            imageMap[image['image_id']] = image['image_origin_url'] ?? '';
          }
          return imageMap;
        }
      }
    } catch (error) {
      print('獲取圖片資料失敗: $error');
    }
    return {};
  }

  // 格式化日期
  String _formatDate(String? dateString) {
    if (dateString == null) return '未知時間';

    try {
      final DateTime newsDate = DateTime.parse(dateString);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(newsDate);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}分鐘前';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}小時前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}天前';
      } else {
        return '${newsDate.year}年${newsDate.month}月${newsDate.day}日';
      }
    } catch (e) {
      return '未知時間';
    }
  }

  // 獲取用戶資訊
  Future<Map<String, dynamic>> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'account': prefs.getString('Account') ?? '',
      'isAdmin': (prefs.getInt('UserLevel') ?? 0) >= 5,
    };
  }

  // 新增：解析時間字串為秒數
  // 新增:格式化剩餘時間顯示
  String _formatRemainingTime() {
    // 顯示剩餘篇數
    int remaining = paragraphCount - _currentParagraphIndex;
    return '$remaining 篇';
  }

  // 快速播放功能
  Future<void> _startQuickPlay() async {
    if (paragraphText.isEmpty || paragraphCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有可播放的文本')),
      );
      return;
    }

    setState(() {
      _isPlayerVisible = true;
      _currentParagraphIndex = 0;
    });

    // 播放第一篇文章
    await _playCurrentParagraph();
  }

  // 播放當前文章
  Future<void> _playCurrentParagraph() async {
    if (_currentParagraphIndex >= paragraphText.length) {
      // 所有文章播放完畢
      _closePlayer();
      return;
    }

    try {
      String currentText = paragraphText[_currentParagraphIndex];

      print('🎵 準備播放第 ${_currentParagraphIndex + 1} 篇文章: ${currentText.substring(0, currentText.length > 50 ? 50 : currentText.length)}...');

      // 呼叫 TTS API
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/tts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': currentText,
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

        print('🎵 正在播放第 ${_currentParagraphIndex + 1} 篇文章');
      } else {
        print('❌ TTS API 錯誤: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('語音合成失敗: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('❌ 播放錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放錯誤: $e')),
        );
      }
    }
  }

  // 音訊播放完成回調
  void _onAudioComplete() {
    print('✅ 第 ${_currentParagraphIndex + 1} 篇播放完成');

    // 自動播放下一篇
    if (_currentParagraphIndex < paragraphText.length - 1) {
      setState(() {
        _currentParagraphIndex++;
      });
      _playCurrentParagraph();
    } else {
      // 所有文章播放完畢
      _closePlayer();
    }
  }

  // 切換播放/暫停
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

  // 上一篇文章
  Future<void> _previousNews() async {
    if (_currentParagraphIndex > 0) {
      setState(() {
        _currentParagraphIndex--;
      });
      await _playCurrentParagraph();
    }
  }

  // 下一篇文章
  Future<void> _nextNews() async {
    if (_currentParagraphIndex < paragraphText.length - 1) {
      setState(() {
        _currentParagraphIndex++;
      });
      await _playCurrentParagraph();
    }
  }

  // 調整播放倍速
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

  // 關閉播放器
  Future<void> _closePlayer() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlayerVisible = false;
      _isPlaying = false;
      _currentParagraphIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const MapPage(),
      _buildHomePage(),
      const AIPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      body: SafeArea(
        child: Stack(
          children: [
            pages[_selectedIndex],
            if (_isPlayerVisible) _buildMusicPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHomePage() {
    return Column(
      children: [
        _buildTopToolBar(),
        _buildCategoryFilter(),
        _buildQuickPlaySection(), // 修改後的快速播放區塊
        Expanded(child: _buildNewsList()),
      ],
    );
  }

  // ========== 工具欄：支持登入系統 ==========
  Widget _buildTopToolBar() {
    return FutureBuilder<bool>(
      future: SharedPreferences.getInstance().then(
            (prefs) => prefs.getBool('IsLogin') ?? false,
      ),
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.data ?? false;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              if (!isLoggedIn)
              // 未登入狀態 - 顯示登入和註冊按鈕
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        ).then((_) {
                          // 登入後刷新頁面
                          setState(() {});
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 32),
                      ),
                      child: const Text('登入', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    /*
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupPage(),
                          ),
                        ).then((_) {
                          // 註冊後刷新頁面
                          setState(() {});
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 32),
                      ),
                      child: const Text('註冊', style: TextStyle(fontSize: 12)),
                    ),*/
                  ],
                )
              else
              // 已登入狀態 - 顯示用戶頭像
                FutureBuilder<Map<String, dynamic>>(
                  future: _getUserInfo(),
                  builder: (context, userSnapshot) {
                    final userAccount = userSnapshot.data?['account'] ?? '';
                    final isAdmin = userSnapshot.data?['isAdmin'] ?? false;

                    return Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (isAdmin) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminPage(),
                                ),
                              ).then((_) => setState(() {}));
                            } else {
                              // 導向會員中心頁面
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const MemberCenterPage(),
                                ),
                              ).then((_) => setState(() {}));
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isAdmin ? Colors.red : Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                userAccount.isNotEmpty
                                    ? userAccount[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red),
                            ),
                            child: const Text(
                              '管理員',
                              style: TextStyle(fontSize: 10, color: Colors.red),
                            ),
                          ),
                      ],
                    );
                  },
                ),

              const SizedBox(width: 12),

              // 搜尋欄 - 放在中間並擴展
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SearchPage()),
                    );
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey,
                          spreadRadius: 0,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey, size: 20),
                        SizedBox(width: 10),
                        Text(
                          '搜尋',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 收藏按鈕
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookmarkPage(),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        spreadRadius: 0,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bookmark,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              // 點擊三條線圖標進入自訂分類頁面
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('UserID'); // 修復:使用正確的鍵名
              final isLoggedIn = prefs.getBool('IsLogin') ?? false;

              print('🔍 點擊自訂按鈕 - 登入狀態: $isLoggedIn, UserID: $userId');

              if (!isLoggedIn || userId == null) {
                // 未登入,提示用戶登入
                print('⚠️ 未登入或 UserID 為 null');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請先登入以自訂分類'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }

              print('✅ 導航到自訂分類頁面, UserID: $userId');

              // 導航到自訂分類頁面
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupCustomizePage(userId: userId),
                ),
              );

              // 從自訂頁面返回後重新載入分類
              if (result == true || result == null) {
                print('🔄 從自訂頁面返回,重新載入分類');
                _fetchCategories();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 0,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.menu, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 40, // 固定高度以避免裁切
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final categoryName = category['group_name'] ?? '未命名';
                  final groupId = category['group_id'];
                  final isSelected = _selectedCategory == categoryName;

                  // 為每個箭頭按鈕創建 GlobalKey
                  if (groupId != null && !_arrowButtonKeys.containsKey(groupId)) {
                    _arrowButtonKeys[groupId] = GlobalKey();
                  }

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 主分類按鈕
                        GestureDetector(
                          onTap: () {
                            print('📌 點擊分類: $categoryName (ID: $groupId)');
                            setState(() {
                              _selectedCategory = categoryName;
                              _selectedGroupId = groupId;
                            });
                            _fetchNews();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : Colors.white,
                              borderRadius: groupId != null
                                  ? const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                              )
                                  : BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey,
                                  spreadRadius: 0,
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        // 下拉箭頭按鈕（僅當有 groupId 時顯示）
                        if (groupId != null)
                          GestureDetector(
                            key: _arrowButtonKeys[groupId],
                            onTap: () async {
                              // 先獲取詳細分類
                              print('📌 點擊箭頭: $categoryName (ID: $groupId)');
                              await _fetchCategoryDetails(groupId);

                              // 獲取數據後再顯示菜單
                              final details = _categoryDetails[groupId] ?? [];

                              if (details.isEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('該分類沒有詳細子分類'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                                return;
                              }

                              // 使用 GlobalKey 獲取按鈕位置
                              final RenderBox? button = _arrowButtonKeys[groupId]?.currentContext?.findRenderObject() as RenderBox?;
                              if (button == null) {
                                print('❌ 無法獲取按鈕位置');
                                return;
                              }

                              final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                              final RelativeRect position = RelativeRect.fromRect(
                                Rect.fromPoints(
                                  button.localToGlobal(Offset.zero, ancestor: overlay),
                                  button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
                                ),
                                Offset.zero & overlay.size,
                              );

                              final selectedDetail = await showMenu<Map<String, dynamic>>(
                                context: context,
                                position: position,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 150,
                                  maxWidth: 250,
                                ),
                                items: details.map((detail) {
                                  return PopupMenuItem<Map<String, dynamic>>(
                                    value: detail,
                                    child: Text(
                                      detail['group_detail_name'] ?? '未命名',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                              );

                              if (selectedDetail != null) {
                                print('📌 選擇詳細分類: ${selectedDetail['group_detail_name']} (ID: ${selectedDetail['group_detail_id']})');

                                // 根據詳細分類篩選新聞
                                setState(() {
                                  _selectedCategory = '${categoryName} > ${selectedDetail['group_detail_name']}';
                                  _selectedGroupId = selectedDetail['group_detail_id']; // 使用 detail_id
                                });

                                // 使用 groupType: 'detail' 來篩選新聞
                                _fetchNewsByGroupDetail(selectedDetail['group_detail_id']);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue : Colors.white,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey,
                                    spreadRadius: 0,
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: isSelected ? Colors.white : Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 修改後的快速播放區塊
  Widget _buildQuickPlaySection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 0,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左半部:快速播放
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '快速播放',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _startQuickPlay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('確認', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 右半部:排序方式
          Row(
            children: [
              const Icon(Icons.sort, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedSortType,
                  underline: Container(),
                  items: _sortTypes.map((sortType) {
                    return DropdownMenuItem<String>(
                      value: sortType,
                      child: Text(sortType, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSortType = value!;
                    });
                    _fetchNews(); // 重新整理頁面
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              onPressed: _fetchNews,
              child: const Text('重新載入'),
            ),
          ],
        ),
      );
    }

    if (_newsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '目前沒有新聞資料',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchNews,
              child: const Text('重新載入'),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: RefreshIndicator(
        onRefresh: _fetchNews,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _newsData.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // 顯示載入更多指示器
            if (index == _newsData.length) {
              return Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            }

            final news = _newsData[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 0,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewNewsContent(newsData: news),
                    ),
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: news['cover_img'] != null && news['cover_img'].isNotEmpty
                            ? Image.network(
                          news['cover_img'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image, color: Colors.grey);
                          },
                        )
                            : const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            news['channel'] ?? '未知頻道',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            news['title'] ?? '無標題',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                news['publish_date'] ?? '未知時間',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chat_bubble_outline,
                                color: Colors.grey[600],
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${news['comments'] ?? 0}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 修改後的播放器
  Widget _buildMusicPlayer() {
    if (_newsData.isEmpty) return Container();

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
            // 左側新聞信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flash_on, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '快速播放：剩餘${_formatRemainingTime()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 右側控制按鈕
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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

                // 上一篇按鈕
                IconButton(
                  onPressed: _currentParagraphIndex > 0 ? _previousNews : null,
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 24,
                ),

                // 播放/暫停按鈕
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 28,
                ),

                // 下一篇按鈕
                IconButton(
                  onPressed: _currentParagraphIndex < paragraphText.length - 1 ? _nextNews : null,
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

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '地區新聞'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: '事件整理',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}