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

  @override
  void initState() {
    super.initState();
    _searchImages();
  }

  // 搜尋所有照片
  Future<void> _searchImages() async {
    try {
      var response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        setState(() {
          _images = body['data'] ?? [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("搜尋失敗: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("搜尋錯誤: $e");
    }
  }

  // 新增照片 (URL + 說明)
  Future<void> _uploadImageUrl(String imageUrl) async {
    if (imageUrl.isEmpty) return;

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "img": {
            "src": imageUrl,
            "alt": _altController.text
          }
        }),
      );

      final respJson = json.decode(response.body);

      if (response.statusCode == 200 && respJson['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("照片新增成功")),
        );
        _altController.clear();
        _urlController.clear();
        _searchImages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("新增失敗: ${respJson['message']}")),
        );
      }
    } catch (e) {
      print("新增錯誤: $e");
    }
  }

  // 刪除指定照片
  Future<void> _deleteImage(int id) async {
    try {
      var response = await http.delete(Uri.parse("$apiUrl/$id"));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("照片已刪除")),
        );
        _searchImages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("刪除失敗: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("刪除錯誤: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("照片管理 (URL 版)")),
      body: Column(
        children: [
          // 新增區
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: "照片 URL",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _altController,
                  decoration: const InputDecoration(
                    labelText: "照片說明",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _uploadImageUrl(_urlController.text),
                  child: const Text("新增照片"),
                ),
              ],
            ),
          ),
          const Divider(),
          // 搜尋 & 刪除區
          Expanded(
            child: _images.isEmpty
                ? const Center(child: Text("目前沒有照片"))
                : ListView.builder(
              itemCount: _images.length,
              itemBuilder: (context, index) {
                final img = _images[index];
                return ListTile(
                  leading: Image.network(
                    img['image_origin_url'],
                    width: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image),
                  ),
                  title: Text(img['image_text'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteImage(img['image_id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
