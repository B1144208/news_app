import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart'; // ✅ 新增：分享插件
// 確保此路徑正確指向您的 API 設定
import 'config.dart';
import 'EventSortingDetailPage.dart';
// 確保此路徑正確指向您的留言頁面
import 'CommentsPage.dart';

class MultiplePerspectivesDetailPage extends StatefulWidget {
  final int id;
  const MultiplePerspectivesDetailPage({super.key, required this.id});

  @override
  State<MultiplePerspectivesDetailPage> createState() =>
      _MultiplePerspectivesDetailPageState();
}

class _MultiplePerspectivesDetailPageState
    extends State<MultiplePerspectivesDetailPage> {
  int? _currentUserId;
  bool _isEventSortingMode = false;

  // 儲存從 API 獲取的分數數據
  int _totalScore = 0;
  int _totalRater = 0;
  // 儲存實際的留言人數 (從 total_comment 欄位獲取)
  int _commentCount = 0;
  // 模擬收藏狀態 (假設此頁面也需要)
  bool isFavorite = false;

  // 計算平均分數 (四捨五入到小數點後一位)
  double get _averageScore =>
      _totalRater > 0 ? (_totalScore / _totalRater) : 0.0;

  // 修正：只保留 $baseUrl。
  final String _userActionBaseUrl = '$baseUrl';

  late Future<dynamic> _viewDetailsFuture;

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      // 確保在 _loadUserId 完成後才開始 fetch data
      _viewDetailsFuture = _fetchViewDetails();
      // 在載入完畢後發送 view action
      _insertUserAction('view', 'multipleperspectives');
      setState(() {});
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('UserID');
    });
  }

  // 重新獲取事件詳情，用於評分或留言後更新 UI
  Future<void> _refreshViewDetails() async {
    // 設置新的 Future，並觸發 UI 刷新
    setState(() {
      _viewDetailsFuture = _fetchViewDetails();
    });
  }

  Future<dynamic> _fetchViewDetails() async {
    final uri = Uri.parse(
      '$baseUrl/MultiplePerspectives',
    ).replace(queryParameters: {'id': widget.id.toString()});

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        // 確保中文字元正確解析
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['data'].isNotEmpty) {
          final view = data['data'][0];

          // MODIFIED: 獲取並保存分數數據 和 留言數量
          if (mounted) {
            setState(() {
              // 假設 API 欄位為 'total_score' 和 'total_rater'
              _totalScore = view['total_score'] as int? ?? 0;
              _totalRater = view['total_rater'] as int? ?? 0;
              // 獲取並保存留言數量
              _commentCount = view['total_comment'] as int? ?? 0;

              print(
                'Fetched Score: Total Score $_totalScore, Total Rater $_totalRater',
              );
              print('Fetched Comment Count: $_commentCount');
            });
          }

          return view;
        } else {
          return null;
        }
      } else {
        throw Exception('Failed to load view details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to API or process data: $e');
    }
  }

  // 💥 MODIFIED: 通用用戶行為 API 函式 (已新增 anonymous 參數和處理)
  Future<void> _insertUserAction(
    String actionType,
    String dataType, {
    String? text,
    int? score,
    String? anonymous, // 💥 修正點：新增匿名名稱參數
  }) async {
    // 假設您的後端路由是 $baseUrl/user/:actionType/:dataType
    final url = '$_userActionBaseUrl/user/$actionType/$dataType';

    final body = <String, dynamic>{'dataId': widget.id};
    // 確保 currentUserId 不為 null 才傳入 body
    if (_currentUserId != null) {
      body['userId'] = _currentUserId;
    }

    // 處理特例 actionType
    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1';
      body.remove('userId');
    } else if (actionType == 'deleteComment') {
      // 假設 text 傳遞的是 commentId
      if (text != null && int.tryParse(text) != null) {
        body['commentId'] = int.parse(text);
      } else {
        print(
          'Error: deleteComment action missing valid commentId in text parameter.',
        );
        return;
      }
      body.remove('text'); // 移除 text
    } else if (actionType == 'editComment') {
      // 假設 text 傳遞的是 'commentId:::newText'
      if (text != null && text.contains(':::')) {
        final parts = text.split(':::');
        if (parts.length == 2 && int.tryParse(parts[0]) != null) {
          body['commentId'] = int.parse(parts[0]);
          body['text'] = parts[1];
        } else {
          print('Error: editComment action text format is invalid.');
          return;
        }
      } else {
        print('Error: editComment action missing new text or ID.');
        return;
      }
    } else {
      // 處理一般 comment 和 score
      if (text != null && text.isNotEmpty) body['text'] = text;
      if (score != null) body['score'] = score;

      // 🌟 新增：如果存在匿名名稱，則傳遞給後端 🌟
      if (anonymous != null && anonymous.isNotEmpty)
        body['anonymous'] = anonymous;

      // 如果是非 view/share 操作，但沒有 currentUserId，則阻止操作
      if (_currentUserId == null) {
        print('Error: Action $actionType requires a logged-in user.');
        return;
      }
    }

    // 收藏/取消收藏操作
    if (actionType == 'bookmark') {
      // 在前端先更新狀態以達到即時回饋
      setState(() {
        isFavorite = !isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite ? '已加入收藏' : '已移除收藏'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    body.removeWhere((key, value) => value == null);

    print('Sending API to: $url');
    print('Request Body: ${json.encode(body)}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print('Action $actionType recorded successfully!');
        // 如果是 score, comment, deleteComment, editComment 成功，重新載入數據以更新分數和留言數
        if ([
          'score',
          'comment',
          'deleteComment',
          'editComment',
        ].contains(actionType)) {
          _refreshViewDetails();
        }
      } else {
        print(
          'Failed to record action $actionType. Status: ${response.statusCode}',
        );
        if (actionType != 'view' && actionType != 'bookmark') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '操作失敗: ${response.statusCode} - ${json.decode(response.body)['message'] ?? '伺服器錯誤'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error recording action: $e');
      if (actionType != 'view' && actionType != 'bookmark') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('連線錯誤: $e')));
      }
    }
  }

  // 導航至 CommentsPage 的函式 (保持不變，因為它傳遞了修正後的 _insertUserAction)
  void _navigateToCommentsPage() {
    // 步驟 1: 檢查 currentUserId 是否為 null
    if (_currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先登入以使用評分/留言功能')));
      return;
    }

    // 步驟 2: 導航時，使用 ! 確保傳遞 int 給 CommentsPage
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CommentsPage(
              dataId: widget.id,
              currentUserId: _currentUserId!, // 💥 使用 ! 確保傳遞 int
              dataType: 'multipleperspectives',
              insertUserAction: _insertUserAction,
              // 傳遞目前的分數數據和更新回調
              totalScore: _totalScore,
              totalRater: _totalRater,
              onParentDataUpdated: _refreshViewDetails, // 傳遞回調函式
            ),
      ),
    );
  }

  // ✅ 新增：分享功能 - 使用share_plus
  Future<void> _handleShareTap() async {
    try {
      // 構建分享文本
      final shareText =
          '多方看法分析 - ID: ${widget.id}\n\n'
          '平均評分: ${_averageScore.toStringAsFixed(1)}/10 (${_totalRater}人評分)\n'
          '留言數量: $_commentCount\n\n'
          '分享自新聞聚合平台';

      // 深鏈接
      final shareUrl = 'multipleperspectives://details/${widget.id}';

      final fullShareText = '$shareText\n$shareUrl';

      await Share.share(fullShareText, subject: '多方看法分析');

      print('✅ 分享成功: ID ${widget.id}');
    } catch (e) {
      print('❌ 分享失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分享失敗: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('多方看法', style: TextStyle(color: Colors.black)),
        actions: [
          // Switch for navigation (original logic retained)
          Switch(
            value: !_isEventSortingMode,
            onChanged: (bool value) {
              if (!value) {
                // 切換到事件整理頁面
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventSortingDetailPage(id: widget.id),
                  ),
                );
              }
            },
            activeColor: Colors.blue,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder(
        future: _viewDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('載入失敗: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('找不到多方看法資料。'));
          } else {
            final view = snapshot.data;
            final List<dynamic> viewpoints = view['viewpoints'] ?? [];
            // discussions 欄位似乎在您的範例中是空的，但我們保留其結構
            final List<dynamic> discussions = view['discussions'] ?? [];

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDisclaimer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            view['multipleperspectives_title'] ?? '無標題',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  _buildScoreCard(),
                  _buildViewpointSection(viewpoints),
                  _buildChartSection(viewpoints),
                  _buildDiscussionSection(discussions),
                  const SizedBox(height: 50),
                ],
              ),
            );
          }
        },
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  // --- 輔助 Widget 函式 ---

  // 顯示分數的 Widget (保持不變)
  Widget _buildScoreCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          Text(
            // 格式化分數，保留一位小數
            '${_averageScore.toStringAsFixed(1)} / 5.0',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Text(
            '來自 $_totalRater 位使用者評分',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text(
            "使用AI技術協助",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.info_outline, size: 14, color: Colors.grey),
          const Spacer(),
          const Text(
            "資訊若有失真狀況，一概不負法律責任",
            style: TextStyle(color: Colors.red, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildViewpointSection(List<dynamic> viewpoints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                '看法統整',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Text(
                '統整使用AI技術協助',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
            ],
          ),
        ),
        if (viewpoints.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('沒有觀點資料。', style: TextStyle(color: Colors.grey)),
          )
        else
          ...viewpoints.map((point) {
            final title = point['title'] as String? ?? '';
            final content = point['content'] as String? ?? '';

            // 處理 percent 型態
            double percent = 0.0;
            if (point['percent'] is num) {
              percent = (point['percent'] as num).toDouble();
            } else if (point['percent'] is String) {
              percent = double.tryParse(point['percent']!) ?? 0.0;
            }

            return _buildExpansionCard(
              '${title} (${(percent * 100).toStringAsFixed(0)}%)',
              [content],
            );
          }).toList(),
      ],
    );
  }

  Widget _buildExpansionCard(String title, List<String> details) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children:
            details
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(item),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildChartSection(List<dynamic> viewpoints) {
    List<PieChartSectionData> sections = [];
    final List<Color> colors = [
      Colors.blue.shade300,
      Colors.green.shade300,
      Colors.red.shade300,
      Colors.purple.shade300,
      Colors.orange.shade300,
      Colors.teal.shade300,
      Colors.indigo.shade300,
      Colors.pink.shade300,
    ];

    if (viewpoints.isNotEmpty) {
      double totalPercent = 0;
      for (var point in viewpoints) {
        if (point['percent'] is num) {
          totalPercent += (point['percent'] as num).toDouble();
        } else if (point['percent'] is String) {
          totalPercent += double.tryParse(point['percent']!) ?? 0.0;
        }
      }

      for (int i = 0; i < viewpoints.length; i++) {
        final point = viewpoints[i];
        double percent = 0.0;
        if (point['percent'] is num) {
          percent = (point['percent'] as num).toDouble();
        } else if (point['percent'] is String) {
          percent = double.tryParse(point['percent']!) ?? 0.0;
        }

        // 避免除以零
        final value = (totalPercent > 0) ? (percent / totalPercent * 100) : 0.0;

        sections.add(
          PieChartSectionData(
            color: colors[i % colors.length],
            value: value.toDouble(),
            title: '${(percent * 100).toStringAsFixed(0)}%',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
            showTitle: true,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '圖表分析',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child:
                viewpoints.isEmpty
                    ? const Center(child: Text('沒有足夠資料來生成圖表。'))
                    : PieChart(
                      PieChartData(
                        sections: sections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscussionSection(List<dynamic> discussions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '留言討論區',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (discussions.isEmpty)
            const Text('目前沒有相關留言。', style: TextStyle(color: Colors.grey))
          else
            ...discussions.map((d) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(title: Text(d['content'] ?? '無內容')),
              );
            }).toList(),
        ],
      ),
    );
  }

  // 復刻 EventSortingDetailPage 的留言按鈕樣式 (圓角邊框帶計數)
  Widget _buildCommentAndRatingButton() {
    return InkWell(
      onTap: _navigateToCommentsPage, // 呼叫統一的導航函式
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline, // 模仿原版圖標
              size: 20,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              // 顯示實際的留言數量
              '${_commentCount}則',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // 復刻 EventSortingDetailPage 的機器人按鈕樣式 (藍色圓形)
  Widget _buildFloatingActionRobotButton() {
    return InkWell(
      onTap: () {
        if (_currentUserId != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('點擊了聊天機器人，待實作導航')));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('請先登入以使用聊天機器人')));
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
      ),
    );
  }

  // 復刻 EventSortingDetailPage 的右側動作圖標樣式
  Widget _buildActionIcon({
    required IconData icon,
    required String label, // 雖然不用 label，但保留簽名
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12), // 模仿原版右側按鈕的 padding
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  // 復刻 EventSortingDetailPage 的底部操作欄
  Widget _buildBottomActions() {
    return Container(
      // 復刻原版 BAR 的 padding, 裝飾 (背景色與陰影)
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.4),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. 留言/評分按鈕 (圓角邊框帶計數樣式)
          _buildCommentAndRatingButton(),

          const Spacer(), // 分隔留言按鈕和聊天機器人按鈕
          // 2. 機器人圖示 (圓形藍色樣式)
          _buildFloatingActionRobotButton(),

          const Spacer(), // 分隔機器人按鈕和右側按鈕組
          // 3. 右側按鈕組 (收藏與分享)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 收藏按鈕
              _buildActionIcon(
                icon:
                    isFavorite
                        ? Icons.bookmark
                        : Icons.bookmark_outline, // 根據狀態切換圖標
                label: '收藏',
                iconColor: isFavorite ? Colors.blue : Colors.grey.shade600!,
                onTap: () {
                  if (_currentUserId != null) {
                    // _insertUserAction 會自動切換 isFavorite 狀態並顯示 Snackbar
                    _insertUserAction('bookmark', 'multipleperspectives');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請先登入以使用收藏功能')),
                    );
                  }
                },
              ),

              // ✅ 修改：分享按鈕 - 調用實際分享功能
              _buildActionIcon(
                icon: Icons.share_outlined,
                label: '分享',
                iconColor: Colors.grey.shade600!,
                onTap: () {
                  _insertUserAction('share', 'multipleperspectives');
                  _handleShareTap(); // ✅ 調用實際分享功能
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
