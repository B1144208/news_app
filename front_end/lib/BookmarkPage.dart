import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'ViewNewsContent.dart';
import 'ChannelDetailPage.dart';
import 'GroupCustomizeBookmark.dart';

class BookmarkPage extends StatefulWidget {
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage> {
  String _selectedCategory = '全部';
  int? _selectedCategoryId;
  bool _showNews = true;
  String _selectedType = 'news';
  bool _isLoading = true;
  int? _currentUserId;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _bookmarkedNews = [];
  List<Map<String, dynamic>> _bookmarkedChannels = [];
  List<Map<String, dynamic>> _bookmarkedEvents = [];

  @override
  void initState() {
    super.initState();
    print('📍 BookmarkPage initState');
    _loadUserIdAndFetchData();
  }

  Future<void> _loadUserIdAndFetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID');

      print('📌 載入用戶ID: $userId');

      setState(() {
        _currentUserId = userId;
      });

      if (_currentUserId != null) {
        await _fetchCategories();
        await _fetchBookmarkedData();
      } else {
        print('⚠️ 用戶未登入');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 載入用戶ID失敗: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCategories() async {
    if (_currentUserId == null) return;

    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/order?userId=$_currentUserId&type=bookmark&dataType=$_selectedType'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          List<dynamic> resultList = data['data'];

          List<Map<String, dynamic>> categories = [];
          for (var item in resultList) {
            categories.add({
              'groupcustomize_id': item['groupcustomize_id'],
              'groupcustomize_name': item['groupcustomize_name'],
            });
          }

          setState(() {
            _categories = categories;
          });
        }
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> _fetchBookmarkedData() async {
    if (_currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _fetchBookmarkedNews(),
        _fetchBookmarkedChannels(),
        _fetchBookmarkedEvents(),
      ]);
    } catch (e) {
      print('Error fetching bookmarked data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ 修正：正確處理後端返回的欄位名稱
  Future<void> _fetchBookmarkedNews() async {
    print('\n📰 ========== 開始獲取收藏新聞 ==========');
    print('📌 當前用戶ID: $_currentUserId');

    if (_currentUserId == null) {
      print('❌ 用戶ID為null,跳過獲取');
      return;
    }

    try {
      final url = '${Config.apiBaseUrl}/user/bookmark/news?userId=$_currentUserId';
      print('📌 請求URL: $url');

      final response = await http.get(Uri.parse(url));
      print('📌 響應狀態碼: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📌 解析結果:');
        print('   - success: ${data['success']}');
        print('   - message: ${data['message']}');
        print('   - data數量: ${data['data']?.length ?? 0}');

        if (data['success'] && data['data'] != null) {
          final newsList = List<Map<String, dynamic>>.from(data['data']);

          // ✅ 關鍵修正：標準化欄位名稱
          final normalizedList = newsList.map((item) {
            print('\n📌 原始數據: $item');

            // 標準化欄位名稱映射
            final normalized = {
              'bookmark_id': item['bookmark_id'],
              // 使用 news_id 作為 id（這是實際的新聞ID）
              'id': item['news_id'] ?? item['id'],
              'title': item['news_title'] ?? item['title'] ?? '',
              'channel': item['channel_name'] ?? item['channel'] ?? '',
              'cover_img': item['cover_image_url'] ?? item['cover_img'] ?? item['coverImageUrl'],
              'publish_date': item['publish_date'] ?? item['publishDate'] ?? '',
              'url': item['origin_url'] ?? item['url'] ?? '',
            };

            print('📌 標準化後: $normalized');
            return normalized;
          }).toList();

          setState(() {
            _bookmarkedNews = normalizedList;
          });
          print('\n✅ 收藏新聞更新成功,數量: ${_bookmarkedNews.length}');
        } else {
          print('⚠️ success為false或data為null');
          setState(() {
            _bookmarkedNews = [];
          });
        }
      } else {
        print('❌ HTTP錯誤: ${response.statusCode}');
        print('   響應內容: ${response.body}');
      }
    } catch (e) {
      print('❌ 異常: $e');
    }
    print('========== 獲取收藏新聞結束 ==========\n');
  }

  Future<void> _fetchBookmarkedChannels() async {
    try {
      final url = '${Config.apiBaseUrl}/user/bookmark/channel?userId=$_currentUserId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _bookmarkedChannels = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      print('Error fetching bookmarked channels: $e');
    }
  }

  Future<void> _fetchBookmarkedEvents() async {
    try {
      final url = '${Config.apiBaseUrl}/user/bookmark/eventsorting?userId=$_currentUserId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _bookmarkedEvents = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error fetching bookmarked events: $e');
      setState(() {
        _bookmarkedEvents = [];
      });
    }
  }

  // ✅ 修正：使用正確的 ID 刪除收藏
  Future<void> _removeBookmark(int itemId, String type) async {
    if (_currentUserId == null) return;

    try {
      String url;
      if (type == 'news') {
        // 使用 bookmark_id 來刪除
        url = '${Config.apiBaseUrl}/user/bookmark/$itemId';
      } else if (type == 'channel') {
        url = '${Config.apiBaseUrl}/user/bookmark/$itemId';
      } else {
        url = '${Config.apiBaseUrl}/user/bookmark/$itemId';
      }

      print('🗑️ 刪除收藏: $url');
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          if (type == 'news') {
            // 使用 bookmark_id 來移除
            _bookmarkedNews.removeWhere((news) => news['bookmark_id'] == itemId);
          } else if (type == 'channel') {
            _bookmarkedChannels.removeWhere((channel) => channel['channel_id'] == itemId);
          } else {
            _bookmarkedEvents.removeWhere((event) => event['id'] == itemId);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已從收藏中移除'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error removing bookmark: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('移除失敗,請稍後再試'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCategorySelectionDialog(int itemId, String type) {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先建立分類'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇分類'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return ListTile(
                title: Text(category['groupcustomize_name'].toString()),
                onTap: () {
                  Navigator.pop(context);
                  _assignToCategory(itemId, type, category['groupcustomize_id']);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignToCategory(int itemId, String type, int categoryId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已移動到分類'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openCategoryManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupCustomizeBookmark(
          userId: _currentUserId!,
          bookmarkType: _selectedType,
        ),
      ),
    );
    _fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildCategoryFilter(),
            _buildToggleSwitch(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingWidget()
                  : _buildContentList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFC9BDFF),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Text(
            '新聞收藏',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.star, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openCategoryManagement,
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('全部', null),
                  if (_categories.isNotEmpty)
                    ..._categories.map((category) {
                      return _buildCategoryChip(
                        category['groupcustomize_name'].toString(),
                        category['groupcustomize_id'],
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, int? categoryId) {
    final isSelected = (categoryId == null && _selectedCategoryId == null) ||
        (categoryId == _selectedCategoryId);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = label;
            _selectedCategoryId = categoryId;
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
                color: Colors.grey,
                spreadRadius: 1,
                blurRadius: 2,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showNews = true;
                  _selectedType = 'news';
                  _selectedCategory = '全部';
                  _selectedCategoryId = null;
                });
                _fetchCategories();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedType == 'news' ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '新聞',
                    style: TextStyle(
                      color: _selectedType == 'news' ? Colors.white : Colors.grey[600],
                      fontWeight: _selectedType == 'news' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showNews = false;
                  _selectedType = 'channel';
                  _selectedCategory = '全部';
                  _selectedCategoryId = null;
                });
                _fetchCategories();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedType == 'channel' ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '頻道',
                    style: TextStyle(
                      color: _selectedType == 'channel' ? Colors.white : Colors.grey[600],
                      fontWeight: _selectedType == 'channel' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showNews = false;
                  _selectedType = 'eventsorting';
                  _selectedCategory = '全部';
                  _selectedCategoryId = null;
                });
                _fetchCategories();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedType == 'eventsorting' ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '事件',
                    style: TextStyle(
                      color: _selectedType == 'eventsorting' ? Colors.white : Colors.grey[600],
                      fontWeight: _selectedType == 'eventsorting' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildContentList() {
    print('🎨 構建內容列表');
    print('   _currentUserId: $_currentUserId');
    print('   _selectedType: $_selectedType');
    print('   _bookmarkedNews長度: ${_bookmarkedNews.length}');
    print('   _bookmarkedChannels長度: ${_bookmarkedChannels.length}');
    print('   _bookmarkedEvents長度: ${_bookmarkedEvents.length}');

    if (_currentUserId == null) {
      return _buildNotLoggedInWidget();
    }

    List<Map<String, dynamic>> currentList;
    if (_selectedType == 'news') {
      currentList = _bookmarkedNews;
    } else if (_selectedType == 'channel') {
      currentList = _bookmarkedChannels;
    } else {
      currentList = _bookmarkedEvents;
    }

    print('   當前顯示列表長度: ${currentList.length}');

    if (currentList.isEmpty) {
      return _buildEmptyWidget();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: currentList.length,
      itemBuilder: (context, index) {
        final item = currentList[index];
        if (_selectedType == 'news') {
          return _buildNewsItem(item);
        } else if (_selectedType == 'channel') {
          return _buildChannelItem(item);
        } else {
          return _buildEventItem(item);
        }
      },
    );
  }

  Widget _buildNotLoggedInWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '請先登入以查看收藏內容',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    IconData icon;
    String message;

    if (_selectedType == 'news') {
      icon = Icons.article_outlined;
      message = '尚未收藏任何新聞';
    } else if (_selectedType == 'channel') {
      icon = Icons.tv_outlined;
      message = '尚未收藏任何頻道';
    } else {
      icon = Icons.event_outlined;
      message = '尚未收藏任何事件';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 修正：確保使用正確的 ID 和欄位
  Widget _buildNewsItem(Map<String, dynamic> news) {
    print('🔍 建立新聞項目: ${news['title']} (id: ${news['id']})');

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
          // ✅ 使用實際的 news_id (存在 'id' 欄位)
          print('👆 點擊新聞: id=${news['id']}, title=${news['title']}');
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
              child: news['cover_img'] != null && news['cover_img'].toString().isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  news['cover_img'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image, color: Colors.grey);
                  },
                ),
              )
                  : const Icon(Icons.image, color: Colors.grey),
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
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onSelected: (value) {
                          if (value == 'category') {
                            _showCategorySelectionDialog(news['bookmark_id'], 'news');
                          } else if (value == 'remove') {
                            // ✅ 使用 bookmark_id 來刪除
                            _removeBookmark(news['bookmark_id'], 'news');
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'category',
                            child: Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('選擇分類'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.bookmark_remove, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('取消收藏', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
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
  }

  Widget _buildChannelItem(Map<String, dynamic> channel) {
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
              builder: (context) => ChannelDetailPage(
                channelId: channel['channel_id'],
                channelName: channel['channel_name'] ?? '未知頻道',
                channelDescription: channel['channel_description'],
                channelUrl: channel['channel_url'],
              ),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.tv,
                color: Colors.blue,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel['channel_name'] ?? '未知頻道',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (channel['channel_description'] != null)
                    Text(
                      channel['channel_description'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '頻道',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onSelected: (value) {
                          if (value == 'category') {
                            _showCategorySelectionDialog(channel['channel_id'], 'channel');
                          } else if (value == 'remove') {
                            _removeBookmark(channel['channel_id'], 'channel');
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'category',
                            child: Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('選擇分類'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.bookmark_remove, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('取消收藏', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
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
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
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
          // TODO: 導航到事件詳細頁面
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.event,
                color: Colors.green,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] ?? event['event_name'] ?? '未知事件',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (event['description'] != null)
                    Text(
                      event['description'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        event['date'] ?? '未知時間',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onSelected: (value) {
                          if (value == 'category') {
                            _showCategorySelectionDialog(event['id'], 'eventsorting');
                          } else if (value == 'remove') {
                            _removeBookmark(event['id'], 'eventsorting');
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'category',
                            child: Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('選擇分類'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.bookmark_remove, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('取消收藏', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
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
  }
}