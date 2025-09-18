import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'EventSortingDetailPage.dart';

class MultiplePerspectivesDetailPage extends StatefulWidget {
  final int id;
  const MultiplePerspectivesDetailPage({super.key, required this.id});

  @override
  State<MultiplePerspectivesDetailPage> createState() => _MultiplePerspectivesDetailPageState();
}

class _MultiplePerspectivesDetailPageState extends State<MultiplePerspectivesDetailPage> {
  // 模擬使用者登入狀態，null 為未登入
  final int? _currentUserId = 1;

  bool _isEventSortingMode = false;
  final String _baseUrl = 'http://localhost:3000/api/MultiplePerspectives';
  final String _userActionBaseUrl = 'http://localhost:3000/api/user_action';
  late Future<dynamic> _viewDetailsFuture;

  @override
  void initState() {
    super.initState();
    _viewDetailsFuture = _fetchViewDetails();
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

  // 新增使用者行為記錄的 API 呼叫函式
  Future<void> _insertUserAction(String actionType, String dataType, {String? text, int? score}) async {
    final url = '$_userActionBaseUrl/insert/$actionType/$dataType';
    final body = {
      'userId': _currentUserId,
      'dataId': widget.id,
      'text': text,
      'score': score,
    };

    // 'view' 和 'share' 使用 clientIp，不需 userId
    if (actionType == 'view' || actionType == 'share') {
      body['clientIp'] = '127.0.0.1'; // 請替換為真實 IP
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
            value: !_isEventSortingMode,
            onChanged: (bool value) {
              setState(() {
                _isEventSortingMode = !value;
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
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDisclaimer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(view['multipleperspectives_title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                      ],
                    ),
                  ),
                  _buildViewpointSection(),
                  _buildChartSection(),
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

  Widget _buildViewpointSection() {
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
        _buildExpansionCard('1. 批評左派政策', ['a. 削減消防經費：左派政策過度削減消防資源，導致救災能力不足。', 'b. 環保政策導致火災：批評過度環保要求（如不允許清理枯木）加劇野火風險。', 'c. 多元化政策影響消防隊能力：認為DEI政策妨礙了消防隊選拔精英，降低救災效率。', 'd. 推責給氣候變遷：認為政府將問題歸咎於氣候變遷，逃避管理責任。']),
        _buildExpansionCard('2. 氣候變遷影響', ['a. 極端氣候導致災害：認為加州乾旱及極端風力是野火高風險的重要因素。', 'b. 全球化議題：部分評論強調氣候變遷導致極端天氣事件增多，加劇火災頻率。', 'c. 政治化氣候議題的批評：認為氣候變遷不應成為政治議題，而是全球共同關注的現實問題。']),
        _buildExpansionCard('3. 支持右派觀點', ['...']),
        _buildExpansionCard('4. 災後影響與哀悼', ['...']),
        _buildExpansionCard('5. 不偏不倚的客觀分析', ['...']),
        _buildExpansionCard('6. 幽默或諷刺言論', ['...']),
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

  Widget _buildChartSection() {
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
            width: double.infinity,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Text('這裡可以放置圓餅圖或其他圖表', style: TextStyle(color: Colors.grey)),
          ),
        ),
      ],
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