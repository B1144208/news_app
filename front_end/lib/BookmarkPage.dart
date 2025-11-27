import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  String _selectedCategory = '全部'; // 預設選中"全部"
  int? _selectedCategoryId; // 選中的分類ID (null代表"全部")
  bool _showNews = true; // true: 顯示新聞, false: 顯示頻道
  bool _isLoading = true;
  int? _currentUserId = 1; // TODO: 從登入狀態獲取用戶ID

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _bookmarkedNews = [];
  List<Map<String, dynamic>> _bookmarkedChannels = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchBookmarkedData();
  }

  // 獲取用戶的分類列表
  Future<void> _fetchCategories() async {
    if (_currentUserId == null) return;

    try {
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/bookmark'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': _currentUserId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['result'] != null) {
          List<dynamic> resultList = data['result'];

          // 篩選出當前類型的分類
          String currentType = _showNews ? 'news' : 'channel';
          List<Map<String, dynamic>> categories = [];

          for (var item in resultList) {
            if (item['groupcustomize_type'] == currentType) {
              categories.add({
                'groupcustomize_id': item['groupcustomize_id'],
                'groupcustomize_name': item['groupcustomize_name'],
                'groupcustomize_order': item['groupcustomize_order'],
              });
            }
          }

          // 按照順序排序
          categories.sort((a, b) =>
              (a['groupcustomize_order'] ?? 0).compareTo(b['groupcustomize_order'] ?? 0)
          );

          setState(() {
            _categories = categories;
          });
        }
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  // 獲取收藏的新聞和頻道
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
      ]);
    } catch (e) {
      print('Error fetching bookmarked data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 獲取收藏的新聞
  Future<void> _fetchBookmarkedNews() async {
    // 假設 baseUrl 是在 config.dart 中定義的
    const String baseUrl = 'YOUR_BASE_URL'; // 替換為 config.dart 中的實際變數名，或確保已全局導入
    try {
      final url = '$baseUrl/api/user_action/bookmark/news?userId=$_currentUserId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _bookmarkedNews = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      print('Error fetching bookmarked news: $e');
    }
  }

  // 獲取收藏的頻道
  Future<void> _fetchBookmarkedChannels() async {
    // 假設 baseUrl 是在 config.dart 中定義的
    const String baseUrl = 'YOUR_BASE_URL'; // 替換為 config.dart 中的實際變數名，或確保已全局導入
    try {
      final url = '$baseUrl/api/user_action/bookmark/channel?userId=$_currentUserId';
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

  // 移除收藏
  Future<void> _removeBookmark(int itemId, String type) async {
    if (_currentUserId == null) return;

    // 假設 baseUrl 是在 config.dart 中定義的
    const String baseUrl = 'YOUR_BASE_URL'; // 替換為 config.dart 中的實際變數名，或確保已全局導入
    try {
      final url = type == 'news'
          ? '$baseUrl/api/user_action/delete/bookmark/news/$itemId'
          : '$baseUrl/api/user_action/delete/bookmark/channel/$itemId';

      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          if (type == 'news') {
            _bookmarkedNews.removeWhere((news) => news['id'] == itemId);
          } else {
            _bookmarkedChannels.removeWhere((channel) => channel['channel_id'] == itemId);
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

  // 顯示選擇分類對話框
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

  // 將收藏項目分配到指定分類
  Future<void> _assignToCategory(int itemId, String type, int categoryId) async {
    // 暫時顯示成功訊息
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已移動到分類'),
        backgroundColor: Colors.green,
      ),
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

    // 1. 準備初始分類資料，轉換成 GroupCustomizeBookmark 預期的結構
    final initialCategories = _categories
        .where((c) => c['groupcustomize_id'] != null)
        .toList()
        .map((e) => {
      // GroupCustomizeBookmark 預期接收的鍵名：name 和 order
      'groupcustomize_id': e['groupcustomize_id'] as int?,
      'name': e['groupcustomize_name'] as String?,
      'order': e['groupcustomize_order'] as int?,
    })
        .toList();

    // 2. 導航到 GroupCustomizeBookmark 頁面，傳遞所有必需參數
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupCustomizeBookmark(
          userId: _currentUserId!,
          bookmarkType: _showNews ? 'news' : 'channel',
          initialCategories: initialCategories, // <<< 修正：傳遞缺失的參數
        ),
      ),
    );

    // 3. 返回後重新載入分類
    if (result == true) { // 假設 GroupCustomizeBookmark 返回 true 表示有變更
      _fetchCategories();
    }
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

  // 自定義AppBar
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

  // 類別篩選器
  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 三條線圖標按鈕 - 打開分類管理頁面
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
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // "全部" 分類 - 永遠顯示
                  _buildCategoryChip('全部', null),
                  // 用戶自定義分類 - 只在有分類時顯示
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

  // 分類標籤
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

  // 新聞/頻道切換開關
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
                setState(() {
                  _showNews = true;
                  _selectedCategory = '全部';
                  _selectedCategoryId = null;
                });
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
                setState(() {
                  _showNews = false;
                  _selectedCategory = '全部';
                  _selectedCategoryId = null;
                });
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

  // 載入中指示器
  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // 內容列表
  Widget _buildContentList() {
    if (_currentUserId == null) {
      return _buildNotLoggedInWidget();
    }

    final currentList = _showNews ? _bookmarkedNews : _bookmarkedChannels;

    if (currentList.isEmpty) {
      return _buildEmptyWidget();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: currentList.length,
      itemBuilder: (context, index) {
        final item = currentList[index];
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

  // 新聞項目
  Widget _buildNewsItem(Map<String, dynamic> news) {
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
              child: news['cover_img'] != null
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
                      // 三個點選單
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onSelected: (value) {
                          if (value == 'category') {
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