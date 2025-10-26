import 'dart:convert';
import 'package:http/http.dart' as http;
import 'UserService.dart';

class NewsService {
  static const String baseUrl = "http://localhost:3000/api";
  final UserService _userService = UserService.instance;

  // 獲取授權 Headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = {'Content-Type': 'application/json; charset=utf-8'};

    final isLoggedIn = await _userService.isLoggedIn();
    if (isLoggedIn) {
      final userId = await _userService.getUserId();
      if (userId != null) {
        headers['User-ID'] = userId.toString();
      }

      final token = await _userService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // 查看新聞（view功能 - 所有用戶都可以）
  Future<Map<String, dynamic>> viewNews(int newsId) async {
    try {
      final userId = await _userService.getUserId();

      final response = await http.post(
        Uri.parse('$baseUrl/user/view'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({'news_id': newsId, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '查看失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 分享新聞（share功能 - 所有用戶都可以）
  Future<Map<String, dynamic>> shareNews(int newsId) async {
    try {
      final userId = await _userService.getUserId();

      final response = await http.post(
        Uri.parse('$baseUrl/user/share'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({'news_id': newsId, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '分享失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 收藏新聞（bookmark功能 - 需要登入）
  Future<Map<String, dynamic>> bookmarkNews(int newsId) async {
    try {
      final hasPermission = await _userService.hasPermission('bookmark');
      if (!hasPermission) {
        return {'success': false, 'message': '需要登入才能收藏新聞'};
      }

      final userId = await _userService.getUserId();

      final response = await http.post(
        Uri.parse('$baseUrl/user/bookmark'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({'news_id': newsId, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '收藏失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 評論新聞（comment功能 - 需要登入）
  Future<Map<String, dynamic>> commentNews(int newsId, String comment) async {
    try {
      final hasPermission = await _userService.hasPermission('comment');
      if (!hasPermission) {
        return {'success': false, 'message': '需要登入才能發表評論'};
      }

      final userId = await _userService.getUserId();

      final response = await http.post(
        Uri.parse('$baseUrl/user/comment'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'news_id': newsId,
          'user_id': userId,
          'comment': comment,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '評論失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 新聞評分（score功能 - 需要登入）
  Future<Map<String, dynamic>> scoreNews(int newsId, int score) async {
    try {
      final hasPermission = await _userService.hasPermission('score');
      if (!hasPermission) {
        return {'success': false, 'message': '需要登入才能評分'};
      }

      final userId = await _userService.getUserId();

      final response = await http.post(
        Uri.parse('$baseUrl/user/score'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'news_id': newsId,
          'user_id': userId,
          'score': score,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '評分失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 搜尋新聞（search功能 - 需要登入）
  Future<Map<String, dynamic>> searchNews(String keyword) async {
    try {
      final hasPermission = await _userService.hasPermission('search');
      if (!hasPermission) {
        return {'success': false, 'message': '需要登入才能搜尋'};
      }

      final userId = await _userService.getUserId();

      final response = await http.post(
        Uri.parse('$baseUrl/user/search'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({'user_id': userId, 'keyword': keyword}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '搜尋失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 獲取新聞列表
  Future<Map<String, dynamic>> getNewsList({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/news?page=$page&limit=$limit'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {
          'success': false,
          'message': '獲取新聞列表失敗',
          'error': response.body,
        };
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 獲取新聞詳情
  Future<Map<String, dynamic>> getNewsDetail(int newsId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/news/$newsId'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {
          'success': false,
          'message': '獲取新聞詳情失敗',
          'error': response.body,
        };
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 獲取用戶收藏列表
  Future<Map<String, dynamic>> getUserBookmarks() async {
    try {
      final hasPermission = await _userService.hasPermission('bookmark');
      if (!hasPermission) {
        return {'success': false, 'message': '需要登入才能查看收藏'};
      }

      final userId = await _userService.getUserId();

      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/bookmarks'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {
          'success': false,
          'message': '獲取收藏列表失敗',
          'error': response.body,
        };
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 獲取用戶評論列表
  Future<Map<String, dynamic>> getUserComments() async {
    try {
      final hasPermission = await _userService.hasPermission('comment');
      if (!hasPermission) {
        return {'success': false, 'message': '需要登入才能查看評論'};
      }

      final userId = await _userService.getUserId();

      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/comments'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {
          'success': false,
          'message': '獲取評論列表失敗',
          'error': response.body,
        };
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // 刪除收藏
  Future<Map<String, dynamic>> removeBookmark(int newsId) async {
    try {
      final hasPermission = await _userService.hasPermission('bookmark');
      if (!hasPermission) {
        return {'success': false, 'message': '需要登入才能操作收藏'};
      }

      final userId = await _userService.getUserId();

      final response = await http.delete(
        Uri.parse('$baseUrl/user/bookmark'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({'news_id': newsId, 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '取消收藏失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }
}
