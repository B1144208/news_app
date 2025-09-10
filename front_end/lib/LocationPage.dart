import 'package:flutter/material.dart';
// TODO: 後續需要加入HTTP請求套件
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// 連接頁面
import 'config.dart';

// TODO: 後續需要實現的API函數
/*
// 獲取地區列表
Future<List<dynamic>> fetchRegions() async {
  final url = '$baseUrl/location/regions';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load regions');
  }
}

// 獲取國家列表
Future<List<dynamic>> fetchCountries(int regionId) async {
  final url = '$baseUrl/location/countries?region_id=$regionId';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load countries');
  }
}

// 獲取州/省列表
Future<List<dynamic>> fetchStates(int countryId) async {
  final url = '$baseUrl/location/states?country_id=$countryId';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load states');
  }
}

// 獲取位置統計數據
Future<Map<String, int>> fetchLocationStats() async {
  final url = '$baseUrl/location/stats';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return Map<String, int>.from(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load location stats');
  }
}

// 新增地區
Future<bool> addRegion(Map<String, dynamic> regionData) async {
  final url = '$baseUrl/location/region/add';
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(regionData),
  );

  return response.statusCode == 201;
}

// 新增國家
Future<bool> addCountry(Map<String, dynamic> countryData) async {
  final url = '$baseUrl/location/country/add';
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(countryData),
  );

  return response.statusCode == 201;
}

// 新增州/省
Future<bool> addState(Map<String, dynamic> stateData) async {
  final url = '$baseUrl/location/state/add';
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(stateData),
  );

  return response.statusCode == 201;
}

// 刪除地區
Future<bool> deleteRegion(int regionId) async {
  final url = '$baseUrl/location/region/delete/$regionId';
  final response = await http.delete(Uri.parse(url));

  return response.statusCode == 200;
}

// 刪除國家
Future<bool> deleteCountry(int countryId) async {
  final url = '$baseUrl/location/country/delete/$countryId';
  final response = await http.delete(Uri.parse(url));

  return response.statusCode == 200;
}

// 刪除州/省
Future<bool> deleteState(int stateId) async {
  final url = '$baseUrl/location/state/delete/$stateId';
  final response = await http.delete(Uri.parse(url));

  return response.statusCode == 200;
}

// 搜尋位置
Future<List<dynamic>> searchLocations(String query, String type) async {
  final url = '$baseUrl/location/search?query=$query&type=$type';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to search locations');
  }
}
*/

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  // TODO: 後續需要的狀態變數
  // Map<String, int> locationStats = {'regions': 6, 'countries': 250, 'states': 0};
  // List<dynamic> searchResults = [];
  // bool isLoading = true;
  // String searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  // TODO: 後續需要實現的初始化函數
  /*
  @override
  void initState() {
    super.initState();
    _loadLocationStats();
  }

  Future<void> _loadLocationStats() async {
    setState(() {
      isLoading = true;
    });

    try {
      final stats = await fetchLocationStats();

      setState(() {
        locationStats = stats;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('載入位置統計失敗: $e');
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
        title: const Text('位置管理'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red[50]!, Colors.red[100]!],
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
                      Icons.location_on,
                      size: 50,
                      color: Colors.red[700],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '位置管理中心',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '管理地區、國家和州/省數據',
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
                      '搜尋位置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: '輸入地區、國家或州/省名稱...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.red[700]!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            // TODO: 實現搜尋功能
                            _showComingSoon('搜尋功能');
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('搜尋'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 功能按鈕區域
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
                      '管理功能',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          '新增',
                          Icons.add,
                          Colors.green,
                              () => _showLocationTypeDialog('新增'),
                        ),
                        _buildActionButton(
                          '刪除',
                          Icons.delete,
                          Colors.orange,
                              () => _showLocationTypeDialog('刪除'),
                        ),
                        _buildActionButton(
                          '查詢',
                          Icons.search,
                          Colors.blue,
                              () => _showLocationTypeDialog('查詢'),
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
                      '統計資訊',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          '地區總數',
                          '0' /* TODO: 後續改為 '${locationStats['regions']}' */,
                          Icons.public,
                        ),
                        _buildStatItem(
                          '國家總數',
                          '0' /* TODO: 後續改為 '${locationStats['countries']}' */,
                          Icons.flag,
                        ),
                        _buildStatItem(
                          '州/省總數',
                          '0' /* TODO: 後續改為 '${locationStats['states']}' */,
                          Icons.location_city,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(30),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 40,
          color: Colors.red[600],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showLocationTypeDialog(String action) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('選擇$action類型'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.public, color: Colors.red[600]),
                title: const Text('地區'),
                subtitle: const Text('管理大洲級別的地區'),
                onTap: () {
                  Navigator.of(context).pop();
                  _handleLocationAction(action, 'region');
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.flag, color: Colors.red[600]),
                title: const Text('國家'),
                subtitle: const Text('管理國家級別的位置'),
                onTap: () {
                  Navigator.of(context).pop();
                  _handleLocationAction(action, 'country');
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.location_city, color: Colors.red[600]),
                title: const Text('州/省'),
                subtitle: const Text('管理州或省級別的位置'),
                onTap: () {
                  Navigator.of(context).pop();
                  _handleLocationAction(action, 'state');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  void _handleLocationAction(String action, String type) {
    String typeText = '';
    switch (type) {
      case 'region':
        typeText = '地區';
        break;
      case 'country':
        typeText = '國家';
        break;
      case 'state':
        typeText = '州/省';
        break;
    }

    switch (action) {
      case '新增':
        _showAddDialog(type, typeText);
        break;
      case '刪除':
        _showDeleteDialog(type, typeText);
        break;
      case '查詢':
        _showQueryDialog(type, typeText);
        break;
    }
  }

  void _showAddDialog(String type, String typeText) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController nameEnController = TextEditingController();
    final TextEditingController nameZhTwController = TextEditingController();
    final TextEditingController nameZhCnController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('新增$typeText'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type == 'region') ...[
                  TextField(
                    controller: nameEnController,
                    decoration: const InputDecoration(
                      labelText: '英文名稱',
                      hintText: '請輸入英文名稱',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameZhTwController,
                    decoration: const InputDecoration(
                      labelText: '繁體中文名稱',
                      hintText: '請輸入繁體中文名稱',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameZhCnController,
                    decoration: const InputDecoration(
                      labelText: '簡體中文名稱',
                      hintText: '請輸入簡體中文名稱',
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '$typeText名稱',
                      hintText: '請輸入$typeText名稱',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: 實現新增功能
                _showComingSoon('新增$typeText功能');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(String type, String typeText) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('刪除$typeText'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning,
                color: Colors.orange,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                '請選擇要刪除的$typeText',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '此功能尚未實現，請稍後再試',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: 實現刪除功能
                _showComingSoon('刪除$typeText功能');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  void _showQueryDialog(String type, String typeText) {
    final TextEditingController queryController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('查詢$typeText'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: queryController,
                decoration: InputDecoration(
                  labelText: '搜尋關鍵字',
                  hintText: '請輸入$typeText名稱',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '查詢結果將在此顯示',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: 實現查詢功能
                _showComingSoon('查詢$typeText功能');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('搜尋'),
            ),
          ],
        );
      },
    );
  }

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