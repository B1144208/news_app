import 'package:flutter/material.dart';
// TODO: 後續需要加入HTTP請求套件
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// 連接頁面
import 'config.dart';

// TODO: 後續需要實現的API函數
/*
// 獲取新聞列表
Future<List<dynamic>> fetchNewsList() async {
  final url = '$baseUrl/news/list';
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load news list');
  }
}

// 獲取新聞統計數據
Future<Map<String, int>> fetchNewsStats() async {
  final url = '$baseUrl/news/stats';
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    return Map<String, int>.from(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load news stats');
  }
}

// 新增新聞
Future<bool> addNews(Map<String, dynamic> newsData) async {
  final url = '$baseUrl/news/add';
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(newsData),
  );
  
  return response.statusCode == 201;
}

// 更新新聞
Future<bool> updateNews(int newsId, Map<String, dynamic> newsData) async {
  final url = '$baseUrl/news/update/$newsId';
  final response = await http.put(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(newsData),
  );
  
  return response.statusCode == 200;
}

// 刪除新聞
Future<bool> deleteNews(int newsId) async {
  final url = '$baseUrl/news/delete/$newsId';
  final response = await http.delete(Uri.parse(url));
  
  return response.statusCode == 200;
}
*/

class NewsManagePage extends StatefulWidget {
  const NewsManagePage({super.key});

  @override
  State<NewsManagePage> createState() => _NewsManagePageState();
}

class _NewsManagePageState extends State<NewsManagePage> {
  // TODO: 後續需要的狀態變數
  // List<dynamic> newsList = [];
  // Map<String, int> newsStats = {'total': 0, 'today': 0, 'pending': 0};
  // bool isLoading = true;

  // TODO: 後續需要實現的初始化函數
  /*
  @override
  void initState() {
    super.initState();
    _loadNewsData();
  }

  Future<void> _loadNewsData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final stats = await fetchNewsStats();
      final news = await fetchNewsList();
      
      setState(() {
        newsStats = stats;
        newsList = news;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('載入數據失敗: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('錯誤'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('確定'),
            ),
          ],
        );
      },
    );
  }
  */

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        title: const Text(
          '新聞管理',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF1a2a4e),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF6366f1).withOpacity(0.1),
            height: 1,
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFF0a1428),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 標題區域
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  margin: const EdgeInsets.only(bottom: 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1a2a4e),
                        const Color(0xFF0f1e3d),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366f1).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366f1).withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6366f1),
                              const Color(0xFF60a5fa),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.newspaper,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '新聞管理中心',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '管理新聞的各種數據類型',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // 新聞管理綜合介面
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a2a4e),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6366f1).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366f1).withOpacity(0.08),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '新聞管理功能',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 功能說明
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366f1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF6366f1).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '此頁面包含以下新聞管理功能：',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 15),
                            _buildFeatureItem(
                              'Data',
                              '新聞基本數據和元資料管理',
                              Icons.article,
                              Colors.green,
                            ),
                            const SizedBox(height: 10),
                            _buildFeatureItem(
                              'Body',
                              '新聞內容和文章管理',
                              Icons.description,
                              Colors.orange,
                            ),
                            const SizedBox(height: 10),
                            _buildFeatureItem(
                              'Group',
                              '新聞分類和群組管理',
                              Icons.group_work,
                              Colors.purple,
                            ),
                            const SizedBox(height: 10),
                            _buildFeatureItem(
                              'Location',
                              '新聞地理位置管理',
                              Icons.place,
                              Colors.red,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 操作按鈕區域
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6366f1),
                                    const Color(0xFF60a5fa),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _showComingSoon('新聞列表查看');
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.list, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        '查看新聞',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF34d399),
                                    const Color(0xFF10b981),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _showComingSoon('新聞編輯');
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.edit, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        '編輯新聞',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 統計信息
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 80),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a2a4e),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6366f1).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366f1).withOpacity(0.08),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildStatItem(
                        '總新聞數',
                        '0' /* TODO: 後續改為 '${newsStats['total']}' */,
                        Icons.article,
                      ),
                      const SizedBox(width: 12),
                      _buildStatItem(
                        '今日新增',
                        '0' /* TODO: 後續改為 '${newsStats['today']}' */,
                        Icons.today,
                      ),
                      const SizedBox(width: 12),
                      _buildStatItem(
                        '待審核',
                        '0' /* TODO: 後續改為 '${newsStats['pending']}' */,
                        Icons.pending,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF6366f1), const Color(0xFF60a5fa)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366f1).withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _showComingSoon('添加新聞');
            },
            borderRadius: BorderRadius.circular(14),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String title, String count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0f1e3d).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF6366f1).withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366f1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 28, color: const Color(0xFF60a5fa)),
            ),
            const SizedBox(height: 12),
            Text(
              count,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a2a4e),
          title: const Text(
            '即將推出',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          content: Text(
            '$feature 功能正在開發中，敬請期待！',
            style: TextStyle(color: Colors.grey[300], fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF60a5fa),
              ),
              child: const Text(
                '確定',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}
