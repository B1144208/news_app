import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

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
      coverImage: json['cover_image'] != null ? 'http://localhost:3000/api/image/${json['cover_image']}' : null,
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

  double _currentZoom = 2;
  LatLng _currentCenter = LatLng(20, 0);

  List<Marker> _markers = [];
  List<dynamic> _locations = [];
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _selectedLocation;
  bool _isPanelVisible = false;
  // 新增新聞列表變數
  List<News> _newsList = [];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/api/location'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _locations = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '無法從伺服器取得資料：${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '連線錯誤：請確認伺服器正在執行。';
        _isLoading = false;
      });
    }
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

  void _searchLocation(String query) async {
    if (query.isEmpty) {
      return;
    }

    // 從本地快取中搜尋
    final foundLocation = _locations.firstWhere(
          (location) =>
      (location['country_name_zh_tw'] as String).contains(query) ||
          (location['country_name_en'] as String).contains(query) ||
          (location['state_name_en'] as String? ?? '').contains(query),
      orElse: () => null,
    );

    if (foundLocation != null) {
      LatLng markerLatLng;
      final stateLat = double.tryParse(foundLocation['state_center_latitude'].toString());
      final stateLon = double.tryParse(foundLocation['state_center_longitude'].toString());
      if (stateLat != null && stateLon != null) {
        markerLatLng = LatLng(stateLat, stateLon);
      } else {
        markerLatLng = LatLng(
          double.parse(foundLocation['country_center_latitude'].toString()),
          double.parse(foundLocation['country_center_longitude'].toString()),
        );
      }
      _updateMapWithLocation(foundLocation, markerLatLng);
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

  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    final nearestLocation = _findNearestLocation(latlng);
    if (nearestLocation != null) {
      LatLng markerLatLng;

      final stateLat = double.tryParse(nearestLocation['state_center_latitude'].toString());
      final stateLon = double.tryParse(nearestLocation['state_center_longitude'].toString());
      if (stateLat != null && stateLon != null) {
        markerLatLng = LatLng(stateLat, stateLon);
      } else {
        markerLatLng = LatLng(
          double.parse(nearestLocation['country_center_latitude'].toString()),
          double.parse(nearestLocation['country_center_longitude'].toString()),
        );
      }
      _updateMapWithLocation(nearestLocation, markerLatLng);
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

  // 新增新聞 API 呼叫函式
  Future<List<News>> _fetchNewsByLocation(String locationType, int locationId) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/news?locationId=$locationId&locationType=$locationType'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> newsData = data['data'];
        return newsData.map((json) => News.fromJson(json)).toList();
      } else {
        throw Exception('無法取得新聞資料');
      }
    } catch (e) {
      print('錯誤: $e');
      return [];
    }
  }

  // 修改 _updateMapWithLocation 函式，新增新聞獲取邏輯
  void _updateMapWithLocation(Map<String, dynamic> locationData, LatLng markerLatLng) async {
    final lat = double.tryParse(locationData['country_center_latitude'].toString());
    final lon = double.tryParse(locationData['country_center_longitude'].toString());

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地點經緯度資料不正確。'))
      );
      return;
    }

    // 取得地點的 ID 和類型
    final locationId = locationData['state_id'] ?? locationData['country_id'];
    final locationType = locationData['state_id'] != null ? 'state' : 'country';
    final fetchedNews = await _fetchNewsByLocation(locationType, locationId);

    final newCenter = LatLng(lat, lon);

    setState(() {
      _currentCenter = newCenter;
      _currentZoom = 5;
      _mapController.move(_currentCenter, _currentZoom);

      _markers = [
        Marker(
          point: markerLatLng,
          width: 80,
          height: 80,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40.0,
          ),
        ),
      ];
      _selectedLocation = locationData;
      _isPanelVisible = true;
      _newsList = fetchedNews;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('世界地圖')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋地點...',
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
                              _currentCenter = event.camera.center;
                              _currentZoom = event.camera.zoom;
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