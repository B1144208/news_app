import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart'; // 確保此處導入，且 config.dart 中有頂層變數 baseUrl
import 'ViewNewsContent.dart';
import 'ChannelDetailPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'GroupCustomizeBookmark.dart'; // 確保這個導入存在，用於管理分類頁面

// -------------------------------------------------------------
// BookmarkPage - 收藏頁面主體
// -------------------------------------------------------------
class BookmarkPage extends StatefulWidget {
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage> {

  String _selectedCategory = '全部';
  int? _selectedCategoryId;
  bool _showNews = true;
  bool _isLoading = true;
  int? _currentUserId; // 從 SharedPreferences 載入

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _bookmarkedNews = [];
  List<Map<String, dynamic>> _bookmarkedChannels = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 確保 UserID 載入後才執行 API 請求
  Future<void> _initData() async {
    await _loadUserId();

    if (!mounted) return;

    if (_currentUserId != null) {
      await _fetchCategories();
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      await _fetchBookmarkedData();
    } else {
      print('DEBUG: UserID is NULL. Skipping API calls.');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    // 假設您在應用程式其他地方使用 'UserID' 作為 key 儲存 ID
    final userId = prefs.getInt('UserID');

    if (mounted) {
      setState(() {
        _currentUserId = userId;
        print('DEBUG: BookmarkPage - Loaded UserID: $_currentUserId');
      });
    }
  }

  // 獲取用戶的分類列表
  Future<void> _fetchCategories() async {
    if (_currentUserId == null) return;

    String currentType = _showNews ? 'news' : 'channel';

    try {
      // 使用用戶提供的成功 URL 結構
      final uri = Uri.parse('$baseUrl/groupcustomize/order').replace(
        queryParameters: {
          'userId': _currentUserId.toString(),
          'type': 'bookmark',
          'dataType': currentType,
        },
      );

      final response = await http.get(uri);
      print('DEBUG: Categories API URL: $uri');
      print('DEBUG: Categories API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 🎯 修正點: 使用 'data' 鍵來解析分類列表
        if (data['success'] == true && data['data'] != null) {
          List<dynamic> resultList = data['data'];

          List<Map<String, dynamic>> categories = [];

          // 1. 添加 '全部'
          categories.add({
            'groupcustomize_id': null,
            'groupcustomize_name': '全部',
            'groupcustomize_order': -1,
          });

          // 2. 添加實際分類
          for (var item in resultList) {
            categories.add({
              'groupcustomize_id': item['groupcustomize_id'],
              'groupcustomize_name': item['groupcustomize_name'],
              'groupcustomize_order': item['groupcustomize_order'] ?? 0,
            });
          }

          // 排序
          categories.sort((a, b) =>
              (a['groupcustomize_order'] ?? 0).compareTo(b['groupcustomize_order'] ?? 0)
          );

          if (mounted) {
            setState(() {
              _categories = categories;
              print('DEBUG: Categories Loaded Count: ${_categories.length}');

              if (_selectedCategoryId != null && !_categories.any((cat) => cat['groupcustomize_id'] == _selectedCategoryId)) {
                _selectedCategory = '全部';
                _selectedCategoryId = null;
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  // 獲取收藏的新聞和頻道
  Future<void> _fetchBookmarkedData() async {
    if (_currentUserId == null) return;
    try {
      await Future.wait([
        _fetchBookmarkedNews(),
        _fetchBookmarkedChannels(),
      ]);
    } catch (e) {
      print('Error fetching bookmarked data: $e');
    }
  }

  // 獲取收藏的新聞 (GET)
  Future<void> _fetchBookmarkedNews() async {
    if (_currentUserId == null) return;
    try {
      final url = '$baseUrl/user/bookmark/news?userId=$_currentUserId';
      final response = await http.get(Uri.parse(url));
      print('DEBUG: News Bookmark URL: $url');
      print('DEBUG: News Bookmark Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && mounted) {
          // 修正點: 同時檢查 'data' 和 'result' 鍵，以提高容錯性
          final fetchedList = List<Map<String, dynamic>>.from(data['data'] ?? data['result'] ?? []);
          print('DEBUG: News Bookmarks Fetched Count: ${fetchedList.length}');
          setState(() {
            _bookmarkedNews = fetchedList;
          });
        }
      }
    } catch (e) {
      print('Error fetching bookmarked news: $e');
    }
  }

  // 獲取收藏的頻道 (GET)
  Future<void> _fetchBookmarkedChannels() async {
    if (_currentUserId == null) return;
    try {
      final url = '$baseUrl/user/bookmark/channel?userId=$_currentUserId';
      final response = await http.get(Uri.parse(url));
      print('DEBUG: Channel Bookmark URL: $url');
      print('DEBUG: Channel Bookmark Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && mounted) {
          // 修正點: 同時檢查 'data' 和 'result' 鍵，以提高容錯性
          final fetchedList = List<Map<String, dynamic>>.from(data['data'] ?? data['result'] ?? []);
          print('DEBUG: Channel Bookmarks Fetched Count: ${fetchedList.length}');
          setState(() {
            _bookmarkedChannels = fetchedList;
          });
        }
      }
    } catch (e) {
      print('Error fetching bookmarked channels: $e');
    }
  }

  // 移除收藏 (DELETE)
  Future<void> _removeBookmark(int itemId, String type) async {
    if (_currentUserId == null) return;

    try {
      // 修正路徑: /user/delete/bookmark/:targetId
      final url = '$baseUrl/user/delete/bookmark/$itemId';

      final response = await http.delete(Uri.parse(url));
      print('DEBUG: Remove Bookmark URL: $url');

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            if (type == 'news') {
              _bookmarkedNews.removeWhere((news) => news['id'] == itemId);
            } else {
              _bookmarkedChannels.removeWhere((channel) => channel['channel_id'] == itemId);
            }
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已從收藏中移除'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        print('DEBUG: Remove Bookmark Failed Status: ${response.statusCode}');
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

  // 實際將收藏項目分配到指定分類
  Future<void> _assignToCategory(int itemId, String type, int categoryId) async {
    final url = Uri.parse('$baseUrl/groupcustomize/bookmark');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': _currentUserId,
          'groupId': categoryId,
          'dataType': type,
          'itemId': itemId,
        }),
      );

      if (response.statusCode == 200 && json.decode(response.body)['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已成功移動到分類'), backgroundColor: Colors.green),
        );
        // 成功後建議重新載入數據
        _fetchBookmarkedData();
      } else {
        throw Exception(json.decode(response.body)['message'] ?? '移動失敗');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移動失敗: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 🎯 修正點: 顯示分類選擇對話框的方法
  Future<void> _showCategorySelectionDialog(int itemId, String type) async {
    final availableCategories = _categories.where((c) => c['groupcustomize_id'] != null).toList();

    if (availableCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先新增分類'), backgroundColor: Colors.orange),
      );
      return;
    }

    int? selectedId;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('將${type == 'news' ? '新聞' : '頻道'}移動到...'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: availableCategories.map((category) {
                    final id = category['groupcustomize_id'] as int;
                    final name = category['groupcustomize_name'] as String;
                    return RadioListTile<int>(
                      title: Text(name),
                      value: id,
                      groupValue: selectedId,
                      onChanged: (int? value) {
                        setState(() {
                          selectedId = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('確定'),
              onPressed: () {
                if (selectedId != null) {
                  _assignToCategory(itemId, type, selectedId!);
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 打開分類管理頁面
  Future<void> _openCategoryManagement() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能管理分類'), backgroundColor: Colors.red),
      );
      return;
    }

    final initialCategories = _categories
        .where((c) => c['groupcustomize_id'] != null)
        .map((e) => {
      'groupcustomize_id': e['groupcustomize_id'] as int?,
      'name': e['groupcustomize_name'] as String?,
      'order': e['groupcustomize_order'] as int?,
    }).toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupCustomizeBookmark(
          userId: _currentUserId!,
          bookmarkType: _showNews ? 'news' : 'channel',
          initialCategories: initialCategories,
        ),
      ),
    );

    if (result == true) {
      _fetchCategories();
    }
  }

  // ----------------------------------------------------------------------
  // BUILD METHODS
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            // 只有當載入完成且分類列表數量大於 1 時才顯示分類篩選器 (1個是'全部')
            if (!_isLoading && _categories.length > 1) _buildCategoryFilter(),
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

  // 🎯 修正點: _buildAppBar 方法
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

  // 🎯 修正點: _buildCategoryFilter 方法
  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 管理按鈕
          GestureDetector(
            onTap: _openCategoryManagement,
            child: Container(
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
          ),
          const SizedBox(width: 12),
          // 分類標籤列表
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._categories.map((category) {
                    return _buildCategoryChip(
                      category['groupcustomize_name'].toString(),
                      category['groupcustomize_id'] as int?,
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

  // 分類標籤
  Widget _buildCategoryChip(String label, int? categoryId) {
    final isSelected = (categoryId == null && _selectedCategoryId == null) ||
        (categoryId == _selectedCategoryId);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          if (mounted) {
            setState(() {
              _selectedCategory = label;
              _selectedCategoryId = categoryId;
            });
          }
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

  // 🎯 修正點: _buildToggleSwitch 方法
  Widget _buildToggleSwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
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
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (mounted) {
                  setState(() {
                    _showNews = true;
                    _selectedCategory = '全部';
                    _selectedCategoryId = null;
                  });
                }
                _fetchCategories();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _showNews ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '新聞',
                    style: TextStyle(
                      color: _showNews ? Colors.white : Colors.grey[600],
                      fontWeight: _showNews ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (mounted) {
                  setState(() {
                    _showNews = false;
                    _selectedCategory = '全部';
                    _selectedCategoryId = null;
                  });
                }
                _fetchCategories();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_showNews ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '頻道',
                    style: TextStyle(
                      color: !_showNews ? Colors.white : Colors.grey[600],
                      fontWeight: !_showNews ? FontWeight.bold : FontWeight.normal,
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

  // 🎯 修正點: _buildLoadingWidget 方法
  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // 🎯 修正點: 實作分類過濾邏輯
  Widget _buildContentList() {
    if (_currentUserId == null) {
      return _buildNotLoggedInWidget();
    }

    final allItems = _showNews ? _bookmarkedNews : _bookmarkedChannels;

    // 實作分類篩選邏輯
    final filteredList = allItems.where((item) {
      // 1. 如果選擇了 "全部" (ID為 null)，則顯示所有項目
      if (_selectedCategoryId == null) {
        return true;
      }

      // 2. 篩選出 category ID 匹配的項目
      // 假設書籤項目中包含 'groupcustomize_id' 字段
      final itemCategoryId = item['groupcustomize_id'];

      // 項目必須有 ID 且其 ID 必須等於選中的 ID
      // item['groupcustomize_id'] 應該是您在後端查詢收藏時，JOIN 該項目所屬分類的 ID
      return itemCategoryId != null && itemCategoryId == _selectedCategoryId;

    }).toList();


    if (filteredList.isEmpty) {
      return _buildEmptyWidget();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final item = filteredList[index];
        return _showNews
            ? _buildNewsItem(item)
            : _buildChannelItem(item);
      },
    );
  }

  // 未登入狀態
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

  // 空狀態
  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showNews ? Icons.article_outlined : Icons.tv_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _showNews ? '尚未收藏任何新聞' : '尚未收藏任何頻道',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // News 項目樣式
  Widget _buildNewsItem(Map<String, dynamic> news) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // 導航到新聞內容頁面
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
            // 封面圖片
            Container(
              width: 90,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: news['cover_img'] != null && news['cover_img'].isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  news['cover_img'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 30));
                  },
                ),
              )
                  : const Center(child: Icon(Icons.article, color: Colors.grey, size: 30)),
            ),
            const SizedBox(width: 12),
            // 標題與資訊
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題
                  Text(
                    news['title'] ?? '無標題',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // 頻道、日期與選單
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${news['channel'] ?? '未知頻道'} • ${news['publish_date'] ?? '未知時間'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      // 三個點選單
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onSelected: (value) {
                          if (value == 'category') {
                            // 假設 news['id'] 是新聞的唯一ID
                            _showCategorySelectionDialog(news['id'], 'news');
                          } else if (value == 'remove') {
                            _removeBookmark(news['id'], 'news');
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

  // 頻道項目
  Widget _buildChannelItem(Map<String, dynamic> channel) {
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
                      // 三個點選單
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
}