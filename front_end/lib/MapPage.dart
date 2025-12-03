import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

// 引入配置檔 (假設 config.dart 包含了 baseUrl)
import 'config.dart';
// 如果您還沒有創建 BookmarkPage.dart，請將這行註釋掉
import 'BookmarkPage.dart';
// 💥 1. 新增：引入 ViewNewsContent 頁面
import 'ViewNewsContent.dart';

// 新聞資料模型 (保持不變)
class News {
  // 💥 2. 欄位調整：保留 ViewNewsContent 需要的欄位，但更新註釋
  final int id; // newsId
  final int channelId; // (從 channelName 轉換，假設為 1)
  final int commentsCount; // (後端未提供，預設為 0)

  final String title; // newsTitle
  final String url; // (後端未提供 origin_url，暫時留空或預設)
  final String? coverImage; // coverImageUrl
  final String? publishDate; // publishDate
  final String? sourceName; // channelName

  News({
    required this.id,
    required this.channelId,
    required this.commentsCount,
    required this.title,
    required this.url,
    this.coverImage,
    this.publishDate,
    this.sourceName,
  });

  // 🚨 修正點 1: 根據新的後端 JSON 欄位名稱進行調整 🚨
  factory News.fromJson(Map<String, dynamic> json) {
    // 確保 ID 欄位是 int (使用 'newsId')
    final newsId = int.tryParse(json['newsId']?.toString() ?? '0') ?? 0;

    // 後端未提供 channel_id 和 total_comment，使用預設值或安全值
    final channelId = 1; // 預設值
    final commentsCount =
        int.tryParse(json['total_comment']?.toString() ?? '0') ??
        0; // 後端未提供 total_comment

    // 後端未提供 origin_url，使用預設值
    final originUrl = json['origin_url'] ?? '#';

    return News(
      id: newsId,
      channelId: channelId,
      commentsCount: commentsCount,
      title: json['newsTitle'] ?? '無標題', // 使用 'newsTitle'
      url: originUrl, // 保持不變，如果後端未來提供 origin_url
      // 使用 'coverImageUrl' 欄位
      coverImage: json['coverImageUrl'],
      publishDate: json['publishDate'], // 使用 'publishDate'
      sourceName: json['channelName'], // 使用 'channelName' 作為來源
    );
  }

  // 輔助函式：將 News 物件轉換成 ViewNewsContent 期望的 Map 格式
  Map<String, dynamic> toNewsDataMap() {
    return {
      'id': id,
      'title': title,
      'channel_id': channelId,
      'channel': sourceName ?? '未知來源', // 使用 sourceName 作為 channel 名稱
      'news_date': publishDate,
      'comments': commentsCount,
      // 這裡傳遞 news_id 作為 cover_image 的 ID，讓 ViewNewsContent 決定如何處理
      'cover_image': coverImage, // 傳遞完整的 URL 讓 ViewNewsContent 處理
    };
  }
}

// 💥 介面重構：主頁面為新聞列表
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

// 💥 狀態變數保留/調整
class _MapPageState extends State<MapPage> {
  final TextEditingController _searchController = TextEditingController();

  static const String _kUnselectOption = '--- [未選取] ---';
  static const LatLng _taiwanCenter = LatLng(23.6978, 120.9605);

  int? _currentUserId;
  List<dynamic> _locations = []; // 所有地點資料
  bool _isLoading = true;
  String? _error;

  // 💥 用來追蹤當前顯示新聞的地點
  Map<String, dynamic>? _currentNewsLocation;
  List<News> _newsList = [];
  String _currentNewsScope = 'country'; // country/state/region

  // 💥 下拉選單狀態 (用於對話框)
  String? _selectedRegion;
  String? _selectedCountry;
  String? _selectedState;
  List<String> _regions = [];
  List<String> _countries = [];
  List<String> _states = [];

  // 💥 輔助函式 (從原 MapPage 移入)
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

