import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// 確保此路徑正確指向您的 API 設定
import '../config.dart';

// 通用留言頁面，用於顯示和發送特定數據類型和 ID 的留言。
class CommentsPage extends StatefulWidget {
  final int dataId; // 數據的唯一 ID (如 eventId, perspectiveId)
  final int? currentUserId; // 當前登入的使用者 ID (用於判斷是否能發言)
  final String dataType; // 數據的類型 (如 'eventsorting', 'multipleperspectives')
  // 傳遞父頁面中實作的 API 函式，用於發送新的 'comment' 動作
  final Future<void> Function(String actionType, String dataType, {String? text, int? score}) insertUserAction;

  const CommentsPage({
    super.key,
    required this.dataId,
    required this.currentUserId,
    required this.dataType,
    required this.insertUserAction,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = []; // 用於儲存留言列表
  bool _isLoading = true;

  // API 基礎 URL 始終指向 $baseUrl
  final String _userActionBaseUrl = '$baseUrl';

  @override
  void initState() {
    super.initState();
    if (widget.dataType.isNotEmpty) {
      _fetchComments();
    } else {
      setState(() {
        _isLoading = false;
      });
      print("Error: dataType is missing for CommentsPage.");
    }
  }

  // 1. 獲取現有留言 (GET API)
  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
    });

    // 構造通用的查詢 URL: $baseUrl/user/comment/{dataType}?dataId={dataId}
    // 注意：後端需要有這個 GET 路由並能處理 dataId
    final uri = Uri.parse('$_userActionBaseUrl/user/comment/${widget.dataType}').replace(queryParameters: {
      'dataId': widget.dataId.toString(),
    });

    print('Fetching comments from: $uri');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // 假設後端回傳的資料結構是 {success: true, data: [...]}
          _comments = data['data'] is List ? data['data'] : [];
        });
      } else {
        print('Failed to load comments: ${response.statusCode}, Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('留言載入失敗：請檢查後端查詢 API')),
        );
      }
    } catch (e) {
      print('Error fetching comments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('連線錯誤: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 2. 發送新留言 (POST API)
  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || widget.currentUserId == null) return;

    // 使用父頁面傳入的通用 _insertUserAction 函式
    await widget.insertUserAction(
      'comment',
      widget.dataType,
      text: text, // 留言內容
    );

    _commentController.clear();
    FocusScope.of(context).unfocus(); // 隱藏鍵盤

    // 短暫延遲後重新載入留言，以顯示新留言
    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用戶留言'),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
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

                // 假設後端返回的數據中，至少包含 comment_text 和 created_at
                // 根據您的後端代碼，可能包含 user_id 或 anonymous_id
                final userId = comment['user_id'] ?? comment['anonymous_id'];
                final date = comment['ceated_at']?.split('T')[0] ?? '未知日期';
                final commentText = comment['text'] ?? '無留言內容';

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  // ----------------------------------------------------
                  // 💥 修正點：只顯示通用標籤，不依賴後端返回的 user_name 💥
                  // ----------------------------------------------------
                  title: Text(
                    '用戶留言 #${userId ?? '訪客'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // ----------------------------------------------------
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