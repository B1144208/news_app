import 'package:flutter/material.dart';
// TODO: 後續需要加入HTTP請求套件
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// 連接頁面
import 'NewsManagePage.dart';
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
      appBar: AppBar(
        title: const Text('數據管理'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.green[100]!],
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
                      Icons.storage,
                      size: 50,
                      color: Colors.green[700],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '數據管理中心',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '管理系統中的各種數據類型',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 數據管理項目列表
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      _buildSimpleButton('news', Icons.newspaper, Colors.blue,
                          () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NewsManagePage(),
                          ),
                        );
                      }),
                      const SizedBox(height: 15),
                      _buildSimpleButton('channel', Icons.tv, Colors.purple,
                          () {
                        // TODO: 後續實現頻道管理功能
                        _showComingSoon('頻道管理');
                      }),
                      const SizedBox(height: 15),
                      _buildSimpleButton('image', Icons.image, Colors.orange,
                          () {
                        // TODO: 後續實現圖片管理功能
                        _showComingSoon('圖片管理');
                      }),
                      const SizedBox(height: 15),
                      _buildSimpleButton('group', Icons.group, Colors.teal, () {
                        // TODO: 後續實現群組管理功能
                        _showComingSoon('群組管理');
                      }),
                      const SizedBox(height: 15),
                      _buildSimpleButton(
                          'location', Icons.location_on, Colors.red, () {
                        // TODO: 後續實現位置管理功能
                        _showComingSoon('位置管理');
                      }),
                      const SizedBox(height: 15),
                      _buildSimpleButton('keyword', Icons.key, Colors.indigo,
                          () {
                        // TODO: 後續實現關鍵字管理功能
                        _showComingSoon('關鍵字管理');
                      }),
                      const SizedBox(height: 15),
                      _buildSimpleButton(
                          'relation', Icons.account_tree, Colors.brown, () {
                        // TODO: 後續實現關聯管理功能
                        _showComingSoon('關聯管理');
                      }),
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

  Widget _buildSimpleButton(
      String text, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.3), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 15),
            Text(
              '$text:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
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
