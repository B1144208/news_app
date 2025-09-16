import 'package:flutter/material.dart';

class ViewNewsContent extends StatefulWidget {
  final Map<String, dynamic> newsData;

  const ViewNewsContent({
    super.key,
    required this.newsData,
  });

  @override
  State<ViewNewsContent> createState() => _ViewNewsContentState();
}

class _ViewNewsContentState extends State<ViewNewsContent> {
  bool isFavorite = false;
  bool showComments = false;
  bool showChatBox = false;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  // 模擬留言數據
  final List<Map<String, dynamic>> _comments = [
    {
      'user': '用戶A',
      'content': '這個新聞很有意思！',
      'time': '2小時前',
      'avatar': 'A',
    },
    {
      'user': '用戶B',
      'content': '感謝分享這個重要資訊',
      'time': '3小時前',
      'avatar': 'B',
    },
    {
      'user': '用戶C',
      'content': '希望能有更多這樣的報導',
      'time': '5小時前',
      'avatar': 'C',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 自定義AppBar
                _buildCustomAppBar(),

                // 主要內容區域
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 60), // 為右側按鈕預留空間
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 新聞主要內容
                            _buildNewsContent(),

                            // 底部留白
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),

                      // 右側垂直按鈕欄
                      _buildRightButtonPanel(),
                    ],
                  ),
                ),

                // 底部操作欄
                _buildBottomActionBar(),
              ],
            ),

            // 留言覆蓋層
            if (showComments) _buildCommentsOverlay(),

            // 聊天框覆蓋層
            if (showChatBox) _buildChatOverlay(),
          ],
        ),
      ),
    );
  }

  // 自定義AppBar
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Color(0xFFC9BDFF),
      child: Row(
        children: [
          // 返回按鈕
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),

          const SizedBox(width: 8),

          // 新聞頻道圖片
          Container(
            width: 120,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                '頻道圖片',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 新聞主要內容
  Widget _buildNewsContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 新聞標題
          Text(
            widget.newsData['title'] ?? '無標題',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          // 記者信息
          Text(
            '記者名稱/綜合報導',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),

          const SizedBox(height: 8),

          // 報導時間
          Text(
            '2025年1月1日 週一 上午12:00',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 20),

          // 新聞圖片
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.newsData['cover_img'] != null
                  ? Image.network(
                widget.newsData['cover_img'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image,
                    color: Colors.grey,
                    size: 50,
                  );
                },
              )
                  : const Icon(
                Icons.image,
                color: Colors.grey,
                size: 50,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 圖片說明
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述圖片描述（圖／資料照片）',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 新聞內容
          const Text(
            '新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容新聞內容',
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 右側垂直按鈕欄
  Widget _buildRightButtonPanel() {
    return Positioned(
      right: 8,
      top: 100,
      child: Column(
        children: [
          _buildRightButton(Icons.play_circle_outline, 'AI朗讀', Colors.blue),
          const SizedBox(height: 12),
          _buildRightButton(Icons.library_books_outlined, '事件整理', Colors.green),
          const SizedBox(height: 12),
          _buildRightButton(Icons.download_outlined, '下載', Colors.orange),
          const SizedBox(height: 12),
          _buildRightButton(Icons.flag_outlined, '檢舉', Colors.red),
        ],
      ),
    );
  }

  // 右側單個按鈕
  Widget _buildRightButton(IconData icon, String tooltip, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 24),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$tooltip 功能開發中'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        tooltip: tooltip,
      ),
    );
  }

  // 底部操作欄
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 留言按鈕
          InkWell(
            onTap: () {
              setState(() {
                showComments = !showComments;
              });
            },
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
                  Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${_comments.length}則',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // 機器人圖示
          InkWell(
            onTap: () {
              setState(() {
                showChatBox = !showChatBox;
              });
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          const Spacer(),

          // 右側按鈕組
          Row(
            children: [
              // 收藏按鈕
              InkWell(
                onTap: () {
                  setState(() {
                    isFavorite = !isFavorite;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isFavorite ? '已加入收藏' : '已移除收藏'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                    color: isFavorite ? Colors.blue : Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),

              // 分享按鈕
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分享功能開發中'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.share_outlined,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 留言覆蓋層
  Widget _buildCommentsOverlay() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showComments = false;
                });
              },
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 留言標題欄
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '留言',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_comments.length}則',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            showComments = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 留言列表
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _comments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return _buildCommentItem(comment);
                    },
                  ),
                ),

                // 留言輸入框
                _buildCommentInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 聊天覆蓋層
  Widget _buildChatOverlay() {
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'AI 助手',
                  style: TextStyle(fontWeight: FontWeight.bold,
                    color: Colors.black,),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      showChatBox = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: '請問有什麼要詢問的呢？',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () {
                    if (_chatController.text.trim().isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AI 功能開發中'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      _chatController.clear();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 單個留言項目
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 頭像
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue[100],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              comment['avatar'],
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 留言內容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment['user'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    comment['time'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                comment['content'],
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 留言輸入框
  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: '請輸入文字',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _submitComment,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitComment() {
    if (_commentController.text.trim().isNotEmpty) {
      setState(() {
        _comments.insert(0, {
          'user': '我',
          'content': _commentController.text.trim(),
          'time': '剛剛',
          'avatar': '我',
        });
      });
      _commentController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('留言已發送'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _chatController.dispose();
    super.dispose();
  }
}