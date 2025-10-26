import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'ChannelDetailPage.dart';
import 'EventSortingDetailPage.dart';
import 'MultiplePerspectivesDetailPage.dart';
import 'config.dart';

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

  // 狀態：儲存這次搜尋的 record_id
  int? _currentRecordId;

  // 狀態：模擬登入用戶ID。由於歷史記錄 API 需要 ID，這裡必須有值。
  final int _currentUserId = 1;

  // API 路由
  final String _generalSearchUrl = '$baseUrl/general_search';
  final String _userSearchBaseUrl = '$baseUrl/user/search';
  // 新增歷史記錄和熱門搜尋 API
  final String _searchHistoryUrl = '$baseUrl/search/history';
  final String _popularSearchUrl = '$baseUrl/search/popular';

  // 歷史記錄和熱門搜尋數據列表
  List<Map<String, dynamic>> _currentHistory = [];
  List<String> _popularSearches = [];


  @override
  void initState() {
    super.initState();
    _loadHistoryAndPopularData();
    _searchController.addListener(_onSearchQueryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged() {
    if (_searchController.text.isEmpty && _searchResults.isNotEmpty) {
      setState(() {
        _searchResults = [];
        _currentRecordId = null;
      });
    }
  }


  // MARK: - 歷史記錄與熱門搜尋 API 載入

  Future<void> _loadHistoryAndPopularData() async {
    setState(() {
      _isHistoryAndPopularLoading = true;
    });

      await Future.wait([
        _loadSearchHistory(),
        _loadPopularSearches(),
      ]);

    setState(() {
      _isHistoryAndPopularLoading = false;
    });
  }

  // 獲取歷史記錄 (GET /api/search/history/:userId)
  Future<void> _loadSearchHistory() async {
    try {
      // ⚠️ 這裡使用 /api/search/history/1 模擬用戶 ID
      final response = await http.get(Uri.parse('$_searchHistoryUrl/$_currentUserId'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          setState(() {
            _currentHistory = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      } else {
        print('Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      print('Load history error: $e');
    }
  }

  // 獲取熱門搜尋 (GET /api/search/popular)
  Future<void> _loadPopularSearches() async {
    try {
      final response = await http.get(Uri.parse(_popularSearchUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          setState(() {
            // 將 [{ keyword_id: 1, keyword_text: "..." }] 轉換為 [ "..." ]
            _popularSearches = List<Map<String, dynamic>>.from(data['data'])
                .map((item) => item['keyword_text'] as String)
                .toList();
          });
        }
      } else {
        print('Failed to load popular searches: ${response.statusCode}');
      }
    } catch (e) {
      print('Load popular searches error: $e');
    }
  }

  // 模擬清除歷史記錄的 UI 邏輯 (請替換為實際的 DELETE API)
  void _clearAllSearchHistory() {
    setState(() {
      _currentHistory = [];
    });
  }


  // MARK: - 搜索及點擊記錄邏輯

  // 階段 1: 執行搜尋並獲取 record_id
  Future<void> _performSearch(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse('$_generalSearchUrl?keyword=$keyword');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {

          final int? recordId = data['record_id'];
          setState(() {
            _currentRecordId = recordId;
          });

          List<Map<String, dynamic>> results = [];

          // 處理 News
          final newsList = List<Map<String, dynamic>>.from(data['news'] ?? []);
          results.addAll(newsList.map((item) => {'type': 'news', 'id': item['news_id'] ?? item['id'], 'title': item['title'] ?? '無標題'}));

          // 處理 Channel
          final channelList = List<Map<String, dynamic>>.from(data['channel'] ?? []);
          results.addAll(channelList.map((item) => {'type': 'channel', 'id': item['channel_id'] ?? item['id'], 'title': item['channel_name'] ?? item['title'] ?? '無標題'}));

          // 處理 EventSorting
          final eventList = List<Map<String, dynamic>>.from(data['eventsorting'] ?? []);
          results.addAll(eventList.map((item) => {'type': 'eventSorting', 'id': item['eventsorting_id'] ?? item['id'], 'title': item['eventsorting_title'] ?? item['title'] ?? '無標題'}));

          // 處理 MultiplePerspectives
          final multipleList = List<Map<String, dynamic>>.from(data['multipleperspectives'] ?? []);
          results.addAll(multipleList.map((item) => {'type': 'multiplePerspectives', 'id': item['multipleperspectives_id'] ?? item['id'], 'title': item['multipleperspectives_title'] ?? item['title'] ?? '無標題'}));

          setState(() {
            _searchResults = results;
          });
        }
      }
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 階段 2: 記錄點擊行為
  Future<void> _recordClickAction(String dataType, int dataId) async {
    if (_currentRecordId == null) return;

    String typePath;
    switch (dataType) {
      case 'news': typePath = 'news'; break;
      case 'channel': typePath = 'channel'; break;
      case 'eventSorting': typePath = 'eventsorting'; break;
      case 'multiplePerspectives': typePath = 'multipleperspectives'; break;
      default: return;
    }

    try {
      await http.post(
        Uri.parse('$_userSearchBaseUrl/$typePath'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'recordId': _currentRecordId,
          'dataId': dataId,
        }),
      );
    } catch (e) {
      print('Click action error: $e');
    }
  }

  void _navigateToDetail(Map<String, dynamic> item) {
    final type = item['type'];
    final id = item['id'];

    _recordClickAction(type, id);

    if (type == 'channel') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => ChannelDetailPage(channelId: id, channelName: item['title'])));
    } else if (type == 'eventSorting') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => EventSortingDetailPage(id: id)));
    } else if (type == 'multiplePerspectives') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => MultiplePerspectivesDetailPage(id: id)));
    }
  }


  // MARK: - UI 構建

  @override
  Widget build(BuildContext context) {
    final bool showHistoryAndHot = _searchController.text.isEmpty && _searchResults.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF0F0FF),
        elevation: 0,
        toolbarHeight: 80,
        title: _buildSearchBar(),
      ),
      body: Column(
        children: [
          _isLoading || _isHistoryAndPopularLoading
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
          Expanded(
            child: showHistoryAndHot
                ? _buildHistoryAndHotSearch(context)
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  // 構建頂部的搜索欄和返回箭頭
  Widget _buildSearchBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
                    : null,
              ),
              onChanged: _performSearch,
              onSubmitted: _performSearch,
            ),
          ),
        ),
      ],
    );
  }

  // 構建搜索歷史和熱門搜尋的主體
  Widget _buildHistoryAndHotSearch(BuildContext context) {

    // 提取歷史記錄的關鍵字列表
    final historyKeywords = _currentHistory.map((item) => item['keyword_text'] as String).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 歷史記錄區塊
          _buildHistoryHeader(historyKeywords.isEmpty),
          const SizedBox(height: 8),
          _buildTagsWrapper(historyKeywords),

          const SizedBox(height: 32),

          // 熱門搜尋區塊
          const Text(
            '熱門搜尋',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          _buildTagsWrapper(_popularSearches),

          // 底部可愛插畫 Placeholder 已被刪除
        ],
      ),
    );
  }

  // 歷史記錄的標題和清除按鈕
  Widget _buildHistoryHeader(bool isEmpty) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '歷史記錄',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
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

  // 構建標籤樣式的 Wrapper
  Widget _buildTagsWrapper(List<String> keywords) {
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: keywords.map((keyword) => _buildSearchTag(keyword)).toList(),
    );
  }

  // 構建單個搜索標籤
  Widget _buildSearchTag(String keyword) {
    return InkWell(
      onTap: () {
        _searchController.text = keyword;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
        _performSearch(keyword);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          keyword,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }

  // 搜索結果列表
  Widget _buildResultsList() {
    if (!_isLoading && _searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text('找不到相關內容'));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final type = item['type'];
        final typeText = type == 'channel' ? '頻道'
            : type == 'eventSorting' ? '事件整理'
            : type == 'multiplePerspectives' ? '多重觀點'
            : type == 'news' ? '新聞' : '其他';

        return ListTile(
          title: Text(item['title']),
          subtitle: Text(typeText),
          onTap: () => _navigateToDetail(item),
        );
      },
    );
  }
}