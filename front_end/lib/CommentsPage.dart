import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// 確保此路徑正確指向您的 API 設定
import '../config.dart';

// 通用留言頁面，用於顯示和發送特定數據類型和 ID 的留言。
class CommentsPage extends StatefulWidget {
  final int dataId; // 數據的唯一 ID (如 eventId, perspectiveId)
  final int? currentUserId; // 當前登入的使用者 ID (用於判斷是否能發言)
  final String dataType; // 數據的類型 (如 'eventsorting', 'multipleperspectives')
  // 傳遞父頁面中實作的 API 函式
  final Future<void> Function(String actionType, String dataType, {String? text, int? score}) insertUserAction;

  // 💥 新增：從父頁面傳入平均分數所需的總分數和評分人數
  final int totalScore;
  final int totalRater;

  // 💥 新增：當分數有變動時，通知父頁面重新載入數據
  final VoidCallback onParentDataUpdated;

  const CommentsPage({
    super.key,
    required this.dataId,
    required this.currentUserId,
    required this.dataType,
    required this.insertUserAction,
    // 💥 必填
    required this.totalScore,
    required this.totalRater,
    required this.onParentDataUpdated, // 💥 必填
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = []; // 用於儲存留言列表
  bool _isLoading = true;
  int? _userScore; // 用於儲存當前用戶的評分

  // 💥 修正：使用 late，在 initState 時透過父頁面傳入的數據計算並初始化
  late double? _averageScore;
  late int? _totalRatings;

  final String _userActionBaseUrl = '$baseUrl';

  @override
  void initState() {
    super.initState();

    // 💥 步驟 1：在 initState 立即計算並設定狀態
    _calculateAverageScore(widget.totalScore, widget.totalRater);

    if (widget.dataType.isNotEmpty) {
      _fetchComments();

      Future.microtask(() {
        if (widget.currentUserId != null) {
          _fetchUserScore();
        }
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      print("Error: dataType is missing for CommentsPage.");
    }
  }

  // 處理 currentUserId 延遲載入問題 (由父頁面 setState 觸發)
  @override
  void didUpdateWidget(covariant CommentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果父頁面傳入的分數有更新，則重新計算平均分數
    if (oldWidget.totalScore != widget.totalScore || oldWidget.totalRater != widget.totalRater) {
      _calculateAverageScore(widget.totalScore, widget.totalRater);
    }

    // 檢查 currentUserId 載入
    if (oldWidget.currentUserId == null && widget.currentUserId != null) {
      print('didUpdateWidget: currentUserId 變為非空，開始獲取用戶評分');
      _fetchUserScore();
    }
  }

  // 💥 步驟 2：前端計算平均分數的核心邏輯
  void _calculateAverageScore(int totalScore, int totalRater) {
    setState(() {
      if (totalRater > 0) {
        _averageScore = totalScore / totalRater;
      } else {
        _averageScore = null;
      }
      _totalRatings = totalRater;
    });
  }

  // 1. 獲取現有留言 (GET API)
  Future<void> _fetchComments() async {
    // (載入留言邏輯保持不變)
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse('$_userActionBaseUrl/user/comment/${widget.dataType}').replace(queryParameters: {
      'dataId': widget.dataId.toString(),
    });

    try {
      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _comments = data['data'] is List ? data['data'] : [];
        });
      }
    } catch (e) {
      if (!mounted) return;
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 1.7. 獲取當前用戶的評分 (GET API)
  Future<void> _fetchUserScore() async {
    // (獲取用戶評分邏輯保持不變)
    if (widget.currentUserId == null) return;
    if (!mounted) return;

    final uri = Uri.parse('$_userActionBaseUrl/user/score/${widget.dataType}').replace(queryParameters: {
      'dataId': widget.dataId.toString(),
      'userId': widget.currentUserId.toString(),
    });

    try {
      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final scoreData = data['data'];

        setState(() {
          if (scoreData != null && scoreData['target_score'] is int) {
            _userScore = scoreData['target_score'] as int;
          } else {
            // 如果後端返回的 target_score 是 0 (表示清除) 或 null
            _userScore = null;
          }
        });
      }
    } catch (e) {
      print('Error fetching user score: $e');
    }
  }

  // 2. 發送新留言 (POST API)
  Future<void> _postComment() async {
    // (發送留言邏輯保持不變)
    final text = _commentController.text.trim();
    if (text.isEmpty || widget.currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入並輸入留言內容')),
        );
      }
      return;
    }

    await widget.insertUserAction(
      'comment',
      widget.dataType,
      text: text,
    );

    _commentController.clear();
    FocusScope.of(context).unfocus();

    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchComments();
  }

