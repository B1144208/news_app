import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

// 假設 config.dart 包含 const String baseUrl = 'http://localhost:3000/api';
// ⚠️ 請確保您已建立此文件並包含正確的 baseUrl。
import 'config.dart';

// 通用留言頁面
class CommentsPage extends StatefulWidget {
  final int dataId;
  final int currentUserId;
  final String dataType;

  // 修正 insertUserAction 接受 anonymous 參數
  final Future<void> Function(String actionType, String dataType, {String? text, int? score, String? anonymous}) insertUserAction;

  final int totalScore;
  final int totalRater;

  // 核心回調：通知父元件重新載入所有數據 (包括留言總數)
  final VoidCallback onParentDataUpdated;

  const CommentsPage({
    super.key,
    required this.dataId,
    required this.currentUserId,
    required this.dataType,
    required this.insertUserAction,
    required this.totalScore,
    required this.totalRater,
    required this.onParentDataUpdated,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();

  // 🌟 匿名功能相關的狀態和控制器 🌟
  final TextEditingController _anonymousNameController = TextEditingController(text: '匿名用戶');
  bool _isAnonymous = false;

  List<dynamic> _comments = [];
  bool _isLoading = true;

  int? _userScore;
  int? _userScoreId; // 儲存 score_id，用於 PUT 更新

  late double? _averageScore;
  late int? _totalRatings;

  final String _userActionBaseUrl = baseUrl;

  @override
  void initState() {
    super.initState();
    _calculateAverageScore(widget.totalScore, widget.totalRater);
    if (widget.dataType.isNotEmpty) {
      _fetchComments();
      Future.microtask(() {
        _fetchUserScore();
      });
    } else {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _anonymousNameController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CommentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalScore != widget.totalScore || oldWidget.totalRater != widget.totalRater) {
      _calculateAverageScore(widget.totalScore, widget.totalRater);
    }
  }

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

  // ----------------------------------------------------
  // Data Fetching (GET API)
  // ----------------------------------------------------

  // 刷新所有數據 (留言和評分)，並通知父元件更新
  Future<void> _refreshAllData() async {
    widget.onParentDataUpdated(); // 1. 通知父元件更新所有數據 (包括留言總數)
    await _fetchUserScore();      // 2. 獲取本地頁面的最新分數
    await _fetchComments();       // 3. 獲取本地頁面的最新留言列表
  }

  // 獲取現有留言 (包含 display_name)
  Future<void> _fetchComments() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    // URL: /api/user/comment/dataType?dataId=...
    final uri = Uri.parse('$_userActionBaseUrl/user/comment/${widget.dataType}').replace(queryParameters: {
      'dataId': widget.dataId.toString(),
    });

    try {
      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        List<dynamic> fetchedComments = data['data'] is List ? data['data'] : [];

        // 依據時間倒序排列 (最新的在前)
        // 修正：您的 API 欄位是 'ceated_at'，這裡修正為 'created_at' 比較常見，但為了與您程式碼匹配，保持 'ceated_at'
        fetchedComments.sort((a, b) {
          final timeA = (a['ceated_at'] ?? '0') as String;
          final timeB = (b['ceated_at'] ?? '0') as String;
          return timeB.compareTo(timeA);
        });

        setState(() {
          _comments = fetchedComments;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Error fetching comments: $e');
    } finally {
      if (!mounted) return;
      setState(() { _isLoading = false; });
    }
  }

  // 獲取當前用戶的評分
  Future<void> _fetchUserScore() async {
    if (!mounted) return;

    // URL: /api/user/score/dataType?dataId=...&userId=...
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
          int? fetchedScore;
          int? fetchedScoreId;

          // 處理後端返回單一物件或單元素列表
          if (scoreData is Map<String, dynamic> && scoreData['target_score'] is int) {
            fetchedScore = scoreData['target_score'] as int;
            fetchedScoreId = scoreData['score_id'] as int?;
          } else if (scoreData is List && scoreData.isNotEmpty && scoreData[0]['target_score'] is int) {
            fetchedScore = scoreData[0]['target_score'] as int;
            fetchedScoreId = scoreData[0]['score_id'] as int?;
          }

          _userScore = (fetchedScore != null && fetchedScore > 0) ? fetchedScore : null;
          _userScoreId = fetchedScoreId;
        });
      }
    } catch (e) {
      print('Error fetching user score: $e');
    }
  }

  // ----------------------------------------------------
  // User Actions (POST/PUT/DELETE)
  // ----------------------------------------------------

  // 🌟 修正 _postComment() 傳遞 anonymous 參數 🌟
  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請輸入留言內容')),
        );
      }
      return;
    }

    String? anonymousName;
    if (_isAnonymous) {
      anonymousName = _anonymousNameController.text.trim();
      if (anonymousName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('請輸入匿名名稱')),
          );
        }
        return;
      }
    }

    await widget.insertUserAction(
      'comment',
      widget.dataType,
      text: text,
      anonymous: anonymousName, // 傳遞匿名名稱（如果非空）
    );

    _commentController.clear();
    FocusScope.of(context).unfocus();

    await Future.delayed(const Duration(milliseconds: 300));
    await _refreshAllData(); // 成功後通知父元件和本地頁面更新
  }

  // 💥 NEW: 統一處理評分 (POST 或 PUT)
  Future<void> _submitScore(int newScore) async {
    if (widget.currentUserId == 0 || widget.currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入才能進行評分')),
        );
      }
      return;
    }

    try {
      if (_userScoreId != null) {
        // PUT: 更新現有評分
        await _updateScore(_userScoreId!, newScore);
      } else {
        // POST: 新增評分
        await widget.insertUserAction('score', widget.dataType, score: newScore);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('評分 $newScore 成功！')),
          );
        }
        await _refreshAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('評分提交失敗: $e')),
        );
      }
    }
  }

  // 評分更新 (PUT) - 內部使用
  Future<void> _updateScore(int scoreId, int newScore) async {
    try {
      final url = '$_userActionBaseUrl/user/score/$scoreId';

      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          // ⚠️ 根據您的後端需求，這裡的 body 可能需要調整
          'score': newScore, // 新的分數 (0 表示清除)
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('後端評分更新失敗: Status ${response.statusCode}, Body: ${response.body}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newScore == 0 ? '您的評分已清除' : '評分已更新!')),
        );
      }
      await _refreshAllData();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('評分更新失敗: $e')),
        );
      }
      // 即使失敗也要刷新數據以確保 UI 狀態正確
      await _refreshAllData();
    }
  }


  // 💥 REMOVED: _showRatingDialog (已移除，改為直接點擊)

  // 清除評分
  Future<void> _clearUserScore() async {
    if (_userScoreId == null) return;
    await _updateScore(_userScoreId!, 0); // 傳遞 0 表示清除
  }


  // 刪除留言的函式 (DELETE API) - 保持不變
  Future<void> _deleteComment(int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: const Text('您確定要刪除這則留言嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // URL: /api/user/comment/:commentId
        final url = '$_userActionBaseUrl/user/comment/$commentId';

        final response = await http.delete(
          Uri.parse(url),
        );

        if (response.statusCode != 200 && response.statusCode != 204) {
          throw Exception('後端刪除失敗: Status ${response.statusCode}, Body: ${response.body}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('留言已成功刪除！')),
          );
        }

        await _refreshAllData();

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('刪除失敗: $e')),
          );
        }
      }
    }
  }

  // 編輯留言的函式 (PUT API) - 保持不變
  Future<void> _editComment(int commentId, String currentText) async {
    final TextEditingController editController = TextEditingController(text: currentText);

    final String? newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('編輯留言'),
        content: TextField(
          controller: editController,
          minLines: 1,
          maxLines: 5,
          decoration: const InputDecoration(hintText: "編輯您的留言..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(editController.text.trim());
              }
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (newText != null && newText != currentText) {
      try {
        // URL: /api/user/comment/:commentId
        final url = '$_userActionBaseUrl/user/comment/$commentId';

        final response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            // ⚠️ 根據您的後端需求，這裡的 body 可能需要調整
            'text': newText,
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('後端編輯失敗: Status ${response.statusCode}, Body: ${response.body}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('留言已成功編輯！')),
          );
        }
        await _refreshAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('編輯失敗: $e')),
          );
        }
      }
    }
  }

  // ----------------------------------------------------
  // UI Building
  // ----------------------------------------------------

  String _formatDate(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat('yyyy-MM-dd').format(dateTime);
    } catch (e) {
      return isoString;
    }
  }

  // 💥 MODIFIED: 頂部評分統計區塊 (直接點擊星星評分)
  Widget _buildRatingStatsHeader() {
    final displayScore = _averageScore != null ? _averageScore!.toStringAsFixed(1) : 'N/A';
    final ratingsCount = _totalRatings ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                const Text('您的評分: ', style: TextStyle(fontSize: 16)),
                ...List.generate(5, (index) {
                  final scoreIndex = index + 1;
                  return InkWell(
                    onTap: () => _submitScore(scoreIndex), // 💥 直接呼叫 _submitScore 進行評分
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0), // 調整間距以避免誤觸
                      child: Icon(
                        scoreIndex <= (_userScore ?? 0) ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 28,
                      ),
                    ),
                  );
                }),
                const Spacer(),
                if (_userScore != null)
                  TextButton(
                    onPressed: () => _clearUserScore(), // 💥 清除評分
                    child: const Text('清除', style: TextStyle(color: Colors.red)),
                  )
                // 首次評分時，無需評分按鈕，點擊星星即可
              ],
            ),
          )
        ],
      ),
    );
  }

  // 評論標題區塊 - 保持不變
  Widget _buildCommentHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '評論 (${_comments.length})',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ListView.builder - 保持不變
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
          _buildRatingStatsHeader(),
          _buildCommentHeader(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                ? const Center(child: Text('目前沒有留言，快來搶頭香！'))
                : RefreshIndicator(
              onRefresh: _refreshAllData,
              child: ListView.builder(
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];

                  final displayUser = comment['display_name'] ?? '用戶 #${comment['user_id'] ?? '訪客'}';
                  final date = comment['ceated_at'] != null ? _formatDate(comment['ceated_at']) : '未知日期';
                  final commentText = comment['comment_text'] ?? '無留言內容';

                  final isCurrentUserComment = comment['user_id'] == widget.currentUserId;
                  final commentId = comment['comment_id'] as int?;

                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(comment['is_anonymous'] == true ? Icons.masks : Icons.person),
                    ),
                    title: Text(
                      displayUser,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(commentText, maxLines: 5, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),

                        if (isCurrentUserComment && commentId != null)
                          PopupMenuButton<String>(
                            onSelected: (String result) {
                              if (result == 'edit') {
                                _editComment(commentId, commentText);
                              } else if (result == 'delete') {
                                _deleteComment(commentId);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('編輯'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('刪除', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          _buildCommentInput(),
        ],
      ),
    );
  }

  // 留言輸入框 (包含匿名選擇) - 保持不變
  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              const Text('匿名留言', style: TextStyle(fontSize: 16)),
              Switch(
                value: _isAnonymous,
                onChanged: (bool value) {
                  setState(() {
                    _isAnonymous = value;
                  });
                },
              ),
              if (_isAnonymous)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: TextField(
                      controller: _anonymousNameController,
                      decoration: const InputDecoration(
                        hintText: '輸入匿名名稱',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
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
        ],
      ),
    );
  }
}