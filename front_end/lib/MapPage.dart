import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

// 引入配置檔 (假設 config.dart 包含了 baseUrl)
import 'config.dart';
// 如果您還沒有創建 BookmarkPage.dart，請將這行註釋掉
import 'BookmarkPage.dart';

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
      coverImage: json['cover_image'] != null ? '$baseUrl/image/${json['cover_image']}' : null,
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

  static const String _kUnselectOption = '--- [未選取] ---';

  final int _currentUserId = 1; // 假定的用戶 ID
  static const LatLng _taiwanCenter = LatLng(23.6978, 120.9605);
  static const double _kMaxSearchDistanceKm = 10000.0;

  double _currentZoom = 2;
  LatLng _currentCenter = _taiwanCenter;
  String _displayCoordinates = '緯度: 23.7, 經度: 120.9';

  List<Marker> _markers = [];
  List<dynamic> _locations = [];
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _selectedLocation;
  bool _isPanelVisible = false;
  List<News> _newsList = [];

  // === 分級新聞狀態：追蹤目前顯示的新聞類型 ===
  String _currentNewsScope = 'country';

  // === 多級下拉選單相關狀態變數 ===
  String? _selectedRegion;
  String? _selectedCountry;
  String? _selectedState;

  List<String> _regions = [];
  List<String> _countries = [];
  List<String> _states = [];
  // ===================================

  List<String> get _regionsForDropdown {
    if (_regions.isEmpty) return [_kUnselectOption];
    return [_kUnselectOption, ..._regions];
  }

  List<String> get _countriesForDropdown {
    if (_countries.isEmpty) return [_kUnselectOption];
    return [_kUnselectOption, ..._countries];
  }

  List<String> get _statesForDropdown {
    if (_states.isEmpty) return [_kUnselectOption];
    return [_kUnselectOption, ..._states];
  }

  // === 輔助函式：安全地從 Map 中取得並解析 ID 為 int (處理 NULL, 0, 和 String) ===
  int? _safeId(String key, Map<String, dynamic> locationData) {
    final value = locationData[key];
    if (value == null) return null; // 處理 JSON null

    if (value is int) {
      return value == 0 ? null : value; // 處理數值 0
    }
    if (value is String) {
      if (value.isEmpty || value == '0') return null; // 處理空字串或字串 "0"
      return int.tryParse(value);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fetchLocations(baseUrl);
  }

  @override
  void dispose() {
    int? countryIdToSave;

    // 嘗試從當前選取中找到 Country ID
    if (_selectedLocation != null) {
      countryIdToSave = _safeId('country_id', _selectedLocation!);
    }

    _saveLastLocation(countryIdToSave ?? 0);

    super.dispose();
  }

  // === 輔助函數: 定位到台灣 (預設/後備) ===
  void _zoomToTaiwan() {
    LatLng targetCenter = _taiwanCenter;
    double targetZoom = 7;

    final taiwanLocation = _locations.firstWhere(
          (loc) => (loc['country_name_zh_tw'] as String? ?? '') == '台灣' ||
          (loc['country_name_en'] as String? ?? '').toLowerCase() == 'taiwan',
      orElse: () => null,
    );
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
          child: const Icon(Icons.location_on, color: Colors.red, size: 40.0),
        ),
      ];
      _isPanelVisible = false;
      _selectedLocation = null;
      _newsList = [];
    });
  }

  // === 縮放控制函式 ===
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

  // === 輔助函式：載入新聞並更新狀態 ===
  Future<void> _fetchNewsAndSetState(String locationType, int locationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/news?locationId=$locationId&locationType=$locationType'),
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
      if (mounted) {
        setState(() {
          _newsList = [];
        });
      }
    }
  }

  // 輔助函式：計算兩點距離 (Haversine 公式)
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

  // 輔助函式: 尋找最近地點
  Map<String, dynamic>? _findNearestLocation(LatLng tapLatLng) {
    if (_locations.isEmpty) return null;

    double minDistanceKm = double.infinity;
    const double maxDistanceKm = _kMaxSearchDistanceKm;
    Map<String, dynamic>? nearestLocation;

    for (var location in _locations) {
      LatLng? locationLatLng;
      final stateLat = double.tryParse(location['state_center_latitude']?.toString() ?? '');
      final stateLon = double.tryParse(location['state_center_longitude']?.toString() ?? '');
      if (stateLat != null && stateLon != null) {
        locationLatLng = LatLng(stateLat, stateLon);
      } else {
        final countryLat = double.tryParse(location['country_center_latitude']?.toString() ?? '');
        final countryLon = double.tryParse(location['country_center_longitude']?.toString() ?? '');
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

  // ===================================
  // 新聞切換邏輯 (接收目標範圍參數)
  // 🌟 修正：使用 safeId 確保 ID 準確 🌟
  // ===================================
  void _toggleNewsScope({required String targetScope}) {
    if (_selectedLocation == null) return;

    final int? stateId = _safeId('state_id', _selectedLocation!);
    final int? regionId = _safeId('region_id', _selectedLocation!);
    final int? countryId = _safeId('country_id', _selectedLocation!);

    int? locationId;
    String locationType;

    if (targetScope == 'country') {
      locationId = countryId;
      locationType = 'country';
    } else if (targetScope == 'state') {
      locationId = stateId;
      locationType = 'state';
    } else if (targetScope == 'region') {
      locationId = regionId;
      locationType = 'region';
    } else {
      return;
    }

    if (locationId != null && locationId != 0) {
      setState(() {
        _currentNewsScope = locationType;
        _newsList = [];
      });
      _fetchNewsAndSetState(locationType, locationId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('該地點沒有 ${targetScope == 'country' ? '國家' : targetScope == 'state' ? '州/省' : '地區'} 的新聞資料。'))
      );
    }
  }


  // ===================================
  // UI 構建輔助函式
  // ===================================

  Widget _buildDropdown(
      String hintText,
      String? selectedValue,
      List<String> items,
      ValueChanged<String?> onChanged,
      bool isEnabled,
      ) {
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
            value: selectedValue == _kUnselectOption ? null : selectedValue,
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
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
      child: Row(
        children: [
          _buildDropdown(
            '地區',
            _selectedRegion,
            _regionsForDropdown,
            _onRegionChanged,
            true,
          ),
          const SizedBox(width: 8),

          _buildDropdown(
            '國家',
            _selectedCountry,
            _countriesForDropdown,
            _onCountryChanged,
            _selectedRegion != null && _selectedRegion != _kUnselectOption,
          ),
          const SizedBox(width: 8),

          _buildDropdown(
            '州/省',
            _selectedState,
            _statesForDropdown,
            _onStateChanged,
            _selectedCountry != null && _selectedCountry != _kUnselectOption && _states.isNotEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton() {
    final isEnabled = _selectedRegion != null && _selectedRegion != _kUnselectOption;

    String buttonText = '定位';
    if (_selectedState != null && _selectedState != _kUnselectOption) {
      buttonText = '定位到州/省';
    } else if (_selectedCountry != null && _selectedCountry != _kUnselectOption) {
      buttonText = '定位到國家';
    } else if (_selectedRegion != null && _selectedRegion != _kUnselectOption) {
      buttonText = '定位到地區';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
      child: ElevatedButton.icon(
        onPressed: isEnabled ? _handleDropdownSearch : null,
        icon: const Icon(Icons.location_searching),
        label: Text(buttonText),
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

  // 🌟 修正：使用 safeId 檢查按鈕狀態，並實作雙按鈕邏輯 🌟
  Widget _buildRightPanel() {
    if (_selectedLocation == null) {
      return const SizedBox.shrink();
    }

    final String countryName = _selectedLocation!['country_name_zh_tw'] ?? '未知國家';
    final String regionName = _selectedLocation!['region_name_zh_tw'] ?? '未知地區';
    final String stateName = _selectedLocation!['state_name_en'] ?? '未提供';
    final lat = _selectedLocation!['country_center_latitude'];
    final lon = _selectedLocation!['country_center_longitude'];

    // 檢查個別的細分範圍是否存在 (使用安全檢查)
    final bool hasStateScope = _safeId('state_id', _selectedLocation!) != null;
    final bool hasRegionScope = _safeId('region_id', _selectedLocation!) != null;

    // 判斷是否有任何細分地區可以切換 (State or Region)
    final bool hasSubScope = hasStateScope || hasRegionScope;

    String scopeText;
    if (_currentNewsScope == 'country') {
      scopeText = '$countryName (國家級)';
    } else if (_currentNewsScope == 'state') {
      scopeText = '$stateName (州/省級)';
    } else {
      scopeText = '$regionName (地區級)';
    }

    // === 定義按鈕組件的函式 (雙按鈕邏輯) ===
    Widget buildStateRegionButtons() {
      if (_currentNewsScope != 'country') return const SizedBox.shrink();

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasRegionScope) // 只要有 Region ID 就顯示
            Padding(
              padding: EdgeInsets.only(right: hasStateScope ? 8.0 : 0.0),
              child: ElevatedButton(
                onPressed: () => _toggleNewsScope(targetScope: 'region'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('往地區新聞', style: TextStyle(fontSize: 12)),
              ),
            ),

          if (hasStateScope) // 只要有 State ID 就顯示
            ElevatedButton(
              onPressed: () => _toggleNewsScope(targetScope: 'state'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 30),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('往州/省新聞', style: TextStyle(fontSize: 12)),
            ),
        ],
      );
    }

    // ============================

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
                    _selectedLocation = null;
                    _markers = [];
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

          // === 新聞切換區域 (最終呈現) ===
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '相關新聞',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '目前顯示：$scopeText',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              if (hasSubScope)
                _currentNewsScope == 'country'
                    ? buildStateRegionButtons()
                    : ElevatedButton(
                  onPressed: () => _toggleNewsScope(targetScope: 'country'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 30),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('返回國家新聞', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const Divider(),
          // ===================================

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
  // 下拉選單/搜尋/地圖點擊邏輯
  // ===================================

  void _onRegionChanged(String? newRegion) {
    if (newRegion == _kUnselectOption || newRegion == null) {
      setState(() {
        _selectedRegion = null;
        _selectedCountry = null;
        _selectedState = null;
        _countries = [];
        _states = [];
        _selectedLocation = null;
        _markers = [];
        _isPanelVisible = false;
      });
      _saveLastLocation(0);
      return;
    }
    setState(() {
      _selectedRegion = newRegion;
      _selectedCountry = null;
      _selectedState = null;
      _states = [];
      _countries = _locations
          .where((loc) => loc['region_name_zh_tw'] == newRegion)
          .map((loc) => loc['country_name_zh_tw'] as String)
          .where((country) => country.isNotEmpty)
          .toSet()
          .toList();
      _countries.sort();
      _selectedLocation = null;
      _markers = [];
      _isPanelVisible = false;
    });
    _searchController.clear();
  }

  void _onCountryChanged(String? newCountry) {
    if (newCountry == _kUnselectOption || newCountry == null) {
      setState(() {
        _selectedCountry = null;
        _selectedState = null;
        _states = [];
        _selectedLocation = null;
        _markers = [];
        _isPanelVisible = false;
      });
      _saveLastLocation(0);
      return;
    }
    setState(() {
      _selectedCountry = newCountry;
      _selectedState = null;
      _states = _locations
          .where((loc) =>
      loc['country_name_zh_tw'] == newCountry &&
          (loc['state_name_en'] as String? ?? '').isNotEmpty)
          .map((loc) => loc['state_name_en'] as String)
          .toSet()
          .toList();
      _states.sort();
      _selectedLocation = null;
      _markers = [];
      _isPanelVisible = false;
    });
    _searchController.clear();
  }

  void _onStateChanged(String? newState) {
    if (newState == _kUnselectOption || newState == null) {
      setState(() {
        _selectedState = null;
        _selectedLocation = null;
        _markers = [];
        _isPanelVisible = false;
      });
      _searchController.clear();
      return;
    }
    setState(() {
      _selectedState = newState;
      _selectedLocation = null;
      _markers = [];
      _isPanelVisible = false;
    });
    _searchController.clear();
  }

  // === API: 獲取所有地點資料 ===
  Future<void> _fetchLocations(String baseUrl) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/location'));
      if (mounted && response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _locations = data['data'];
          _isLoading = false;
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

  // === API: 讀取上次儲存的位置 ID ===
  Future<void> _loadLastLocation() async {
    if (_locations.isEmpty) return;
    final uri = Uri.parse('$baseUrl/user');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['data'];
        final userData = results.firstWhere(
              (user) => user['user_id'] == _currentUserId,
          orElse: () => null,
        );
        if (userData != null) {
          final int? countryId = _safeId('location_country_id', userData);
          if (countryId != null && countryId != 0) {
            final Map<String, dynamic>? targetLocation = _locations.firstWhere(
                  (loc) => _safeId('country_id', loc) == countryId,
              orElse: () => null,
            );
            if (targetLocation != null) {
              _setMapToLastLocation(countryId, 'country_id');
              return;
            }
          }
        }
        _zoomToTaiwan();
      } else {
        _zoomToTaiwan();
      }
    } catch (e) {
      _zoomToTaiwan();
    }
  }

  // 替換您檔案中的 _setMapToLastLocation 函式
// 🌟 修正：強制將新聞範圍設定為 country 🌟
  void _setMapToLastLocation(int id, String idKey) {
    try {
      // 找出匹配地點 (使用傳入的 ID 和 Key 來找到地點資料行)
      final Map<String, dynamic>? targetLocation = _locations.firstWhere(
            (loc) => _safeId(idKey, loc) == id,
        orElse: () => null,
      );

      if (targetLocation != null) {
        double? lat;
        double? lng;
        double zoomLevel;

        // 使用最精確的經緯度進行定位（如果有 State/Region 資訊）
        final stateLat = double.tryParse(targetLocation['state_center_latitude']?.toString() ?? '');
        final stateLng = double.tryParse(targetLocation['state_center_longitude']?.toString() ?? '');
        final countryLat = double.tryParse(targetLocation['country_center_latitude']?.toString() ?? '');
        final countryLng = double.tryParse(targetLocation['country_center_longitude']?.toString() ?? '');


        if (stateLat != null && stateLng != null) { // 優先使用 State 中心點
          lat = stateLat;
          lng = stateLng;
          zoomLevel = 9.0;
        } else if (countryLat != null && countryLng != null) { // 其次使用 Country 中心點
          lat = countryLat;
          lng = countryLng;
          zoomLevel = 7.0;
        } else {
          // 如果沒有足夠的經緯度，則返回
          _zoomToTaiwan();
          return;
        }

        final LatLng targetLatLng = LatLng(lat, lng);

        // 找到該地點的 Country ID
        final int? countryIdForNews = _safeId('country_id', targetLocation);

        if (countryIdForNews != null) {
          setState(() {
            _currentCenter = targetLatLng;
            _currentZoom = zoomLevel;
            _mapController.move(targetLatLng, zoomLevel);

            _markers = [
              Marker(
                point: targetLatLng,
                width: 100,
                height: 100,
                child: const Icon(Icons.location_on, color: Colors.blueAccent, size: 50.0),
              ),
            ];
            _selectedLocation = targetLocation;
            _isPanelVisible = true;

            // 🚨 點擊後，強制新聞範圍為 'country'
            _currentNewsScope = 'country';
          });

          // 使用 Country ID 抓取新聞
          _fetchNewsAndSetState('country', countryIdForNews);
        } else {
          _zoomToTaiwan();
        }

      } else {
        _zoomToTaiwan();
      }
    } catch (e) {
      _zoomToTaiwan();
    }
  }

  // === API: 儲存當前位置 ID ===
  Future<void> _saveLastLocation(int? countryId) async {
    if (countryId == null) return;

    final Map<String, dynamic> body = {
      "user_id": _currentUserId,
      "location_country_id": countryId,
    };

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        // success
      } else {
        // failure
      }
    } catch (e) {
      // error
    }
  }

  // === 核心邏輯：根據關鍵字搜尋並定位地圖 ===
  void _searchLocation(String query) {
    if (query.isEmpty) return;

    final lowerCaseQuery = query.toLowerCase();

    final foundExactLocation = _locations.firstWhere(
          (location) {
        final zhTwCountryName = (location['country_name_zh_tw'] as String? ?? '');
        final zhTwStateName = (location['state_name_zh_tw'] as String? ?? '');
        final enCountryName = (location['country_name_en'] as String? ?? '');
        final enStateName = (location['state_name_en'] as String? ?? '');

        return zhTwCountryName == query ||
            zhTwStateName == query ||
            enCountryName.toLowerCase() == lowerCaseQuery ||
            enStateName.toLowerCase() == lowerCaseQuery;
      },
      orElse: () => null,
    );

    final foundLocation = foundExactLocation ?? _locations.firstWhere(
          (location) {
        final zhTwMatch = (location['country_name_zh_tw'] as String? ?? '').contains(query) ||
            (location['state_name_zh_tw'] as String? ?? '').contains(query) ||
            (location['region_name_zh_tw'] as String? ?? '').contains(query);

        final enCountryName = (location['country_name_en'] as String? ?? '').toLowerCase();
        final enStateName = (location['state_name_en'] as String? ?? '').toLowerCase();

        final enMatch = enCountryName.contains(lowerCaseQuery) || enStateName.contains(lowerCaseQuery);

        return zhTwMatch || enMatch;
      },
      orElse: () => null,
    );

    if (foundLocation != null) {
      final int? stateId = _safeId('state_id', foundLocation);
      final int? countryId = _safeId('country_id', foundLocation);
      final int? regionId = _safeId('region_id', foundLocation);

      final int? idToUse = stateId ?? countryId ?? regionId;
      String idKey = stateId != null ? 'state_id' :
      countryId != null ? 'country_id' :
      regionId != null ? 'region_id' : '';

      if (idToUse != null && idKey.isNotEmpty) {
        _setMapToLastLocation(idToUse, idKey);

        final int? countryIdToSave = _safeId('country_id', foundLocation);
        if (countryIdToSave != null) {
          _saveLastLocation(countryIdToSave);
        }
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

// === 地圖點擊尋找最近地點邏輯 ===
  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    final nearestLocation = _findNearestLocation(latlng);
    if (nearestLocation != null) {
      // 1. 取得所有 ID
      final int? stateId = _safeId('state_id', nearestLocation);
      final int? countryId = _safeId('country_id', nearestLocation);
      final int? regionId = _safeId('region_id', nearestLocation);

      // 2. 確定用於【定位】的 ID 和 Key (State > Country > Region)
      int? idToUseForLocation;
      String idKeyForLocation;

      if (stateId != null) {
        idToUseForLocation = stateId;
        idKeyForLocation = 'state_id';
      } else if (countryId != null) {
        idToUseForLocation = countryId;
        idKeyForLocation = 'country_id';
      } else if (regionId != null) {
        idToUseForLocation = regionId;
        idKeyForLocation = 'region_id';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('該地點沒有可用的地理 ID 進行定位。'))
        );
        return;
      }

      // 3. 執行定位和新聞抓取
      if (idToUseForLocation != null) {
        // _setMapToLastLocation 會使用最精確的經緯度（State > Country）來定位地圖
        _setMapToLastLocation(idToUseForLocation, idKeyForLocation);

        // 4. 儲存最後地點 (始終儲存 Country ID)
        final int? countryIdToSave = countryId;
        if (countryIdToSave != null) {
          _saveLastLocation(countryIdToSave);
        }
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

  // 處理點擊「定位/搜尋」按鈕的邏輯
  void _handleDropdownSearch() {
    String? searchTarget;
    int? countryIdToSave;
    Map<String, dynamic>? targetLocation;

    if (_selectedState != null && _selectedState != _kUnselectOption) {
      searchTarget = _selectedState;
      targetLocation = _locations.firstWhere(
            (loc) => loc['state_name_en'] == _selectedState && loc['country_name_zh_tw'] == _selectedCountry,
        orElse: () => null,
      );
      countryIdToSave = targetLocation != null ? _safeId('country_id', targetLocation) : null;

    } else if (_selectedCountry != null && _selectedCountry != _kUnselectOption) {
      searchTarget = _selectedCountry;
      targetLocation = _locations.firstWhere(
            (loc) => loc['country_name_zh_tw'] == _selectedCountry,
        orElse: () => null,
      );
      countryIdToSave = targetLocation != null ? _safeId('country_id', targetLocation) : null;

    } else if (_selectedRegion != null && _selectedRegion != _kUnselectOption) {
      searchTarget = _selectedRegion;
      countryIdToSave = null;

    } else {
      _zoomToTaiwan();
      _saveLastLocation(0);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地點已清除，定位至世界中心。'))
      );
      return;
    }

    if (searchTarget != null) {
      _searchLocation(searchTarget);

      if (countryIdToSave != null) {
        _saveLastLocation(countryIdToSave);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    _displayCoordinates =
    '緯度: ${_currentCenter.latitude.toStringAsFixed(3)}, 經度: ${_currentCenter.longitude.toStringAsFixed(3)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('世界地圖'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookmarkPage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                _buildDropdownFilters(),
                _buildSearchButton(),
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
                          cameraConstraint: CameraConstraint.contain(
                            bounds: LatLngBounds(
                              LatLng(-90, -180),
                              LatLng(90, 180),
                            ),
                          ),
                          onMapEvent: (event) {
                            if (event is MapEventMoveEnd) {
                              setState(() {
                                _currentCenter = event.camera.center;
                                _currentZoom = event.camera.zoom;
                              });
                            }
                          },
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

                      // 經緯度顯示框
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _displayCoordinates,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
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