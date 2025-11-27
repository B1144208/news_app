import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

// ----------------------------------------------------------------
// GroupCustomizeBookmark - 分類管理頁面
// ----------------------------------------------------------------
class GroupCustomizeBookmark extends StatefulWidget {
  final int userId;
  final String bookmarkType; // 'news' or 'channel'
  final List<Map<String, dynamic>> initialCategories;

  const GroupCustomizeBookmark({
    super.key,
    required this.userId,
    required this.bookmarkType,
    required this.initialCategories,
  });

  @override
  State<GroupCustomizeBookmark> createState() => _GroupCustomizeBookmarkState();
}

class _GroupCustomizeBookmarkState extends State<GroupCustomizeBookmark> {
  late List<Map<String, dynamic>> _categories;
  final TextEditingController _newCategoryController = TextEditingController();
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _categories = widget.initialCategories.map((item) => {
      'groupcustomize_id': item['groupcustomize_id'] as int?,
      'name': item['name'] as String?,
      'order': item['order'] as int? ?? 0,
      'isNew': false,
      'isDeleted': false,
    }).toList();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // 核心 API 邏輯：_saveChanges (分為 POST + PUT)
  // ----------------------------------------------------------------

  Future<bool> _saveChanges() async {
    if (_isSaving) return false;
    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有變更需要保存'), backgroundColor: Colors.orange),
      );
      return true;
    }

    if (mounted) {
      setState(() { _isSaving = true; });
    }

    try {
      // ---------------------------------------------------------
      // 階段一: 處理新增 (POST /groupcustomize/bookmark)
      // ---------------------------------------------------------
      final newCategories = _categories.where((c) => c['isNew'] == true).toList();

      for (var cat in newCategories) {
        final name = cat['name'];
        final url = Uri.parse('$baseUrl/groupcustomize/bookmark');

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': widget.userId,
            'name': name,
            'type': widget.bookmarkType, // 這裡使用 type
            'kind': 'bookmark',
          }),
        );

        final responseBody = json.decode(response.body);
        final newId = responseBody['insertId'];

        if (response.statusCode == 200 && responseBody['success'] == true && newId != null) {
          if (mounted) {
            setState(() {
              cat['groupcustomize_id'] = newId; // 獲取後端返回的 ID
              cat['isNew'] = false; // 標記為已保存
            });
          }
        } else {
          // 如果任何一個新增失敗，則拋出錯誤
          throw Exception(responseBody['message'] ?? '新增分類失敗: $name');
        }
      }

      // ---------------------------------------------------------
      // 階段二: 處理排序和刪除 (PUT /groupcustomize/order/bookmark)
      // ---------------------------------------------------------

      List<List<dynamic>> groupOrder = [];
      int currentOrder = 10;

      // 處理排序
      final updatableCategories = _categories.where((c) => !c['isDeleted']).toList();
      for (var cat in updatableCategories) {
        cat['order'] = currentOrder;
        if (cat['groupcustomize_id'] != null) {
          groupOrder.add(['update', cat['groupcustomize_id'], currentOrder]);
        }
        currentOrder += 10;
      }

      // 處理刪除
      final deletedCategories = _categories.where((c) => c['isDeleted'] == true).toList();
      for (var cat in deletedCategories) {
        if (cat['groupcustomize_id'] != null) {
          groupOrder.add(['delete', cat['groupcustomize_id'], null]);
        }
      }

      // 如果沒有排序或刪除操作，則階段二跳過
      if (groupOrder.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('新增分類已成功保存！'), backgroundColor: Colors.green),
        );
        _hasChanges = false;
        return true;
      }

      final orderUrl = Uri.parse('$baseUrl/groupcustomize/order/bookmark');
      final requestBody = {
        'userId': widget.userId,
        'type': 'bookmark',
        'dataType': widget.bookmarkType,
        'groupOrder': groupOrder, // 只包含 update 和 delete
      };

      final orderResponse = await http.put(
        orderUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      final orderResponseBody = json.decode(orderResponse.body);

      if (orderResponse.statusCode == 200 && orderResponseBody['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分類已成功保存!'), backgroundColor: Colors.green),
        );

        if(mounted) {
          setState(() {
            _categories.removeWhere((c) => c['isDeleted'] == true);
            _hasChanges = false;
          });
        }
        return true;
      }

      throw Exception(orderResponseBody['message'] ?? '排序/刪除操作失敗');

    } catch (e) {
      print('DEBUG: Save Category Error (Catch): $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失敗: $e'), backgroundColor: Colors.red),
      );
      return false;
    } finally {
      if(mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }


  // 修改單個分類名稱 (PUT /groupcustomize/bookmark) - 已修正 'dataType' 為 'type'
  Future<void> _renameExistingCategory(Map<String, dynamic> category) async {
    final tempController = TextEditingController(text: category['name']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('修改分類名稱'),
          content: TextField(controller: tempController),
          actions: [
            TextButton(child: const Text('取消'), onPressed: () => Navigator.pop(context)),
            TextButton(
              child: const Text('確認'),
              onPressed: () async {
                final newName = tempController.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(context);

                  final url = Uri.parse('$baseUrl/groupcustomize/bookmark');
                  try {
                    final response = await http.put(
                      url,
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'userId': widget.userId,
                        'groupId': category['groupcustomize_id'],
                        'name': newName,
                        'type': widget.bookmarkType,
                      }),
                    );

                    final responseBody = json.decode(response.body);

                    if (response.statusCode == 200 && responseBody['success'] == true) {
                      if(mounted) {
                        setState(() {
                          category['name'] = newName;
                        });
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('名稱修改成功!'), backgroundColor: Colors.green),
                      );
                      _hasChanges = true;
                    } else {
                      throw Exception(responseBody['message'] ?? 'API 回應失敗');
                    }
                  } catch (e) {
                    print('DEBUG: Rename Category Error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('修改名稱失敗: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    _newCategoryController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新增分類'),
          content: TextField(
            controller: _newCategoryController,
            decoration: const InputDecoration(hintText: "輸入分類名稱"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('新增'),
              onPressed: () {
                if (_newCategoryController.text.trim().isNotEmpty) {
                  _addLocalCategory(_newCategoryController.text.trim());
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _addLocalCategory(String name) {
    if(mounted) {
      setState(() {
        _categories.add({
          'groupcustomize_id': DateTime.now().millisecondsSinceEpoch,
          'name': name,
          'order': 0,
          'isNew': true,
          'isDeleted': false,
        });
        _hasChanges = true;
      });
    }
  }

  void _handleCategoryAction(Map<String, dynamic> category) {
    if (category['isNew'] == true) {
      _showRenameNewCategoryDialog(category);
    } else {
      _renameExistingCategory(category);
    }
  }

  void _showRenameNewCategoryDialog(Map<String, dynamic> category) {
    final tempController = TextEditingController(text: category['name']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('修改分類名稱'),
          content: TextField(controller: tempController),
          actions: [
            TextButton(child: const Text('取消'), onPressed: () => Navigator.pop(context)),
            TextButton(
              child: const Text('確認'),
              onPressed: () {
                if (tempController.text.trim().isNotEmpty) {
                  if(mounted) {
                    setState(() {
                      category['name'] = tempController.text.trim();
                      _hasChanges = true;
                    });
                  }
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _markForDeletion(Map<String, dynamic> category) {
    if(mounted) {
      setState(() {
        if (category['isNew'] == true) {
          _categories.remove(category);
        } else {
          category['isDeleted'] = true;
        }
        _hasChanges = true;
      });
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    final visibleCategories = _categories.where((c) => !c['isDeleted']).toList();

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = visibleCategories.removeAt(oldIndex);
    visibleCategories.insert(newIndex, item);

    final deletedCategories = _categories.where((c) => c['isDeleted']).toList();

    if(mounted) {
      setState(() {
        _categories = [...visibleCategories, ...deletedCategories];
        _hasChanges = true;
      });
    }
  }

  // UI BUILD 保持不變
  @override
  Widget build(BuildContext context) {
    final visibleCategories = _categories.where((c) => !c['isDeleted']).toList();

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges && !_isSaving) {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('未儲存的變更'),
              content: const Text('您有未儲存的分類變更，確定要離開嗎？'),
              actions: [
                TextButton(child: const Text('取消'), onPressed: () => Navigator.of(context).pop(false)),
                TextButton(child: const Text('確定離開'), onPressed: () => Navigator.of(context).pop(true)),
              ],
            ),
          );
          return result ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('管理收藏分類 (${widget.bookmarkType})'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddCategoryDialog,
              tooltip: '新增分類',
            ),
            TextButton(
              onPressed: _isSaving ? null : () async {
                final success = await _saveChanges();
                if (success) {
                  if(mounted) Navigator.pop(context, true);
                }
              },
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('保存', style: TextStyle(color: Colors.white.withOpacity(_isSaving ? 0.5 : 1.0))),
            ),
          ],
        ),
        body: ReorderableListView(
          onReorder: _onReorder,
          children: visibleCategories.map((category) {
            final keyId = category['groupcustomize_id']?.toString() ?? category['name'].toString();

            return Dismissible(
              key: ValueKey(keyId),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) {
                _markForDeletion(category);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已標記 ${category['name']} 為刪除 (儲存後生效)')),
                );
              },
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: ListTile(
                key: ValueKey(keyId),
                leading: const Icon(Icons.drag_handle),
                title: Text(category['name'] ?? ''),
                subtitle: category['isNew'] == true ? const Text('新增 (點擊儲存以生效)') : null,
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _handleCategoryAction(category),
                ),
                onTap: () => _handleCategoryAction(category),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}