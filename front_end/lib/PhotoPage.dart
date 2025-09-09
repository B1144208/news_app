import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PhotoPage extends StatefulWidget {
  const PhotoPage({super.key});

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  PlatformFile? _pickedFile;
  Uint8List? _webImage;
  List<dynamic> _images = []; // 搜尋結果
  final String apiUrl = "http://localhost:3000/api/image"; // TODO: API更改位置

  // 選擇照片
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFile = result.files.first;
        if (kIsWeb) {
          _webImage = _pickedFile!.bytes;
        }
      });
    }
  }

  // 上傳照片
  Future<void> _uploadImage() async {
    if (_pickedFile == null) return;

    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

    if (kIsWeb) {
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        _webImage!,
        filename: _pickedFile!.name,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        _pickedFile!.path!,
      ));
    }

    request.fields['alt'] = 'Flutter file_picker test';

    var response = await request.send();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("照片上傳成功")),
      );
      _searchImages(); // 上傳後刷新列表
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("上傳失敗: ${response.statusCode}")),
      );
    }
  }

  // 搜尋所有照片
  Future<void> _searchImages() async {
    try {
      var response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          _images = json.decode(response.body);
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

  // 刪除指定照片
  Future<void> _deleteImage(int id) async {
    try {
      var response = await http.delete(Uri.parse("$apiUrl/$id"));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("照片已刪除")),
        );
        _searchImages(); // 刪除後刷新
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
  void initState() {
    super.initState();
    _searchImages(); // 頁面載入時先查一次
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("照片管理")),
      body: Column(
        children: [
          // 上傳區
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pickedFile == null
                      ? const Text("尚未選擇照片")
                      : kIsWeb
                      ? Image.memory(_webImage!, height: 200)
                      : Image.file(File(_pickedFile!.path!), height: 200),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text("選擇照片"),
                  ),
                  ElevatedButton(
                    onPressed: _uploadImage,
                    child: const Text("上傳照片"),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          // 搜尋 & 刪除區
          Expanded(
            flex: 3,
            child: _images.isEmpty
                ? const Center(child: Text("目前沒有照片"))
                : ListView.builder(
              itemCount: _images.length,
              itemBuilder: (context, index) {
                final img = _images[index];
                return ListTile(
                  leading: Image.network(
                    img['src'],
                    width: 60,
                    fit: BoxFit.cover,
                  ),
                  title: Text(img['alt'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteImage(img['id']),
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
