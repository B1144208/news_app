import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
// 確保此路徑正確指向您的 API 設定
import 'config.dart';
import 'EventSortingDetailPage.dart';
// 確保此路徑正確指向您的留言頁面
import 'CommentsPage.dart';

class MultiplePerspectivesDetailPage extends StatefulWidget {
  final int id;
  const MultiplePerspectivesDetailPage({super.key, required this.id});

  @override
  State<MultiplePerspectivesDetailPage> createState() => _MultiplePerspectivesDetailPageState();
}

class _MultiplePerspectivesDetailPageState extends State<MultiplePerspectivesDetailPage> {
  int? _currentUserId;
  bool _isEventSortingMode = false;

  // 💥 NEW: 儲存從 API 獲取的分數數據
  int _totalScore = 0;
  int _totalRater = 0;
  // 💥 NEW: 計算平均分數 (四捨五入到小數點後一位)
  double get _averageScore => _totalRater > 0 ? (_totalScore / _totalRater) : 0.0;

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

  // 💥 NEW: 重新獲取事件詳情，用於評分或留言後更新 UI
  Future<void> _refreshViewDetails() async {
    // 設置新的 Future，並觸發 UI 刷新
    setState(() {
      _viewDetailsFuture = _fetchViewDetails();
    });
  }

  Future<dynamic> _fetchViewDetails() async {
    final uri = Uri.parse('$baseUrl/MultiplePerspectives').replace(queryParameters: {'id': widget.id.toString()});

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        // 確保中文字元正確解析
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['data'].isNotEmpty) {
          final view = data['data'][0];

          // 💥 NEW: 獲取並保存分數數據
          if (mounted) {
            setState(() {
              // 假設 API 欄位為 'total_score' 和 'total_rater'
              _totalScore = view['total_score'] as int? ?? 0;
              _totalRater = view['total_rater'] as int? ?? 0;
              print('Fetched Score: Total Score $_totalScore, Total Rater $_totalRater');
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

  // 通用用戶行為 API 函式
  Future<void> _insertUserAction(String actionType, String dataType, {String? text, int? score}) async {
    // 假設您的後端路由是 $baseUrl/user/:actionType/:dataType
    final url = '$_userActionBaseUrl/user/$actionType/$dataType';

    final body = <String, dynamic>{
      // 確保傳遞給後端的 userId 和 dataId 是 int 類型 (或 null for view/share)
      'userId': _currentUserId,
      'dataId': widget.id,
      if (text != null && text.isNotEmpty) 'text': text,
      if (score != null) 'score': score,
    };

    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1';
      // 僅在 view/share 動作時移除 userId，讓後端使用 clientIp
      body.remove('userId');
    }

    body.removeWhere((key, value) => value == null);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print('Action $actionType recorded successfully!');
        // 💥 NEW: 如果是 score 或 comment 成功，重新載入數據以更新分數
        if (actionType == 'score' || actionType == 'comment') {
          _refreshViewDetails();
        }
      } else {
        print('Failed to record action $actionType. Status: ${response.statusCode}');
        if (actionType != 'view') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失敗: ${response.statusCode} - ${json.decode(response.body)['message'] ?? '伺服器錯誤'}')),
          );
        }
      }
    } catch (e) {
      print('Error recording action: $e');
      if (actionType != 'view') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('連線錯誤: $e')),
        );
      }
    }
  }

  // 💥 NEW: 導航至 CommentsPage 的函式，傳遞分數和回調
  void _navigateToCommentsPage() {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入以使用評分/留言功能')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsPage(
          dataId: widget.id,
          currentUserId: _currentUserId,
          dataType: 'multipleperspectives',
          insertUserAction: _insertUserAction,
          // 💥 NEW: 傳遞目前的分數數據和更新回調
          totalScore: _totalScore,
          totalRater: _totalRater,
          onParentDataUpdated: _refreshViewDetails, // 傳遞回調函式
        ),
      ),
    );
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
                  MaterialPageRoute(builder: (context) => EventSortingDetailPage(id: widget.id)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            view['multipleperspectives_title'] ?? '無標題',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  // 💥 NEW: 顯示分數
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

  // 💥 NEW: 顯示分數的 Widget
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
          const Text("使用AI技術協助", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.info_outline, size: 14, color: Colors.grey),
          const Spacer(),
          const Text("資訊若有失真狀況，一概不負法律責任", style: TextStyle(color: Colors.red, fontSize: 10)),
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
              const Text('看法統整', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('統整使用AI技術協助', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
        children: details.map((item) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(item),
        )).toList(),
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
          child: Text('圖表分析', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            child: viewpoints.isEmpty
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
                child: ListTile(
                  title: Text(d['content'] ?? '無內容'),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 💥 MODIFIED: 評分/留言
          _buildActionIcon(
              icon: Icons.message,
              label: '評分/留言',
              onTap: _navigateToCommentsPage // 呼叫統一的導航函式
          ),
          _buildActionIcon(
              icon: Icons.chat_bubble_outline,
              label: '聊天機器人',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('聊天機器人功能已啟用')),
                );
              }
          ),

          _buildActionIcon(
              icon: Icons.bookmark,
              label: '收藏',
              onTap: () {
                if (_currentUserId != null) {
                  _insertUserAction('bookmark', 'multipleperspectives');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已收藏此觀點')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請先登入以使用收藏功能')),
                  );
                }
              }
          ),
          _buildActionIcon(
              icon: Icons.share,
              label: '分享',
              onTap: () {
                _insertUserAction('share', 'multipleperspectives');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分享功能已啟用')),
                );
              }
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey.shade700),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ],
      ),
    );
  }
}