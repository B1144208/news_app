import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // 引入套件

// 引入詳細頁面
import 'EventSortingDetailPage.dart';
import 'MultiplePerspectivesDetailPage.dart';
import 'config.dart';

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  int? _currentUserId;

  // true: 事件整理, false: 多方看法
  bool _isEventSortingMode = true;
  late Future<List<dynamic>> _eventsortingFuture;
  late Future<List<dynamic>> _multiplePerspectivesFuture;


  Map<int, bool> _bookmarkStatus = {};

  // 後端 API 基礎 URL，現在從 config.dart 中讀取
  final String _baseUrl = baseUrl;

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      _fetchData();
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');

    setState(() {
      _currentUserId = userId;
    });
  }

  void _fetchData() {
    _eventsortingFuture = _searchEventsorting();
    _multiplePerspectivesFuture = _searchMultipleperspectives();
    if (_currentUserId != null) {
      _fetchBookmarks();
    }
  }

  // 搜尋事件整理資料
  Future<List<dynamic>> _searchEventsorting({int? id}) async {
    final Map<String, dynamic> queryParams = {};
    if (id != null) {
      queryParams['id'] = id.toString();
    }
    final uri = Uri.parse('$_baseUrl/api/EventSorting').replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to load eventsorting data: Status Code ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to eventsorting API: $e');
    }
  }

  // 搜尋多方看法資料
  Future<List<dynamic>> _searchMultipleperspectives({int? id}) async {
    final Map<String, dynamic> queryParams = {};
    if (id != null) {
      queryParams['id'] = id.toString();
    }
    final uri = Uri.parse('$_baseUrl/api/MultiplePerspectives').replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to load multipleperspectives data: Status Code ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to multipleperspectives API: $e');
    }
  }

  // 獲取使用者的收藏列表
  Future<void> _fetchBookmarks() async {
    if (_currentUserId == null) return;

    final url = '$_baseUrl/api/user_action/bookmark/eventsorting?userId=$_currentUserId';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List bookmarks = data['data'];
        final Map<int, bool> newBookmarkStatus = {};
        for (var item in bookmarks) {
          if (item['eventsorting_id'] != null) {
            newBookmarkStatus[item['eventsorting_id']] = true;
          }
        }
        setState(() {
          _bookmarkStatus = newBookmarkStatus;
        });
      }
    } catch (e) {
      print('Failed to fetch bookmarks: $e');
    }
  }

  // 處理收藏的新增或刪除
  Future<void> _toggleBookmark(int eventId) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入以使用收藏功能')),
      );
      return;
    }

    final isBookmarked = _bookmarkStatus[eventId] ?? false;
    final url = isBookmarked
        ? '$_baseUrl/api/user_action/delete/bookmark/$eventId'
        : '$_baseUrl/api/user_action/insert/bookmark/eventsorting';

    final body = {
      'userId': _currentUserId,
      'dataId': eventId,
    };

    try {
      final response = isBookmarked
          ? await http.delete(Uri.parse(url))
          : await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        setState(() {
          _bookmarkStatus[eventId] = !isBookmarked;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isBookmarked ? '已取消收藏' : '已收藏')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失敗，請稍後再試')),
        );
      }
    } catch (e) {
      print('Error toggling bookmark: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('網路錯誤，無法完成操作')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- 頂部導覽列 ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.account_circle),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: _isEventSortingMode ? "搜尋事件" : "搜尋多方觀點",
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _currentUserId != null ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    onPressed: () {
                      if (_currentUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('請先登入以查看收藏')),
                        );
                      } else {
                        // TODO: 點擊後跳轉到收藏列表頁面
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('即將跳轉到收藏頁面')),
                        );
                      }
                    },
                  ),
                  Switch(
                    value: !_isEventSortingMode,
                    onChanged: (bool value) {
                      setState(() {
                        _isEventSortingMode = !value;
                      });
                    },
                    activeColor: Colors.blue,
                    inactiveTrackColor: Colors.grey.shade300,
                    inactiveThumbColor: Colors.white,
                  ),
                ],
              ),
            ),
            // AI技術協助聲明
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text("使用AI技術協助", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const Spacer(),
                  const Text("資訊若有失真狀況，一概不負法律責任", style: TextStyle(color: Colors.red, fontSize: 10)),
                ],
              ),
            ),
            // --- 主要內容區 ---
            Expanded(
              child: _isEventSortingMode ? _buildEventSortingContent() : _buildMultiplePerspectivesContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventSortingContent() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text("AI整理近期焦點新聞", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder(
            future: _eventsortingFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('載入失敗: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('目前沒有事件整理資料。'));
              } else {
                final List events = snapshot.data!;
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final eventId = event['eventsorting_id'];
                    final isBookmarked = _bookmarkStatus[eventId] ?? false;

                    return _buildNewsCard(
                      title: event['eventsorting_title'],
                      content: event['eventsorting_summary'],
                      details: '${event['eventsorting_background_count'] ?? 0}則事件背景',
                      isBookmarked: isBookmarked,
                      onBookmarkTap: () => _toggleBookmark(eventId),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EventSortingDetailPage(id: eventId)),
                        );
                      },
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMultiplePerspectivesContent() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text("近期新聞不同觀點之討論", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder(
            future: _multiplePerspectivesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('載入失敗: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('目前沒有多方看法資料。'));
              } else {
                final List views = snapshot.data!;
                return ListView.builder(
                  itemCount: views.length,
                  itemBuilder: (context, index) {
                    final view = views[index];
                    return _buildNewsCard(
                      title: view['multipleperspectives_title'],
                      content: '看法統整',
                      details: '${view['multipleperspectives_view_count'] ?? 0}種對立觀點',
                      isMultiplePerspectives: true,
                      onBookmarkTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('此類型暫不支援收藏功能')),
                        );
                      },
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => MultiplePerspectivesDetailPage(id: view['multipleperspectives_id'])),
                        );
                      },
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCard({
    required String title,
    required String content,
    required String details,
    bool isMultiplePerspectives = false,
    required VoidCallback onTap,
    required VoidCallback onBookmarkTap,
    bool isBookmarked = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (isMultiplePerspectives) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.local_fire_department, color: Colors.red),
                    const Icon(Icons.local_fire_department, color: Colors.red),
                    const Icon(Icons.local_fire_department, color: Colors.red),
                  ],
                  IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? Colors.amber : Colors.grey,
                    ),
                    onPressed: onBookmarkTap,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(content),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    details,
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}