  int? _safeId(String key, Map<String, dynamic> locationData) {
    final value = locationData[key];
    if (value == null) return null;

    if (value is int) {
      return value == 0 ? null : value;
    }
    if (value is String) {
      if (value.isEmpty || value == '0') return null;
      return int.tryParse(value);
    }
    return null;
  }

  // 💥 生命週期方法 (保留並調整)
  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      _fetchLocations(baseUrl).then((_) {
        if (!_isLoading && _error == null) {
          _loadLastLocation(); // 載入最後位置並取得新聞
        } else {
          // 如果載入失敗，預設載入台灣或世界中心的新聞
          _loadDefaultNews();
        }
      });
    });
  }

  @override
  void dispose() {
    int? countryIdToSave;
    if (_currentNewsLocation != null) {
      countryIdToSave = _safeId('country_id', _currentNewsLocation!);
    }
    _saveLastLocation(countryIdToSave ?? 0);
    _searchController.dispose();
    super.dispose();
  }

  // 💥 新增：載入預設新聞（台灣）
  void _loadDefaultNews() {
    final taiwanLocation = _locations.firstWhere(
      (loc) =>
          (loc['country_name_zh_tw'] as String? ?? '') == '台灣' ||
          (loc['country_name_en'] as String? ?? '').toLowerCase() == 'taiwan',
      orElse: () => null,
    );

    if (taiwanLocation != null) {
      final countryId = _safeId('country_id', taiwanLocation);
      if (countryId != null) {
        setState(() {
          _currentNewsLocation = taiwanLocation;
          _currentNewsScope = 'country';
        });
        _fetchNewsAndSetState('country', countryId);
      }
    } else {
      // 找不到台灣，預設為 null，顯示無新聞
      setState(() {
        _currentNewsLocation = null;
        _newsList = [];
        _isLoading = false;
      });
    }
  }

  // 💥 輔助函式：載入新聞並更新狀態 (從原 MapPage 移入)
  Future<void> _fetchNewsAndSetState(
    String locationType,
    int locationId,
  ) async {
    // 💥 這裡加上 isLoading 狀態，讓列表顯示載入中
    if (mounted) {
      setState(() {
        _isLoading = true;
        _newsList = []; // 清空舊列表
      });
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/news/search'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'locationId': locationId,
          'locationType': locationType,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        List<dynamic> newsData = [];
        final dataField = responseBody['data'];

        if (dataField != null && dataField is Map<String, dynamic>) {
          final simpleList = dataField['simpleList'];

          if (simpleList != null && simpleList is List<dynamic>) {
            newsData = simpleList;
          }
        }

        final fetchedNews =
            newsData
                .map((json) => News.fromJson(json as Map<String, dynamic>))
                .toList();

        if (mounted) {
          setState(() {
            _newsList = fetchedNews;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('無法取得新聞資料 (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Fetch news error: $e');
      if (mounted) {
        setState(() {
          _newsList = [];
          _isLoading = false;
        });
      }
    }
  }

  // 💥 輔助函式：切換新聞範圍 (從原 MapPage 移入)
  void _toggleNewsScope({required String targetScope}) {
    if (_currentNewsLocation == null) return;

    final int? stateId = _safeId('state_id', _currentNewsLocation!);
    final int? regionId = _safeId('region_id', _currentNewsLocation!);
    final int? countryId = _safeId('country_id', _currentNewsLocation!);

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
      });
      _fetchNewsAndSetState(locationType, locationId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '該地點沒有 ${targetScope == 'country'
                ? '國家'
                : targetScope == 'state'
                ? '州/省'
                : '地區'} 的新聞資料。',
          ),
        ),
      );
    }
  }

  // 💥 輔助函式：導航到新聞內容頁面 (從原 MapPage 移入)
  void _navigateToNewsContentPage(News newsItem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ViewNewsContent(newsData: newsItem.toNewsDataMap()),
      ),
    );
  }

  // 💥 輔助函式：處理所有地點資料的載入 (從原 MapPage 移入)
  Future<void> _fetchLocations(String baseUrl) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/location'));
      if (mounted && response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        setState(() {
          _locations = data['data'];
          _regions =
              _locations
                  .map((loc) => loc['region_name_zh_tw'] as String)
                  .where((region) => region.isNotEmpty)
                  .toSet()
                  .toList();
          _regions.sort();
        });
      } else if (mounted) {
        setState(() {
          _error = '無法從伺服器取得地點資料：${response.statusCode}';
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

  // 💥 輔助函式：載入使用者最後位置 (從原 MapPage 移入)
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getInt('UserID');
      });
    }
  }

  // 💥 輔助函式：載入並設置最後位置的新聞 (從原 MapPage 移入)
  Future<void> _loadLastLocation() async {
    if (_currentUserId == null || _locations.isEmpty) {
      _loadDefaultNews();
      return;
    }

    final uri = Uri.parse('$baseUrl/user');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
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
              _setCurrentLocationAndFetchNews(targetLocation, 'country');
              return;
            }
          }
        }
        _loadDefaultNews(); // 找不到最後位置，載入預設新聞
      } else {
        _loadDefaultNews();
      }
    } catch (e) {
      _loadDefaultNews();
    }
  }

  // 💥 輔助函式：保存使用者最後位置 (從原 MapPage 移入)
  Future<void> _saveLastLocation(int? countryId) async {
    if (_currentUserId == null || countryId == null || countryId == 0) {
      return;
    }

    final Map<String, dynamic> body = {
      "user_id": _currentUserId,
      "location_country_id": countryId,
    };

    try {
      await http.put(
        Uri.parse('$baseUrl/user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      // error
    }
  }

  // 💥 新增：設置當前地點並獲取新聞
  void _setCurrentLocationAndFetchNews(
    Map<String, dynamic> locationData,
    String scope,
  ) {
    final int? stateId = _safeId('state_id', locationData);
    final int? countryId = _safeId('country_id', locationData);
    final int? regionId = _safeId('region_id', locationData);

    int? idToUse;
    String locationType;

    if (scope == 'state' && stateId != null) {
      idToUse = stateId;
      locationType = 'state';
    } else if (scope == 'country' && countryId != null) {
      idToUse = countryId;
      locationType = 'country';
    } else if (scope == 'region' && regionId != null) {
      idToUse = regionId;
      locationType = 'region';
    } else if (countryId != null) {
      // 降級為國家級
      idToUse = countryId;
      locationType = 'country';
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('該地點沒有可用的地理 ID 進行定位。')));
      return;
    }

    if (idToUse != null) {
      setState(() {
        _currentNewsLocation = locationData;
        _currentNewsScope = locationType;
        _isLoading = true;
      });

      _fetchNewsAndSetState(locationType, idToUse).then((_) {
        // 保存最後定位的國家 ID
        final int? countryIdToSave = _safeId('country_id', locationData);
        if (countryIdToSave != null) {
          _saveLastLocation(countryIdToSave);
        }
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('地點資料不完整，無法取得新聞。')));
    }
  }

  // 💥 輔助函式：地點搜尋 (從原 MapPage 移入)
  void _searchLocation(String query) {
    if (query.isEmpty) return;

    final lowerCaseQuery = query.toLowerCase();

    final foundExactLocation = _locations.firstWhere((location) {
      final zhTwCountryName = (location['country_name_zh_tw'] as String? ?? '');
      final zhTwStateName = (location['state_name_zh_tw'] as String? ?? '');
      final enCountryName = (location['country_name_en'] as String? ?? '');
      final enStateName = (location['state_name_en'] as String? ?? '');

      return zhTwCountryName == query ||
          zhTwStateName == query ||
          enCountryName.toLowerCase() == lowerCaseQuery ||
          enStateName.toLowerCase() == lowerCaseQuery;
    }, orElse: () => null);

    final foundLocation =
        foundExactLocation ??
        _locations.firstWhere((location) {
          final zhTwMatch =
              (location['country_name_zh_tw'] as String? ?? '').contains(
                query,
              ) ||
              (location['state_name_zh_tw'] as String? ?? '').contains(query) ||
              (location['region_name_zh_tw'] as String? ?? '').contains(query);

          final enCountryName =
              (location['country_name_en'] as String? ?? '').toLowerCase();
          final enStateName =
              (location['state_name_en'] as String? ?? '').toLowerCase();

          final enMatch =
              enCountryName.contains(lowerCaseQuery) ||
              enStateName.contains(lowerCaseQuery);

          return zhTwMatch || enMatch;
        }, orElse: () => null);

    if (foundLocation != null) {
      // 預設以 State > Country > Region 的優先級定位，並獲取 Country 級新聞
      final String scopeToUse =
          _safeId('state_id', foundLocation) != null
              ? 'state'
              : _safeId('country_id', foundLocation) != null
              ? 'country'
              : 'region';

      _setCurrentLocationAndFetchNews(foundLocation, scopeToUse);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到該地點。')));
    }
  }

  // 💥 輔助函式：處理下拉選單搜尋 (從原 MapPage 移入)
  void _handleDropdownSearch() {
    String? searchTarget;
    Map<String, dynamic>? targetLocation;

    if (_selectedState != null && _selectedState != _kUnselectOption) {
      searchTarget = _selectedState;
      targetLocation = _locations.firstWhere(
        (loc) =>
            loc['state_name_en'] == _selectedState &&
            loc['country_name_zh_tw'] == _selectedCountry,
        orElse: () => null,
      );
    } else if (_selectedCountry != null &&
        _selectedCountry != _kUnselectOption) {
      searchTarget = _selectedCountry;
      targetLocation = _locations.firstWhere(
        (loc) => loc['country_name_zh_tw'] == _selectedCountry,
        orElse: () => null,
      );
    } else if (_selectedRegion != null && _selectedRegion != _kUnselectOption) {
      searchTarget = _selectedRegion;
      targetLocation = _locations.firstWhere(
        (loc) => loc['region_name_zh_tw'] == _selectedRegion,
        orElse: () => null,
      );
    } else {
      _loadDefaultNews();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('地點已清除，定位至預設新聞。')));
      return;
    }

    if (targetLocation != null) {
      // 預設以 Country 級新聞為主
      _setCurrentLocationAndFetchNews(targetLocation, 'country');
      Navigator.of(context).pop(); // 關閉對話框
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到該地點的完整資料。')));
    }
  }

  // 💥 輔助函式：建立下拉選單 (從原 MapPage 移入)
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
          color: isEnabled ? Colors.white : const Color(0xFF1a2a4e),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3b82f6)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            hint: Text(hintText),
            value: selectedValue == _kUnselectOption ? null : selectedValue,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down),
            onChanged: isEnabled ? onChanged : null,
            items:
                items.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
            disabledHint: Text(
              hintText,
              style: TextStyle(color: const Color(0xFFe5e7eb)),
            ),
          ),
        ),
      ),
    );
  }

  // 💥 輔助函式：下拉選單的篩選邏輯 (從原 MapPage 移入)
  void _onRegionChanged(String? newRegion) {
    if (newRegion == _kUnselectOption || newRegion == null) {
      setState(() {
        _selectedRegion = null;
        _selectedCountry = null;
        _selectedState = null;
        _countries = [];
        _states = [];
      });
      return;
    }
    setState(() {
      _selectedRegion = newRegion;
      _selectedCountry = null;
      _selectedState = null;
      _states = [];
      _countries =
          _locations
              .where((loc) => loc['region_name_zh_tw'] == newRegion)
              .map((loc) => loc['country_name_zh_tw'] as String)
              .where((country) => country.isNotEmpty)
              .toSet()
              .toList();
      _countries.sort();
    });
    _searchController.clear();
  }

  void _onCountryChanged(String? newCountry) {
    if (newCountry == _kUnselectOption || newCountry == null) {
      setState(() {
        _selectedCountry = null;
        _selectedState = null;
        _states = [];
      });
      return;
    }
    setState(() {
      _selectedCountry = newCountry;
      _selectedState = null;
      _states =
          _locations
              .where(
                (loc) =>
                    loc['country_name_zh_tw'] == newCountry &&
                    (loc['state_name_en'] as String? ?? '').isNotEmpty,
              )
              .map((loc) => loc['state_name_en'] as String)
              .toSet()
              .toList();
      _states.sort();
    });
    _searchController.clear();
  }

  void _onStateChanged(String? newState) {
    if (newState == _kUnselectOption || newState == null) {
      setState(() {
        _selectedState = null;
      });
      return;
    }
    setState(() {
      _selectedState = newState;
    });
    _searchController.clear();
  }

  // 💥 新增：顯示搜尋/篩選器對話框
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // 使用 StateSetter 更新對話框內部的狀態 (用於下拉選單)
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateInDialog) {
            // 由於下拉選單的狀態是在主 Widget 的 State 中，我們需要使用主 State 的值，
            // 並將 onChanged 的 setState 呼叫包裝在 setStateInDialog 中。

            // 💥 注意: 為了讓下拉選單在對話框中也能更新，需要將 `_onRegionChanged`, `_onCountryChanged`, `_onStateChanged`
            // 的 `setState` 改為接受一個 `StateSetter` 參數。但為了簡化，我們直接在對話框內實現狀態更新。

            // 為了不影響主頁面的狀態，這裡暫時使用本地變數，但由於 _countries, _states 的計算邏輯在主 State 中，
            // 這裡直接使用主 State 的 `_selectedRegion` 等變數和邏輯。
            // 這樣做雖然有點不嚴謹，但在 Flutter 狀態樹上可以接受，因為對話框是主頁面的子級。

            return AlertDialog(
              title: const Text('搜尋地點並查看新聞'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- 1. 文字搜尋 ---
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '輸入地點名稱（中/英）搜尋...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1a2a4e),
                      ),
                      onSubmitted: (query) {
                        _searchLocation(query);
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '或使用下拉選單定位：',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // --- 2. 下拉選單過濾器 ---
                    // 這裡必須使用 setStateInDialog 來更新對話框內部的狀態，同時也要觸發主頁面的狀態更新邏輯
                    Row(
                      children: [
                        _buildDropdown(
                          '地區',
                          _selectedRegion,
                          _regionsForDropdown,
                          (String? newRegion) => setState(() {
                            setStateInDialog(() {
                              _onRegionChanged(newRegion);
                            });
                          }),
                          true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        _buildDropdown(
                          '國家',
                          _selectedCountry,
                          _countriesForDropdown,
                          (String? newCountry) => setState(() {
                            setStateInDialog(() {
                              _onCountryChanged(newCountry);
                            });
                          }),
                          _selectedRegion != null &&
                              _selectedRegion != _kUnselectOption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        _buildDropdown(
                          '州/省',
                          _selectedState,
                          _statesForDropdown,
                          (String? newState) => setState(() {
                            setStateInDialog(() {
                              _onStateChanged(newState);
                            });
                          }),
                          _selectedCountry != null &&
                              _selectedCountry != _kUnselectOption &&
                              _states.isNotEmpty,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  onPressed:
                      (_selectedRegion != null &&
                              _selectedRegion != _kUnselectOption)
                          ? _handleDropdownSearch
                          : null,
                  child: const Text('定位並查看新聞'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 💥 新增：導航到全地圖搜尋頁
  void _navigateToFullMapSearch() async {
    final Map<String, dynamic>? resultLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => _FullMapSearchPage(
              locations: _locations,
              initialLocation: _currentNewsLocation,
            ),
      ),
    );

    if (resultLocation != null) {
      // 導航回主頁面後，使用地圖選中的地點來更新新聞列表
      _setCurrentLocationAndFetchNews(resultLocation, 'country');
    }
  }

  // 💥 新增：構建主要的新聞列表介面
  Widget _buildNewsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('載入錯誤: $_error'));
    }

    if (_currentNewsLocation == null) {
      return const Center(child: Text('無法取得地點資料，請嘗試手動搜尋。'));
    }

    final String countryName =
        _currentNewsLocation!['country_name_zh_tw'] ?? '未知國家';
    final String stateName = _currentNewsLocation!['state_name_en'] ?? '未提供';
    final String regionName =
        _currentNewsLocation!['region_name_zh_tw'] ?? '未知地區';

    String scopeText;
    if (_currentNewsScope == 'country') {
      scopeText = '$countryName (國家級)';
    } else if (_currentNewsScope == 'state') {
      scopeText = '$stateName (州/省級)';
    } else {
      scopeText = '$regionName (地區級)';
    }

    final bool hasStateScope =
        _safeId('state_id', _currentNewsLocation!) != null;
    final bool hasRegionScope =
        _safeId('region_id', _currentNewsLocation!) != null;
    final bool hasSubScope = hasStateScope || hasRegionScope;

    Widget buildScopeButtons() {
      if (_currentNewsScope == 'country') {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasRegionScope)
              Padding(
                padding: EdgeInsets.only(right: hasStateScope ? 8.0 : 0.0),
                child: ElevatedButton(
                  onPressed: () => _toggleNewsScope(targetScope: 'region'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 30),
                    backgroundColor: const Color(0xFF60a5fa),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('往地區新聞', style: TextStyle(fontSize: 12)),
                ),
              ),

            if (hasStateScope)
              ElevatedButton(
                onPressed: () => _toggleNewsScope(targetScope: 'state'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  backgroundColor: const Color(0xFF60a5fa),
                  foregroundColor: Colors.white,
                ),
                child: const Text('往州/省新聞', style: TextStyle(fontSize: 12)),
              ),
          ],
        );
      } else {
        return ElevatedButton(
          onPressed: () => _toggleNewsScope(targetScope: 'country'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 30),
            backgroundColor: const Color(0xFF0a1428),
            foregroundColor: Colors.white,
          ),
          child: const Text('返回國家新聞', style: TextStyle(fontSize: 12)),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🌏 ${countryName} - 新聞列表',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '目前顯示範圍: $scopeText',
                    style: const TextStyle(
                      fontSize: 14,
                      color: const Color(0xFFe5e7eb),
                    ),
                  ),
                  if (hasSubScope) buildScopeButtons(),
                ],
              ),
              const Divider(),
            ],
          ),
        ),

        Expanded(
          child:
              _newsList.isEmpty
                  ? const Center(child: Text('目前沒有相關新聞。'))
                  : ListView.builder(
                    itemCount: _newsList.length,
                    itemBuilder: (context, index) {
                      final news = _newsList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          leading:
                              news.coverImage != null
                                  ? Image.network(
                                    news.coverImage!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.image,
                                              color: const Color(0xFFe5e7eb),
                                            ),
                                  )
                                  : const Icon(
                                    Icons.article,
                                    color: const Color(0xFF60a5fa),
                                  ),
                          title: Text(
                            news.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${news.sourceName ?? '未知'} · ${news.publishDate ?? ''}',
                          ),
                          onTap: () => _navigateToNewsContentPage(news),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  // 💥 MapPage 的主 build 方法
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地區新聞'),
        actions: [
          // 💥 1. 搜尋按鈕：文字/選單搜尋
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: '搜尋地點/篩選新聞',
          ),
          // 💥 2. 地圖按鈕：全螢幕地圖搜尋
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _navigateToFullMapSearch,
            tooltip: '地圖選取地點',
          ),
          // 3. 書籤按鈕 (保留)
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(builder: (context) => const BookmarkPage()),
              // );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildNewsList(), // 💥 主要內容為新聞列表
    );
  }
}