  // 3. 顯示評分/修改評分對話框
  Future<void> _showRatingDialog(int? initialScore) async {
    int? selectedScore = initialScore;

    if (widget.currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入以使用評分功能')),
        );
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(initialScore == null ? '為此內容評分' : '您的評分：${initialScore} 分 (可修改)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('請給予 1 到 5 分 (5 分為最高)：'),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final score = index + 1;
                      return IconButton(
                        icon: Icon(
                          score <= (selectedScore ?? 0) ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedScore = score;
                          });
                        },
                      );
                    }),
                  );
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('確定'),
              onPressed: () async {
                if (selectedScore != null && selectedScore! >= 1 && selectedScore! <= 5) {
                  // 1. 發送評分 API
                  await widget.insertUserAction('score', widget.dataType, score: selectedScore);

                  // 2. 刷新用戶自己的評分
                  await _fetchUserScore();

                  // 3. 💥 呼叫回調函式，通知父頁面重新載入平均分數
                  widget.onParentDataUpdated();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('感謝您的 $selectedScore 分評分!')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請選擇有效的分數 (1-5)！')),
                    );
                  }
                }
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 4. 💥 新增：清除評分
  Future<void> _clearUserScore() async {
    if (widget.currentUserId == null || _userScore == null) return;

    // 假設清除評分是透過發送 score: 0
    await widget.insertUserAction('score', widget.dataType, score: 0);

    // 更新本地用戶分數
    setState(() {
      _userScore = null;
    });

    // 💥 呼叫回調函式，通知父頁面重新載入平均分數
    widget.onParentDataUpdated();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('您的評分已清除')),
      );
    }
  }


  // 5. 💥 新增：頂部評分統計區塊 (使用 _averageScore 和 _totalRatings)
  Widget _buildRatingStatsHeader() {
    // 確保分數顯示為一位小數
    final displayScore = _averageScore != null ? _averageScore!.toStringAsFixed(1) : 'N/A';
    final ratingsCount = _totalRatings ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部平均評分區塊 (類似 4.3 星)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                displayScore,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star, color: Colors.amber, size: 30),
              const SizedBox(width: 16),
              Text(
                '${ratingsCount} 份評分',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // 您的評分區塊
          if (widget.currentUserId != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: [
                  const Text('您的評分: ', style: TextStyle(fontSize: 16)),
                  // 顯示用戶自己的評分星級
                  ...List.generate(5, (index) {
                    final scoreIndex = index + 1;
                    return IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        scoreIndex <= (_userScore ?? 0) ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 28,
                      ),
                      onPressed: () => _showRatingDialog(_userScore), // 點擊星級直接進入修改
                    );
                  }),
                  const Spacer(),
                  // 清除/修改按鈕
                  if (_userScore != null)
                    TextButton(
                      onPressed: () => _clearUserScore(),
                      child: const Text('清除', style: TextStyle(color: Colors.red)),
                    )
                  else
                    TextButton(
                      onPressed: () => _showRatingDialog(null),
                      child: const Text('評分', style: TextStyle(color: Colors.blue)),
                    ),
                ],
              ),
            )
          else
          // 未登入提示
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Text('登入後可為此內容評分', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ),
        ],
      ),
    );
  }

  // 6. 評論標題區塊
  Widget _buildCommentHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '評論',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('評分與評論'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💥 評分統計區塊
          _buildRatingStatsHeader(),

          // 評論標題區塊
          _buildCommentHeader(),

          // 留言列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                ? const Center(child: Text('目前沒有留言，快來搶頭香！'))
                : ListView.builder(
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];

                final userId = comment['user_id'] ?? comment['anonymous_id'];
                // 注意：這裡假設後端欄位是 'created_at' 或 'ceated_at'
                final date = (comment['created_at'] ?? comment['ceated_at'])?.split('T')[0] ?? '未知日期';
                final commentText = comment['text'] ?? '無留言內容';

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    '用戶留言 #${userId ?? '訪客'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(commentText, maxLines: 5, overflow: TextOverflow.ellipsis),
                  trailing: Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                );
              },
            ),
          ),

          // 留言輸入框
          _buildCommentInput(),
        ],
      ),
    );
  }

  // 獨立的留言輸入框元件
  Widget _buildCommentInput() {
    if (widget.currentUserId == null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        color: Colors.white,
        child: const Center(
          child: Text(
            '請先登入才能發送留言',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 4.0, bottom: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: '輸入你的留言...',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              minLines: 1,
              maxLines: 5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue, size: 30),
            onPressed: _postComment,
          ),
        ],
      ),
    );
  }
}