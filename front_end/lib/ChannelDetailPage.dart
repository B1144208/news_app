import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChannelDetailPage extends StatefulWidget {
  final int channelId;
  final String channelName;
  final String? channelDescription;
  final String? channelUrl;

  const ChannelDetailPage({
    Key? key,
    required this.channelId,
    required this.channelName,
    this.channelDescription,
    this.channelUrl,
  }) : super(key: key);

  @override
  State<ChannelDetailPage> createState() => _ChannelDetailPageState();
}

class _ChannelDetailPageState extends State<ChannelDetailPage> {
  static const String apiUrl =
      "http://localhost:3000/api/news"; // TODO: 實際API端點
  static const String channelImageUrl =
      "http://localhost:3000/api/channel/image"; // 頻道圖片API

  List<dynamic> channelNews = [];
  List<dynamic> channelReviews = [];
  bool isLoading = false;
  double averageRating = 4.3;
  int totalReviews = 1302;
  String updateFrequency = "每日更新";
  String? channelBackgroundImage; // 頻道背景圖片URL

  // TODO: 未來可以從資料庫獲取的頻道詳細資訊
  Map<String, dynamic> channelStats = {
    'totalViews': '2.5萬',
    'totalSubscribers': '1,234',
    'establishedDate': '2023年1月',
    'language': '繁體中文',
    'category': '國際新聞',
    'publisher': 'BBC World Service',
    'copyright': '© (C) BBC 2025',
  };

  @override
  void initState() {
    super.initState();
    _loadChannelData();
  }