// =========================================================================
// 💥 新增類別：_FullMapSearchPage - 專門處理地圖搜尋和定位
// -------------------------------------------------------------------------
class _FullMapSearchPage extends StatefulWidget {
  final List<dynamic> locations;
  final Map<String, dynamic>? initialLocation;

  const _FullMapSearchPage({required this.locations, this.initialLocation});

  @override
  State<_FullMapSearchPage> createState() => _FullMapSearchPageState();
}

class _FullMapSearchPageState extends State<_FullMapSearchPage> {
  final MapController _mapController = MapController();
  static const double _kMaxSearchDistanceKm = 10000.0;
  static const LatLng _taiwanCenter = LatLng(23.6978, 120.9605);

  double _currentZoom = 7;
  LatLng _currentCenter = _taiwanCenter;
  List<Marker> _markers = [];
  Map<String, dynamic>? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  // 💥 輔助函式：安全 ID 檢查 (從原 MapPage 移入)
  int? _safeId(String key, Map<String, dynamic> locationData) {
    final value = locationData[key];
    if (value == null) return null;

    if (value is int) {
      return value == 0 ? null : value;
    }
    if (value is String) {
      if (value.isEmpty || value == '0') return null;
      return int.tryParse(value);
    }
    return null;
  }

  // 💥 輔助函式：地圖初始化
  void _initializeMap() {
    if (widget.initialLocation != null) {
      final loc = widget.initialLocation!;
      double? lat;
      double? lng;
      double zoomLevel;

      final stateLat = double.tryParse(
        loc['state_center_latitude']?.toString() ?? '',
      );
      final stateLng = double.tryParse(
        loc['state_center_longitude']?.toString() ?? '',
      );
      final countryLat = double.tryParse(
        loc['country_center_latitude']?.toString() ?? '',
      );
      final countryLng = double.tryParse(
        loc['country_center_longitude']?.toString() ?? '',
      );

      if (stateLat != null && stateLng != null) {
        lat = stateLat;
        lng = stateLng;
        zoomLevel = 9.0;
      } else if (countryLat != null && countryLng != null) {
        lat = countryLat;
        lng = countryLng;
        zoomLevel = 7.0;
      } else {
        lat = _taiwanCenter.latitude;
        lng = _taiwanCenter.longitude;
        zoomLevel = 7.0;
      }

      final LatLng targetLatLng = LatLng(lat, lng);

      setState(() {
        _currentCenter = targetLatLng;
        _currentZoom = zoomLevel;
        _selectedLocation = loc;
        _markers = [
          Marker(
            point: targetLatLng,
            width: 100,
            height: 100,
            child: const Icon(
              Icons.location_on,
              color: const Color(0xFF60a5fa),
              size: 50.0,
            ),
          ),
        ];
      });
    } else {
      // 預設放大到台灣
      _zoomToTaiwan();
    }
  }

