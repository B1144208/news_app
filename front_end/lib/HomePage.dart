import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'config.dart';
import 'LoginPage.dart';
import 'AdminPage.dart';
import 'ViewNewsContent.dart';
import 'MapPage.dart';
import 'AIPage.dart';
import 'SearchPage.dart';
import 'BookmarkPage.dart';
import 'MemberCenterPage.dart';
import 'SignupPage.dart';
import 'GroupCustomizePage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;
  String _selectedCategory = '全部';
  int? _selectedGroupId; // 新增:選中的分類ID
  String _selectedSortType = '總熱度'; // 新增:排序方式

  // 側邊欄相關
  bool _isSidebarExpanded = true;
  static const double SIDEBAR_EXPANDED_WIDTH = 180;
  static const double SIDEBAR_COLLAPSED_WIDTH = 0;

  // 細分類相關
  Map<int, List<Map<String, dynamic>>> _categoryDetails = {};
  Map<int, GlobalKey> _arrowButtonKeys = {};

  List<Map<String, dynamic>> _categories = []; // 改為動態列表
  final List<String> _sortTypes = [
    '總熱度',
    '瀏覽數量',
    '分享數量',
    '收藏數量',
    '留言數量',
  ]; // 新增:排序選項

  List<Map<String, dynamic>> _newsData = [];
  List<Map<String, dynamic>> _allNewsData = []; // 新增:儲存所有新聞資料
  bool _isLoading = false;
  bool _isLoadingMore = false; // 新增:載入更多資料的狀態
  String? _error;
  int _currentPage = 0; // 新增:當前頁碼
  final int _newsPerPage = 30; // 新增:每頁新聞數量
  final ScrollController _scrollController = ScrollController(); // 新增:滾動控制器
  int _displayStartIndex = 0; // 新增:當前顯示資料在_allNewsData中的起始索引

  // ========== 新增:圖片代理函數 ==========
  String _getProxiedImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return '';

    // URL 編碼原始圖片 URL
    final encodedUrl = Uri.encodeComponent(originalUrl);

    // 構建代理 URL
    return '${Config.apiBaseUrl}/image/proxy?url=$encodedUrl';
  }

  // 快速播放相關變數
  bool _isPlayerVisible = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  // 新增:AudioPlayer 實例
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 新增:後台文本串列（10 篇新聞）
  int paragraphCount = 10;
  List<String> paragraphText = [
    "快訊／川普簽字！白宮宣布《台灣保證實施法案》正式生效。這項法案旨在加強美國對台灣的支持與保證，標誌著美台關係進一步穩固，對區域安全有重要影響。",
    "1972年日中聯合聲明重申台灣是中國領土不可分割的一部分。高雄市政府表示，這項立場沒有改變，強調遵守當年聲明的原則，維持兩岸關係現狀。",
    "高市早苗公開稱台灣是中國領土不可分割的一部分。此言論引發關注，顯示她在兩岸立場上有所收斂，與過去表態相比態度轉趨保守。",
    "川普簽署的《台灣保證實施法案》包含七大重點。法案強化美國對台軍事與外交支持，提升台灣安全保障，並促進雙邊經濟合作，展現美國對台承諾。",
    "王世堅宣布不參選台北市長，首度透露原因令人心酸。他表示因個人考量與家庭因素，決定不投入選戰，強調未來仍會關注市政發展。",
    "中國對日本展現霸凌態勢。華爾街日報社論指出，中國行為給全球上了一課，提醒國際社會警惕區域安全威脅，呼籲各國加強合作應對挑戰。",
    "印航一架波音七三七客機消失十三年，竟停在機場無人知曉。事件離譜，航空公司還需支付三千五百萬賠償，引發外界對管理漏洞質疑。",
    "記憶體股目標價衝上百八十元，EPS估計達十九點五元。華邦電、南亞科和群聯被點名為最強三巨頭，市場報價一路飆升，展望明年持續看好。",
    "清潔隊員轉送價值三十二元電鍋給拾荒婦遭判刑。清潔隊長回應此事，強調依法處理並呼籲社會關注弱勢，案件引發輿論熱議。",
    "谷歌四百萬片TPU產量未達標，原因卡在台積電。分析師表示，真正大規模爆發要等到二零二七年，顯示半導體供應鏈仍面臨挑戰。"
  ];
  int _currentParagraphIndex = 0; // 當前播放的文章索引

  // 儲存已生成的 MP3 快取（避免重複生成）
  final Map<int, String> _audioCache = {};
  @override
  void initState() {
    super.initState();
    _fetchCategories(); // 先載入分類
    _scrollController.addListener(_onScroll); // 新增:監聽滾動事件

    // 監聽音訊播放完成事件
    _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return; // 檢查 widget 是否還在樹中
      _onAudioComplete();
    });

    // 監聽音訊播放狀態
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return; // 檢查 widget 是否還在樹中

      if (state == PlayerState.playing) {
        setState(() {
          _isPlaying = true;
        });
      } else if (state == PlayerState.paused || state == PlayerState.stopped) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  // 新增:獲取分類列表
  Future<void> _fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID');
      final isLoggedIn = prefs.getBool('IsLogin') ?? false;

      print('🔍 _fetchCategories - 登入狀態: $isLoggedIn, UserID: $userId');

      List<Map<String, dynamic>> categories = [];

      // 先獲取所有 group_data
      final groupResponse = await http.get(
        Uri.parse('${Config.apiBaseUrl}/group'),
      );

      if (groupResponse.statusCode != 200) {
        throw Exception('獲取分類資料失敗');
      }

      final groupData = json.decode(groupResponse.body);
      if (groupData['success'] != true || groupData['data'] == null) {
        throw Exception('分類資料格式錯誤');
      }

      print('📡 獲取到 ${groupData['data'].length} 個分類');

      // 使用 Set 來追蹤已添加的 group_id,確保不重複
      Set<int> addedGroupIds = {};

      for (var item in groupData['data']) {
        int? groupId = item['group_id'];

        if (groupId != null && !addedGroupIds.contains(groupId)) {
          categories.add({
            'group_id': groupId,
            'group_name': item['group_name'] ?? '未命名',
          });
          addedGroupIds.add(groupId);
          print('   ✅ 添加: ${item['group_name']} (ID: $groupId)');
        } else {
          print('   ⚠️ 跳過重複: ${item['group_name']} (ID: $groupId)');
        }
      }

      // 按 group_id 排序
      categories.sort(
            (a, b) => (a['group_id'] ?? 0).compareTo(b['group_id'] ?? 0),
      );

      print('✅ 最終分類數量: ${categories.length}');
      print('✅ 分類 IDs: $addedGroupIds');

      setState(() {
        // 在最前面添加"全部"選項
        _categories = [
          {'group_id': null, 'group_name': '全部'},
          ...categories,
        ];
      });

      // 分類載入完成後再載入新聞
      _fetchNews();
    } catch (error) {
      print('❌ 獲取分類失敗: $error');
      setState(() {
        _categories = [
          {'group_id': null, 'group_name': '全部'},
        ];
      });
      _fetchNews();
    }
  }

  // 新增:獲取特定分類的詳細子分類
  Future<void> _fetchCategoryDetails(int groupId) async {
    // 如果已經加載過,直接返回
    if (_categoryDetails.containsKey(groupId)) {
      return;
    }

    try {
      print('🔍 獲取分類詳情 - groupId: $groupId');

      // 使用 /group 端點獲取所有分類和詳細分類的數據
      final response = await http.get(Uri.parse('${Config.apiBaseUrl}/group'));

      print('📡 API 響應狀態碼: ${response.statusCode}');
      print(
        '📡 API 響應內容: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        List<dynamic> dataList = [];

        // 處理兩種可能的返回格式
        if (responseData is Map && responseData['data'] != null) {
          // 格式: {"success":true, "data": [...]}
          dataList = responseData['data'];
          print('📦 使用 Map 格式，data 長度: ${dataList.length}');
        } else if (responseData is List) {
          // 格式: [...]
          dataList = responseData;
          print('📦 使用 List 格式，長度: ${dataList.length}');
        }

        if (dataList.isNotEmpty) {
          List<Map<String, dynamic>> details = [];

          // 過濾出符合當前 groupId 的詳細分類
          for (var item in dataList) {
            print(
              '🔍 檢查項目: group_id=${item['group_id']}, group_detail_name=${item['group_detail_name']}',
            );

            if (item['group_id'] == groupId &&
                item['group_detail_name'] != null) {
              details.add({
                'group_detail_id': item['group_detail_id'],
                'group_detail_name': item['group_detail_name'],
              });
              print('   ✅ 匹配! 添加: ${item['group_detail_name']}');
            }
          }

          print('✅ 獲取到 ${details.length} 個詳細分類 (groupId: $groupId)');

          setState(() {
            _categoryDetails[groupId] = details;
          });
        } else {
          print('⚠️ 沒有數據');
        }
      } else {
        print('❌ API 錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 獲取分類詳情失敗: $error');
      print('❌ 錯誤堆棧: ${StackTrace.current}');
    }
  }

  // 修改：滾動監聽 - 支援雙向載入
  void _onScroll() {
    // 向下滾動到底部 - 載入更多
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore && _allNewsData.isNotEmpty) {
        _loadMoreNews();
      }
    }
    // 向上滾動到頂部 - 載入前面的資料
    else if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 100) {
      if (!_isLoadingMore && _displayStartIndex > 0) {
        _loadPreviousNews();
      }
    }
  }

  // 修改：載入更多新聞（向下滾動）
  Future<void> _loadMoreNews() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      // 計算當前顯示資料的結束索引
      int currentEndIndex = _displayStartIndex + _newsData.length;

      // 檢查是否還有更多資料可載入
      if (currentEndIndex < _allNewsData.length) {
        // 如果已有60個新聞，刪除前30個
        if (_newsData.length >= 60) {
          _newsData.removeRange(0, 30);
          _displayStartIndex += 30;
        }

        // 載入接下來的30個新聞
        int newEndIndex = currentEndIndex + _newsPerPage;
        if (newEndIndex > _allNewsData.length) {
          newEndIndex = _allNewsData.length;
        }

        _newsData.addAll(_allNewsData.sublist(currentEndIndex, newEndIndex));
      }

      _isLoadingMore = false;
    });
  }

  // 新增：載入前面的新聞（向上滾動）
  Future<void> _loadPreviousNews() async {
    if (_isLoadingMore || _displayStartIndex <= 0) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    // 保存當前滾動位置
    final currentScrollPosition = _scrollController.position.pixels;
    final itemHeight =
        _scrollController.position.maxScrollExtent / _newsData.length;

    setState(() {
      // 如果已有60個新聞，刪除後30個
      if (_newsData.length >= 60) {
        _newsData.removeRange(30, _newsData.length);
      }

      // 計算要載入的起始索引
      int newStartIndex = _displayStartIndex - _newsPerPage;
      if (newStartIndex < 0) {
        newStartIndex = 0;
      }

      // 在前面插入資料
      _newsData.insertAll(
        0,
        _allNewsData.sublist(newStartIndex, _displayStartIndex),
      );
      _displayStartIndex = newStartIndex;

      _isLoadingMore = false;
    });

    // 延遲調整滾動位置，避免突然跳轉
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // 計算新增加的項目高度，保持視覺位置
        final addedItemsCount =
        _displayStartIndex == 0
            ? _newsPerPage
            : (_allNewsData.length - _displayStartIndex);
        _scrollController.jumpTo(currentScrollPosition + (itemHeight * 30));
      }
    });
  }

  // 修復後的 _fetchNews() 方法
  // 新增:呼叫 getScript API
  Future<List<Map<String, dynamic>>?> _callGetScriptAPI(int? clickedNewsId) async {
    try {
      // 檢查 clickedNewsId 是否有效
      if (clickedNewsId == null) {
        print('⚠️ clickedNewsId 為 null，無法呼叫 getScript API');
        return null;
      }

      // 構建 idList：點擊的新聞 ID 在第一位，其餘按原順序
      List<int> idList = [];

      // 先加入點擊的新聞 ID
      idList.add(clickedNewsId);

      // 再加入其他新聞 ID（排除已點擊的）
      for (var news in _newsData) {
        final newsId = news['id']; // 修正：使用 'id' 而不是 'news_id'
        if (newsId != null && newsId is int && newsId != clickedNewsId) {
          idList.add(newsId);
        }
      }

      // 如果沒有任何有效的 ID，則不呼叫 API
      if (idList.isEmpty) {
        print('⚠️ idList 為空，無法呼叫 getScript API');
        return null;
      }

      print('🎯 呼叫 getScript API - idList: $idList');

      // 構建 URL
      final url = Uri.parse(
        '${Config.apiBaseUrl}/script/general?idList=${jsonEncode(idList)}',
      );

      print('📡 API URL: $url');

      // 發送 GET 請求
      final response = await http.get(url);

      print('📡 API 響應狀態碼: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ getScript API 呼叫成功');

        // 打印原始回應內容（前500字元）
        final rawBody = response.body;
        print('📄 原始回應長度: ${rawBody.length} 字元');
        print('📄 原始回應（前500字元）: ${rawBody.substring(0, rawBody.length > 500 ? 500 : rawBody.length)}');

        // ========== 處理 SSE 格式 ==========
        List<Map<String, dynamic>> scriptList = [];

        // 按行分割
        final lines = rawBody.split('\n');
        print('📄 總共 ${lines.length} 行');

        for (var line in lines) {
          line = line.trim();

          // 跳過空行
          if (line.isEmpty) continue;

          // 處理 SSE 格式：data: {...}
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6); // 移除 "data: " 前綴

            try {
              final jsonData = json.decode(jsonStr);

              // 檢查類型
              if (jsonData is Map) {
                final type = jsonData['type'];

                if (type == 'item') {
                  // 這是一則新聞
                  scriptList.add(Map<String, dynamic>.from(jsonData));
                  print('✅ 解析新聞: ${jsonData['newsId']} - ${jsonData['title']}');
                } else if (type == 'done') {
                  // 結束標記
                  print('✅ 收到結束標記');
                } else {
                  print('⚠️ 未知類型: $type');
                }
              }
            } catch (e) {
              print('❌ 解析 JSON 失敗: $e');
              print('❌ 問題行: $jsonStr');
            }
          }
        }

        // 打印第一則新聞的詳細信息
        if (scriptList.isNotEmpty) {
          print('📰 第一則新聞:');
          print('   keys: ${scriptList[0].keys}');
          print('   newsId: ${scriptList[0]['newsId']}');
          print('   title: ${scriptList[0]['title']}');
          print('   reporter 長度: ${scriptList[0]['reporter']?.toString().length ?? 0}');
          print('   chat 數量: ${(scriptList[0]['chat'] as List?)?.length ?? 0}');
        }

        print('📋 最終接收到 ${scriptList.length} 則新聞腳本');
        return scriptList;
      } else {
        print('❌ getScript API 呼叫失敗: ${response.statusCode}');
        return null;
      }
    } catch (error) {
      print('❌ 呼叫 getScript API 發生錯誤: $error');
      return null;
    }
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _displayStartIndex = 0; // 重置顯示起始索引
      _newsData.clear();
      _allNewsData.clear();
    });

    try {
      http.Response response;

      if (_selectedGroupId != null) {
        // 查詢特定分類 - ✅ 修復: 使用 /search 端點
        print('🔡 查詢特定分類新聞 - groupId: $_selectedGroupId');

        response = await http.post(
          Uri.parse(
            '${Config.apiBaseUrl}/news/search?mode=simple&order=general&limit=300',
          ),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'groupId': _selectedGroupId, 'groupType': 'data'}),
        );

        print('🔡 特定分類回應: ${response.statusCode}');
      } else {
        // 查詢所有新聞 - ✅ 修復: 使用 /search 端點
        print('🔡 查詢所有新聞');

        response = await http.post(
          Uri.parse(
            '${Config.apiBaseUrl}/news/search?mode=simple&order=general&limit=300',
          ),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({}),
        );

        print('🔡 所有新聞回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> newsList;

          if (responseData['data'] is List) {
            newsList = responseData['data'];
            print('📦 data 是 List 格式');
          } else if (responseData['data'] is Map) {
            newsList = responseData['data']['simpleList'] ?? [];
            print('📦 data 是 Map 格式,提取 simpleList');
          } else {
            newsList = [];
            print('⚠️ data 格式不明');
          }

          print('✅ 獲取到新聞數量: ${newsList.length}');

          if (newsList.isEmpty) {
            setState(() {
              _allNewsData = [];
              _newsData = [];
              _isLoading = false;
              _error = null;
            });
            return;
          }

          // 處理新聞數據
          List<Map<String, dynamic>> processedNews =
          newsList.map<Map<String, dynamic>>((news) {
            return {
              'id': news['newsId'],
              'title': news['newsTitle'] ?? '無標題',
              'channel': news['channelName'] ?? '未知頻道',
              'publish_date': _formatDate(news['publishDate']),
              'cover_img': news['coverImageUrl'],
              'cover_img_alt': news['coverImageAlt'] ?? '',
              'news_date': news['publishDate'],
              'comments': 0,
              'views': 0,
              'shares': 0,
              'bookmarks': 0,
            };
          }).toList();

          // 根據選擇的排序方式排序
          _sortNews(processedNews);

          setState(() {
            _allNewsData = processedNews;
            _newsData = _allNewsData.take(_newsPerPage).toList();
            _isLoading = false;
          });
        } else {
          throw Exception(responseData['message'] ?? '獲取新聞失敗');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 載入新聞錯誤: $error');
      setState(() {
        _error = '載入新聞時發生錯誤: $error';
        _isLoading = false;
      });
    }
  }

  // 新增：根據詳細分類篩選新聞
  Future<void> _fetchNewsByGroupDetail(int groupDetailId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _displayStartIndex = 0; // 重置顯示起始索引
      _newsData.clear();
      _allNewsData.clear();
    });

    try {
      print('🔡 查詢詳細分類新聞 - groupDetailId: $groupDetailId');

      final response = await http.post(
        Uri.parse(
          '${Config.apiBaseUrl}/news/search?mode=simple&order=general&limit=300',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'groupId': groupDetailId,
          'groupType': 'detail', // 使用 detail 類型
        }),
      );

      print('🔡 詳細分類回應: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> newsList = responseData['data'] ?? [];
          print('📰 獲取到 ${newsList.length} 條詳細分類新聞');

          List<Map<String, dynamic>> processedNews = [];
          for (var news in newsList) {
            processedNews.add({
              'news_id': news['newsId'],
              'channel': news['channelName'] ?? '未知頻道',
              'cover_img': news['coverImageUrl'],
              'title': news['newsTitle'] ?? '無標題',
              'publish_date': news['publishDate'] ?? '未知時間',
              'comments': 0, // API 可能沒有返回評論數
            });
          }

          // 根據選擇的排序方式排序
          _sortNews(processedNews);

          setState(() {
            _allNewsData = processedNews;
            _newsData = _allNewsData.take(_newsPerPage).toList();
            _isLoading = false;
          });
        } else {
          throw Exception(responseData['message'] ?? '獲取詳細分類新聞失敗');
        }
      } else {
        throw Exception('伺服器錯誤: ${response.statusCode}');
      }
    } catch (error) {
      print('❌ 載入詳細分類新聞錯誤: $error');
      setState(() {
        _error = '載入詳細分類新聞時發生錯誤: $error';
        _isLoading = false;
      });
    }
  }

  // 新增：根據排序方式排序新聞
  void _sortNews(List<Map<String, dynamic>> newsList) {
    switch (_selectedSortType) {
      case '瀏覽數量':
        newsList.sort(
              (a, b) => (b['views'] as int).compareTo(a['views'] as int),
        );
        break;
      case '分享數量':
        newsList.sort(
              (a, b) => (b['shares'] as int).compareTo(a['shares'] as int),
        );
        break;
      case '收藏數量':
        newsList.sort(
              (a, b) => (b['bookmarks'] as int).compareTo(a['bookmarks'] as int),
        );
        break;
      case '留言數量':
        newsList.sort(
              (a, b) => (b['comments'] as int).compareTo(a['comments'] as int),
        );
        break;
      case '總熱度':
      default:
      // 總熱度 = 瀏覽數 + 分享數*2 + 收藏數*3 + 留言數*2
        newsList.sort((a, b) {
          int heatA =
              (a['views'] as int) +
                  (a['shares'] as int) * 2 +
                  (a['bookmarks'] as int) * 3 +
                  (a['comments'] as int) * 2;
          int heatB =
              (b['views'] as int) +
                  (b['shares'] as int) * 2 +
                  (b['bookmarks'] as int) * 3 +
                  (b['comments'] as int) * 2;
          return heatB.compareTo(heatA);
        });
        break;
    }
  }

  // 獲取頻道資料
  Future<Map<int, String>> _fetchChannelData() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/channel'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> channels = responseData['data'];
          Map<int, String> channelMap = {};
          for (var channel in channels) {
            channelMap[channel['channel_id']] =
                channel['channel_name'] ?? '未知頻道';
          }
          return channelMap;
        }
      }
    } catch (error) {
      print('獲取頻道資料失敗: $error');
    }
    return {};
  }

  // 獲取圖片資料
  Future<Map<int, String>> _fetchImageData() async {
    try {
      final response = await http.get(Uri.parse('${Config.apiBaseUrl}/image'));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<dynamic> images = responseData['data'];
          Map<int, String> imageMap = {};
          for (var image in images) {
            imageMap[image['image_id']] = image['image_origin_url'] ?? '';
          }
          return imageMap;
        }
      }
    } catch (error) {
      print('獲取圖片資料失敗: $error');
    }
    return {};
  }

  // 格式化日期
  String _formatDate(String? dateString) {
    if (dateString == null) return '未知時間';

    try {
      final DateTime newsDate = DateTime.parse(dateString);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(newsDate);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}分鐘前';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}小時前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}天前';
      } else {
        return '${newsDate.year}年${newsDate.month}月${newsDate.day}日';
      }
    } catch (e) {
      return '未知時間';
    }
  }

  // 獲取用戶資訊
  Future<Map<String, dynamic>> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'account': prefs.getString('Account') ?? '',
      'isAdmin': (prefs.getInt('UserLevel') ?? 0) >= 5,
    };
  }

  // 新增：解析時間字串為秒數
  // 新增:格式化剩餘時間顯示
  String _formatRemainingTime() {
    // 顯示剩餘篇數
    int remaining = paragraphCount - _currentParagraphIndex;
    return '$remaining 篇';
  }

  // 快速播放功能
  Future<void> _startQuickPlay() async {
    // 直接開始播放，不從 API 獲取
    setState(() {
      _isPlayerVisible = true;
      _currentParagraphIndex = 0;
    });

    // 播放第一篇文章
    await _playCurrentParagraph();
  }

  // 播放當前文章 - 檢查快取或生成 TTS
  Future<void> _playCurrentParagraph() async {
    if (_currentParagraphIndex >= paragraphCount) {
      // 所有文章播放完畢
      _closePlayer();
      return;
    }

    try {
      String currentText = paragraphText[_currentParagraphIndex];

      print('🎵 準備播放第 ${_currentParagraphIndex + 1} 篇');

      // 檢查是否已有快取的音訊
      if (_audioCache.containsKey(_currentParagraphIndex)) {
        // 使用快取的 data URL
        String cachedAudioUrl = _audioCache[_currentParagraphIndex]!;
        print('✅ 使用快取音訊');

        await _audioPlayer.stop();
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.play(UrlSource(cachedAudioUrl));

        setState(() {
          _isPlaying = true;
        });

        print('🎵 正在播放第 ${_currentParagraphIndex + 1} 篇文章');
        return;
      }

      // 沒有快取，呼叫 TTS API 生成音訊
      print('🔄 生成 TTS 音訊...');

      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/tts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': currentText,
          'voiceId': '9lHjugDhwqoxA5MhX0az', // ANNA_SU - Taiwan, social media
          'stability': 0.5,
          'similarity_boost': 0.75,
        }),
      );

      if (response.statusCode == 200) {
        // 獲取音訊 bytes
        final Uint8List bytes = response.bodyBytes;

        print('✅ 收到音訊數據: ${bytes.length} bytes');

        // 停止當前播放
        await _audioPlayer.stop();

        // 轉換為 base64 data URL
        final String base64Audio = base64Encode(bytes);
        final String dataUrl = 'data:audio/mpeg;base64,$base64Audio';

        // 儲存到快取
        _audioCache[_currentParagraphIndex] = dataUrl;

        print('💾 音訊已快取');

        // 設定播放速度
        await _audioPlayer.setPlaybackRate(_playbackSpeed);

        // 使用 UrlSource 播放 data URL
        await _audioPlayer.play(UrlSource(dataUrl));

        setState(() {
          _isPlaying = true;
        });

        print('🎵 正在播放第 ${_currentParagraphIndex + 1} 篇文章');
      } else {
        print('❌ TTS API 錯誤: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('語音合成失敗: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('❌ 播放錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('播放錯誤: $e')));
      }
    }
  }

  // 音訊播放完成回調
  void _onAudioComplete() {
    print('✅ 第 ${_currentParagraphIndex + 1} 篇播放完成');

    // 自動播放下一篇
    if (_currentParagraphIndex < paragraphCount - 1) {
      setState(() {
        _currentParagraphIndex++;
      });
      _playCurrentParagraph();
    } else {
      // 所有文章播放完畢
      _closePlayer();
    }
  }

  // 切換播放/暫停
  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.resume();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  // 上一篇文章
  Future<void> _previousNews() async {
    if (_currentParagraphIndex > 0) {
      setState(() {
        _currentParagraphIndex--;
      });
      await _playCurrentParagraph();
    }
  }

  // 下一篇文章
  Future<void> _nextNews() async {
    if (_currentParagraphIndex < paragraphCount - 1) {
      setState(() {
        _currentParagraphIndex++;
      });
      await _playCurrentParagraph();
    }
  }

  // 調整播放倍速
  Future<void> _adjustPlaybackSpeed() async {
    setState(() {
      if (_playbackSpeed == 0.5) {
        _playbackSpeed = 1.0;
      } else if (_playbackSpeed == 1.0) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 0.5;
      }
    });

    // 更新 AudioPlayer 的播放速度
    await _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  // 關閉播放器
  Future<void> _closePlayer() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlayerVisible = false;
      _isPlaying = false;
      _currentParagraphIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const MapPage(),
      _buildHomePageWithSidebar(),
      const AIPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      body: SafeArea(
        child: Stack(
          children: [
            pages[_selectedIndex],
            if (_isPlayerVisible) _buildMusicPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHomePageWithSidebar() {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width:
          _isSidebarExpanded
              ? SIDEBAR_EXPANDED_WIDTH
              : SIDEBAR_COLLAPSED_WIDTH,
          child:
          _isSidebarExpanded
              ? _buildLeftSidebar()
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Column(
            children: [
              _buildTopToolBar(),
              _buildQuickPlaySection(),
              Expanded(child: _buildNewsList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0a0e27),
        border: Border(
          right: BorderSide(
            color: const Color(0x4D6366f1), // 0.3 opacity
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('UserID');
              final isLoggedIn = prefs.getBool('IsLogin') ?? false;

              if (!isLoggedIn || userId == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請先登入以自訂分類'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupCustomizePage(userId: userId),
                ),
              );

              if (result == true || result == null) {
                _fetchCategories();
              }
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x406366f1), // 0.25 opacity
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0x996366f1), // 0.6 opacity
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, size: 12, color: Color(0xFF60a5fa)),
                  SizedBox(width: 4),
                  Text(
                    '自訂',
                    style: TextStyle(
                      color: Color(0xFF60a5fa),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0x4D6366f1), // 0.3 opacity
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
            _categories.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 40,
                    color: const Color(0xFF94a3b8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '暫無分類',
                    style: TextStyle(
                      color: const Color(0xFF94a3b8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final categoryName = category['group_name'] ?? '未命名';
                final groupId = category['group_id'];
                final isSelected = _selectedCategory == categoryName;

                // 提前初始化 GlobalKey（確保箭頭能使用）
                if (groupId != null &&
                    !_arrowButtonKeys.containsKey(groupId)) {
                  _arrowButtonKeys[groupId] = GlobalKey();
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                    isSelected
                        ? const Color.fromARGB(255, 87, 25, 152)
                        : const Color.fromARGB(0, 6, 6, 6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border(
                      left: BorderSide(
                        color:
                        isSelected
                            ? const Color.fromARGB(
                          255,
                          88,
                          151,
                          223,
                        )
                            : const Color.fromARGB(
                          77, // 0.3 opacity (77 = 0x4D)
                          72,
                          60,
                          206,
                        ),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 左邊：分類名稱（點擊切換）
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _selectedCategory = categoryName;
                              _selectedGroupId = groupId ?? 0;
                            });
                            _fetchNews();
                          },
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              color: const Color.fromARGB(
                                255,
                                84,
                                122,
                                209,
                              ),
                              fontWeight:
                              isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // 分割線（不明顯，透明度 20%）
                      Container(
                        width: 1,
                        height: 16,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        color: const Color(0x336366f1), // 0.2 opacity
                      ),
                      // 右邊：下拉箭頭（點擊顯示菜單）
                      if (groupId != null)
                        GestureDetector(
                          key: _arrowButtonKeys[groupId],
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            print(
                              '📌 點擊箭頭: $categoryName (ID: $groupId)',
                            );
                            await _fetchCategoryDetails(groupId);

                            final details =
                                _categoryDetails[groupId] ?? [];

                            if (details.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text('該分類沒有詳細子分類'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                              return;
                            }

                            final RenderBox? button =
                            _arrowButtonKeys[groupId]
                                ?.currentContext
                                ?.findRenderObject()
                            as RenderBox?;
                            if (button == null) {
                              print('❌ 無法獲取按鈕位置');
                              return;
                            }

                            final RenderBox overlay =
                            Overlay.of(
                              context,
                            ).context.findRenderObject()
                            as RenderBox;
                            final RelativeRect position =
                            RelativeRect.fromRect(
                              Rect.fromPoints(
                                button.localToGlobal(
                                  Offset.zero,
                                  ancestor: overlay,
                                ),
                                button.localToGlobal(
                                  button.size.bottomRight(
                                    Offset.zero,
                                  ),
                                  ancestor: overlay,
                                ),
                              ),
                              Offset.zero & overlay.size,
                            );

                            final selectedDetail = await showMenu<
                                Map<String, dynamic>
                            >(
                              context: context,
                              position: position,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: const Color(0xFF1a2a4e),
                              constraints: const BoxConstraints(
                                minWidth: 150,
                                maxWidth: 250,
                              ),
                              items:
                              details.map((detail) {
                                return PopupMenuItem<
                                    Map<String, dynamic>
                                >(
                                  value: detail,
                                  child: Text(
                                    detail['group_detail_name'] ??
                                        '未命名',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFd1d5db),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );

                            if (selectedDetail != null) {
                              print(
                                '📌 選擇詳細分類: ${selectedDetail['group_detail_name']} (ID: ${selectedDetail['group_detail_id']})',
                              );

                              setState(() {
                                _selectedCategory =
                                '${categoryName} > ${selectedDetail['group_detail_name']}';
                                _selectedGroupId =
                                selectedDetail['group_detail_id'];
                              });

                              _fetchNewsByGroupDetail(
                                selectedDetail['group_detail_id'],
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color:
                              isSelected
                                  ? const Color.fromARGB(
                                255,
                                73,
                                99,
                                218,
                              )
                                  : const Color.fromARGB(
                                255,
                                78,
                                90,
                                222,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========== 工具欄：支持登入系統 ==========
  Widget _buildTopToolBar() {
    return FutureBuilder<bool>(
      future: SharedPreferences.getInstance().then(
            (prefs) => prefs.getBool('IsLogin') ?? false,
      ),
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.data ?? false;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              if (!isLoggedIn)
              // 未登入狀態 - 顯示登入和註冊按鈕
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
                          setState(() {});
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 71, 11, 95),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 32),
                      ),
                      child: const Text('登入', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    /*
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupPage(),
                          ),
                        ).then((_) {
                          // 註冊後刷新頁面
                          setState(() {});
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 32),
                      ),
                      child: const Text('註冊', style: TextStyle(fontSize: 12)),
                    ),*/
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
                              color: Colors.red,
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

              const SizedBox(width: 12),

              // 搜尋欄 - 放在中間並擴展
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchPage(),
                      ),
                    );
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a2a4e),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey,
                          spreadRadius: 0,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: const Color(0xFFd1d5db),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Text(
                          '搜尋',
                          style: TextStyle(
                            color: const Color(0xFFd1d5db),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 收藏按鈕
              GestureDetector(
                onTap: () {
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
                    color: const Color(0xFF6366f1),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        spreadRadius: 0,
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              // 點擊三條線圖標進入自訂分類頁面
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('UserID'); // 修復:使用正確的鍵名
              final isLoggedIn = prefs.getBool('IsLogin') ?? false;

              print('🔍 點擊自訂按鈕 - 登入狀態: $isLoggedIn, UserID: $userId');

              if (!isLoggedIn || userId == null) {
                // 未登入,提示用戶登入
                print('⚠️ 未登入或 UserID 為 null');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('請先登入以自訂分類'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }

              print('✅ 導航到自訂分類頁面, UserID: $userId');

              // 導航到自訂分類頁面
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupCustomizePage(userId: userId),
                ),
              );

              // 從自訂頁面返回後重新載入分類
              if (result == true || result == null) {
                print('🔄 從自訂頁面返回,重新載入分類');
                _fetchCategories();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1a2a4e),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 0,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu,
                size: 20,
                color: const Color(0xFFd1d5db),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 40, // 固定高度以避免裁切
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final categoryName = category['group_name'] ?? '未命名';
                  final groupId = category['group_id'];
                  final isSelected = _selectedCategory == categoryName;

                  // 為每個箭頭按鈕創建 GlobalKey
                  if (groupId != null &&
                      !_arrowButtonKeys.containsKey(groupId)) {
                    _arrowButtonKeys[groupId] = GlobalKey();
                  }

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 主分類按鈕
                        GestureDetector(
                          onTap: () {
                            print('📌 點擊分類: $categoryName (ID: $groupId)');
                            setState(() {
                              _selectedCategory = categoryName;
                              _selectedGroupId = groupId;
                            });
                            _fetchNews();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                              isSelected
                                  ? const Color.fromARGB(255, 157, 60, 218)
                                  : const Color(0xFF1a2a4e),
                              borderRadius:
                              groupId != null
                                  ? const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                              )
                                  : BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey,
                                  spreadRadius: 0,
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                color:
                                isSelected
                                    ? Colors.white
                                    : const Color(0xFFd1d5db),
                                fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        // 下拉箭頭按鈕（僅當有 groupId 時顯示）
                        if (groupId != null)
                          GestureDetector(
                            key: _arrowButtonKeys[groupId],
                            onTap: () async {
                              // 先獲取詳細分類
                              print('📌 點擊箭頭: $categoryName (ID: $groupId)');
                              await _fetchCategoryDetails(groupId);

                              // 獲取數據後再顯示菜單
                              final details = _categoryDetails[groupId] ?? [];

                              if (details.isEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('該分類沒有詳細子分類'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                                return;
                              }

                              // 使用 GlobalKey 獲取按鈕位置
                              final RenderBox? button =
                              _arrowButtonKeys[groupId]?.currentContext
                                  ?.findRenderObject()
                              as RenderBox?;
                              if (button == null) {
                                print('❌ 無法獲取按鈕位置');
                                return;
                              }

                              final RenderBox overlay =
                              Overlay.of(context).context.findRenderObject()
                              as RenderBox;
                              final RelativeRect position =
                              RelativeRect.fromRect(
                                Rect.fromPoints(
                                  button.localToGlobal(
                                    Offset.zero,
                                    ancestor: overlay,
                                  ),
                                  button.localToGlobal(
                                    button.size.bottomRight(Offset.zero),
                                    ancestor: overlay,
                                  ),
                                ),
                                Offset.zero & overlay.size,
                              );

                              final selectedDetail = await showMenu<
                                  Map<String, dynamic>
                              >(
                                context: context,
                                position: position,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 150,
                                  maxWidth: 250,
                                ),
                                items:
                                details.map((detail) {
                                  return PopupMenuItem<
                                      Map<String, dynamic>
                                  >(
                                    value: detail,
                                    child: Text(
                                      detail['group_detail_name'] ?? '未命名',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                              );

                              if (selectedDetail != null) {
                                print(
                                  '📌 選擇詳細分類: ${selectedDetail['group_detail_name']} (ID: ${selectedDetail['group_detail_id']})',
                                );

                                // 根據詳細分類篩選新聞
                                setState(() {
                                  _selectedCategory =
                                  '${categoryName} > ${selectedDetail['group_detail_name']}';
                                  _selectedGroupId =
                                  selectedDetail['group_detail_id'];
                                });

                                // 使用 groupType: 'detail' 來篩選新聞
                                _fetchNewsByGroupDetail(
                                  selectedDetail['group_detail_id'],
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue : Colors.white,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey,
                                    spreadRadius: 0,
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: isSelected ? Colors.white : Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 修改後的快速播放區塊
  Widget _buildQuickPlaySection() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0a1428),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x336366f1)), // 0.2 opacity
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSidebarExpanded = !_isSidebarExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0x336366f1), // 0.2 opacity
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0x8060a5fa), // 0.5 opacity
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _isSidebarExpanded ? Icons.menu_open : Icons.menu,
                    size: 14,
                    color: const Color(0xFF60a5fa),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.flash_on,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '快速播放',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color.fromARGB(255, 112, 146, 224),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isPlayerVisible = !_isPlayerVisible;
                          if (_isPlayerVisible && !_isPlaying) {
                            _startQuickPlay();
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF60a5fa),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 0,
                      ),
                      child: const Text('播放', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              /*
              Row(
                children: [
                  const Icon(Icons.sort, color: Color(0xFF60a5fa), size: 16),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0x4D6366f1), // 0.3 opacity
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedSortType,
                      underline: Container(),
                      dropdownColor: const Color(0xFF0f1f3d),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 111, 146, 229),
                        fontSize: 12,
                      ),
                      items:
                      _sortTypes.map((sortType) {
                        return DropdownMenuItem<String>(
                          value: sortType,
                          child: Text(
                            sortType,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSortType = value!;
                        });
                        _fetchNews();
                      },
                    ),
                  ),
                ],
              ),*/
            ],
          ),
        ),
        Container(height: 1, color: const Color(0x266366f1)), // 0.15 opacity
      ],
    );
  }

  Widget _buildNewsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchNews, child: const Text('重新載入')),
          ],
        ),
      );
    }

    if (_newsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('目前沒有新聞資料', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchNews, child: const Text('重新載入')),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: RefreshIndicator(
        onRefresh: _fetchNews,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _newsData.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // 顯示載入更多指示器
            if (index == _newsData.length) {
              return Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            }

            final news = _newsData[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0a1428),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 0,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () async {
                  print('🖱️ 點擊新聞: ${news['id']} - ${news['title']}');

                  // 構建 idList：點擊的新聞 ID 在第一位，其餘按原順序
                  List<int> idList = [];

                  // 先加入點擊的新聞 ID
                  final clickedId = news['id'];
                  if (clickedId != null && clickedId is int) {
                    idList.add(clickedId);
                  }

                  // 再加入其他新聞 ID（排除已點擊的）
                  for (var newsItem in _newsData) {
                    final newsId = newsItem['id'];
                    if (newsId != null && newsId is int && newsId != clickedId) {
                      idList.add(newsId);
                    }
                  }

                  print('📋 構建 idList: ${idList.length} 則新聞');
                  print('   第一個 ID: ${idList.isNotEmpty ? idList[0] : "無"}');

                  // 導航到新聞詳情頁，傳遞 idList
                  if (mounted) {
                    print('🚀 導航到 ViewNewsContent');
                    print('   傳遞 idList: ${idList.length} 個 ID');

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewNewsContent(
                          newsData: news,
                          newsIdList: idList, // 傳遞 ID 列表而不是 scriptList
                        ),
                      ),
                    );
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3b82f6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                        news['cover_img'] != null &&
                            news['cover_img'].isNotEmpty
                            ? Image.network(
                          _getProxiedImageUrl(news['cover_img']),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image,
                              color: Colors.grey,
                            );
                          },
                        )
                            : const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            news['channel'] ?? '未知頻道',
                            style: const TextStyle(
                              color: const Color(0xFFd1d5db),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            news['title'] ?? '無標題',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFFFFFFFF),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                news['publish_date'] ?? '未知時間',
                                style: const TextStyle(
                                  color: const Color(0xFFd1d5db),
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chat_bubble_outline,
                                color: const Color(0xFFe5e7eb),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${news['comments'] ?? 0}',
                                style: const TextStyle(
                                  color: const Color(0xFFd1d5db),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 修改後的播放器
  Widget _buildMusicPlayer() {
    if (_newsData.isEmpty) return Container();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a2a4e),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFe5e7eb),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 左側新聞信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flash_on,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '現正播放第${_currentParagraphIndex + 1}篇/總共${paragraphCount}篇',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 右側控制按鈕
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 調整倍速按鈕
                GestureDetector(
                  onTap: _adjustPlaybackSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,

                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_playbackSpeed}x',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 上一篇按鈕
                IconButton(
                  onPressed: _currentParagraphIndex > 0 ? _previousNews : null,
                  icon: const Icon(Icons.skip_previous),
                  color: Colors.white,
                  iconSize: 24,
                ),

                // 播放/暫停按鈕
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  color: Colors.white,
                  iconSize: 28,
                ),

                // 下一篇按鈕
                IconButton(
                  onPressed:
                  _currentParagraphIndex < paragraphCount - 1
                      ? _nextNews
                      : null,
                  icon: const Icon(Icons.skip_next),
                  color: Colors.white,
                  iconSize: 24,
                ),

                // 關閉按鈕
                IconButton(
                  onPressed: _closePlayer,
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a2a4e),
        boxShadow: [
          BoxShadow(color: Colors.grey, spreadRadius: 1, blurRadius: 3),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFF60a5fa),
        unselectedItemColor: Colors.grey[400],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '地區新聞'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首頁'),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: '事件整理',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}