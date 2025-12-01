// SearchPage.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// 確保導入了所有需要的檔案
import 'ChannelDetailPage.dart';
import 'EventSortingDetailPage.dart';
import 'MultiplePerspectivesDetailPage.dart';
import 'ViewNewsContent.dart';
import 'config.dart'; // 包含 baseUrl

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _isHistoryAndPopularLoading = false;

  int? _currentRecordId;
  // 🌟 修正：將初始值設為 null，模擬未登入狀態，歷史紀錄將隱藏。
  // (若要測試登入狀態，請設為 int? _currentUserId = 1;)
  int? _currentUserId = null;

  Timer? _debounceTimer;

  // 狀態變數：追蹤當前的篩選類型
  String _currentFilter = 'all'; // 預設為 'all'

  final String _generalSearchUrl = '$baseUrl/search';
  final String _userSearchClickUrl = '$baseUrl/user/search/click';
  final String _searchHistoryUrl = '$baseUrl/search/history';
  final String _popularSearchUrl = '$baseUrl/search/popular';

  List<Map<String, dynamic>> _currentHistory = [];
  List<String> _popularSearches = [];

  // 篩選按鈕對應的資訊
  final List<Map<String, String>> _filters = const [
    {'label': '全部', 'type': 'all'},
    {'label': '新聞', 'type': 'news'},
    {'label': '頻道', 'type': 'channel'},
    {'label': '事件整理', 'type': 'eventSorting'},
    {'label': '多方觀點', 'type': 'multiplePerspectives'},
  ];

  @override
  void initState() {
    super.initState();
    _loadHistoryAndPopularData();
    _searchController.addListener(_onSearchQueryChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged() {
    if (_searchController.text.trim().isEmpty && _searchResults.isNotEmpty) {
      setState(() {
        _searchResults = [];
        _currentRecordId = null;
        _currentFilter = 'all';
        _loadHistoryAndPopularData();
      });
    }
  }

  // MARK: - 歷史記錄與熱門搜尋 API 載入

  Future<void> _loadHistoryAndPopularData() async {
    setState(() {
      _isHistoryAndPopularLoading = true;
    });

    try {
      final futures = [_loadPopularSearches()];

      // 只有登入狀態才載入歷史紀錄
      if (_currentUserId != null) {
        futures.add(_loadSearchHistory());
      }

      await Future.wait(futures);
    } catch (e) {
      print('!!! History/Popular Load Error: $e !!!');
      setState(() {
        if (_currentUserId != null) _currentHistory = [];
        _popularSearches = [];
      });
    }

    setState(() {
      _isHistoryAndPopularLoading = false;
    });
  }

  // 實現載入歷史記錄 (包含登入狀態檢查)
  Future<void> _loadSearchHistory() async {
    if (_currentUserId == null) return;

    // 修正 URL 格式以匹配後端路由：將 _currentUserId 放入 URL 路徑中
    final uri = Uri.parse('$_searchHistoryUrl/$_currentUserId');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['data'] is List) {
          setState(() {
            _currentHistory = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      } else {
        print('History API HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load search history: $e');
    }
  }

  // 實現載入熱門搜尋
  Future<void> _loadPopularSearches() async {
    final uri = Uri.parse(_popularSearchUrl);
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['data'] is List) {
          setState(() {
            _popularSearches = List<String>.from(
              data['data'].map(
                (item) =>
                    item['keyword'] ?? item['keyword_text'] ?? item.toString(),
              ),
            );
          });
        }
      } else {
        print('Popular Search API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load popular searches: $e');
    }
  }

  void _clearAllSearchHistory() {
    setState(() {
      _currentHistory = [];
    });
    // TODO: 應呼叫刪除歷史記錄 API
  }

  // MARK: - 搜索及點擊記錄邏輯

  // 處理 Debouncing 邏輯
  void _performSearch(String keyword) {
    final trimmedKeyword = keyword.trim();

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (trimmedKeyword.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentRecordId = null;
      });
      if (_searchResults.isNotEmpty) {
        _loadHistoryAndPopularData();
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearchCall(trimmedKeyword);
    });
  }

  // 更新篩選器並重新執行搜索
  void _updateFilterAndSearch(String newFilter) {
    setState(() {
      _currentFilter = newFilter;
    });
    // 只有在搜索框有內容時才重新搜索
    if (_searchController.text.trim().isNotEmpty) {
      _performSearchCall(_searchController.text.trim());
    }
  }

  // 階段 1: 執行 general_search 並獲取 record_id
  Future<void> _performSearchCall(String keyword) async {
    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse(_generalSearchUrl);
    final bodyData = json.encode({
      'keyword': [keyword],
      if (_currentUserId != null) 'userId': _currentUserId,
      'dataType': _currentFilter, // 傳遞當前的篩選類型
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: bodyData,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['success'] == true && data['data'] != null) {
          final Map<String, dynamic> resultData = data['data'];
          final int? recordId =
              resultData['record_id'] ?? resultData['insertId'];

          setState(() {
            _currentRecordId = recordId;
          });

          List<Map<String, dynamic>> results = [];

          // 🌟 關鍵修正：只處理與 _currentFilter 匹配的列表，如果是 'all' 則處理所有列表

          // newsList
          if (_currentFilter == 'all' || _currentFilter == 'news') {
            final newsList = List<Map<String, dynamic>>.from(
              resultData['newsList'] ?? [],
            );
            results.addAll(
              newsList.map(
                (item) => {
                  'type': 'news',
                  'id': item['newsId'] ?? item['news_id'] ?? item['id'],
                  'title': item['newsTitle'] ?? item['title'] ?? '無標題',
                  'data': item,
                },
              ),
            );
          }

          // channelList
          if (_currentFilter == 'all' || _currentFilter == 'channel') {
            final channelList = List<Map<String, dynamic>>.from(
              resultData['channelList'] ?? [],
            );
            results.addAll(
              channelList.map(
                (item) => {
                  'type': 'channel',
                  'id': item['channel_id'] ?? item['id'],
                  'title':
                      item['channel_name'] ??
                      item['channelName'] ??
                      item['title'] ??
                      '無標題',
                  'data': item,
                },
              ),
            );
          }

          // eventsortingList
          if (_currentFilter == 'all' || _currentFilter == 'eventSorting') {
            final eventList = List<Map<String, dynamic>>.from(
              resultData['eventsortingList'] ?? [],
            );
            results.addAll(
              eventList.map(
                (item) => {
                  'type': 'eventSorting',
                  'id': item['eventsorting_id'] ?? item['id'],
                  'title': item['eventsorting_title'] ?? item['title'] ?? '無標題',
                  'data': item,
                },
              ),
            );
          }

          // multipleperspectivesList
          if (_currentFilter == 'all' ||
              _currentFilter == 'multiplePerspectives') {
            final multipleList = List<Map<String, dynamic>>.from(
              resultData['multipleperspectivesList'] ?? [],
            );
            results.addAll(
              multipleList.map(
                (item) => {
                  'type': 'multiplePerspectives',
                  'id': item['multipleperspectives_id'] ?? item['id'],
                  'title':
                      item['multipleperspectives_title'] ??
                      item['title'] ??
                      '無標題',
                  'data': item,
                },
              ),
            );
          }

          // -----------------------------------------------------------------

          setState(() {
            _searchResults = results;
          });
        } else {
          setState(() {
            _searchResults = [];
          });
        }
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    } on TimeoutException {
      setState(() {
        _searchResults = [];
      });
    } catch (e) {
      print('!!! General Search Error: $e');
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _recordClickAction(String dataType, int dataId) async {
    if (_currentRecordId == null || _currentUserId == null) {
      return;
    }
    final clickUrl = Uri.parse(_userSearchClickUrl);
    final bodyData = json.encode({
      'userId': _currentUserId,
      'recordId': _currentRecordId,
      'dataType': dataType,
      'dataId': dataId,
    });
    try {
      await http
          .post(
            clickUrl,
            headers: {'Content-Type': 'application/json'},
            body: bodyData,
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Error recording click: $e');
    }
  }

  void _navigateToDetail(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final id =
        item['id'] is int ? item['id'] : int.tryParse(item['id'].toString());
    final title = item['title'];
    final data = item['data'] as Map<String, dynamic>;

    if (id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('錯誤：找不到資料ID無法導航')));
      return;
    }

    _recordClickAction(type, id);

    Widget destinationPage;
    switch (type) {
      case 'news':
        destinationPage = ViewNewsContent(newsData: data);
        break;
      case 'channel':
        destinationPage = ChannelDetailPage(
          channelId: id,
          channelName: title,
          channelDescription: data['channelDescription'],
          channelUrl: data['channelUrl'],
        );
        break;
      case 'eventSorting':
        destinationPage = EventSortingDetailPage(id: id);
        break;
      case 'multiplePerspectives':
        destinationPage = MultiplePerspectivesDetailPage(id: id);
        break;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('未知的內容類型: $type')));
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => destinationPage),
    );
  }

  // MARK: - UI 構建

  @override
  Widget build(BuildContext context) {
    final bool showHistoryAndHot =
        _searchController.text.isEmpty && _searchResults.isEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0a1428),
        elevation: 0,
        toolbarHeight: 80,
        title: _buildSearchBar(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 篩選按鈕列始終顯示
          _buildFilterButtons(),

          _isLoading || _isHistoryAndPopularLoading
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
          Expanded(
            child:
                showHistoryAndHot
                    ? _buildHistoryAndHotSearch(context)
                    : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  // 構建篩選按鈕列
  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              _filters.map((filter) {
                final type = filter['type']!;
                final isSelected = type == _currentFilter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ActionChip(
                    label: Text(filter['label']!),
                    labelStyle: TextStyle(
                      color:
                          isSelected
                              ? const Color(0xFF0a1428)
                              : const Color(0xFF60a5fa),
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor:
                        isSelected
                            ? const Color(0xFF1e40af)
                            : const Color(0xFF0a1428),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color:
                            isSelected
                                ? const Color(0xFF1e40af)!
                                : Colors.grey.shade300,
                      ),
                    ),
                    onPressed: () => _updateFilterAndSearch(type),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0a0e27),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                        : null,
              ),
              onChanged: (value) {
                // 確保 UI 更新
                setState(() {});
                _performSearch(value);
              },
              onSubmitted: (value) {
                _performSearchCall(value.trim());
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryAndHotSearch(BuildContext context) {
    // 只有 _currentUserId 不為 null (登入) 時才顯示歷史紀錄
    final bool showHistory = _currentUserId != null;
    final historyKeywords =
        showHistory
            ? _currentHistory
                .map((item) => item['keyword_text'] as String)
                .toList()
            : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 歷史記錄區塊 (只有登入時才顯示)
          if (showHistory) ...[
            _buildHistoryHeader(historyKeywords.isEmpty),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children:
                  historyKeywords
                      .map((keyword) => _buildSearchTag(keyword))
                      .toList(),
            ),
            const SizedBox(height: 32),
          ],

          // 熱門搜尋區塊 (始終顯示)
          const Text(
            '熱門搜尋',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children:
                _popularSearches
                    .map((keyword) => _buildSearchTag(keyword))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader(bool isEmpty) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '歷史記錄',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        TextButton(
          onPressed: isEmpty ? null : _clearAllSearchHistory,
          child: const Text(
            '刪除歷史記錄',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9090FF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTag(String keyword) {
    return InkWell(
      onTap: () {
        _searchController.text = keyword;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
        _performSearchCall(keyword);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0a0e27),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6366f1).withOpacity(0.2)),
        ),
        child: Text(
          keyword,
          style: const TextStyle(
            fontSize: 16,
            color: Color.fromARGB(222, 255, 255, 255),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (!_isLoading &&
        _searchResults.isEmpty &&
        _searchController.text.isNotEmpty) {
      return const Center(child: Text('找不到相關內容'));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final type = item['type'];
        final typeText =
            type == 'channel'
                ? '頻道'
                : type == 'eventSorting'
                ? '事件整理'
                : type == 'multiplePerspectives'
                ? '多重觀點'
                : type == 'news'
                ? '新聞'
                : '其他';

        return ListTile(
          title: Text(item['title']),
          subtitle: Text(typeText),
          onTap: () => _navigateToDetail(item),
        );
      },
    );
  }
}