  void _zoomToTaiwan() {
    LatLng targetCenter = _taiwanCenter;
    double targetZoom = 7;

    final taiwanLocation = widget.locations.firstWhere(
      (loc) =>
          (loc['country_name_zh_tw'] as String? ?? '') == '台灣' ||
          (loc['country_name_en'] as String? ?? '').toLowerCase() == 'taiwan',
      orElse: () => null,
    );
    if (taiwanLocation != null) {
      final lat = double.tryParse(
        taiwanLocation['country_center_latitude'].toString(),
      );
      final lon = double.tryParse(
        taiwanLocation['country_center_longitude'].toString(),
      );
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
          child: const Icon(
            Icons.location_on,
            color: const Color(0xFFef4444),
            size: 40.0,
          ),
        ),
      ];
      _selectedLocation = null;
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

  // 💥 輔助函式：計算兩點距離 (從原 MapPage 移入)
  double _calculateHaversineDistance(LatLng start, LatLng end) {
    const R = 6371;
    final lat1Rad = start.latitude * pi / 180;
    final lon1Rad = start.longitude * pi / 180;
    final lat2Rad = end.latitude * pi / 180;
    final lon2Rad = end.longitude * pi / 180;

    final dLat = lat2Rad - lat1Rad;
    final dLon = lon2Rad - lon1Rad;

    final a =
        pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  // 💥 輔助函式：尋找最近地點 (從原 MapPage 移入)
  Map<String, dynamic>? _findNearestLocation(LatLng tapLatLng) {
    if (widget.locations.isEmpty) return null;

    double minDistanceKm = double.infinity;
    const double maxDistanceKm = _kMaxSearchDistanceKm;
    Map<String, dynamic>? nearestLocation;

    for (var location in widget.locations) {
      LatLng? locationLatLng;
      final stateLat = double.tryParse(
        location['state_center_latitude']?.toString() ?? '',
      );
      final stateLon = double.tryParse(
        location['state_center_longitude']?.toString() ?? '',
      );
      if (stateLat != null && stateLon != null) {
        locationLatLng = LatLng(stateLat, stateLon);
      } else {
        final countryLat = double.tryParse(
          location['country_center_latitude']?.toString() ?? '',
        );
        final countryLon = double.tryParse(
          location['country_center_longitude']?.toString() ?? '',
        );
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

  // 💥 輔助函式：處理地圖點擊 (從原 MapPage 移入)
  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    final nearestLocation = _findNearestLocation(latlng);
    if (nearestLocation != null) {
      final int? stateId = _safeId('state_id', nearestLocation);
      final int? countryId = _safeId('country_id', nearestLocation);

      double? lat;
      double? lng;
      double zoomLevel;

      final stateLat = double.tryParse(
        nearestLocation['state_center_latitude']?.toString() ?? '',
      );
      final stateLng = double.tryParse(
        nearestLocation['state_center_longitude']?.toString() ?? '',
      );
      final countryLat = double.tryParse(
        nearestLocation['country_center_latitude']?.toString() ?? '',
      );
      final countryLng = double.tryParse(
        nearestLocation['country_center_longitude']?.toString() ?? '',
      );

      if (stateId != null && stateLat != null && stateLng != null) {
        lat = stateLat;
        lng = stateLng;
        zoomLevel = 9.0;
      } else if (countryId != null &&
          countryLat != null &&
          countryLng != null) {
        lat = countryLat;
        lng = countryLng;
        zoomLevel = 7.0;
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('該地點沒有可用的經緯度資料進行定位。')));
        return;
      }

      final LatLng targetLatLng = LatLng(lat, lng);

      setState(() {
        _currentCenter = targetLatLng;
        _currentZoom = zoomLevel;
        _mapController.move(targetLatLng, zoomLevel);
        _selectedLocation = nearestLocation;
        _markers = [
          Marker(
            point: targetLatLng,
            width: 100,
            height: 100,
            child: const Icon(
              Icons.location_on,
              color: const Color(0xFF60a5fa),
              size: 50.0,
            ),
          ),
        ];
      });
    } else {
      setState(() {
        _selectedLocation = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('附近沒有可用的地點資料。')));
    }
  }

  // 💥 地圖頁面的 build 方法
  @override
  Widget build(BuildContext context) {
    final displayCoordinates =
        '緯度: ${_currentCenter.latitude.toStringAsFixed(3)}, 經度: ${_currentCenter.longitude.toStringAsFixed(3)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('地圖選取地點'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // 直接返回，不帶結果
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: _currentZoom,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(LatLng(-90, -180), LatLng(90, 180)),
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
                _mapController.move(_currentCenter, _currentZoom);
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

          // 坐標顯示
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFe5e7eb),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayCoordinates,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),

          // 縮放按鈕
          Positioned(
            right: 10,
            bottom: 80, // 為確定按鈕騰出空間
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "mapZoomIn",
                  mini: true,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "mapZoomOut",
                  mini: true,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // 確定按鈕
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: ElevatedButton.icon(
              onPressed:
                  _selectedLocation != null
                      ? () =>
                          Navigator.pop(context, _selectedLocation) // 傳回選中的地點
                      : null,
              icon: const Icon(Icons.check),
              label: Text(
                _selectedLocation != null
                    ? '確定選擇: ${_selectedLocation!['country_name_zh_tw'] ?? '未知地點'}'
                    : '請點擊地圖選擇地點',
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF10b981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
