import 'package:flutter/material.dart';

// 通用頁面模板 - 可適用於所有管理頁面
// 使用方法：繼承此模板並自定義主題色彩和內容

class UniversalManagePage extends StatefulWidget {
  final String pageTitle;           // 頁面標題
  final String pageDescription;     // 頁面描述  
  final IconData pageIcon;          // 頁面圖標
  final Color themeColor;           // 主題顏色
  final String searchHint;          // 搜尋提示文字
  final Widget contentWidget;       // 主要內容區域
  final VoidCallback? onAddPressed; // 新增按鈕回調
  final Function(String)? onSearch; // 搜尋回調

  const UniversalManagePage({
    Key? key,
    required this.pageTitle,
    required this.pageDescription,
    required this.pageIcon,
    required this.themeColor,
    required this.searchHint,
    required this.contentWidget,
    this.onAddPressed,
    this.onSearch,
  }) : super(key: key);

  @override
  State<UniversalManagePage> createState() => _UniversalManagePageState();
}

class _UniversalManagePageState extends State<UniversalManagePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.pageTitle),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題區域卡片
              _buildHeaderCard(),
              const SizedBox(height: 30),
              
              // 搜尋區域
              if (widget.onSearch != null) _buildSearchSection(),
              if (widget.onSearch != null) const SizedBox(height: 30),
              
              // 統計資訊區域
              _buildStatsSection(),
              const SizedBox(height: 30),
              
              // 主要內容區域
              _buildMainContent(),
              
              // 底部留白給浮動按鈕
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      // 浮動新增按鈕
      floatingActionButton: widget.onAddPressed != null
          ? FloatingActionButton(
              onPressed: widget.onAddPressed,
              backgroundColor: widget.themeColor,
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: '新增${widget.pageTitle}',
            )
          : null,
    );
  }

  // 建構標題區域卡片
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 主題圖標
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.pageIcon,
              size: 32,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(height: 16),
          // 標題
          Text(
            widget.pageTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(height: 8),
          // 描述
          Text(
            widget.pageDescription,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 建構搜尋區域
  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: Icon(Icons.search, color: widget.themeColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.themeColor, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => widget.onSearch!(_searchController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('搜尋'),
          ),
        ],
      ),
    );
  }

  // 建構統計資訊區域
  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('總數', '0', Icons.analytics_outlined),
          _buildStatItem('今日新增', '0', Icons.today_outlined),
          _buildStatItem('活躍項目', '0', Icons.trending_up_outlined),
        ],
      ),
    );
  }

  // 建構統計項目
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: widget.themeColor,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: widget.themeColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 建構主要內容區域
  Widget _buildMainContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.contentWidget,
    );
  }
}