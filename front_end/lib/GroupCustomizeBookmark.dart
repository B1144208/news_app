import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class GroupCustomizeBookmark extends StatefulWidget {
  final int userId;
  final String bookmarkType; // 'news' or 'channel'

  const GroupCustomizeBookmark({
    super.key,
    required this.userId,
    required this.bookmarkType,
  });

  @override
  State<GroupCustomizeBookmark> createState() => _GroupCustomizeBookmarkState();
}

class _GroupCustomizeBookmarkState extends State<GroupCustomizeBookmark> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  bool _isSelectionMode = false;
  Set<int> _selectedCategoryIds = {};
  bool _hasChanges = false;

  // 拖動相關變數
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  // 獲取用戶的收藏分類
  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/bookmark'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['result'] != null) {
          List<dynamic> resultList = data['result'];

          // 只篩選出符合當前類型的分類
          List<Map<String, dynamic>> categories = [];
          for (var item in resultList) {
            if (item['groupcustomize_type'] == widget.bookmarkType) {
              categories.add({
                'groupcustomize_id': item['groupcustomize_id'],
                'groupcustomize_name': item['groupcustomize_name'],
                'groupcustomize_order': item['groupcustomize_order'],
              });
            }
          }

          // 按照順序排序
          categories.sort((a, b) =>
              (a['groupcustomize_order'] ?? 0).compareTo(b['groupcustomize_order'] ?? 0)
          );

          setState(() {
            _categories = categories;
            _isLoading = false;
          });
        } else {
          setState(() {
            _categories = [];
            _isLoading = false;
          });
        }
      }
    } catch (error) {
      print('Error fetching categories: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 新增分類
  Future<void> _addCategory(String categoryName) async {
    if (categoryName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('分類名稱不能為空'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/insert/bookmark'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'name': categoryName,
          'type': widget.bookmarkType,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true || data['insertId'] != null) {
          await _fetchCategories();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('新增分類成功'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (error) {
      print('Error adding category: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('新增失敗: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 重新命名分類
  Future<void> _renameCategory(int categoryId, String oldName, String newName) async {
    if (newName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('分類名稱不能為空'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 先刪除舊的
      await http.delete(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/delete/bookmark'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'groupId': [categoryId],
        }),
      );

      // 然後新增新的
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/insert/bookmark'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'name': newName,
          'type': widget.bookmarkType,
        }),
      );

      if (response.statusCode == 200) {
        await _fetchCategories();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('重新命名成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (error) {
      print('Error renaming category: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重新命名失敗: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 刪除分類
  Future<void> _deleteCategories(List<int> categoryIds) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/delete/bookmark'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'groupId': categoryIds,
        }),
      );

      if (response.statusCode == 200) {
        await _fetchCategories();
        setState(() {
          _selectedCategoryIds.clear();
          _isSelectionMode = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('刪除成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (error) {
      print('Error deleting categories: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刪除失敗: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 保存排序變更
  Future<void> _saveOrder() async {
    if (!_hasChanges) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 準備 groupOrder 資料
      List<List<dynamic>> groupOrder = [];

      for (int i = 0; i < _categories.length; i++) {
        var category = _categories[i];
        int newOrder = (i + 1) * 10;
        groupOrder.add(['update', category['groupcustomize_id'], newOrder]);
      }

      final response = await http.put(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/order/bookmark'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'type': widget.bookmarkType,
          'groupOrder': groupOrder,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _hasChanges = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('儲存成功'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _fetchCategories();
      }
    } catch (error) {
      print('Error saving order: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('儲存失敗: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 顯示新增分類對話框
  void _showAddCategoryDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增分類'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '請輸入分類名稱',
            border: OutlineInputBorder(),
          ),
          maxLength: 10,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addCategory(controller.text);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // 顯示重新命名對話框
  void _showRenameDialog() {
    if (_selectedCategoryIds.length != 1) return;

    int categoryId = _selectedCategoryIds.first;
    var category = _categories.firstWhere(
            (cat) => cat['groupcustomize_id'] == categoryId
    );

    final TextEditingController controller = TextEditingController(
        text: category['groupcustomize_name'].toString()
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '請輸入新的分類名稱',
            border: OutlineInputBorder(),
          ),
          maxLength: 10,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _renameCategory(
                categoryId,
                category['groupcustomize_name'].toString(),
                controller.text,
              );
              setState(() {
                _selectedCategoryIds.clear();
                _isSelectionMode = false;
              });
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // 顯示刪除確認對話框
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除選中的 ${_selectedCategoryIds.length} 個分類嗎?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCategories(_selectedCategoryIds.toList());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E3FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8E3FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '管理收藏分類',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          // 新增按鈕
          IconButton(
            icon: const Icon(Icons.add, color: Colors.blue),
            onPressed: _showAddCategoryDialog,
          ),
          // 選取按鈕
          TextButton(
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) {
                  _selectedCategoryIds.clear();
                }
              });
            },
            child: Text(
              _isSelectionMode ? '取消' : '選取',
              style: const TextStyle(color: Colors.blue, fontSize: 14),
            ),
          ),
          // 重新命名按鈕 (只在選中一個時顯示)
          if (_isSelectionMode && _selectedCategoryIds.length == 1)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: _showRenameDialog,
            ),
          // 刪除按鈕 (選中至少一個時顯示)
          if (_isSelectionMode && _selectedCategoryIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _showDeleteDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: _categories.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '尚未建立任何分類',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '點擊右上角 + 號新增分類',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ReorderableListView.builder(
              itemCount: _categories.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _categories.removeAt(oldIndex);
                  _categories.insert(newIndex, item);
                  _hasChanges = true;
                });
              },
              itemBuilder: (context, index) {
                final category = _categories[index];
                final categoryId = category['groupcustomize_id'];
                final isSelected = _selectedCategoryIds.contains(categoryId);

                return _buildCategoryItem(
                  category,
                  index,
                  isSelected,
                );
              },
            ),
          ),
          if (_hasChanges) _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
      Map<String, dynamic> category,
      int index,
      bool isSelected,
      ) {
    final categoryId = category['groupcustomize_id'];

    return Card(
      key: ValueKey(categoryId),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: _isSelectionMode
            ? Checkbox(
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedCategoryIds.add(categoryId);
              } else {
                _selectedCategoryIds.remove(categoryId);
              }
            });
          },
        )
            : const Icon(Icons.drag_handle),
        title: Text(
          category['groupcustomize_name'].toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: _isSelectionMode
            ? null
            : const Icon(Icons.menu, color: Colors.grey),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saveOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          '儲存變更',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}