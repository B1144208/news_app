import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
  int? _selectedGroupId; // 新增：選中的分類ID
  String _selectedDuration = '15分鐘';
  String _selectedSortType = '總熱度'; // 新增:排序方式

  List<Map<String, dynamic>> _categories = []; // 改為動態列表
  final List<String> _durations = ['15分鐘', '30分鐘', '45分鐘', '1小時', '一直'];
  final List<String> _sortTypes = ['總熱度', '瀏覽數量', '分享數量', '收藏數量', '留言數量']; // 新增:排序選項

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
  int _currentNewsIndex = 0;

  // 新增:倒數計時相關變數
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // 先載入分類
    _scrollController.addListener(_onScroll); // 新增：監聽滾動事件
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

  // 獲取新聞資料
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
        // 查詢特定分類 - 使用 POST 請求
        print('📡 查詢特定分類新聞 - groupId: $_selectedGroupId');

        response = await http.post(
          Uri.parse('http://localhost:3000/api/news?mode=simple&order=general&limit=300'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'groupId': _selectedGroupId,
            'groupType': 'data',  // ✅ 使用 'data' (news_group 表中的 group_data_id)
          }),
        );

        print('📡 特定分類回應: ${response.statusCode}');
        if (response.statusCode == 200) {
          print('📡 回應內容前200字: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        }
      } else {
        // 查詢所有新聞 - 使用 POST 請求 + 空 body
        print('📡 查詢所有新聞');

        response = await http.post(
          Uri.parse('http://localhost:3000/api/news?mode=simple&order=general&limit=300'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({}),  // ✅ 傳空物件
        );

        print('📡 所有新聞回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // ✅ 修復: 後端返回 {simpleList: [...]} 格式
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

          // ✅ 修復: 使用後端 simple mode 返回的欄位 (camelCase)
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
            // 初始載入前30個新聞
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
        Uri.parse('http://localhost:3000/api/channel'),
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
        Uri.parse('http://localhost:3000/api/image'),
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
  int _parseDurationToSeconds(String duration) {
    if (duration == '一直') return 86400; // 24小時

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
    return 900; // 預設15分鐘
  }

  // 新增：格式化剩餘時間顯示
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

  // 快速播放功能
  void _startQuickPlay() {
    if (_newsData.isNotEmpty) {
      // 初始化倒數計時
      _remainingSeconds = _parseDurationToSeconds(_selectedDuration);

      // 取消現有的計時器
      _countdownTimer?.cancel();

      setState(() {
        _isPlayerVisible = true;
        _isPlaying = true;
        _currentNewsIndex = 0;
      });

      // 啟動倒數計時
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            // 時間到，停止播放
            _closePlayer();
          }
        });
      });
    }
  }

  // 切換播放/暫停
  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      // 恢復倒數計時
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
      // 暫停倒數計時
      _countdownTimer?.cancel();
    }
  }

  // 上一篇新聞
  void _previousNews() {
    if (_currentNewsIndex > 0) {
      setState(() {
        _currentNewsIndex--;
      });
    }
  }

  // 下一篇新聞
  void _nextNews() {
    if (_currentNewsIndex < _newsData.length - 1) {
      setState(() {
        _currentNewsIndex++;
      });
    }
  }

  // 調整播放倍速
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
  }

  // 關閉播放器
  void _closePlayer() {
    _countdownTimer?.cancel();
    setState(() {
      _isPlayerVisible = false;
      _isPlaying = false;
      _remainingSeconds = 0;
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
        _buildSearchBar(),
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

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    ),
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

              const Spacer(),

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
              height: 40, // 固定高度以避免裁切
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
                          _selectedGroupId = groupId; // 設定選中的分類ID
                        });
                        _fetchNews(); // 重新載入該分類的新聞
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

  // 修改後的快速播放區塊
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
          // 左半部：快速播放
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedDuration,
                    underline: Container(),
                    items: _durations.map((duration) {
                      return DropdownMenuItem<String>(
                        value: duration,
                        child: Text(duration, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDuration = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
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

          // 右半部：排序方式
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: RefreshIndicator(
        onRefresh: _fetchNews,
        child: ListView.builder(
          controller: _scrollController,
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
                  onPressed: _currentNewsIndex > 0 ? _previousNews : null,
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
                  onPressed: _currentNewsIndex < _newsData.length - 1 ? _nextNews : null,
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
    _countdownTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}