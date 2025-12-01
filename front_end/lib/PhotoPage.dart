import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PhotoPage extends StatefulWidget {
  const PhotoPage({super.key});

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  List<dynamic> _images = []; // 搜尋結果
  final TextEditingController _altController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final String apiUrl = "http://localhost:3000/api/image"; // API
  bool isLoading = false;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchImages();
  }

  @override
  void dispose() {
    _altController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // API
  // 搜尋所有照片
  Future<void> _searchImages() async {
    setState(() => isLoading = true);

    try {
      var response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        setState(() {
          _images = body['data'] ?? [];
        });
      } else {
        _showErrorMessage("搜尋失敗: ${response.statusCode}");
      }
    } catch (e) {
      print("搜尋錯誤: $e");
      _showErrorMessage("網路連接錯誤");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 新增照片 (URL + 說明)
  Future<void> _uploadImageUrl(String imageUrl) async {
    if (imageUrl.isEmpty) {
      _showErrorMessage("請輸入圖片 URL");
      return;
    }

    setState(() => isLoading = true);

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "img": {"src": imageUrl, "alt": _altController.text},
        }),
      );

      final respJson = json.decode(response.body);

      if (response.statusCode == 200 && respJson['success'] == true) {
        _showSuccessMessage("照片新增成功");
        _altController.clear();
        _urlController.clear();
        await _searchImages();
      } else {
        _showErrorMessage("新增失敗: ${respJson['message'] ?? '未知錯誤'}");
      }
    } catch (e) {
      print("新增錯誤: $e");
      _showErrorMessage("網路連接錯誤");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 刪除指定照片
  Future<void> _deleteImage(int id) async {
    try {
      var response = await http.delete(Uri.parse("$apiUrl/$id"));
      if (response.statusCode == 200) {
        _showSuccessMessage("照片已刪除");
        await _searchImages();
      } else {
        _showErrorMessage("刪除失敗: ${response.statusCode}");
      }
    } catch (e) {
      print("刪除錯誤: $e");
      _showErrorMessage("網路連接錯誤");
    }
  }

  // 主要內容區域 Widget
  Widget _buildPhotoContent() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('載入中...', style: TextStyle(color: Color(0xFF9ca3af))),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 圖片管理說明
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1a2a4e),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3b82f6).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: const Color(0xFF60a5fa)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '圖片管理功能',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF60a5fa),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '支援 URL 上傳、圖片說明編輯、預覽和刪除功能',
                      style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 圖片列表
        if (_images.isEmpty) _buildEmptyState() else _buildImageGrid(),
      ],
    );
  }

  // 空狀態顯示
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: const Color(0xFF9ca3af),
          ),
          const SizedBox(height: 16),
          Text(
            '目前沒有照片',
            style: TextStyle(
              fontSize: 18,
              color: const Color(0xFF9ca3af),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '點擊右下角的新增按鈕來添加第一張照片',
            style: TextStyle(fontSize: 14, color: const Color(0xFF9ca3af)),
          ),
        ],
      ),
    );
  }

  // 圖片網格顯示
  Widget _buildImageGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '圖片列表 (${_images.length} 張)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF60a5fa),
          ),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: _images.length,
          itemBuilder: (context, index) {
            final img = _images[index];
            return _buildImageCard(img);
          },
        ),
      ],
    );
  }

  // 圖片卡片
  Widget _buildImageCard(dynamic img) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 圖片預覽
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFF1a2a4e),
              child: Image.network(
                img['image_origin_url'] ?? '',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value:
                          loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                      color: const Color(0xFF60a5fa),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF3b82f6).withOpacity(0.2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 40,
                          color: const Color(0xFF9ca3af),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '載入失敗',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF9ca3af),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 圖片資訊
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 圖片說明
                  Text(
                    img['image_text'] ?? '無說明',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // 圖片 ID
                  Text(
                    'ID: ${img['image_id'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF9ca3af),
                    ),
                  ),

                  const Spacer(),

                  // 操作按鈕
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showImageDetails(img),
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('詳情'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3b82f6),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showDeleteConfirmDialog(img),
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red[600],
                        iconSize: 20,
                        tooltip: '刪除圖片',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 對話框和輔助方法
  void _showAddPhotoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.add_photo_alternate, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('新增照片'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: "圖片 URL",
                      hintText: "請輸入圖片網址",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _altController,
                    decoration: const InputDecoration(
                      labelText: "圖片說明",
                      hintText: "為圖片添加描述",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a2a4e),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFF60a5fa),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '請確保 URL 指向有效的圖片檔案',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _uploadImageUrl(_urlController.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF60a5fa),
                  foregroundColor: Colors.white,
                ),
                child: const Text('新增'),
              ),
            ],
          ),
    );
  }

  void _showImageDetails(dynamic img) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text('圖片詳情'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      img['image_origin_url'] ?? '',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: const Color(0xFF3b82f6).withOpacity(0.2),
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 50),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('圖片 ID', '${img['image_id'] ?? 'N/A'}'),
                  _buildDetailRow('說明', img['image_text'] ?? '無說明'),
                  _buildDetailRow('原始 URL', img['image_origin_url'] ?? 'N/A'),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmDialog(dynamic img) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[600]),
                const SizedBox(width: 8),
                const Text('確認刪除'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    img['image_origin_url'] ?? '',
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: const Color(0xFF3b82f6).withOpacity(0.2),
                        child: const Icon(Icons.broken_image),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '確定要刪除這張圖片嗎？\n\n"${img['image_text'] ?? '無說明'}"\n\n此操作無法復原。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteImage(img['image_id']);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFef4444),
                  foregroundColor: Colors.white,
                ),
                child: const Text('刪除'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9ca3af),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // 搜尋功能
  void _performSearch(String query) {
    setState(() {
      searchQuery = query;
    });

    if (query.trim().isEmpty) {
      _searchImages();
      return;
    }

    // 基本的本地搜尋過濾 (可以擴展為 API 搜尋)
    setState(() {
      // 這裡可以實作 API 搜尋，目前使用本地過濾
      _images =
          _images.where((img) {
            final text = (img['image_text'] ?? '').toString().toLowerCase();
            return text.contains(query.toLowerCase());
          }).toList();
    });
  }

  // 訊息顯示方法
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF10b981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFFef4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 主 Widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a1428),
      appBar: AppBar(
        title: const Text('圖片管理'),
        backgroundColor: const Color(0xFF0a1428),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [_buildPhotoContent(), const SizedBox(height: 80)],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPhotoDialog,
        backgroundColor: const Color(0xFF60a5fa),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: '新增圖片',
      ),
    );
    ;
  }
}
