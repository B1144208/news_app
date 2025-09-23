import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart'; // 新增 fl_chart 套件

import 'EventSortingDetailPage.dart';

class MultiplePerspectivesDetailPage extends StatefulWidget {
  final int id;
  const MultiplePerspectivesDetailPage({super.key, required this.id});

  @override
  State<MultiplePerspectivesDetailPage> createState() => _MultiplePerspectivesDetailPageState();
}

class _MultiplePerspectivesDetailPageState extends State<MultiplePerspectivesDetailPage> {
  int? _currentUserId;
  bool _isEventSortingMode = false;
  final String _baseUrl = 'http://localhost:3000/api/MultiplePerspectives';
  final String _userActionBaseUrl = 'http://localhost:3000/api/user_action';
  late Future<dynamic> _viewDetailsFuture;

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      _viewDetailsFuture = _fetchViewDetails();
      setState(() {});
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('userId');
    });
  }

  Future<dynamic> _fetchViewDetails() async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {'id': widget.id.toString()});

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'].isNotEmpty) {
          return data['data'][0];
        } else {
          return null;
        }
      } else {
        throw Exception('Failed to load view details');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  Future<void> _insertUserAction(String actionType, String dataType, {String? text, int? score}) async {
    final url = '$_userActionBaseUrl/insert/$actionType/$dataType';
    final body = {
      'userId': _currentUserId,
      'dataId': widget.id,
      'text': text,
      'score': score,
    };

    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1';
      body.remove('userId');
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        print('Action $actionType recorded successfully!');
      } else {
        print('Failed to record action $actionType: ${response.body}');
      }
    } catch (e) {
      print('Error recording action: $e');
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
          Switch(
            value: _isEventSortingMode,
            onChanged: (bool value) {
              setState(() {
                _isEventSortingMode = value;
              });
              if (_isEventSortingMode) {
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
                            view['multipleperspectives_title'] ?? '',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  _buildViewpointSection(viewpoints),
                  _buildChartSection(viewpoints),
                  _buildDiscussionSection(discussions),
                ],
              ),
            );
          }
        },
      ),
      bottomNavigationBar: _buildBottomActions(),
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

            // 處理 percent 型態，無論是 num 或 String 都可轉換
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
        final title = point['title'] as String? ?? '未知';
        double percent = 0.0;
        if (point['percent'] is num) {
          percent = (point['percent'] as num).toDouble();
        } else if (point['percent'] is String) {
          percent = double.tryParse(point['percent']!) ?? 0.0;
        }

        final value = (totalPercent > 0) ? (percent / totalPercent * 100) : 0;

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
            const Text('目前沒有留言。', style: TextStyle(color: Colors.grey))
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
          _buildActionIcon(
              icon: Icons.message,
              label: '留言',
              onTap: () {
                if (_currentUserId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('留言功能已啟用')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請先登入以使用留言功能')),
                  );
                }
              }
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