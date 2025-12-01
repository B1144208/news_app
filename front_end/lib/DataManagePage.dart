import 'package:flutter/material.dart';
import 'PhotoPage.dart';
import 'ChannelPage.dart';
import 'GroupPage.dart';

// TODO: 後續需要加入HTTP請求套件
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// 連接頁面
import 'NewsManagePage.dart';
import 'LocationPage.dart';
import 'KeywordPage.dart';
import 'config.dart';

// TODO: 後續需要實現的API函數
/*
// 獲取各數據類型統計
Future<Map<String, int>> fetchDataStats() async {
  final url = '$baseUrl/data/stats';
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    return Map<String, int>.from(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load data stats');
  }
}

// 頻道管理相關API
Future<List<dynamic>> fetchChannels() async {
  final url = '$baseUrl/channel/list';
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load channels');
  }
}

// 圖片管理相關API
Future<List<dynamic>> fetchImages() async {
  final url = '$baseUrl/image/list';
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load images');
  }
}

// 群組管理相關API
Future<List<dynamic>> fetchGroups() async {
  final url = '$baseUrl/group/list';
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load groups');
  }
}

// 位置管理相關API
Future<List<dynamic>> fetchLocations() async {
  final url = '$baseUrl/location/list';
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load locations');
  }
}

// 關鍵字管理相關API
Future<List<dynamic>> fetchKeywords() async {
  final url = '$baseUrl/keyword/list';
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load keywords');
  }
}

// 關聯管理相關API
Future<List<dynamic>> fetchRelations() async {
  final url = '$baseUrl/relation/list';
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load relations');
  }
}
*/

class DataManagePage extends StatefulWidget {
  const DataManagePage({super.key});

  @override
  State<DataManagePage> createState() => _DataManagePageState();
}

class _DataManagePageState extends State<DataManagePage> {
  // TODO: 後續需要的狀態變數
  // Map<String, int> dataStats = {};
  // bool isLoading = true;

  // TODO: 後續需要實現的初始化函數
  /*
  @override
  void initState() {
    super.initState();
    _loadDataStats();
  }

  Future<void> _loadDataStats() async {
    setState(() {
      isLoading = true;
    });

    try {
      final stats = await fetchDataStats();
      
      setState(() {
        dataStats = stats;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('載入數據統計失敗: $e');
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
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        title: const Text(
          '數據管理',
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 標題區域
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a2a4e),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6366f1).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366f1).withOpacity(0.1),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6366f1),
                              const Color(0xFF60a5fa),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storage,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '數據管理中心',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '管理系統中的各種數據類型',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // 數據管理項目列表
                Column(
                  children: [
                    _buildSimpleButton(
                      'news',
                      Icons.newspaper,
                      Colors.blue,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NewsManagePage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildSimpleButton('channel', Icons.tv, Colors.purple, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChannelPage(),
                        ),
                      );
                    }),
                    const SizedBox(height: 15),
                    _buildSimpleButton('image', Icons.image, Colors.orange, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PhotoPage(),
                        ),
                      );
                    }),

                    const SizedBox(height: 15),
                    _buildSimpleButton('group', Icons.group, Colors.teal, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GroupPage()),
                      );
                    }),

                    const SizedBox(height: 15),
                    _buildSimpleButton(
                      'location',
                      Icons.location_on,
                      Colors.red,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LocationPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildSimpleButton('keyword', Icons.key, Colors.indigo, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const KeywordPage(),
                        ),
                      );
                    }),
                    const SizedBox(height: 15),
                    _buildSimpleButton(
                      'relation',
                      Icons.account_tree,
                      Colors.brown,
                      () {
                        // TODO: 後續實現關聯管理功能
                        _showComingSoon('關聯管理');
                      },
                    ),
                    const SizedBox(height: 20), // 底部留白
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6366f1), const Color(0xFF60a5fa)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366f1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '$text',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
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
