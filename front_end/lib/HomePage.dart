import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'LoginPage.dart';
import 'AdminPage.dart';
import 'ViewNewsContent.dart';
import 'MapPage.dart';
import 'AIPage.dart';
import 'MemberCenterPage.dart';
import 'SearchPage.dart';
import 'BookmarkPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 1; // 預設選中首頁
  String _selectedCategory = '熱門';
  String _selectedDuration = '15分鐘';
  final TextEditingController _searchController = TextEditingController();

  // 用戶狀態
  bool _isLoggedIn = false;
  String _userAccount = '';
  bool _isAdmin = false;
  bool _isLoading = false;
  String? _error;

  final List<String> _categories = ['熱門', '娛樂', '天氣', '國際', '運動'];
  final List<String> _durations = ['15分鐘', '30分鐘', '45分鐘', '1小時', '一直'];

  // 新聞數據
  List<Map<String, dynamic>> _newsData = [];

  // 快速播放相關變數
  bool _isPlayerVisible = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentNewsIndex = 0;

  // 三個主要頁面
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = [const MapPage(), _buildHomePage(), const AIPage()];
    // 立即檢查登入狀態
    _checkLoginStatus();
    // 獲取新聞數據
    _fetchNews();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 當應用程式回到前台時重新檢查登入狀態
      _checkLoginStatus();
    }
  }

  // 檢查登入狀態方法（來自第一個文件）
  Future<void> _checkLoginStatus() async {
    print('🔍 開始檢查登入狀態...');
    try {
      final prefs = await SharedPreferences.getInstance();

      // 直接讀取 SharedPreferences 中的所有相關資料
      final isLoginStored = prefs.getBool('IsLogin') ?? false;
      final userAccount = prefs.getString('Account') ?? '';
      final userId = prefs.getInt('UserID') ?? 0;
      final isManager = prefs.getInt('IsManager') ?? 0;

      print('=== SharedPreferences 內容 ===');
      print('IsLogin: $isLoginStored');
      print('Account: $userAccount');
      print('UserID: $userId');
      print('IsManager: $isManager');

      // 管理員判斷：IsManager為1 或 帳號以admin開頭
      bool isAdminAccount = userAccount.toLowerCase().startsWith('admin');
      bool isAdmin = isManager == 1 || isAdminAccount;

      print('isAdminAccount: $isAdminAccount');
      print('最終 isAdmin: $isAdmin');
      print('==============================');

      if (mounted) {
        setState(() {
          _isLoggedIn = isLoginStored;
          _userAccount = userAccount;
          _isAdmin = isAdmin;
        });

        print('✅ UI 狀態已更新:');
        print('   _isLoggedIn: $_isLoggedIn');
        print('   _userAccount: $_userAccount');
        print('   _isAdmin: $_isAdmin');
      }
    } catch (e) {
      print('❌ 檢查登入狀態錯誤: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _userAccount = '';
          _isAdmin = false;
        });
      }
    }
  }

  // 手動刷新登入狀態
  void _refreshLoginState() {
    print('🔄 手動刷新登入狀態');
    _checkLoginStatus();
  }

  // 統一用戶行為處理（來自第一個文件）
  void _handleUserAction() {
    print('👆 點擊用戶按鈕');
    print('   當前登入狀態: $_isLoggedIn');
    print('   用戶帳號: $_userAccount');
    print('   是否管理員: $_isAdmin');

    if (!_isLoggedIn) {
      print('   → 導向登入頁面');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      ).then((_) {
        print('   ← 從登入頁面返回，重新檢查狀態');
        _refreshLoginState();
      });
    } else if (_isAdmin) {
      print('   → 導向管理員頁面');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminPage()),
      ).then((_) {
        _refreshLoginState();
      });
    } else {
      print('   → 導向會員中心');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MemberCenterPage()),
      ).then((_) {
        print('   ← 從會員中心返回，重新檢查狀態');
        _refreshLoginState();
      });
    }
  }

  // 獲取新聞資料（來自第二個文件）
  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/news'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> newsList = responseData['data'];

          // 獲取所有相關的頻道和圖片資料
          final channelData = await _fetchChannelData();
          final imageData = await _fetchImageData();

          setState(() {
            _newsData = newsList.map<Map<String, dynamic>>((news) {
              return {
                'id': news['news_id'],
                'title': news['news_title'] ?? '無標題',
                'channel_id': news['channel_id'],
                'channel': channelData[news['channel_id']] ?? '未知頻道',
                'publish_date': _formatDate(news['news_date']),
                'comments': news['total_comment'] ?? 0,
                'cover_img': imageData[news['cover_image']],
                'news_date': news['news_date'],
                'cover_image_id': news['cover_image'],
              };
            }).toList();
            _isLoading = false;
          });
        } else {
          throw Exception(responseData['message'] ?? '獲取新聞失敗');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      setState(() {
        _error = '載入新聞時發生錯誤: $error';
        _isLoading = false;
      });
    }
  }

  // 獲取頻道資料（來自第二個文件）
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

  // 獲取圖片資料（來自第二個文件）
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

  // 格式化日期（來自第二個文件）
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

  // 快速播放功能（來自第二個文件）
  void _startQuickPlay() {
    if (_newsData.isNotEmpty) {
      setState(() {
        _isPlayerVisible = true;
        _isPlaying = true;
        _currentNewsIndex = 0;
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _previousNews() {
    if (_currentNewsIndex > 0) {
      setState(() {
        _currentNewsIndex--;
      });
    }
  }

  void _nextNews() {
    if (_currentNewsIndex < _newsData.length - 1) {
      setState(() {
        _currentNewsIndex++;
      });
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
  }

  void _closePlayer() {
    setState(() {
      _isPlayerVisible = false;
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      body: SafeArea(
        child: Stack(
          children: [
            _pages[_selectedIndex],
            if (_isPlayerVisible) _buildMusicPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // 首頁內容
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

  // 上方工具欄 - 結合兩個文件的設計
  Widget _buildTopToolBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 左側智能按鈕（登入後變頭像）
          if (!_isLoggedIn)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _handleUserAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: const Size(70, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '登入',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _handleUserAction,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors:
                        _isAdmin
                            ? [Colors.red[400]!, Colors.red[600]!]
                            : [Colors.blue[400]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: (_isAdmin ? Colors.red : Colors.blue).withOpacity(
                        0.4,
                      ),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 主要頭像
                    Center(
                      child: Text(
                        _userAccount.isNotEmpty
                            ? _userAccount[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 管理員皇冠圖標
                    if (_isAdmin)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.amber[400],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.5),
                                spreadRadius: 1,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.stars,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(width: 12),

          // 顯示用戶狀態（登入後）
          if (_isLoggedIn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isAdmin ? Colors.red[200]! : Colors.blue[200]!,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: _isAdmin ? Colors.red[600] : Colors.blue[600],
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isAdmin ? '管理員' : '會員',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isAdmin ? Colors.red[700] : Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // 右側收藏按鈕
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BookmarkPage()),
                  );
                },
                child: Icon(
                  Icons.bookmark_outline,
                  color: Colors.grey[600],
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 搜尋欄（整合兩個文件的設計）
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
              color: Colors.grey.withOpacity(0.3),
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
            Text('搜尋', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // 新聞類別篩選
  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.menu, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _categories.map((category) {
                      final isSelected = category == _selectedCategory;
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
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
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 快速播放功能
  Widget _buildQuickPlaySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          const Text(
            '快速播放',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedDuration,
              underline: Container(),
              items:
                  _durations.map((duration) {
                    return DropdownMenuItem<String>(
                      value: duration,
                      child: Text(duration),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDuration = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _startQuickPlay,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  // 新聞列表（整合兩個文件的功能）
  Widget _buildNewsList() {
    print('_buildNewsList called:');
    print('_isLoading: $_isLoading');
    print('_error: $_error');
    print('_newsData.length: ${_newsData.length}');

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
            Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('目前沒有新聞資料', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchNews, child: const Text('重新載入')),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: RefreshIndicator(
        onRefresh: _fetchNews,
        child: ListView.builder(
          itemCount: _newsData.length,
          itemBuilder: (context, index) {
            final news = _newsData[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
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
                        child:
                            news['cover_img'] != null &&
                                news['cover_img'].isNotEmpty
                            ? Image.network(
                                news['cover_img'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.image,
                                    color: Colors.grey,
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

  // 音樂播放器（來自第二個文件）
  Widget _buildMusicPlayer() {
    if (_newsData.isEmpty) return Container();

    final currentNews = _newsData[_currentNewsIndex];

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
              color: Colors.grey.withOpacity(0.3),
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
                  Text(
                    currentNews['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentNews['publish_date'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                  onPressed: _currentNewsIndex < _newsData.length - 1
                      ? _nextNews
                      : null,
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

  // 底部導航欄
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
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
}
