import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  double _currentZoom = 2;
  LatLng _currentCenter = LatLng(20, 0); // 🌍 目前中心 (自己維護)

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('世界地圖')),
      body: Column(
        children: [
          // 🔍 搜尋框
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
              onSubmitted: (value) {
                debugPrint("搜尋: $value");
              },
            ),
          ),

          // 🌍 地圖 + 放大縮小按鈕
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: _currentZoom,
                    onMapEvent: (event) {
                      // 📌 更新目前中心點
                      if (event is MapEventMoveEnd) {
                        _currentCenter = event.camera.center;
                        _currentZoom = event.camera.zoom;
                      }
                    },
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
                  ],
                ),

                // ➕➖ 控制按鈕 (右下角)
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
        ],
      ),
    );
  }
}
