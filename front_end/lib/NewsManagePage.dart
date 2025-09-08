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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新聞管理'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.blue[100]!],
          ),
        ),
        child: SingleChildScrollView(
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
                        Icons.newspaper,
                        size: 50,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '新聞管理中心',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '管理新聞的各種數據類型',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // 新聞管理綜合介面
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
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
                        '新聞管理功能',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 功能說明
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '此頁面包含以下新聞管理功能：',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[800],
                              ),
                            ),
                            const SizedBox(height: 15),
                            _buildFeatureItem('Data', '新聞基本數據和元資料管理',
                                Icons.article, Colors.green),
                            const SizedBox(height: 10),
                            _buildFeatureItem('Body', '新聞內容和文章管理',
                                Icons.description, Colors.orange),
                            const SizedBox(height: 10),
                            _buildFeatureItem('Group', '新聞分類和群組管理',
                                Icons.group_work, Colors.purple),
                            const SizedBox(height: 10),
                            _buildFeatureItem('Location', '新聞地理位置管理',
                                Icons.place, Colors.red),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 操作按鈕區域
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: 後續實現新聞列表功能
                                _showComingSoon('新聞列表查看');
                              },
                              icon: Icon(Icons.list),
                              label: Text('查看新聞'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // TODO: 後續實現新聞編輯功能
                                _showComingSoon('新聞編輯');
                              },
                              icon: Icon(Icons.edit),
                              label: Text('編輯新聞'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 80), // 底部留更多空間給浮動按鈕
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                          '總新聞數',
                          '0' /* TODO: 後續改為 '${newsStats['total']}' */,
                          Icons.article),
                      _buildStatItem(
                          '今日新增',
                          '0' /* TODO: 後續改為 '${newsStats['today']}' */,
                          Icons.today),
                      _buildStatItem(
                          '待審核',
                          '0' /* TODO: 後續改為 '${newsStats['pending']}' */,
                          Icons.pending),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 後續實現添加新聞功能
          // _showAddNewsDialog();
          _showComingSoon('添加新聞');
        },
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: '添加新聞',
      ),
    );
  }

  Widget _buildFeatureItem(
      String title, String description, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String title, String count, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 25,
          color: Colors.blue[700],
        ),
        const SizedBox(height: 8),
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('即將推出'),
          content: Text('$feature 功能正在開發中，敬請期待！'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('確定'),
            ),
          ],
        );
      },
    );
  }
}
