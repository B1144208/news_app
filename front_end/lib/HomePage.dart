import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
  String _selectedDuration = '5分鐘';
  String _selectedSortType = '總熱度';

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

  // 快速播放相關變數
  bool _isPlayerVisible = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentNewsIndex = 0;

  // 新增：倒數計時相關變數
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  // 🎵 新增：TTS 相關變數
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoadingAudio = false;
  List<String> _customTexts = []; // 儲存自訂文本列表
  int _currentTextIndex = 0; // 當前播放的文本索引
  int _totalTexts = 0; // 總文章篇數

  // 🎤 新增：後台文本輸入控制器
  final TextEditingController _textInputController = TextEditingController();
  final TextEditingController _articleCountController = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _scrollController.addListener(_onScroll);

    // 🎵 監聽音訊播放完成事件
    _audioPlayer.onPlayerComplete.listen((event) {
      _onAudioComplete();
    });
  }

  // 🎵 新增：音訊播放完成後自動播放下一篇
  void _onAudioComplete() {
    print('[TTS] 音訊播放完成');
    if (_isPlaying && _currentTextIndex < _totalTexts - 1) {
      print('[TTS] 自動播放下一篇');
      _nextNews();
    } else {
      print('[TTS] 已播放完所有文章');
      _closePlayer();
    }
  }

  // 🎵 新增：生成自訂文本列表
  void _generateCustomTexts() {
    final count = int.tryParse(_articleCountController.text) ?? 5;
    final baseText = _textInputController.text.isEmpty
        ? '這是測試文本'
        : _textInputController.text;

    _customTexts.clear();
    for (int i = 0; i < count; i++) {
      _customTexts.add('第${i + 1}篇：$baseText');
    }

    _totalTexts = _customTexts.length;
    print('[TTS] 生成 $_totalTexts 篇自訂文本');
  }

  // 🎵 新增：呼叫 TTS API 並播放
  Future<void> _playTextToSpeech(String text) async {
    setState(() {
      _isLoadingAudio = true;
    });

    try {
      print('[TTS] 開始轉換文本: ${text.substring(0, text.length > 30 ? 30 : text.length)}...');

      final response = await http.post(
        Uri.parse('http://localhost:3000/api/tts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'voiceId': 'fQj4gJSexpu8RDE2Ii5m', // YU - Taiwan, conversational
          'stability': 0.5,
          'similarity_boost': 0.75,
          'model_id': 'eleven_multilingual_v2'
        }),
      );

      if (response.statusCode == 200) {
        print('[TTS] 音訊轉換成功，開始播放');

        // 將音訊數據轉換為 base64 URL
        final audioBytes = response.bodyBytes;
        final base64Audio = base64Encode(audioBytes);
        final audioUrl = 'data:audio/mpeg;base64,$base64Audio';

        // 使用 BytesSource 播放音訊
        await _audioPlayer.play(BytesSource(audioBytes));

        setState(() {
          _isLoadingAudio = false;
          _isPlaying = true;
        });
      } else {
        throw Exception('TTS API 錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('[TTS] 錯誤: $error');
      setState(() {
        _isLoadingAudio = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('語音轉換失敗: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID');
      final isLoggedIn = prefs.getBool('IsLogin') ?? false;

      print('🔍 _fetchCategories - 登入狀態: $isLoggedIn, UserID: $userId');

      List<Map<String, dynamic>> categories = [];

      final groupResponse = await http.get(
        Uri.parse('http://localhost:3000/api/group'),
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

      categories.sort((a, b) => (a['group_id'] ?? 0).compareTo(b['group_id'] ?? 0));

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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
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
        endIndex = endIndex > _allNewsData.length ? _allNewsData.length : endIndex;
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
        print('📡 查詢特定分類新聞 - groupId: $_selectedGroupId');

        response = await http.post(
          Uri.parse('http://localhost:3000/api/news/search?mode=simple&order=general&limit=300'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'groupId': _selectedGroupId,
            'groupType': 'data',
          }),
        );

        print('📡 特定分類回應: ${response.statusCode}');
      } else {
        print('📡 查詢所有新聞');

        response = await http.post(
          Uri.parse('http://localhost:3000/api/news/search?mode=simple&order=general&limit=300'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({}),
        );

        print('📡 所有新聞回應: ${response.statusCode}');
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

  int _parseDurationToSeconds(String duration) {
    if (duration == '一直') return 86400;

    final match = RegExp(r'(\d+)(分鐘|小時)').firstMatch(duration);
    if (match != null) {
      final value = int.parse(match.group(1)!);
      final unit = match.group(2);

      if (unit == '分鐘') {
        return value * 60;
      } else if (unit == '小時') {
        return value * 3600;
      }
    }
    return 900;
  }

  String _formatRemainingTime() {
    if (_remainingSeconds <= 0) return '0分鐘';

    final hours = _remainingSeconds ~/ 3600;
    final minutes = (_remainingSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours小時${minutes}分鐘';
    } else {
      return '$minutes分鐘';
    }
  }

  // 🎵 修改：開始快速播放（使用 TTS）
  void _startQuickPlay() {
    // 生成自訂文本列表
    _generateCustomTexts();

    if (_customTexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先設定文本內容'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _remainingSeconds = _parseDurationToSeconds(_selectedDuration);
    _countdownTimer?.cancel();

    setState(() {
      _isPlayerVisible = true;
      _isPlaying = true;
      _currentTextIndex = 0;
    });

    // 🎵 播放第一篇文本
    _playTextToSpeech(_customTexts[_currentTextIndex]);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _closePlayer();
        }
      });
    });
  }

  // 🎵 修改：切換播放/暫停
  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _audioPlayer.resume();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _closePlayer();
          }
        });
      });
    } else {
      _audioPlayer.pause();
      _countdownTimer?.cancel();
    }
  }

  // 🎵 修改：上一篇新聞
  void _previousNews() {
    if (_currentTextIndex > 0) {
      setState(() {
        _currentTextIndex--;
      });
      _audioPlayer.stop();
      _playTextToSpeech(_customTexts[_currentTextIndex]);
    }
  }

  // 🎵 修改：下一篇新聞
  void _nextNews() {
    if (_currentTextIndex < _totalTexts - 1) {
      setState(() {
        _currentTextIndex++;
      });
      _audioPlayer.stop();
      _playTextToSpeech(_customTexts[_currentTextIndex]);
    } else {
      // 已經是最後一篇
      _closePlayer();
    }
  }

  void _adjustPlaybackSpeed() {
    setState(() {
      if (_playbackSpeed == 0.5) {
        _playbackSpeed = 1.0;
      } else if (_playbackSpeed == 1.0) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 0.5;
      }
    });
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  // 🎵 修改：關閉播放器
  void _closePlayer() {
    _countdownTimer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _isPlayerVisible = false;
      _isPlaying = false;
      _remainingSeconds = 0;
      _currentTextIndex = 0;
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
            // 🎤 隱藏的文本輸入區塊（用於調試，實際不顯示）
            _buildHiddenTextInput(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // 🎤 新增：隱藏的文本輸入區塊
  Widget _buildHiddenTextInput() {
    return Positioned(
      top: -1000, // 移到畫面外
      left: 0,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Column(
          children: [
            TextField(
              controller: _textInputController,
              decoration: const InputDecoration(
                labelText: '自訂文本',
                hintText: '輸入要轉換的文本',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _articleCountController,
              decoration: const InputDecoration(
                labelText: '文章篇數',
                hintText: '輸入篇數',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    return Column(
      children: [
        _buildTopToolBar(),
        _buildSearchBar(),
        _buildCategoryFilter(),
        _buildQuickPlaySection(),
        Expanded(child: _buildNewsList()),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    ),
                  ],
                )
              else
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

              const Spacer(),

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
                        spreadRadius: 1,
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

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 10),
            Text(
              '搜尋',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 1,
                    blurRadius: 2,
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
                              color: Colors.grey,
                              spreadRadius: 1,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
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
                    _fetchNews();
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: RefreshIndicator(
        onRefresh: _fetchNews,
        child: ListView.builder(
          controller: _scrollController,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 1,
                    blurRadius: 3,
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

  // 🎵 修改：播放器顯示剩餘篇數
  Widget _buildMusicPlayer() {
    if (_customTexts.isEmpty) return Container();

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
                      const Icon(Icons.flash_on, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '快速播放：剩餘 ${_totalTexts - _currentTextIndex} 篇',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_isLoadingAudio)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '正在轉換語音...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    )
                  else
                    Text(
                      '第 ${_currentTextIndex + 1} 篇',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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

                IconButton(
                  onPressed: _currentTextIndex > 0 ? _previousNews : null,
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 24,
                ),

                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 28,
                ),

                IconButton(
                  onPressed: _currentTextIndex < _totalTexts - 1 ? _nextNews : null,
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
    _countdownTimer?.cancel();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _textInputController.dispose();
    _articleCountController.dispose();
    super.dispose();
  }
}