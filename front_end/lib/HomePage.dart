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
  int? _selectedGroupId;
  String _selectedSortType = '總熱度';

  // 側邊欄相關
  bool _isSidebarExpanded = true;
  static const double SIDEBAR_EXPANDED_WIDTH = 180;
  static const double SIDEBAR_COLLAPSED_WIDTH = 0;

  List<Map<String, dynamic>> _categories = [];
  final List<String> _sortTypes = ['總熱度', '瀏覽數量', '分享數量', '收藏數量', '留言數量'];

  List<Map<String, dynamic>> _newsData = [];
  List<Map<String, dynamic>> _allNewsData = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 0;
  final int _newsPerPage = 30;
  final ScrollController _scrollController = ScrollController();

  bool _isPlayerVisible = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  int paragraphCount = 6;
  List<String> paragraphText = [
    "開始為您播放今日焦點新聞，第一篇是快新聞，北市中正一警局下通牒　黃國昌明天未到案就送北檢偵辦。",
    "第二篇是快新聞／好可怕！台南警匪追逐戰　歹徒持榔頭攻擊員警、所長被咬傷。",
    "第三篇是青少年受情緒困擾 兒盟調查：逾2成想過輕生。",
    "第四篇是喝咖啡讓人更長壽？　營養師：每天3至5杯效果最佳。",
    "第五篇是腸病毒重症已奪8命！伊科11型來勢洶洶　疾管署：幼童是高風險族群。",
    "接下來是各篇新聞的大致內容：「走讀活動」引發警方與民眾對峙，8名警員受傷，而主嫌黃國昌涉嫌違反《集會遊行法》及《聚眾妨害公務法》。台北市警局已通知黃國昌明早到案說服，如果他不來將送北檢處理。",
  ];
  int _currentParagraphIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _scrollController.addListener(_onScroll);

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

  Future<void> _fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID');
      final isLoggedIn = prefs.getBool('IsLogin') ?? false;

      print('🔍 _fetchCategories - 登入狀態: $isLoggedIn, UserID: $userId');

      List<Map<String, dynamic>> categories = [];

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

      categories.sort(
        (a, b) => (a['group_id'] ?? 0).compareTo(b['group_id'] ?? 0),
      );

      print('✅ 最終分類數量: ${categories.length}');
      print('✅ 分類 IDs: $addedGroupIds');

      setState(() {
        _categories = [
          {'group_id': null, 'group_name': '全部'},
          ...categories,
        ];
      });

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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore && _allNewsData.isNotEmpty) {
        _loadMoreNews();
      }
    }
  }

  Future<void> _loadMoreNews() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      if (_newsData.length >= 60) {
        _newsData.removeRange(0, 30);
        _currentPage++;
      }

      int startIndex = (_currentPage + 1) * _newsPerPage;
      int endIndex = startIndex + _newsPerPage;

      if (startIndex < _allNewsData.length) {
        endIndex =
            endIndex > _allNewsData.length ? _allNewsData.length : endIndex;
        _newsData.addAll(_allNewsData.sublist(startIndex, endIndex));
        _currentPage++;
      }

      _isLoadingMore = false;
    });
  }

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
        print('🔡 查詢特定分類新聞 - groupId: $_selectedGroupId');

        response = await http.post(
          Uri.parse(
            '${Config.apiBaseUrl}/news/search?mode=simple&order=general&limit=300',
          ),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'groupId': _selectedGroupId, 'groupType': 'data'}),
        );

        print('🔡 特定分類回應: ${response.statusCode}');
      } else {
        print('🔡 查詢所有新聞');

        response = await http.post(
          Uri.parse(
            '${Config.apiBaseUrl}/news/search?mode=simple&order=general&limit=300',
          ),
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

          List<Map<String, dynamic>> processedNews =
              newsList.map<Map<String, dynamic>>((news) {
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

  void _sortNews(List<Map<String, dynamic>> newsList) {
    switch (_selectedSortType) {
      case '瀏覽數量':
        newsList.sort(
          (a, b) => (b['views'] as int).compareTo(a['views'] as int),
        );
        break;
      case '分享數量':
        newsList.sort(
          (a, b) => (b['shares'] as int).compareTo(a['shares'] as int),
        );
        break;
      case '收藏數量':
        newsList.sort(
          (a, b) => (b['bookmarks'] as int).compareTo(a['bookmarks'] as int),
        );
        break;
      case '留言數量':
        newsList.sort(
          (a, b) => (b['comments'] as int).compareTo(a['comments'] as int),
        );
        break;
      case '總熱度':
      default:
        newsList.sort((a, b) {
          int heatA =
              (a['views'] as int) +
              (a['shares'] as int) * 2 +
              (a['bookmarks'] as int) * 3 +
              (a['comments'] as int) * 2;
          int heatB =
              (b['views'] as int) +
              (b['shares'] as int) * 2 +
              (b['bookmarks'] as int) * 3 +
              (b['comments'] as int) * 2;
          return heatB.compareTo(heatA);
        });
        break;
    }
  }

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
            channelMap[channel['channel_id']] =
                channel['channel_name'] ?? '未知頻道';
          }
          return channelMap;
        }
      }
    } catch (error) {
      print('獲取頻道資料失敗: $error');
    }
    return {};
  }

  Future<Map<int, String>> _fetchImageData() async {
    try {
      final response = await http.get(Uri.parse('${Config.apiBaseUrl}/image'));

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

  Future<Map<String, dynamic>> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'account': prefs.getString('Account') ?? '',
      'isAdmin': (prefs.getInt('UserLevel') ?? 0) >= 5,
    };
  }

  String _formatRemainingTime() {
    int remaining = paragraphCount - _currentParagraphIndex;
    return '$remaining 篇';
  }

  Future<void> _startQuickPlay() async {
    if (paragraphText.isEmpty || paragraphCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('沒有可播放的文本')));
      return;
    }

    setState(() {
      _isPlayerVisible = true;
      _currentParagraphIndex = 0;
    });

    await _playCurrentParagraph();
  }

  Future<void> _playCurrentParagraph() async {
    if (_currentParagraphIndex >= paragraphText.length) {
      _closePlayer();
      return;
    }

    try {
      String currentText = paragraphText[_currentParagraphIndex];

      print(
        '🎵 準備播放第 ${_currentParagraphIndex + 1} 篇文章: ${currentText.substring(0, currentText.length > 50 ? 50 : currentText.length)}...',
      );

      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/tts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': currentText,
          'voiceId': '9lHjugDhwqoxA5MhX0az',
          'stability': 0.5,
          'similarity_boost': 0.75,
        }),
      );

      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;

        print('✅ 收到音訊數據: ${bytes.length} bytes');

        await _audioPlayer.stop();

        final String base64Audio = base64Encode(bytes);
        final String dataUrl = 'data:audio/mpeg;base64,$base64Audio';

        print('🔄 轉換為 data URL, 長度: ${dataUrl.length}');

        await _audioPlayer.setPlaybackRate(_playbackSpeed);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('播放錯誤: $e')));
      }
    }
  }

  void _onAudioComplete() {
    print('✅ 第 ${_currentParagraphIndex + 1} 篇播放完成');

    if (_currentParagraphIndex < paragraphText.length - 1) {
      setState(() {
        _currentParagraphIndex++;
      });
      _playCurrentParagraph();
    } else {
      _closePlayer();
    }
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

  Future<void> _previousNews() async {
    if (_currentParagraphIndex > 0) {
      setState(() {
        _currentParagraphIndex--;
      });
      await _playCurrentParagraph();
    }
  }

  Future<void> _nextNews() async {
    if (_currentParagraphIndex < paragraphText.length - 1) {
      setState(() {
        _currentParagraphIndex++;
      });
      await _playCurrentParagraph();
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
      _currentParagraphIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const MapPage(),
      _buildHomePageWithSidebar(),
      const AIPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
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

  Widget _buildHomePageWithSidebar() {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width:
              _isSidebarExpanded
                  ? SIDEBAR_EXPANDED_WIDTH
                  : SIDEBAR_COLLAPSED_WIDTH,
          child:
              _isSidebarExpanded
                  ? _buildLeftSidebar()
                  : const SizedBox.shrink(),
        ),
        Expanded(
          child: Column(
            children: [
              _buildTopToolBar(),
              _buildQuickPlaySection(),
              Expanded(child: _buildNewsList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0a0e27),
        border: Border(
          right: BorderSide(
            color: const Color(0xFF6366f1).withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('UserID');
              final isLoggedIn = prefs.getBool('IsLogin') ?? false;

              if (!isLoggedIn || userId == null) {
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

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupCustomizePage(userId: userId),
                ),
              );

              if (result == true || result == null) {
                _fetchCategories();
              }
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366f1).withOpacity(0.25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF6366f1).withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, size: 12, color: Color(0xFF60a5fa)),
                  SizedBox(width: 4),
                  Text(
                    '自訂',
                    style: TextStyle(
                      color: Color(0xFF60a5fa),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF6366f1).withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                _categories.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 40,
                            color: const Color(0xFF94a3b8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '暫無分類',
                            style: TextStyle(
                              color: const Color(0xFF94a3b8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final categoryName = category['group_name'] ?? '未命名';
                        final groupId = category['group_id'];
                        final isSelected = _selectedCategory == categoryName;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = categoryName;
                              _selectedGroupId = groupId;
                            });
                            _fetchNews();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? const Color(0xFF6366f1)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border(
                                left: BorderSide(
                                  color:
                                      isSelected
                                          ? const Color(0xFF60a5fa)
                                          : const Color.fromARGB(
                                            255,
                                            70,
                                            72,
                                            188,
                                          ).withOpacity(0.3),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                color: const Color.fromARGB(255, 106, 144, 232),
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopToolBar() {
    return FutureBuilder<bool>(
      future: SharedPreferences.getInstance().then(
        (prefs) => prefs.getBool('IsLogin') ?? false,
      ),
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.data ?? false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0a1428),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF6366f1).withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (!isLoggedIn)
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
                          setState(() {});
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366f1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(50, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('登入', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupPage(),
                          ),
                        ).then((_) {
                          setState(() {});
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF60a5fa),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(50, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('註冊', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                )
              else
                FutureBuilder<Map<String, dynamic>>(
                  future: _getUserInfo(),
                  builder: (context, userSnapshot) {
                    final userAccount = userSnapshot.data?['account'] ?? '';
                    final isAdmin = userSnapshot.data?['isAdmin'] ?? false;

                    return GestureDetector(
                      onTap: () {
                        if (isAdmin) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminPage(),
                            ),
                          ).then((_) => setState(() {}));
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MemberCenterPage(),
                            ),
                          ).then((_) => setState(() {}));
                        }
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              isAdmin
                                  ? const Color(0xFF9333ea)
                                  : const Color(0xFF6366f1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1a2a4e),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            userAccount.isNotEmpty
                                ? userAccount[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: const Color(0xFF1a2a4e),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(width: 12),

              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchPage(),
                      ),
                    );
                  },
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a2a4e),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF6366f1).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, size: 16, color: Color(0xFF94a3b8)),
                        SizedBox(width: 8),
                        Text(
                          '搜尋新聞、事件...',
                          style: TextStyle(
                            color: Color(0xFF94a3b8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              IconButton(
                icon: const Icon(
                  Icons.bookmark_border,
                  color: Color(0xFF60a5fa),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookmarkPage(),
                    ),
                  );
                },
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
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
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('UserID');
              final isLoggedIn = prefs.getBool('IsLogin') ?? false;

              print('🔍 點擊自訂按鈕 - 登入狀態: $isLoggedIn, UserID: $userId');

              if (!isLoggedIn || userId == null) {
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

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupCustomizePage(userId: userId),
                ),
              );

              if (result == true || result == null) {
                print('🔄 從自訂頁面返回,重新載入分類');
                _fetchCategories();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2a4e),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFe5e7eb),
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
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final categoryName = category['group_name'] ?? '未命名';
                  final groupId = category['group_id'];
                  final isSelected = _selectedCategory == categoryName;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
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
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFe5e7eb),
                              spreadRadius: 0,
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : const Color(0xFF9ca3af),
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildQuickPlaySection() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0a1428),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366f1).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSidebarExpanded = !_isSidebarExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366f1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF60a5fa).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _isSidebarExpanded ? Icons.menu_open : Icons.menu,
                    size: 14,
                    color: const Color(0xFF60a5fa),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.rocket_launch,
                      color: Color(0xFF60a5fa),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '快速播放',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color.fromARGB(255, 112, 146, 224),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isPlayerVisible = !_isPlayerVisible;
                          if (_isPlayerVisible && !_isPlaying) {
                            _startQuickPlay();
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF60a5fa),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 0,
                      ),
                      child: const Text('播放', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              Row(
                children: [
                  const Icon(Icons.sort, color: Color(0xFF60a5fa), size: 16),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF6366f1).withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedSortType,
                      underline: Container(),
                      dropdownColor: const Color(0xFF0f1f3d),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 111, 146, 229),
                        fontSize: 12,
                      ),
                      items:
                          _sortTypes.map((sortType) {
                            return DropdownMenuItem<String>(
                              value: sortType,
                              child: Text(
                                sortType,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSortType = value!;
                        });
                        _fetchNews();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(height: 1, color: const Color(0xFF6366f1).withOpacity(0.15)),
      ],
    );
  }

  Widget _buildNewsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: const Color(0xFFe5e7eb)),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: const Color(0xFFe5e7eb)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchNews, child: const Text('重新載入')),
          ],
        ),
      );
    }

    if (_newsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: const Color(0xFFe5e7eb),
            ),
            const SizedBox(height: 16),
            Text('目前沒有新聞資料', style: TextStyle(color: const Color(0xFFe5e7eb))),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchNews, child: const Text('重新載入')),
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
                color: const Color(0xFF1a2a4e),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366f1).withOpacity(0.2),
                  width: 1,
                ),
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
                        color: const Color(0xFF3b82f6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            news['cover_img'] != null &&
                                    news['cover_img'].isNotEmpty
                                ? Image.network(
                                  news['cover_img'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.image,
                                      color: const Color(0xFFe5e7eb),
                                    );
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
                            style: const TextStyle(
                              color: const Color(0xFFd1d5db),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            news['title'] ?? '無標題',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF1a2a4e),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                news['publish_date'] ?? '未知時間',
                                style: const TextStyle(
                                  color: const Color(0xFFd1d5db),
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chat_bubble_outline,
                                color: const Color(0xFFe5e7eb),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${news['comments'] ?? 0}',
                                style: const TextStyle(
                                  color: const Color(0xFFd1d5db),
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

  Widget _buildMusicPlayer() {
    if (_newsData.isEmpty) return Container();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a2a4e),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFe5e7eb),
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
                      const Icon(
                        Icons.flash_on,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '快速播放：剩餘${_formatRemainingTime()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _adjustPlaybackSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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

                IconButton(
                  onPressed: _currentParagraphIndex > 0 ? _previousNews : null,
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 24,
                ),

                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 28,
                ),

                IconButton(
                  onPressed:
                      _currentParagraphIndex < paragraphText.length - 1
                          ? _nextNews
                          : null,
                  icon: const Icon(Icons.skip_next),
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

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a2a4e),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF6366f1).withOpacity(0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.15),
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
        selectedItemColor: const Color(0xFF60a5fa),
        unselectedItemColor: Colors.grey[400],
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
