import 'package:flutter/material.dart';
// TODO: 後續需要加入HTTP請求套件
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// 連接頁面
import 'config.dart';

// TODO: 後續需要實現的API函數
/*
// 搜尋關鍵字
Future<List<dynamic>> searchKeywords(String query) async {
  final url = '$baseUrl/keyword/search?query=$query';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to search keywords');
  }
}

// 獲取關鍵字詳細信息
Future<Map<String, dynamic>> getKeywordDetails(int keywordId) async {
  final url = '$baseUrl/keyword/details/$keywordId';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to get keyword details');
  }
}

// 獲取熱門關鍵字
Future<List<dynamic>> getPopularKeywords({int limit = 10}) async {
  final url = '$baseUrl/keyword/popular?limit=$limit';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to get popular keywords');
  }
}

// 獲取關鍵字統計
Future<Map<String, int>> getKeywordStats() async {
  final url = '$baseUrl/keyword/stats';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return Map<String, int>.from(jsonDecode(response.body));
  } else {
    throw Exception('Failed to get keyword stats');
  }
}
*/

class KeywordPage extends StatefulWidget {
  const KeywordPage({super.key});

  @override
  State<KeywordPage> createState() => _KeywordPageState();
}

class _KeywordPageState extends State<KeywordPage> {
  final TextEditingController _searchController = TextEditingController();

  // TODO: 後續需要的狀態變數
  // List<dynamic> searchResults = [];
  // List<dynamic> popularKeywords = [];
  // bool isLoading = false;
  // bool hasSearched = false;
  // String currentSearchQuery = '';

  // TODO: 後續需要實現的初始化函數
  /*
  @override
  void initState() {
    super.initState();
    _loadPopularKeywords();
  }

  Future<void> _loadPopularKeywords() async {
    try {
      final popular = await getPopularKeywords();
      setState(() {
        popularKeywords = popular;
      });
    } catch (e) {
      _showErrorDialog('載入熱門關鍵字失敗: $e');
    }
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) {
      _showErrorDialog('請輸入搜尋關鍵字');
      return;
    }

    setState(() {
      isLoading = true;
      currentSearchQuery = _searchController.text.trim();
    });

    try {
      final results = await searchKeywords(currentSearchQuery);
      setState(() {
        searchResults = results;
        hasSearched = true;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('搜尋失敗: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('錯誤'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('關鍵字管理'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo[50]!, Colors.indigo[100]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題區域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.key,
                      size: 50,
                      color: Colors.indigo[700],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '關鍵字搜尋中心',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[800],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '搜尋和管理系統關鍵字',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 搜尋區域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '搜尋關鍵字',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[800],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: '輸入要搜尋的關鍵字...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.indigo[700]!),
                              ),
                            ),
                            onSubmitted: (value) {
                              // TODO: 實現搜尋功能
                              // _performSearch();
                              _showComingSoon('搜尋功能');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: 實現搜尋功能
                            // _performSearch();
                            _showComingSoon('搜尋功能');
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('搜尋'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Text(
                          '搜尋範圍：',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Chip(
                          label: const Text('關鍵字文本'),
                          backgroundColor: Colors.indigo[100],
                          labelStyle: TextStyle(color: Colors.indigo[800]),
                        ),
                        const SizedBox(width: 10),
                        Chip(
                          label: const Text('按熱度排序'),
                          backgroundColor: Colors.indigo[100],
                          labelStyle: TextStyle(color: Colors.indigo[800]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 搜尋結果區域
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '搜尋結果',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[800],
                            ),
                          ),
                          const Spacer(),
                          // TODO: 顯示結果數量
                          // if (hasSearched)
                          //   Text(
                          //     '找到 ${searchResults.length} 個結果',
                          //     style: TextStyle(
                          //       fontSize: 14,
                          //       color: Colors.grey[600],
                          //     ),
                          //   ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: _buildSearchResultsArea(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsArea() {
    // TODO: 實現搜尋結果顯示
    /*
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!hasSearched) {
      return _buildEmptyState();
    }

    if (searchResults.isEmpty) {
      return _buildNoResultsState();
    }

    return _buildSearchResults();
    */

    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            '輸入關鍵字開始搜尋',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '您可以搜尋關鍵字文本、查看搜尋熱度等信息',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.indigo[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.indigo[600],
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '搜尋提示',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '• 顯示搜尋次數和熱度信息\n'
                      '• 結果按搜尋熱度排序',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TODO: 實現其他搜尋結果相關的Widget
  /*
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            '沒有找到相關關鍵字',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '嘗試使用其他關鍵字或檢查拼寫',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final keyword = searchResults[index];
        return _buildKeywordCard(keyword);
      },
    );
  }

  Widget _buildKeywordCard(Map<String, dynamic> keyword) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo[100],
          child: Icon(
            Icons.key,
            color: Colors.indigo[700],
          ),
        ),
        title: Text(
          keyword['keyword_text'] ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('搜尋次數: ${keyword['total_search'] ?? 0}'),
            Text('搜尋熱度: ${keyword['total_search_heat'] ?? 0}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            _showKeywordDetails(keyword);
          },
        ),
      ),
    );
  }

  void _showKeywordDetails(Map<String, dynamic> keyword) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('關鍵字詳情'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('關鍵字: ${keyword['keyword_text'] ?? ''}'),
              Text('總搜尋次數: ${keyword['total_search'] ?? 0}'),
              Text('最近搜尋次數: ${keyword['total_recent_search'] ?? 0}'),
              Text('搜尋熱度: ${keyword['total_search_heat'] ?? 0}'),
              Text('關聯ID: ${keyword['keyword_relation_id'] ?? ''}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }
  */

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('功能開發中'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction,
                color: Colors.orange,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                '$feature即將推出，敬請期待！',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}