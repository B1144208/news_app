import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
// 引入配置檔 (假設 config.dart 包含了 baseUrl)
import 'config.dart';
// 如果您還沒有創建 BookmarkPage.dart，請將這行註釋掉
// import 'BookmarkPage.dart';

// 新聞資料模型
class News {
  final String title;
  final String url;
  final String? coverImage;
  final String? publishDate;

  News({
    required this.title,
    required this.url,
    this.coverImage,
    this.publishDate,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      title: json['news_title'],
      url: json['origin_url'],
      // 使用 baseUrl
      coverImage: json['cover_image'] != null ? '$baseUrl/api/image/${json['cover_image']}' : null,
      publishDate: json['news_date'],
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  // 假設的用戶 ID (請替換為實際登入用戶的 ID)
  final int _currentUserId = 1;
  // 台灣的預設中心點 (備用)
  static const LatLng _taiwanCenter = LatLng(23.6978, 120.9605);

  double _currentZoom = 2;
  LatLng _currentCenter = _taiwanCenter;

  List<Marker> _markers = [];
  List<dynamic> _locations = [];
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _selectedLocation;
  bool _isPanelVisible = false;
  List<News> _newsList = [];

  // === 多級下拉選單相關狀態變數 ===
  String? _selectedRegion;
  String? _selectedCountry;
  String? _selectedState;

  List<String> _regions = [];
  List<String> _countries = [];
  List<String> _states = [];
  // ===================================

  @override
  void initState() {
    super.initState();
    // 啟動時先載入地點數據
    _fetchLocations();
    // 載入上次位置的邏輯移至 onMapReady 確保地圖控制器已連接
  }

  @override
  void dispose() {
    // 🌟 檢查：只在 _selectedLocation 有效且包含 ID 時才嘗試儲存 🌟
    if (_selectedLocation != null) {
      final int? regionId = _selectedLocation!['region_id'];
      final int? countryId = _selectedLocation!['country_id'];
      final int? stateId = _selectedLocation!['state_id'];

      // 確保至少有一個 ID 不是 null
      if (stateId != null || countryId != null || regionId != null) {
        // 優先級：State ID > Country ID > Region ID
        if (stateId != null) {
          _saveLastLocation(null, null, stateId); // 儲存 State ID
        } else if (countryId != null) {
          _saveLastLocation(null, countryId, null); // 儲存 Country ID
        } else if (regionId != null) {
          _saveLastLocation(regionId, null, null); // 儲存 Region ID
        }
      }
    }

    _searchController.dispose();
    super.dispose();
  }

  // === API: 獲取所有地點資料 (http://localhost:3000/api/location) ===
  Future<void> _fetchLocations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/location'));
      if (mounted && response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _locations = data['data'];
          _isLoading = false;

          // 初始化 Regions 列表
          _regions = _locations
              .map((loc) => loc['region_name_zh_tw'] as String)
              .where((region) => region.isNotEmpty)
              .toSet()
              .toList();
          _regions.sort();
        });
      } else if (mounted) {
        setState(() {
          _error = '無法從伺服器取得資料：${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '連線錯誤：請確認伺服器正在執行。';
          _isLoading = false;
        });
      }
    }
  }

  // === API: 讀取上次儲存的位置 ID (GET /api/user/action/search/location/news?userId=...) ===
  Future<void> _loadLastLocation() async {
    // 1. 確保所有地點資料已經載入
    if (_locations.isEmpty) {
      print('Location data is not yet loaded or is empty.');
      return;
    }

    // 1. 修正：將 userId 參數加入 URL 查詢字串中
    final uri = Uri.parse('$baseUrl/api/user/location/news')
        .replace(queryParameters: {'userId': _currentUserId.toString()});

    try {
      // 2. 修正：使用 http.get，並移除 body 參數
      final response = await http.get(
        uri,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 後端 searchUserAction 返回的是一個陣列
        final List<dynamic> results = data['data'];

        if (results.isNotEmpty) {
          final locationData = results.first;

          // 找出非 NULL 的 ID (以下邏輯保持不變)
          final int? stateId = locationData['state_id'];
          final int? countryId = locationData['country_id'];
          final int? regionId = locationData['region_id'];

          // 確定 ID 和 ID 類型
          final int? idToUse = stateId ?? countryId ?? regionId;
          String idKey = stateId != null ? 'state_id' :
          countryId != null ? 'country_id' :
          regionId != null ? 'region_id' : '';

          if (idToUse != null && idKey.isNotEmpty) {
            _setMapToLastLocation(idToUse, idKey);
          } else {
            // 如果 ID 為空，使用預設台灣
            _zoomToTaiwan();
          }
        } else {
          // 如果結果集為空，使用預設台灣
          _zoomToTaiwan();
        }
      } else {
        print('Error fetching last location: ${response.statusCode}');
        _zoomToTaiwan();
      }
    } catch (e) {
      print('Error loading last location: $e');
      _zoomToTaiwan();
    }
  }

  // === 輔助函數: 根據 ID 定位地圖 (上次位置 / 搜尋定位通用) ===
  void _setMapToLastLocation(int id, String idKey) {
    try {
      // 1. 在 _locations 列表中查找匹配的 ID
      final Map<String, dynamic>? targetLocation = _locations.firstWhere(
            (loc) => loc[idKey] == id,
        orElse: () => null,
      );

      if (targetLocation != null) {
        // 🌟 修正點：從 _locations 數據中提取經緯度，優先 State 坐標
        double? lat = double.tryParse(targetLocation['state_center_latitude']?.toString() ?? '');
        double? lng = double.tryParse(targetLocation['state_center_longitude']?.toString() ?? '');

        // 如果 State 坐標為空，則回退到 Country 坐標
        if (lat == null || lng == null) {
          lat = double.tryParse(targetLocation['country_center_latitude']?.toString() ?? '');
          lng = double.tryParse(targetLocation['country_center_longitude']?.toString() ?? '');
        }

        if (lat != null && lng != null) {
          final LatLng lastLocation = LatLng(lat, lng);

          // 2. 移動地圖視角並更新狀態
          setState(() {
            _currentCenter = lastLocation;
            _currentZoom = 10.0;
            _mapController.move(lastLocation, 10.0);

            _markers = [
              Marker(
                point: lastLocation,
                width: 80,
                height: 80,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40.0),
              ),
            ];
            _selectedLocation = targetLocation;
            _isPanelVisible = true;
          });

          // 載入新聞
          final locationType = targetLocation['state_id'] != null ? 'state' : 'country';
          final locationId = targetLocation['state_id'] ?? targetLocation['country_id'];
          _fetchNewsAndSetState(locationType, locationId);

        } else {
          print('坐標無效。ID: $id');
          _zoomToTaiwan();
        }
      } else {
        print('Location ID $id not found in local _locations data.');
        _zoomToTaiwan();
      }
    } catch (e) {
      print('Error setting map location: $e');
      _zoomToTaiwan();
    }
  }

  // === API: 儲存當前位置 ID (POST /api/user/location/news) ===
  Future<void> _saveLastLocation(int? regionId, int? countryId, int? stateId) async {
    // 雙重檢查：如果三個 ID 都是 null，則直接返回
    if (regionId == null && countryId == null && stateId == null) {
      print('Skipping location save: All IDs are null.');
      return;
    }

    final Map<String, dynamic> body = {
      "userId": _currentUserId,
      "dataId": 1, // 這裡 dataId 應該對應一個固定的 ID，如 1
      "clientIp": "127.0.0.1",
      "region_id": regionId,
      "country_id": countryId,
      "state_id": stateId,
      "actionType": "location", // 必須傳遞給後端
      "dataType": "news", // 必須傳遞給後端
    };
    // 移除所有為 null 的欄位
    body.removeWhere((key, value) => value == null);

    try {
      final response = await http.post(
        // 注意路由是 /api/action，而非 /api/user/location/news
        Uri.parse('$baseUrl/api/user/location/news'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        print('上次位置 ID 儲存成功');
      } else {
        print('上次位置 ID 儲存失敗: ${response.statusCode}');
      }
    } catch (e) {
      print('位置 ID 儲存連線錯誤: $e');
    }
  }

  // === 輔助函數: 定位到台灣 (預設/後備) ===
  void _zoomToTaiwan() {
    final taiwanLocation = _locations.firstWhere(
          (loc) =>
      (loc['country_name_zh_tw'] as String? ?? '') == '台灣' ||
          (loc['country_name_en'] as String? ?? '').toLowerCase() == 'taiwan',
      orElse: () => null,
    );

    LatLng targetCenter = _taiwanCenter;
    double targetZoom = 7;

    if (taiwanLocation != null) {
      final lat = double.tryParse(taiwanLocation['country_center_latitude'].toString());
      final lon = double.tryParse(taiwanLocation['country_center_longitude'].toString());

      if (lat != null && lon != null) {
        targetCenter = LatLng(lat, lon);
      }
    }

    setState(() {
      _currentCenter = targetCenter;
      _currentZoom = targetZoom;
      _mapController.move(_currentCenter, _currentZoom);
      _markers = [
        Marker(
          point: targetCenter,
          width: 80,
          height: 80,
          child: const Icon(Icons.home, color: Colors.green, size: 40.0),
        ),
      ];
      _isPanelVisible = false;
      _selectedLocation = taiwanLocation;
      _newsList = [];
    });
  }

  void _zoomIn() {
    setState(() {
      _currentZoom++;
      _mapController.move(_currentCenter, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom--;
      _mapController.move(_currentCenter, _currentZoom);
    });
  }

  // === 核心邏輯：根據關鍵字搜尋並定位地圖 ===
  void _searchLocation(String query) {
    if (query.isEmpty) {
      return;
    }

    final lowerCaseQuery = query.toLowerCase();

    // 從本地快取中搜尋
    final foundLocation = _locations.firstWhere(
          (location) {
        final zhTwMatch = (location['country_name_zh_tw'] as String? ?? '').contains(query) ||
            (location['state_name_zh_tw'] as String? ?? '').contains(query);

        final enCountryName = (location['country_name_en'] as String? ?? '').toLowerCase();
        final enStateName = (location['state_name_en'] as String? ?? '').toLowerCase();

        final enMatch = enCountryName.contains(lowerCaseQuery) || enStateName.contains(lowerCaseQuery);

        return zhTwMatch || enMatch;
      },
      orElse: () => null,
    );

    if (foundLocation != null) {
      // 取得地點的 ID 和類型
      final int? stateId = foundLocation['state_id'];
      final int? countryId = foundLocation['country_id'];
      final int? regionId = foundLocation['region_id'];

      // 確定 ID 和 ID 類型
      final int? idToUse = stateId ?? countryId ?? regionId;
      String idKey = stateId != null ? 'state_id' :
      countryId != null ? 'country_id' :
      regionId != null ? 'region_id' : '';

      if (idToUse != null && idKey.isNotEmpty) {
        _setMapToLastLocation(idToUse, idKey);
      }
    } else {
      setState(() {
        _isPanelVisible = false;
        _newsList = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('找不到該地點。'))
      );
    }
  }

  // ========================================================

  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    // 這裡的邏輯是找出點擊點最近的地點，並進行定位和新聞載入
    final nearestLocation = _findNearestLocation(latlng);
    if (nearestLocation != null) {
      final int? stateId = nearestLocation['state_id'];
      final int? countryId = nearestLocation['country_id'];
      final int? regionId = nearestLocation['region_id'];

      final int? idToUse = stateId ?? countryId ?? regionId;
      String idKey = stateId != null ? 'state_id' :
      countryId != null ? 'country_id' :
      regionId != null ? 'region_id' : '';

      if (idToUse != null && idKey.isNotEmpty) {
        _setMapToLastLocation(idToUse, idKey);
      }
    } else {
      setState(() {
        _isPanelVisible = false;
        _newsList = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('附近沒有可用的地點資料。'))
      );
    }
  }

  // 輔助函式：計算兩點距離
  double _calculateHaversineDistance(LatLng start, LatLng end) {
    const R = 6371;
    final lat1Rad = start.latitude * pi / 180;
    final lon1Rad = start.longitude * pi / 180;
    final lat2Rad = end.latitude * pi / 180;
    final lon2Rad = end.longitude * pi / 180;

    final dLat = lat2Rad - lat1Rad;
    final dLon = lon2Rad - lon1Rad;

    final a = pow(sin(dLat / 2), 2) + cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  Map<String, dynamic>? _findNearestLocation(LatLng tapLatLng) {
    if (_locations.isEmpty) return null;

    double minDistanceKm = double.infinity;
    const double maxDistanceKm = 200.0;
    Map<String, dynamic>? nearestLocation;

    for (var location in _locations) {
      LatLng? locationLatLng;

      final stateLat = double.tryParse(location['state_center_latitude'].toString());
      final stateLon = double.tryParse(location['state_center_longitude'].toString());
      if (stateLat != null && stateLon != null) {
        locationLatLng = LatLng(stateLat, stateLon);
      } else {
        final countryLat = double.tryParse(location['country_center_latitude'].toString());
        final countryLon = double.tryParse(location['country_center_longitude'].toString());
        if (countryLat != null && countryLon != null) {
          locationLatLng = LatLng(countryLat, countryLon);
        }
      }

      if (locationLatLng != null) {
        final distance = _calculateHaversineDistance(locationLatLng, tapLatLng);

        if (distance < minDistanceKm && distance <= maxDistanceKm) {
          minDistanceKm = distance;
          nearestLocation = location;
        }
      }
    }

    return nearestLocation;
  }

  // 輔助函式：載入新聞並更新狀態
  Future<void> _fetchNewsAndSetState(String locationType, int locationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/news?locationId=$locationId&locationType=$locationType'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> newsData = data['data'];
        final fetchedNews = newsData.map((json) => News.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            _newsList = fetchedNews;
          });
        }
      } else {
        throw Exception('無法取得新聞資料');
      }
    } catch (e) {
      print('新聞載入錯誤: $e');
      if (mounted) {
        setState(() {
          _newsList = [];
        });
      }
    }
  }

  // ===================================
  // 三級聯動下拉選單邏輯 (保持不變)
  // ===================================

  void _onRegionChanged(String? newRegion) {
    setState(() {
      _selectedRegion = newRegion;
      _selectedCountry = null;
      _selectedState = null;
      _states = [];

      if (newRegion != null) {
        _countries = _locations
            .where((loc) => loc['region_name_zh_tw'] == newRegion)
            .map((loc) => loc['country_name_zh_tw'] as String)
            .toSet()
            .toList();
        _countries.sort();
      } else {
        _countries = [];
      }

      _searchController.clear();
      _isPanelVisible = false;
      _markers = [];
      _selectedLocation = null;
    });
  }

  void _onCountryChanged(String? newCountry) {
    setState(() {
      _selectedCountry = newCountry;
      _selectedState = null;

      if (newCountry != null) {
        _states = _locations
            .where((loc) =>
        loc['country_name_zh_tw'] == newCountry &&
            (loc['state_name_en'] as String? ?? '').isNotEmpty)
            .map((loc) => loc['state_name_en'] as String)
            .toSet()
            .toList();
        _states.sort();
      } else {
        _states = [];
      }

      _searchController.clear();
      _isPanelVisible = false;
      _markers = [];
      _selectedLocation = null;
    });
  }

  void _onStateChanged(String? newState) {
    setState(() {
      _selectedState = newState;
    });

    _searchController.clear();
  }

  // 處理點擊「定位/搜尋」按鈕的邏輯
  void _handleDropdownSearch() {
    String? searchTarget;

    if (_selectedState != null) {
      searchTarget = _selectedState;
    } else if (_selectedCountry != null) {
      searchTarget = _selectedCountry;
    }

    if (searchTarget != null) {
      _searchLocation(searchTarget);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先選擇國家或州/省。'))
      );
    }
  }

  // ===================================
  // UI 構建輔助函式 (保持不變)
  // ===================================

  Widget _buildDropdown(
      String hintText,
      String? selectedValue,
      List<String> items,
      ValueChanged<String?> onChanged,
      bool isEnabled,
      ) {
    // ... (Dropdown 實現) ...
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            hint: Text(hintText),
            value: selectedValue,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down),
            onChanged: isEnabled ? onChanged : null,
            items: items.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, overflow: TextOverflow.ellipsis),
              );
            }).toList(),

            disabledHint: Text(hintText, style: TextStyle(color: Colors.grey[400])),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFilters() {
    // ... (Dropdown 佈局) ...
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
      child: Row(
        children: [
          _buildDropdown(
            '地區',
            _selectedRegion,
            _regions,
            _onRegionChanged,
            true,
          ),
          const SizedBox(width: 8),

          _buildDropdown(
            '國家',
            _selectedCountry,
            _countries,
            _onCountryChanged,
            _selectedRegion != null,
          ),
          const SizedBox(width: 8),

          _buildDropdown(
            '州/省',
            _selectedState,
            _states,
            _onStateChanged,
            _selectedCountry != null,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton() {
    // 只有當 Country 或 State 有選擇時，按鈕才啟用
    final isEnabled = _selectedCountry != null || _selectedState != null;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
      child: ElevatedButton.icon(
        onPressed: isEnabled ? _handleDropdownSearch : null,
        icon: const Icon(Icons.location_searching),
        label: Text(_selectedState != null ? '定位到州/省' : '定位到國家'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }


  Widget _buildRightPanel() {
    if (_selectedLocation == null) {
      return const SizedBox.shrink();
    }

    final String countryName = _selectedLocation!['country_name_zh_tw'] ?? '未知國家';
    final String regionName = _selectedLocation!['region_name_zh_tw'] ?? '未知地區';
    final String stateName = _selectedLocation!['state_name_en'] ?? '未提供';
    final lat = _selectedLocation!['country_center_latitude'];
    final lon = _selectedLocation!['country_center_longitude'];

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  countryName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isPanelVisible = false;
                    _newsList = [];
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.public, color: Colors.grey),
            title: Text('地區：$regionName'),
          ),
          ListTile(
            leading: const Icon(Icons.map, color: Colors.grey),
            title: Text('州/省：$stateName'),
          ),
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.grey),
            title: Text('經緯度：$lat, $lon'),
          ),
          const SizedBox(height: 20),
          const Text(
            '相關新聞',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
          if (_newsList.isEmpty)
            const Text('目前沒有相關新聞。')
          else
            Expanded(
              child: ListView.builder(
                itemCount: _newsList.length,
                itemBuilder: (context, index) {
                  final news = _newsList[index];
                  return Card(
                    child: ListTile(
                      title: Text(news.title),
                      subtitle: Text(news.publishDate ?? ''),
                      onTap: () {
                        // TODO: 點擊後開啟新聞連結
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ===================================
  // 主要 Build 函式
  // ===================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // === 頂部 AppBar 與書籤圖標 ===
      appBar: AppBar(
        title: const Text('世界地圖'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('書籤功能待實作')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // =================================

      body: Column(
        children: [
          // 搜尋欄
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '輸入地點名稱（中/英）搜尋...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: _searchLocation,
            ),
          ),

          // === 下拉選單和搜尋按鈕區塊 ===
          if (!_isLoading && _error == null)
            Column(
              children: [
                _buildDropdownFilters(), // 三個下拉選單
                _buildSearchButton(),    // 定位按鈕
              ],
            ),
          // ==============================

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : Row(
              children: [
                Expanded(
                  flex: _isPanelVisible ? 2 : 1,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentCenter,
                          initialZoom: _currentZoom,
                          onMapEvent: (event) {
                            if (event is MapEventMoveEnd) {
                              // 更新中心點和 Zoom 級別
                              _currentCenter = event.camera.center;
                              _currentZoom = event.camera.zoom;
                            }
                          },
                          // 🌟 修正點：地圖準備就緒後，載入上次位置
                          onMapReady: () {
                            if (_locations.isNotEmpty) {
                              _loadLastLocation();
                            } else {
                              _zoomToTaiwan();
                            }
                          },
                          onTap: _handleMapTap,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          MarkerLayer(markers: _markers),
                        ],
                      ),
                      // 縮放按鈕
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Column(
                          children: [
                            FloatingActionButton(
                              heroTag: "zoomIn",
                              mini: true,
                              onPressed: _zoomIn,
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton(
                              heroTag: "zoomOut",
                              mini: true,
                              onPressed: _zoomOut,
                              child: const Icon(Icons.remove),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isPanelVisible)
                  Expanded(
                    flex: 1,
                    child: _buildRightPanel(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}