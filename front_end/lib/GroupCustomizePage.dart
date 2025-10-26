import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class GroupCustomizePage extends StatefulWidget {
  final int userId;

  const GroupCustomizePage({super.key, required this.userId});

  @override
  State<GroupCustomizePage> createState() => _GroupCustomizePageState();
}

class _GroupCustomizePageState extends State<GroupCustomizePage> {
  List<Map<String, dynamic>> _activeCategories = [];
  List<Map<String, dynamic>> _deletedCategories = [];
  bool _isLoading = false;
  String? _error;
  bool _hasChanges = false;

  // 拖動相關變數
  int? _draggingIndex;
  bool _isDraggingOverDeleteZone = false;

  @override
  void initState() {
    super.initState();
    _fetchUserCategories();
  }

  // 獲取用戶自訂分類資料
  Future<void> _fetchUserCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 獲取用戶在 groupcustomize_general 的排序資料
      final customizeResponse = await http.post(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/general'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': widget.userId}),
      );

      if (customizeResponse.statusCode == 200) {
        final customizeData = json.decode(customizeResponse.body);

        if (customizeData['success'] == true && customizeData['data'] != null) {
          List<dynamic> customList = customizeData['data'];

          // 分離 active 和 deleted 類別
          List<Map<String, dynamic>> active = [];
          List<Map<String, dynamic>> deleted = [];

          for (var item in customList) {
            Map<String, dynamic> category = {
              'group_id': item['group_id'],
              'group_name': item['group_name'] ?? '未命名',
              'group_order': item['group_order'],
              'original_order': item['group_order'], // 儲存原始順序
              'was_deleted': false,
            };

            // 如果 group_order 為 null 或 0，表示是隱藏的類別
            if (category['group_order'] == null || category['group_order'] == 0) {
              category['was_deleted'] = true;
              deleted.add(category);
            } else {
              active.add(category);
            }
          }

          // 按照 group_order 排序
          active.sort((a, b) => (a['group_order'] ?? 0).compareTo(b['group_order'] ?? 0));
          deleted.sort((a, b) => a['group_name'].compareTo(b['group_name']));

          setState(() {
            _activeCategories = active;
            _deletedCategories = deleted;
            _isLoading = false;
          });
        }
      }
    } catch (error) {
      setState(() {
        _error = '載入分類失敗: $error';
        _isLoading = false;
      });
    }
  }

  // 保存變更到資料庫
  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 準備 groupOrder 資料
      // 格式: [[type, groupId, order], ...]
      // type: "insert" (從刪除區恢復), "update" (更新順序), "delete" (移到刪除區)
      List<List<dynamic>> groupOrder = [];

      // 添加 active categories
      for (int i = 0; i < _activeCategories.length; i++) {
        var category = _activeCategories[i];
        int newOrder = (i + 1) * 10;

        // 檢查是否從刪除區恢復
        if (category['was_deleted'] == true) {
          // 從刪除區恢復 (insert 會設定 is_delete = 0)
          groupOrder.add(['insert', category['group_id'], newOrder]);
        } else {
          // 更新順序
          groupOrder.add(['update', category['group_id'], newOrder]);
        }
      }

      // 添加 deleted categories (設定 group_order = null 表示隱藏)
      for (var category in _deletedCategories) {
        // 只處理新刪除的項目
        if (category['was_deleted'] != true ||
            (category['original_order'] != null && category['original_order'] != 0)) {
          // delete 會設定 is_delete = 1，group_order 保持原值
          groupOrder.add(['delete', category['group_id'], null]);
        }
      }

      print('Sending groupOrder: $groupOrder'); // Debug

      // 發送更新請求到 /groupcustomize/order/general
      final response = await http.put(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/order/general'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
          'groupOrder': groupOrder,
        }),
      );

      print('Response status: ${response.statusCode}'); // Debug
      print('Response body: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          setState(() {
            _hasChanges = false;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('儲存成功'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }

          // 重新載入資料
          await _fetchUserCategories();
        }
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('儲存失敗: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 恢復預設設定
  Future<void> _restoreDefaults() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 使用 kind = "reset" 來恢復預設
      final response = await http.put(
        Uri.parse('${Config.apiBaseUrl}/groupcustomize/order/reset'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': widget.userId,
        }),
      );

      if (response.statusCode == 200) {
        await _fetchUserCategories();
        setState(() {
          _hasChanges = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已恢復預設設定'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢復預設失敗: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          '自訂新聞類別',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _restoreDefaults,
            child: const Text(
              '恢復預設',
              style: TextStyle(color: Colors.blue, fontSize: 14),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInstructionCard(),
                  const SizedBox(height: 20),
                  _buildActiveCategoriesSection(),
                  const SizedBox(height: 20),
                  _buildDeletedCategoriesSection(),
                ],
              ),
            ),
          ),
          if (_hasChanges) _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '長按拖曳類別可調整順序',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '顯示的類別',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _activeCategories.isEmpty
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '沒有顯示的類別',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
              : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _activeCategories.asMap().entries.map((entry) {
              int index = entry.key;
              var category = entry.value;
              return _buildDraggableCategoryChip(
                category,
                index,
                true,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDeletedCategoriesSection() {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        setState(() {
          _isDraggingOverDeleteZone = true;
        });
        return true;
      },
      onLeave: (data) {
        setState(() {
          _isDraggingOverDeleteZone = false;
        });
      },
      onAcceptWithDetails: (details) {
        setState(() {
          // 標記為被刪除
          details.data['was_deleted'] = true;

          _activeCategories.remove(details.data);
          _deletedCategories.add(details.data);
          _isDraggingOverDeleteZone = false;
          _hasChanges = true;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isDraggingOverDeleteZone
                ? Colors.red.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDraggingOverDeleteZone ? Colors.red : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: _isDraggingOverDeleteZone ? Colors.red : Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '隱藏的類別',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isDraggingOverDeleteZone ? Colors.red : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              if (_deletedCategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _deletedCategories.map((category) {
                    return _buildDeletedCategoryChip(category);
                  }).toList(),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '拖曳類別到此處以隱藏',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableCategoryChip(
      Map<String, dynamic> category,
      int index,
      bool isActive,
      ) {
    return LongPressDraggable<Map<String, dynamic>>(
      key: ValueKey(category['group_id']),
      data: category,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            category['group_name'],
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCategoryChipContent(category, index, isActive),
      ),
      onDragStarted: () {
        setState(() {
          _draggingIndex = index;
        });
      },
      onDragEnd: (details) {
        setState(() {
          _draggingIndex = null;
        });
      },
      onDraggableCanceled: (velocity, offset) {
        setState(() {
          _draggingIndex = null;
        });
      },
      child: DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (details) => details.data != category,
        onAcceptWithDetails: (details) {
          setState(() {
            final oldIndex = _activeCategories.indexOf(details.data);
            final newIndex = _activeCategories.indexOf(category);

            if (oldIndex != -1 && newIndex != -1) {
              _activeCategories.removeAt(oldIndex);
              _activeCategories.insert(newIndex, details.data);
              _hasChanges = true;
            }
          });
        },
        builder: (context, candidateData, rejectedData) {
          return _buildCategoryChipContent(category, index, isActive);
        },
      ),
    );
  }

  Widget _buildCategoryChipContent(
      Map<String, dynamic> category,
      int index,
      bool isActive,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive
            ? (index == 0 ? Colors.grey.shade400 : Colors.white)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: index == 0 ? Colors.black54 : Colors.grey.shade300,
          width: index == 0 ? 2 : 1,
        ),
      ),
      child: Text(
        category['group_name'],
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isActive ? Colors.black87 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildDeletedCategoryChip(Map<String, dynamic> category) {
    return GestureDetector(
      onTap: () {
        setState(() {
          // 標記為恢復
          category['was_deleted'] = false;

          _deletedCategories.remove(category);
          _activeCategories.add(category);
          _hasChanges = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category['group_name'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color: Colors.grey.shade700,
            ),
          ],
        ),
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
        onPressed: _saveChanges,
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
}