  // TODO: 從資料庫載入頻道相關新聞和圖片
  Future<void> _loadChannelData() async {
    setState(() => isLoading = true);

    try {
      // TODO: 載入頻道背景圖片
      // final imageResponse = await http.get(Uri.parse("$channelImageUrl/${widget.channelId}"));
      // if (imageResponse.statusCode == 200) {
      //   final imageData = json.decode(imageResponse.body);
      //   channelBackgroundImage = imageData['background_image_url'];
      // }

      // TODO: 實際API呼叫，目前使用模擬資料
      await Future.delayed(Duration(seconds: 1)); // 模擬網路延遲

      setState(() {
        // 模擬頻道背景圖片（之後從資料庫獲取）
        channelBackgroundImage =
            'https://via.placeholder.com/400x200/ff6b6b/ffffff?text=Channel+Background';

        // 模擬新聞資料
        channelNews = [
          {
            'id': 1,
            'title':
                'Alleged head of \'Zizlam\' cult arrested, linked to agent\'s death near Canada',
            'publish_time': '2小時前',
            'views': 1234,
            'thumbnail': 'https://via.placeholder.com/60x45',
            'url': 'https://example.com/news/1',
          },
          {
            'id': 2,
            'title':
                'Health Canada seizes unauthorized sex enhancement products, issues...',
            'publish_time': '4小時前',
            'views': 856,
            'thumbnail': 'https://via.placeholder.com/60x45',
            'url': 'https://example.com/news/2',
          },
          {
            'id': 3,
            'title':
                'Alberta premier shuffles deputy health minister amid corruption allegations',
            'publish_time': '6小時前',
            'views': 2341,
            'thumbnail': 'https://via.placeholder.com/60x45',
            'url': 'https://example.com/news/3',
          },
          // 更多新聞...
        ];

        // 模擬評論資料
        channelReviews = [
          {
            'user': '新聞愛好者',
            'rating': 5,
            'comment': '很棒的國際新聞頻道，報導深入且及時',
            'time': '2天前',
          },
          {
            'user': '媒體觀察員',
            'rating': 4,
            'comment': '內容豐富，但有時更新頻率不夠',
            'time': '1週前',
          },
        ];
      });
    } catch (e) {
      _showErrorMessage('載入頻道資料失敗: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE8E3FF), // 與截圖相似的淺紫色背景
      appBar: _buildAppBar(),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildChannelHeader(),
                  SizedBox(height: 16),
                  _buildNewsSection(),
                  SizedBox(height: 16),
                  _buildRatingSection(),
                  SizedBox(height: 16),
                  _buildDescriptionSection(),
                  SizedBox(height: 16),
                  _buildInfoSection(),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // 自定義AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0xFFB39DDB), // 與截圖相似的紫色
      foregroundColor: Colors.black87,
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.channelName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: Icon(Icons.more_horiz), onPressed: _showMoreOptions),
      ],
      elevation: 1,
    );
  }

  // 頻道標題區域（支持背景圖片）
  Widget _buildChannelHeader() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 280,
          child: Stack(
            children: [
              // 背景圖片層（從資料庫獲取）
              Positioned.fill(
                child: channelBackgroundImage != null
                    ? Image.network(
                        channelBackgroundImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultBackground();
                        },
                      )
                    : _buildDefaultBackground(),
              ),

              // 漸變遮罩層
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // 內容層
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 頂部操作按鈕
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 分類標籤
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white38),
                            ),
                            child: Text(
                              '${channelStats['category']}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          // 頻道操作選單（分享和檢舉）
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.white),
                            iconSize: 24,
                            onSelected: (value) {
                              switch (value) {
                                case 'share':
                                  _shareChannel();
                                  break;
                                case 'report':
                                  _reportChannel();
                                  break;
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.share,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 8),
                                    Text('分享頻道'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'report',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.report,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text('檢舉頻道'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      Spacer(),

                      // 頻道名稱
                      Text(
                        widget.channelName.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 8),

                      // 副標題
                      Text(
                        channelStats['publisher'] ?? 'Unknown Publisher',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // 描述
                      Text(
                        widget.channelDescription ??
                            'The day\'s top stories from BBC News, including the latest from Gaza, on US politics and about the Ukraine conflict. Delivered twice a day on weekdays, daily at weekends.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.4,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 20),

                      // 統計資訊
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          SizedBox(width: 4),
                          Text(
                            '$averageRating ($totalReviews)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 20),
                          Icon(Icons.schedule, color: Colors.white70, size: 18),
                          SizedBox(width: 4),
                          Text(
                            updateFrequency,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 預設背景（當沒有圖片時）
  Widget _buildDefaultBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red[600]!, Colors.red[800]!],
        ),
      ),
    );
  }

  // 新聞列表區域
  Widget _buildNewsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article, color: Colors.deepPurple, size: 20),
              SizedBox(width: 8),
              Text(
                '新聞',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: 導航到完整新聞列表
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('顯示全部', style: TextStyle(color: Colors.deepPurple)),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          ...channelNews.take(3).map((news) => _buildNewsItem(news)),
        ],
      ),
    );
  }

  // 單個新聞項目（增加分享和檢舉功能）
  Widget _buildNewsItem(Map<String, dynamic> news) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: 導航到新聞詳細頁面
          _showComingSoon('新聞詳細頁面');
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 新聞縮圖
              Container(
                width: 60,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    news['thumbnail'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.image,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
              ),

              SizedBox(width: 12),

              // 新聞內容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news['title'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 6),

                    Row(
                      children: [
                        Text(
                          news['publish_time'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.visibility,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        SizedBox(width: 2),
                        Text(
                          '${news['views'] ?? 0}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 新聞操作選單
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                      _shareNews(news);
                      break;
                    case 'report':
                      _reportNews(news);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('分享新聞'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.report, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('檢舉新聞'),
                      ],
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

  // 評分評論區域
  Widget _buildRatingSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rate, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                '評分與評論',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: _showAllReviews,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('查看全部', style: TextStyle(color: Colors.deepPurple)),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // 整體評分
          Row(
            children: [
              Text(
                '評分：',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(width: 8),
              ...List.generate(5, (index) {
                return Icon(
                  index < averageRating.floor()
                      ? Icons.star
                      : (index < averageRating
                            ? Icons.star_half
                            : Icons.star_border),
                  color: Colors.amber,
                  size: 20,
                );
              }),
              SizedBox(width: 8),
              Text(
                '$averageRating',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // 評論列表
          ...channelReviews.take(2).map((review) => _buildReviewItem(review)),

          // TODO: 新增評論按鈕
          SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: 實現新增評論功能
                _showComingSoon('新增評論功能');
              },
              icon: Icon(Icons.add_comment, size: 18),
              label: Text('新增評論'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: BorderSide(color: Colors.deepPurple),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 單個評論項目
  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.deepPurple[100],
                child: Text(
                  review['user'][0],
                  style: TextStyle(
                    color: Colors.deepPurple[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  review['user'],
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < review['rating'] ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ),
              SizedBox(width: 8),
              Text(
                review['time'],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            review['comment'],
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }

  // 簡介區域
  Widget _buildDescriptionSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.deepPurple, size: 20),
              SizedBox(width: 8),
              Text(
                '簡介',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            widget.channelDescription ??
                'The day\'s top stories from BBC News, including the latest from Gaza, on US politics and about the Ukraine conflict. Delivered twice a day on weekdays, daily at weekends.',
            style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }

  // 資訊區域
  Widget _buildInfoSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Colors.deepPurple,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '資訊',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          _buildInfoRow('製作者', channelStats['publisher']),
          _buildInfoRow('創作者', channelStats['publisher']),
          _buildInfoRow('年齡分級', '另少適宜'),
          _buildInfoRow('版權', channelStats['copyright']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: TextStyle(color: Colors.black87, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // 更多選項（實現分享和檢舉功能）
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 標題
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.share, color: Colors.blue),
                ),
                title: Text('分享頻道'),
                subtitle: Text('分享到社群媒體或傳送給朋友'),
                onTap: () {
                  Navigator.pop(context);
                  _shareChannel();
                },
              ),

              Divider(),

              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bookmark_add, color: Colors.green),
                ),
                title: Text('加入書籤'),
                subtitle: Text('儲存此頻道供日後查看'),
                onTap: () {
                  Navigator.pop(context);
                  _bookmarkChannel();
                },
              ),

              Divider(),

              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.report, color: Colors.red),
                ),
                title: Text('檢舉頻道'),
                subtitle: Text('回報不當內容或違規行為'),
                onTap: () {
                  Navigator.pop(context);
                  _reportChannel();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 顯示所有評論
  void _showAllReviews() {
    // TODO: 實現完整評論頁面
    _showComingSoon('完整評論頁面');
  }

  // 分享頻道功能
  void _shareChannel() async {
    try {
      final String shareContent =
          '''
📺 ${widget.channelName}
${channelStats['publisher'] ?? ''}

${widget.channelDescription ?? '頻道描述'}

⭐ 評分: $averageRating/5.0 ($totalReviews 則評論)
📅 更新頻率: $updateFrequency

立即查看更多精彩內容！
${widget.channelUrl ?? 'https://example.com/channel/${widget.channelId}'}
      ''';

      // TODO: 實際分享功能實現
      // 可以使用 share_plus 套件: await Share.share(shareContent);

      // 目前顯示分享對話框
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.share, color: Colors.blue),
              SizedBox(width: 8),
              Text('分享頻道'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分享內容預覽：'),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(shareContent, style: TextStyle(fontSize: 14)),
                ),
                SizedBox(height: 16),
                Text('分享選項：', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildShareOption('複製連結', Icons.link, () {
                      Navigator.pop(context);
                      _copyToClipboard(shareContent);
                    }),
                    _buildShareOption('LINE', Icons.message, () {
                      Navigator.pop(context);
                      _showComingSoon('LINE分享');
                    }),
                    _buildShareOption('Facebook', Icons.facebook, () {
                      Navigator.pop(context);
                      _showComingSoon('Facebook分享');
                    }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorMessage('分享失敗: $e');
    }
  }

  // 分享新聞功能
  void _shareNews(Map<String, dynamic> news) async {
    try {
      final String shareContent =
          '''
📰 ${news['title']}

來自頻道: ${widget.channelName}
發布時間: ${news['publish_time']}
觀看次數: ${news['views']}

${news['url'] ?? 'https://example.com/news/${news['id']}'}
      ''';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.share, color: Colors.blue),
              SizedBox(width: 8),
              Text('分享新聞'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分享內容預覽：'),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(shareContent, style: TextStyle(fontSize: 14)),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildShareOption('複製連結', Icons.link, () {
                      Navigator.pop(context);
                      _copyToClipboard(shareContent);
                    }),
                    _buildShareOption('分享', Icons.share, () {
                      Navigator.pop(context);
                      _showComingSoon('系統分享');
                    }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorMessage('分享新聞失敗: $e');
    }
  }

  // 檢舉頻道功能
  void _reportChannel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.report, color: Colors.red),
            SizedBox(width: 8),
            Text('檢舉頻道'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('請選擇檢舉原因：'),
              SizedBox(height: 16),

              ...['不當內容', '虛假資訊', '版權侵權', '垃圾訊息', '其他'].map(
                (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: null, // TODO: 實現選擇狀態管理
                  onChanged: (value) {
                    Navigator.pop(context);
                    _submitChannelReport(reason);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
        ],
      ),
    );
  }

  // 檢舉新聞功能
  void _reportNews(Map<String, dynamic> news) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.report, color: Colors.red),
            SizedBox(width: 8),
            Text('檢舉新聞'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('新聞標題：'),
              SizedBox(height: 4),
              Text(
                news['title'],
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('請選擇檢舉原因：'),
              SizedBox(height: 16),

              ...['不實消息', '不當內容', '版權侵權', '仇恨言論', '其他'].map(
                (reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: null, // TODO: 實現選擇狀態管理
                  onChanged: (value) {
                    Navigator.pop(context);
                    _submitNewsReport(news['id'], reason);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
        ],
      ),
    );
  }

  // 書籤功能
  void _bookmarkChannel() async {
    try {
      // TODO: 實現書籤API調用
      // final response = await http.post(
      //   Uri.parse("$baseUrl/user/bookmark"),
      //   body: json.encode({'channel_id': widget.channelId}),
      // );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bookmark_added, color: Colors.green),
              SizedBox(width: 8),
              Text('書籤成功'),
            ],
          ),
          content: Text('已將「${widget.channelName}」加入您的書籤清單'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('確定'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: 導航到書籤頁面
                _showComingSoon('書籤頁面');
              },
              child: Text('查看書籤'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorMessage('加入書籤失敗: $e');
    }
  }

  // 提交頻道檢舉
  void _submitChannelReport(String reason) async {
    try {
      // TODO: 實現檢舉API調用
      // final response = await http.post(
      //   Uri.parse("$baseUrl/report/channel"),
      //   body: json.encode({
      //     'channel_id': widget.channelId,
      //     'reason': reason,
      //     'timestamp': DateTime.now().toIso8601String(),
      //   }),
      // );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('檢舉已提交，我們將盡快處理。原因：$reason')),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _showErrorMessage('提交檢舉失敗: $e');
    }
  }

  // 提交新聞檢舉
  void _submitNewsReport(int newsId, String reason) async {
    try {
      // TODO: 實現新聞檢舉API調用
      // final response = await http.post(
      //   Uri.parse("$baseUrl/report/news"),
      //   body: json.encode({
      //     'news_id': newsId,
      //     'channel_id': widget.channelId,
      //     'reason': reason,
      //     'timestamp': DateTime.now().toIso8601String(),
      //   }),
      // );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('新聞檢舉已提交，我們將盡快處理。原因：$reason')),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _showErrorMessage('提交新聞檢舉失敗: $e');
    }
  }

  // 複製到剪貼板
  void _copyToClipboard(String content) async {
    try {
      // TODO: 使用 flutter/services 實現剪貼板功能
      // await Clipboard.setData(ClipboardData(text: content));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('內容已複製到剪貼板'),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showErrorMessage('複製失敗: $e');
    }
  }

  // 分享選項Widget
  Widget _buildShareOption(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.blue),
            SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // 顯示開發中提示
  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 開發中...'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  // 顯示錯誤訊息
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// TODO: 未來可以擴展的功能
/*
未來可以增加的功能：

1. 訂閱/取消訂閱功能
   - 加入 FloatingActionButton 進行訂閱
   - 顯示訂閱狀態和訂閱者數量

2. 推播通知設定
   - 新聞發布通知
   - 頻道更新提醒

3. 個人化推薦
   - 基於用戶喜好推薦相似頻道
   - 個人化新聞排序

4. 進階搜尋和篩選
   - 按日期篩選新聞
   - 按類型篩選內容
   - 關鍵字搜尋頻道內容

5. 社群互動功能
   - 評論點讚/回覆
   - 分享到社群媒體
   - 用戶關注系統

6. 多媒體內容支援
   - 音頻播放器
   - 視頻播放器
   - 直播功能

7. 離線功能
   - 下載新聞供離線閱讀
   - 離線播放音頻

8. 分析和統計
   - 閱讀時間統計
   - 頻道流量分析
   - 用戶行為追蹤

9. 多語言支援
   - 國際化界面
   - 內容翻譯

10. 無障礙功能
    - 語音朗讀
    - 字體大小調整
    - 高對比度模式
*/
