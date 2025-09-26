import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'LoginPage.dart';
import 'AdminPage.dart';
import 'ViewNewsContent.dart';
import 'MapPage.dart';
import 'AIPage.dart';
import 'SearchPage.dart';
import 'BookmarkPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;
  String _selectedCategory = '熱門';
  String _selectedDuration = '15分鐘';

  final List<String> _categories = ['熱門', '娛樂', '天氣', '國際', '運動'];
  final List<String> _durations = ['15分鐘', '30分鐘', '45分鐘', '1小時'];

  List<Map<String, dynamic>> _newsData = [];
  Map<int, String> _channelNames = {}; // 存儲頻道名稱
  Map<int, String> _imageUrls = {}; // 存儲圖片URL
  bool _isLoading = false;
  String? _error;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const MapPage(),
      _buildHomePage(),
      const AIPage(),
    ];
    _initializeData();
  }

  // 初始化數據 - 依序獲取所有必要的資料
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. 先獲取頻道資料
      await _fetchChannels();
      // 2. 獲取圖片資料
      await _fetchImages();
      // 3. 最後獲取新聞資料
      await _fetchNews();
    } catch (error) {
      setState(() {
        _error = '載入資料時發生錯誤: $error';
        _isLoading = false;
      });
    }
  }

  // 獲取頻道資料
  Future<void> _fetchChannels() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/channel'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> channels = responseData['data'];
          for (var channel in channels) {
            _channelNames[channel['channel_id']] = channel['channel_name'] ?? '未知頻道';
          }
        }
      }
    } catch (error) {
      print('獲取頻道資料失敗: $error');
    }
  }

  // 獲取圖片資料
  Future<void> _fetchImages() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/image'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> images = responseData['data'];
          for (var image in images) {
            _imageUrls[image['image_id']] = image['image_origin_url'] ?? '';
          }
        }
      }
    } catch (error) {
      print('獲取圖片資料失敗: $error');
    }
  }

  // 獲取新聞資料
  Future<void> _fetchNews() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/news'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> newsList = responseData['data'];

          setState(() {
            _newsData = newsList.map<Map<String, dynamic>>((news) {
              return {
                'id': news['news_id'],
                'title': news['news_title'] ?? '無標題',
                'channel': _channelNames[news['channel_id']] ?? '未知頻道',
                'publish_date': _formatDate(news['news_date']),
                'comments': news['total_comment'] ?? 0,
                'cover_img': _imageUrls[news['cover_image']],
                // 保留原始資料供詳情頁使用
                'channel_id': news['channel_id'],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      body: SafeArea(
        child: _pages[_selectedIndex],
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
        _buildQuickPlaySection(),
        Expanded(child: _buildNewsList()),
      ],
    );
  }

  Widget _buildTopToolBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
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
                    MaterialPageRoute(builder: (context) => const AdminPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(80, 32),
                ),
                child: const Text('管理員', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          const Spacer(),

          // 收藏按鈕
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookmarkPage()),
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
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.bookmark, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
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
                children: _categories.map((category) {
                  final isSelected = category == _selectedCategory;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                        // TODO: 實現分類篩選功能
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
                            isSelected ? FontWeight.bold : FontWeight.normal,
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
              items: _durations.map((duration) {
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
            onPressed: () {
              // TODO: 實現快速播放功能
            },
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
              onPressed: _initializeData,
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
              onPressed: _initializeData,
              child: const Text('重新載入'),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: RefreshIndicator(
        onRefresh: _initializeData,
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
                            news['channel'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            news['title'],
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
                                news['publish_date'],
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
                                '${news['comments']}',
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

  @override
  void dispose() {
    super.dispose();
  }
}