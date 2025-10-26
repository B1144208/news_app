import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'ChannelDetailPage.dart';
import 'EventSortingDetailPage.dart';
import 'MultiplePerspectivesDetailPage.dart';
import 'config.dart';

// 假設歷史記錄數據 (靜態模擬)
const List<String> _mockSearchHistory = [
  '00000', '22222', '44444', '11111', '33333', '55555',
];

// 假設熱門搜尋數據 (靜態模擬)
const List<String> _mockHotSearches = [
  '00000', '11111', '22222', '33333', '44444',
  '55555', '66666', '77777', '88888', '99999',
];




class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  final String _channelUrl = '$baseUrl/channel';
  final String _eventSortingUrl = '$baseUrl/EventSorting';
  final String _multiplePerspectivesUrl = '$baseUrl/MultiplePerspectives';

  // ⚠️ 歷史記錄狀態現在由一個可變列表來模擬，以便實現「刪除」的 UI 效果
  List<String> _currentHistory = List<String>.from(_mockSearchHistory);


  @override
  void initState() {
    super.initState();
    // 移除 _loadSearchHistory()
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
      });
    }
  }

  // MARK: - 歷史記錄模擬邏輯

  // 模擬「清除所有歷史記錄」
  void _clearAllSearchHistory() {
    setState(() {
      _currentHistory = [];
    });
    // ⚠️ 這裡不再調用任何持久化或 API 邏輯
  }

  // 模擬「保存關鍵字」：點擊標籤或搜索成功時，模擬將其提到最前面
  void _simulateSaveKeyword(String keyword) {
    // 僅在當前列表不包含該關鍵字時，模擬插入
    if (!_currentHistory.contains(keyword)) {
      setState(() {
        _currentHistory.insert(0, keyword);
      });
    }
    // ⚠️ 這裡不再調用任何持久化或 API 邏輯
  }


  // MARK: - 搜索及導航邏輯 (保留原有功能)

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
      final channelResp = await http.get(Uri.parse(_channelUrl));
      final eventResp = await http.get(Uri.parse(_eventSortingUrl));
      final multipleResp = await http.get(Uri.parse(_multiplePerspectivesUrl));

      List<Map<String, dynamic>> results = [];

      // ... (原有的 API 數據處理和篩選邏輯 - 保持不變) ...
      if (channelResp.statusCode == 200) {
        final data = json.decode(channelResp.body)['data'];
        for (var item in data) {
          final name = item['channel_name'] ?? '';
          if (name.toLowerCase().contains(keyword.toLowerCase())) {
            results.add({'type': 'channel', 'id': item['channel_id'], 'title': name});
          }
        }
      }

      if (eventResp.statusCode == 200) {
        final data = json.decode(eventResp.body)['data'];
        for (var item in data) {
          final title = item['eventsorting_title'] ?? '';
          if (title.toLowerCase().contains(keyword.toLowerCase())) {
            results.add({'type': 'eventSorting', 'id': item['eventsorting_id'], 'title': title});
          }
        }
      }

      if (multipleResp.statusCode == 200) {
        final data = json.decode(multipleResp.body)['data'];
        for (var item in data) {
          final title = item['multipleperspectives_title'] ?? '';
          if (title.toLowerCase().contains(keyword.toLowerCase())) {
            results.add({'type': 'multiplePerspectives', 'id': item['multipleperspectives_id'], 'title': title});
          }
        }
      }

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToDetail(Map<String, dynamic> item) {
    final currentKeyword = _searchController.text.trim();
    if (currentKeyword.isNotEmpty) {
      // ⚠️ 模擬保存關鍵字
      _simulateSaveKeyword(currentKeyword);
    }

    final type = item['type'];
    final id = item['id'];

    // 導航邏輯保持不變...
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
          _isLoading
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

  // 1. 構建頂部的搜索欄和返回箭頭 (保持不變)
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

  // 2. 構建搜索歷史和熱門搜尋的主體
  Widget _buildHistoryAndHotSearch(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 歷史記錄區塊
          _buildHistoryHeader(),
          const SizedBox(height: 8),
          _buildTagsWrapper(_currentHistory), // ⚠️ 使用可變的 _currentHistory

          const SizedBox(height: 32),

          // 熱門搜尋區塊
          const Text(
            '熱門搜尋',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          _buildTagsWrapper(_mockHotSearches), // ⚠️ 使用靜態的 _mockHotSearches

          const SizedBox(height: 50),
          // 截圖中的可愛插畫（這裡使用一個 Placeholder 容器代替圖片）
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.pink.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('可愛插畫 Placeholder', textAlign: TextAlign.center, style: TextStyle(color: Colors.pink)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. 構建歷史記錄的標題和清除按鈕
  Widget _buildHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '歷史記錄',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        TextButton(
          // ⚠️ 調用模擬的清除邏輯
          onPressed: _currentHistory.isEmpty ? null : _clearAllSearchHistory,
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

  // 4. 構建標籤樣式的 Wrapper (用於歷史記錄和熱門搜尋) (保持不變)
  Widget _buildTagsWrapper(List<String> keywords) {
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: keywords.map((keyword) => _buildSearchTag(keyword)).toList(),
    );
  }

  // 5. 構建單個搜索標籤
  Widget _buildSearchTag(String keyword) {
    return InkWell(
      onTap: () {
        // 點擊標籤時，模擬保存關鍵字並執行搜索
        _simulateSaveKeyword(keyword); // ⚠️ 模擬保存
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

  // 6. 搜索結果列表 (保持不變)
  Widget _buildResultsList() {
    if (!_isLoading && _searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text('找不到相關內容'));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final typeText = item['type'] == 'channel' ? '頻道' : item['type'] == 'eventSorting' ? '事件整理' : '多重觀點';

        return ListTile(
          title: Text(item['title']),
          subtitle: Text(typeText),
          onTap: () => _navigateToDetail(item),
        );
      },
    );
  }
}