import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 引入詳細頁面 (請確保這些檔案存在)
import 'EventSortingDetailPage.dart';
import 'MultiplePerspectivesDetailPage.dart';
import 'config.dart'; // 假設 config.dart 包含 baseUrl

// 引入導航頁面 (確保這些檔案存在且名稱正確)
import 'LoginPage.dart';
import 'BookmarkPage.dart'; // 👈 這裡就是您的收藏列表頁面
import 'SignupPage.dart'; // 新增
import 'AdminPage.dart'; // 新增
import 'MemberCenterPage.dart'; // 新增

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  int? _currentUserId;

  // true: 事件整理, false: 多方看法
  bool _isEventSortingMode = true;

  // 狀態變量用於儲存內容數據 (完整資料)
  List<dynamic> _eventsortingList = [];
  List<dynamic> _multiplePerspectivesList = [];

  // # 🌟 搜尋功能修正 🌟
  // 儲存篩選後的資料，UI 將會依賴這個列表
  List<dynamic> _filteredEventsortingList = [];
  List<dynamic> _filteredMultiplePerspectivesList = [];
  // 搜尋欄的控制器
  final TextEditingController _searchController = TextEditingController();
  // 記錄當前搜尋關鍵字
  String _currentSearchKeyword = '';
  // 記錄是否正在搜尋中 (可以不用，但有利於區分狀態)
  bool _isSearching = false;

  // 🌟 修正點 1：統一的 Future，確保所有數據載入完成，解決刷新不同步問題 🌟
  late Future<void> _loadingFuture;

  // 修正點 2：將狀態變量改為儲存 bookmark_id (int)
  // 事件整理的收藏狀態： key: eventsorting_id, value: bookmark_id
  Map<int, int?> _bookmarkIdStatus = {};
  // 多方看法的收藏狀態： key: multipleperspectives_id, value: bookmark_id
  Map<int, int?> _multiplePerspectivesBookmarkIdStatus = {};

  // 後端 API 基礎 URL
  final String _baseUrl = baseUrl;

  @override
  void initState() {
    super.initState();
    // 🌟 修正點 3：將所有初始化邏輯放在一個 Future 中 🌟
    _loadingFuture = _loadUserId().then((_) {
      return _fetchData();
    });

    // # 🌟 搜尋功能修正 🌟
    // 監聽 TextField 的變化
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    // # 🌟 搜尋功能修正 🌟
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // # 🌟 搜尋功能修正 🌟
  // 當搜尋欄內容改變時調用
  void _onSearchChanged() {
    // 避免在 setState 內部直接呼叫 setState 導致的錯誤
    final keyword = _searchController.text;
    if (_currentSearchKeyword != keyword) {
      _currentSearchKeyword = keyword;
      _filterData(keyword);
    }
  }

  // # 🌟 搜尋功能修正 🌟
  // 核心篩選邏輯
  void _filterData(String keyword) {
    if (keyword.isEmpty) {
      setState(() {
        _filteredEventsortingList = _eventsortingList;
        _filteredMultiplePerspectivesList = _multiplePerspectivesList;
        _isSearching = false;
      });
      return;
    }

    final lowerCaseKeyword = keyword.toLowerCase();
    _isSearching = true;

    // 篩選事件整理 (Eventsorting)
    final filteredEvents =
    _eventsortingList.where((event) {
      final title = event['eventsorting_title']?.toLowerCase() ?? '';
      final summary = event['eventsorting_summary']?.toLowerCase() ?? '';
      return title.contains(lowerCaseKeyword) ||
          summary.contains(lowerCaseKeyword);
    }).toList();

    // 篩選多方看法 (MultiplePerspectives)
    final filteredMP =
    _multiplePerspectivesList.where((view) {
      // 💥 修正點 1: multipleperspectives_title 已移除，改用 eventsorting_title 進行篩選
      final title = view['eventsorting_title']?.toLowerCase() ?? '';
      // 由於多方看法資料沒有 summary，只篩選 title
      return title.contains(lowerCaseKeyword);
    }).toList();

    setState(() {
      _filteredEventsortingList = filteredEvents;
      _filteredMultiplePerspectivesList = filteredMP;
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    // 重新載入 _currentUserId，以便檢查登入狀態
    final userId = prefs.getInt('UserID');

    // 注意：這裡只更新 _currentUserId，不調用 setState，讓 _loadingFuture 結束後統一更新 UI
    _currentUserId = userId;
  }

  // 獲取用戶資訊 (從 HomePage 移植)
  Future<Map<String, dynamic>> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'account': prefs.getString('Account') ?? '',
      'isAdmin': (prefs.getInt('UserLevel') ?? 0) >= 5,
    };
  }

  // 🌟 修正點 4：統一載入數據和收藏狀態 🌟
  Future<void> _fetchData() async {
    try {
      // 1. 同時開始載入內容數據
      final eventFuture = _searchEventsorting();
      final mpFuture = _searchMultipleperspectives();

      // 2. 等待內容數據完成
      final results = await Future.wait([eventFuture, mpFuture]);

      // 3. 賦值給狀態變量
      _eventsortingList = results[0];
      _multiplePerspectivesList = results[1];

      // # 🌟 搜尋功能修正 🌟
      // 初始化篩選列表為完整列表
      _filteredEventsortingList = List.from(_eventsortingList);
      _filteredMultiplePerspectivesList = List.from(_multiplePerspectivesList);
      // 如果有關鍵字，則進行一次篩選
      if (_currentSearchKeyword.isNotEmpty) {
        _filterData(_currentSearchKeyword);
      }

      // 4. 載入收藏狀態
      if (_currentUserId != null) {
        await _fetchBookmarks(); // 這裡會更新 _bookmarkIdStatus 並調用內部的 setState
      }
    } catch (e) {
      print('Error during initial data fetch: $e');
      // 為了讓 FutureBuilder 顯示錯誤，可以重新拋出異常
      rethrow;
    }
  }

  // 搜尋事件整理資料 (邏輯不變)
  Future<List<dynamic>> _searchEventsorting({int? id}) async {
    final Map<String, dynamic> queryParams = {};
    if (id != null) {
      queryParams['id'] = id.toString();
    }
    final uri = Uri.parse(
      '$_baseUrl/EventSorting',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception(
          'Failed to load eventsorting data: Status Code ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to connect to eventsorting API: $e');
    }
  }

  // 搜尋多方看法資料 (邏輯不變)
  Future<List<dynamic>> _searchMultipleperspectives({int? id}) async {
    final Map<String, dynamic> queryParams = {};
    if (id != null) {
      queryParams['id'] = id.toString();
    }
    final uri = Uri.parse(
      '$_baseUrl/MultiplePerspectives',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception(
          'Failed to load multipleperspectives data: Status Code ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to connect to multipleperspectives API: $e');
    }
  }

  // 🌟 修正點 5：獲取使用者的收藏列表 (儲存 bookmark_id) 🌟
  Future<void> _fetchBookmarks() async {
    if (_currentUserId == null) return;

    try {
      final Map<int, int?> newEventsortingStatus = {};
      final Map<int, int?> newMultiplePerspectivesStatus = {};

      // 1. 獲取事件整理 (Eventsorting) 的收藏
      final eventsortingUrl =
          '$_baseUrl/user/bookmark/eventsorting?userId=$_currentUserId';
      final eventsortingResponse = await http.get(Uri.parse(eventsortingUrl));

      if (eventsortingResponse.statusCode == 200) {
        final data = json.decode(eventsortingResponse.body);
        final List bookmarks = data['data'] ?? [];

        for (var item in bookmarks) {
          final dataId = item['eventsorting_id'];
          final bookmarkId = item['bookmark_id'];

          if (dataId != null && dataId is int && bookmarkId != null) {
            newEventsortingStatus[dataId] = bookmarkId as int?;
          }
        }
      }

      // 2. 獲取多方看法 (MultiplePerspectives) 的收藏
      final mpUrl =
          '$_baseUrl/user/bookmark/multipleperspectives?userId=$_currentUserId';
      final mpResponse = await http.get(Uri.parse(mpUrl));

      if (mpResponse.statusCode == 200) {
        final mpData = json.decode(mpResponse.body);
        final List mpBookmarks = mpData['data'] ?? [];

        for (var item in mpBookmarks) {
          final dataId = item['multipleperspectives_id'];
          final bookmarkId = item['bookmark_id'];

          if (dataId != null && dataId is int && bookmarkId != null) {
            newMultiplePerspectivesStatus[dataId] = bookmarkId as int?;
          }
        }
      }

      // 統一調用 setState 更新 UI
      setState(() {
        _bookmarkIdStatus = newEventsortingStatus;
        _multiplePerspectivesBookmarkIdStatus = newMultiplePerspectivesStatus;
      });
    } catch (e) {
      print('Failed to fetch bookmarks: $e');
    }
  }

  // 🌟 修正點 6：處理收藏的新增或刪除 (使用 bookmark_id 進行刪除) 🌟
  Future<void> _toggleBookmark(int dataId, String dataType) async {
    if (_currentUserId == null) {
      // 處理未登入狀態 (不變)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入以使用收藏功能')));

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      ).then((_) async {
        await _loadUserId();
        if (_currentUserId != null) {
          await _fetchData();
        }
      });

      if (_currentUserId == null) return;
    }

    final isEventsorting = dataType == 'eventsorting';
    final statusMap =
    isEventsorting
        ? _bookmarkIdStatus
        : _multiplePerspectivesBookmarkIdStatus;

    // 檢查是否已收藏，並取出 bookmark_id
    final bookmarkId = statusMap[dataId];
    final isBookmarked = bookmarkId != null;

    // POST (新增) 路由：POST $_baseUrl/user/bookmark/{dataType}
    final addUrl = '$_baseUrl/user/bookmark/$dataType';

    // DELETE (刪除) 路由：DELETE $_baseUrl/user/bookmark/{bookmarkId}
    final deleteUrl = '$_baseUrl/user/bookmark/$bookmarkId';

    final url = isBookmarked ? deleteUrl : addUrl;
    final method = isBookmarked ? 'DELETE' : 'POST';

    final body = {'userId': _currentUserId, 'dataId': dataId};

    try {
      http.Response response;

      if (method == 'POST') {
        response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );
      } else {
        if (bookmarkId == null) {
          throw Exception("Cannot delete, bookmarkId is missing.");
        }
        response = await http.delete(Uri.parse(url));
      }

      if (response.statusCode == 200) {
        // 🌟 修正點 7：操作成功後，強制重新獲取狀態以確保高亮同步 🌟
        await _fetchBookmarks();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(isBookmarked ? '已取消收藏' : '已收藏')));
      } else {
        print(
          'Bookmark failed. Status: ${response.statusCode}, Method: $method, URL: $url, Body: ${response.body}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失敗 (Status: ${response.statusCode})')),
        );
      }
    } catch (e) {
      print('Error toggling bookmark: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('網路連線錯誤，無法完成操作')));
    }
  }

  // ========== 頂部工具欄 (從 HomePage 移植) ==========
  Widget _buildTopToolBar() {
    return FutureBuilder<bool>(
      // 檢查是否登入
      future: SharedPreferences.getInstance().then(
            (prefs) => prefs.getBool('IsLogin') ?? false,
      ),
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.data ?? false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (!isLoggedIn)
              // 未登入狀態 - 顯示登入按鈕 (已移除註冊按鈕)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        ).then((_) {
                          // 登入後刷新頁面
                          setState(() {
                            _loadUserId().then((__) => _fetchData());
                          });
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366f1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('登入', style: TextStyle(fontSize: 12)),
                    ),
                    // 移除註冊按鈕
                    // const SizedBox(width: 8),
                    // ElevatedButton(
                    //   onPressed: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (context) => const SignupPage(),
                    //       ),
                    //     ).then((_) {
                    //       // 註冊後刷新頁面
                    //       setState(() {
                    //         _loadUserId().then((__) => _fetchData());
                    //       });
                    //     });
                    //   },
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: const Color(0xFF60a5fa),
                    //     foregroundColor: Colors.white,
                    //     elevation: 0,
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 12,
                    //       vertical: 6,
                    //     ),
                    //     minimumSize: const Size(60, 32),
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(6),
                    //     ),
                    //   ),
                    //   child: const Text('註冊', style: TextStyle(fontSize: 12)),
                    // ),
                  ],
                )
              else
              // 已登入狀態 - 顯示用戶頭像
                FutureBuilder<Map<String, dynamic>>(
                  future: _getUserInfo(),
                  builder: (context, userSnapshot) {
                    final userAccount = userSnapshot.data?['account'] ?? '';
                    final isAdmin = userSnapshot.data?['isAdmin'] ?? false;

                    return Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (isAdmin) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminPage(),
                                ),
                              ).then((_) => setState(() {}));
                            } else {
                              // 導向會員中心頁面
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const MemberCenterPage(),
                                ),
                              ).then((_) => setState(() {}));
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isAdmin ? Colors.red : Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                userAccount.isNotEmpty
                                    ? userAccount[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red),
                            ),
                            child: const Text(
                              '管理員',
                              style: TextStyle(fontSize: 10, color: Colors.red),
                            ),
                          ),
                      ],
                    );
                  },
                ),

              const Spacer(),

              // 收藏按鈕 (來自 HomePage)
              GestureDetector(
                onTap: () {
                  // 檢查是否登入，未登入則導向登入頁面
                  if (!isLoggedIn) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('請先登入以查看收藏')));
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    ).then(
                          (_) => setState(() {
                        _loadUserId().then((__) => _fetchData());
                      }),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookmarkPage(),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bookmark,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 8),
              /*
              // Switch for Event Sorting / Multiple Perspectives (原 AIPage 邏輯)
              Switch(
                value: !_isEventSortingMode,
                onChanged: (bool value) {
                  setState(() {
                    _isEventSortingMode = !value;
                    // # 🌟 搜尋功能修正 🌟
                    // 切換模式後，如果正在搜尋，重新觸發篩選，確保切換後的列表是正確篩選的
                    _filterData(_currentSearchKeyword);
                  });
                },
                activeColor: Colors.blue,
                inactiveTrackColor: Colors.grey.shade300,
                inactiveThumbColor: Colors.white,
              ),*/
            ],
          ),
        );
      },
    );
  }

  // ========== 搜尋列 (從 AIPage 原本邏輯改為 HomePage 樣式) ==========
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController, // 綁定控制器
        decoration: InputDecoration(
          hintText: _isEventSortingMode ? "搜尋事件整理" : "搜尋多方觀點",
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon:
          _currentSearchKeyword.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
            onPressed: () {
              _searchController.clear(); // 清空輸入框
              // _onSearchChanged 會被觸發，重新顯示完整列表
            },
          )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      body: SafeArea(
        child: Column(
          children: [
            // --- 頂部導覽列 ---
            _buildTopToolBar(), // 替換為新工具欄
            // --- 搜尋列 ---
            _buildSearchBar(), // 替換為新搜尋列
            // AI技術協助聲明 (保留)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    "使用AI技術協助",
                    style: TextStyle(color: Color(0xFF9ca3af), fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Color(0xFF9ca3af),
                  ),
                  const Spacer(),
                  const Text(
                    "資訊若有失真狀況，一概不負法律責任",
                    style: TextStyle(color: Color(0xFFef4444), fontSize: 10),
                  ),
                ],
              ),
            ),
            // --- 主要內容區 (使用 FutureBuilder 確保數據載入) ---
            Expanded(
              child: FutureBuilder<void>(
                future: _loadingFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    print('Loading error: ${snapshot.error}');
                    return Center(child: Text('數據載入失敗: ${snapshot.error}'));
                  } else {
                    // 只有在數據和收藏狀態都載入完畢後，才繪製內容
                    return _isEventSortingMode
                        ? _buildEventSortingContent()
                        : _buildMultiplePerspectivesContent();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 事件整理內容 (使用 _filteredEventsortingList) ---
  Widget _buildEventSortingContent() {
    // # 🌟 搜尋功能修正 🌟 - 使用篩選後的列表
    final listToShow = _filteredEventsortingList;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                _isSearching && _currentSearchKeyword.isNotEmpty
                    ? "搜尋結果 (${listToShow.length} 筆)"
                    : "AI整理近期焦點新聞",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child:
          listToShow.isEmpty
              ? Center(child: Text('找不到與 "$_currentSearchKeyword" 相關的事件'))
              : ListView.builder(
            itemCount: listToShow.length,
            itemBuilder: (context, index) {
              final event = listToShow[index];

              final String title = event['eventsorting_title'] ?? '';
              if (title.isEmpty) {
                return const SizedBox.shrink();
              }

              final eventId = event['eventsorting_id'];
              // 收藏狀態判斷：檢查 _bookmarkIdStatus 中是否有非 null 的 bookmark_id
              final isBookmarked =
                  _bookmarkIdStatus.containsKey(eventId) &&
                      _bookmarkIdStatus[eventId] != null;

              return _buildNewsCard(
                title: title,
                content: event['eventsorting_summary'] ?? '',
                // 根據要求，清掉 'details' 的內容
                details: '', // <-- 修改點 1
                isBookmarked: isBookmarked,
                onBookmarkTap:
                    () => _toggleBookmark(eventId, 'eventsorting'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                          EventSortingDetailPage(id: eventId),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 多方看法內容 (使用 _filteredMultiplePerspectivesList) ---
  Widget _buildMultiplePerspectivesContent() {
    // # 🌟 搜尋功能修正 🌟 - 使用篩選後的列表
    final listToShow = _filteredMultiplePerspectivesList;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                _isSearching && _currentSearchKeyword.isNotEmpty
                    ? "搜尋結果 (${listToShow.length} 筆)"
                    : "近期新聞不同觀點之討論",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child:
          listToShow.isEmpty
              ? Center(child: Text('找不到與 "$_currentSearchKeyword" 相關的觀點'))
              : ListView.builder(
            itemCount: listToShow.length,
            itemBuilder: (context, index) {
              final view = listToShow[index];

              // 💥 修正點 2: multipleperspectives_title 已移除，改用 eventsorting_title
              final String title =
                  view['eventsorting_title'] ?? '';
              if (title.isEmpty) {
                return const SizedBox.shrink();
              }

              final mpId = view['multipleperspectives_id'];
              // 收藏狀態判斷：檢查 _multiplePerspectivesBookmarkIdStatus 中是否有非 null 的 bookmark_id
              final isBookmarked =
                  _multiplePerspectivesBookmarkIdStatus.containsKey(
                    mpId,
                  ) &&
                      _multiplePerspectivesBookmarkIdStatus[mpId] != null;

              return _buildNewsCard(
                title: title,
                content: '看法統整',
                details:
                '${view['multipleperspectives_view_count'] ?? 0}種對立觀點',
                isMultiplePerspectives: true,
                isBookmarked: isBookmarked,
                onBookmarkTap: () {
                  _toggleBookmark(mpId, 'multipleperspectives');
                },
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                          MultiplePerspectivesDetailPage(id: mpId),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 卡片元件 (保持不變) ---
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
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
