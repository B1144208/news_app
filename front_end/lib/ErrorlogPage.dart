import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class ErrorlogPage extends StatefulWidget {
  const ErrorlogPage({super.key});

  @override
  State<ErrorlogPage> createState() => _ErrorlogPageState();
}

class _ErrorlogPageState extends State<ErrorlogPage> {
  List<dynamic> _errorLogs = [];
  List<dynamic> _filteredErrorLogs = [];
  bool _isLoading = true;
  String _error = '';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, today, week, month

  // 後端 API 基礎 URL，從 config.dart 中讀取
  final String _baseUrl = baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchErrorLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 從後端API獲取錯誤日誌數據
  Future<void> _fetchErrorLogs() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 假設後端有一個 GET /api/errorlog 的端點
      final response = await http.get(
        Uri.parse('$_baseUrl/api/errorlog'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _errorLogs = data['data'] ?? [];
          _filteredErrorLogs = _errorLogs;
          _isLoading = false;
        });
        _applyFilters();
      } else {
        setState(() {
          _error = 'Failed to load error logs: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  // 應用搜索和時間過濾
  void _applyFilters() {
    setState(() {
      _filteredErrorLogs = _errorLogs.where((log) {
        // 搜索過濾
        bool matchesSearch = _searchQuery.isEmpty ||
            (log['error_message']?.toLowerCase()?.contains(_searchQuery.toLowerCase()) ?? false) ||
            (log['error_description']?.toLowerCase()?.contains(_searchQuery.toLowerCase()) ?? false);

        // 時間過濾
        bool matchesTimeFilter = true;
        if (_selectedFilter != 'all') {
          DateTime logDate = DateTime.parse(log['created_at']);
          DateTime now = DateTime.now();

          switch (_selectedFilter) {
            case 'today':
              matchesTimeFilter = logDate.day == now.day &&
                  logDate.month == now.month &&
                  logDate.year == now.year;
              break;
            case 'week':
              matchesTimeFilter = now.difference(logDate).inDays <= 7;
              break;
            case 'month':
              matchesTimeFilter = now.difference(logDate).inDays <= 30;
              break;
          }
        }

        return matchesSearch && matchesTimeFilter;
      }).toList();
    });
  }

  // 搜索功能
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  // 時間過濾功能
  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _applyFilters();
  }

  // 格式化日期時間
  String _formatDateTime(String dateTimeStr) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  // 顯示錯誤詳情對話框
  void _showErrorDetails(Map<String, dynamic> errorLog) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('錯誤詳情'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailItem('ID', errorLog['error_id']?.toString() ?? ''),
                  _buildDetailItem('錯誤訊息', errorLog['error_message'] ?? ''),
                  _buildDetailItem('描述', errorLog['error_description'] ?? '無'),
                  _buildDetailItem('發生時間', _formatDateTime(errorLog['created_at'] ?? '')),
                  if (errorLog['error_stack'] != null) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Stack Trace:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        errorLog['error_stack'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '無' : value),
        ],
      ),
    );
  }

  // 取得錯誤級別顏色
  Color _getErrorLevelColor(String? errorMessage) {
    if (errorMessage == null) return Colors.grey;

    String lowerMessage = errorMessage.toLowerCase();
    if (lowerMessage.contains('fatal') || lowerMessage.contains('critical')) {
      return Colors.red;
    } else if (lowerMessage.contains('error')) {
      return Colors.orange;
    } else if (lowerMessage.contains('warning') || lowerMessage.contains('warn')) {
      return Colors.yellow[700]!;
    } else {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('錯誤日誌管理'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _fetchErrorLogs,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索和過濾器區域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                // 搜索框
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索錯誤訊息或描述...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                // 過濾器按鈕
                Row(
                  children: [
                    const Text('時間過濾: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          _buildFilterChip('全部', 'all'),
                          _buildFilterChip('今天', 'today'),
                          _buildFilterChip('本週', 'week'),
                          _buildFilterChip('本月', 'month'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 統計信息
          if (_errorLogs.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Text(
                '總計: ${_errorLogs.length} 條錯誤日誌，顯示: ${_filteredErrorLogs.length} 條',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),

          // 主要內容區域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchErrorLogs,
                    child: const Text('重試'),
                  ),
                ],
              ),
            )
                : _filteredErrorLogs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '沒有找到錯誤日誌',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredErrorLogs.length,
              itemBuilder: (context, index) {
                final errorLog = _filteredErrorLogs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 4,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: _getErrorLevelColor(errorLog['error_message']),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    title: Text(
                      errorLog['error_message'] ?? '未知錯誤',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (errorLog['error_description'] != null)
                          Text(
                            errorLog['error_description'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDateTime(errorLog['created_at'] ?? ''),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '#${errorLog['error_id']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showErrorDetails(errorLog),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        if (selected) _onFilterChanged(value);
      },
      selectedColor: Colors.red[100],
      checkmarkColor: Colors.red[800],
    );
  }
}