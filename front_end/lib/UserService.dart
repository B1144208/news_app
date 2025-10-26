import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class UserService {
  static final UserService instance = UserService._internal();

  UserService._internal();

  factory UserService() {
    return instance;
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = {'Content-Type': 'application/json; charset=utf-8'};
    final isLoggedIn = await this.isLoggedIn();
    if (isLoggedIn) {
      final userId = await getUserId();
      if (userId != null) {
        headers['User-ID'] = userId.toString();
      }
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('UserID');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<bool> hasPermission(String permission) async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsJson = prefs.getString('permissions');
    if (permissionsJson == null) return false;
    try {
      final permissions = jsonDecode(permissionsJson) as Map<String, dynamic>;
      return permissions[permission] == true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String account, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/login'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'user_account': account, 'user_password': password}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        if (result['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('Account', account);
          await prefs.setInt('UserID', result['data']['user_id'] ?? 0);
          await prefs.setString('token', result['data']['token'] ?? '');
          await prefs.setInt('IsManager', result['data']['is_manager'] ?? 0);
          if (result['data']['permissions'] != null) {
            await prefs.setString(
              'permissions',
              jsonEncode(result['data']['permissions']),
            );
          }
        }
        return result;
      } else {
        return {'success': false, 'message': '登入失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  Future<Map<String, dynamic>> signup(
    String account,
    String password,
    String email,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/signup'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'user_account': account,
          'user_password': password,
          'user_email': email,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '註冊失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // ✅ 修改登出方法 - 直接清除本地數據
  Future<Map<String, dynamic>> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('Account');
      await prefs.remove('UserID');
      await prefs.remove('token');
      await prefs.remove('IsManager');
      await prefs.remove('permissions');

      print('登出成功 - 本地數據已清除');

      return {'success': true, 'message': '登出成功'};
    } catch (e) {
      print('登出失敗: $e');
      return {'success': false, 'message': '登出失敗: $e'};
    }
  }

  // ✅ 修改個人資料
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? birthday,
  }) async {
    try {
      final userId = await getUserId();

      if (userId == null) {
        return {'success': false, 'message': '用戶ID不存在'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/user'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'action': 'update-profile',
          'user_id': userId,
          'user_name': name,
          'user_email': email,
          'user_birthday': birthday,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '更新失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // ✅ 修改密碼
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'message': '用戶ID不存在'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/user'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'action': 'change-password',
          'user_id': userId,
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'message': '修改密碼失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // ✅ 刪除帳號
  Future<Map<String, dynamic>> deleteAccount({required String password}) async {
    try {
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'message': '用戶ID不存在'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/user'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'action': 'delete-account',
          'user_id': userId,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        if (result['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('Account');
          await prefs.remove('UserID');
          await prefs.remove('token');
          await prefs.remove('IsManager');
          await prefs.remove('permissions');
        }
        return result;
      } else {
        return {'success': false, 'message': '刪除帳號失敗', 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // ✅ 發送郵箱驗證碼 - 支持多種路由
  Future<Map<String, dynamic>> sendEmailVerification(String email) async {
    try {
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'message': '用戶ID不存在'};
      }

      print('📧 發送郵箱驗證碼');
      print('   用戶ID: $userId');
      print('   郵箱: $email');

      // ✅ 嘗試不同的路由組合
      final routesToTry = [
        // 優先嘗試 PUT /user (最可能)
        {
          'method': 'PUT',
          'url': '$baseUrl/user',
          'body': {
            'user_id': userId,
            'action': 'send-email-code',
            'email': email,
          },
        },
        // 次選 POST /user
        {
          'method': 'POST',
          'url': '$baseUrl/user',
          'body': {
            'user_id': userId,
            'action': 'send-email-code',
            'email': email,
          },
        },
        // 第三選擇 PUT /user/{id}
        {
          'method': 'PUT',
          'url': '$baseUrl/user/$userId',
          'body': {'action': 'send-email-code', 'email': email},
        },
        // 第四選擇 POST /user/{id}
        {
          'method': 'POST',
          'url': '$baseUrl/user/$userId',
          'body': {'action': 'send-email-code', 'email': email},
        },
      ];

      for (int i = 0; i < routesToTry.length; i++) {
        final route = routesToTry[i];
        print(
          '📧 嘗試端點 ${i + 1}/${routesToTry.length}: ${route['method']} ${route['url']}',
        );

        try {
          late http.Response response;

          if (route['method'] == 'PUT') {
            response = await http
                .put(
                  Uri.parse(route['url']! as String),
                  headers: await _getAuthHeaders(),
                  body: jsonEncode(route['body']),
                )
                .timeout(const Duration(seconds: 10));
          } else {
            response = await http
                .post(
                  Uri.parse(route['url']! as String),
                  headers: await _getAuthHeaders(),
                  body: jsonEncode(route['body']),
                )
                .timeout(const Duration(seconds: 10));
          }

          print('📧 API 響應狀態碼: ${response.statusCode}');

          if (response.statusCode == 200) {
            final result = jsonDecode(utf8.decode(response.bodyBytes));
            print('✅ 成功！使用端點: ${route['method']} ${route['url']}');
            return result;
          }
        } catch (e) {
          print('❌ 端點 ${i + 1} 失敗: $e');
          continue;
        }
      }

      return {'success': false, 'message': '發送驗證碼失敗，所有端點都不可用'};
    } catch (e) {
      print('❌ 發送郵箱驗證碼異常: $e');
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // ✅ 驗證郵箱 - 支持多種路由
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'message': '用戶ID不存在'};
      }

      print('✅ 驗證郵箱');
      print('   用戶ID: $userId');
      print('   郵箱: $email');
      print('   驗證碼: $code');

      final routesToTry = [
        {
          'method': 'PUT',
          'url': '$baseUrl/user',
          'body': {
            'user_id': userId,
            'action': 'verify-email-code',
            'email': email,
            'code': code,
          },
        },
        {
          'method': 'POST',
          'url': '$baseUrl/user',
          'body': {
            'user_id': userId,
            'action': 'verify-email-code',
            'email': email,
            'code': code,
          },
        },
        {
          'method': 'PUT',
          'url': '$baseUrl/user/$userId',
          'body': {'action': 'verify-email-code', 'email': email, 'code': code},
        },
        {
          'method': 'POST',
          'url': '$baseUrl/user/$userId',
          'body': {'action': 'verify-email-code', 'email': email, 'code': code},
        },
      ];

      for (int i = 0; i < routesToTry.length; i++) {
        final route = routesToTry[i];
        print(
          '✅ 嘗試端點 ${i + 1}/${routesToTry.length}: ${route['method']} ${route['url']}',
        );

        try {
          late http.Response response;

          if (route['method'] == 'PUT') {
            response = await http
                .put(
                  Uri.parse(route['url']! as String),
                  headers: await _getAuthHeaders(),
                  body: jsonEncode(route['body']),
                )
                .timeout(const Duration(seconds: 10));
          } else {
            response = await http
                .post(
                  Uri.parse(route['url']! as String),
                  headers: await _getAuthHeaders(),
                  body: jsonEncode(route['body']),
                )
                .timeout(const Duration(seconds: 10));
          }

          print('✅ API 響應狀態碼: ${response.statusCode}');

          if (response.statusCode == 200) {
            final result = jsonDecode(utf8.decode(response.bodyBytes));
            print('✅ 成功！使用端點: ${route['method']} ${route['url']}');
            return result;
          }
        } catch (e) {
          print('❌ 端點 ${i + 1} 失敗: $e');
          continue;
        }
      }

      return {'success': false, 'message': '郵箱驗證失敗，所有端點都不可用'};
    } catch (e) {
      print('❌ 郵箱驗證異常: $e');
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // ✅ 發送手機驗證碼 - 支持多種路由
  Future<Map<String, dynamic>> sendPhoneVerification(String phone) async {
    try {
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'message': '用戶ID不存在'};
      }

      print('📱 發送手機驗證碼');
      print('   用戶ID: $userId');
      print('   手機: $phone');

      final routesToTry = [
        {
          'method': 'PUT',
          'url': '$baseUrl/user',
          'body': {
            'user_id': userId,
            'action': 'send-phone-code',
            'phone': phone,
          },
        },
        {
          'method': 'POST',
          'url': '$baseUrl/user',
          'body': {
            'user_id': userId,
            'action': 'send-phone-code',
            'phone': phone,
          },
        },
        {
          'method': 'PUT',
          'url': '$baseUrl/user/$userId',
          'body': {'action': 'send-phone-code', 'phone': phone},
        },
        {
          'method': 'POST',
          'url': '$baseUrl/user/$userId',
          'body': {'action': 'send-phone-code', 'phone': phone},
        },
      ];

      for (int i = 0; i < routesToTry.length; i++) {
        final route = routesToTry[i];
        print(
          '📱 嘗試端點 ${i + 1}/${routesToTry.length}: ${route['method']} ${route['url']}',
        );

        try {
          late http.Response response;

          if (route['method'] == 'PUT') {
            response = await http
                .put(
                  Uri.parse(route['url']! as String),
                  headers: await _getAuthHeaders(),
                  body: jsonEncode(route['body']),
                )
                .timeout(const Duration(seconds: 10));
          } else {
            response = await http
                .post(
                  Uri.parse(route['url']! as String),
                  headers: await _getAuthHeaders(),
                  body: jsonEncode(route['body']),
                )
                .timeout(const Duration(seconds: 10));
          }

          print('📱 API 響應狀態碼: ${response.statusCode}');

          if (response.statusCode == 200) {
            final result = jsonDecode(utf8.decode(response.bodyBytes));
            print('✅ 成功！使用端點: ${route['method']} ${route['url']}');
            return result;
          }
        } catch (e) {
          print('❌ 端點 ${i + 1} 失敗: $e');
          continue;
        }
      }

      return {'success': false, 'message': '發送驗證碼失敗，所有端點都不可用'};
    } catch (e) {
      print('❌ 發送手機驗證碼異常: $e');
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }

  // ✅ 驗證手機 - 支持多種路由
  Future<Map<String, dynamic>> verifyPhone({
    required String phone,
    required String code,
  }) async {
    try {
      final userId = await getUserId();
      if (userId == null) {
        return {'success': false, 'message': '用戶ID不存在'};
      }

      print('✅ 驗證手機');
      print('   用戶ID: $userId');
      print('   手機: $phone');
      print('   驗證碼: $code');

      final routesToTry = [
        {
          'method': 'PUT',
          'url': '$baseUrl/user',
          'body': {
            'user_id': userId,
            'action': 'verify-phone-code',
            'phone': phone,
            'code': code,
          },
        },
        {
          'method': 'POST',
          'url': '$baseUrl/user',
          'body': {
            'user_id': userId,
            'action': 'verify-phone-code',
            'phone': phone,
            'code': code,
          },
        },
        {
          'method': 'PUT',
          'url': '$baseUrl/user/$userId',
          'body': {'action': 'verify-phone-code', 'phone': phone, 'code': code},
        },
        {
          'method': 'POST',
          'url': '$baseUrl/user/$userId',
          'body': {'action': 'verify-phone-code', 'phone': phone, 'code': code},
        },
      ];

      for (int i = 0; i < routesToTry.length; i++) {
        final route = routesToTry[i];
        print(
          '✅ 嘗試端點 ${i + 1}/${routesToTry.length}: ${route['method']} ${route['url']}',
        );

        try {
          late http.Response response;

          if (route['method'] == 'PUT') {
            response = await http
                .put(
                  Uri.parse(route['url']! as String),
                  headers: await _getAuthHeaders(),
                  body: jsonEncode(route['body']),
                )
                .timeout(const Duration(seconds: 10));
          } else {
            response = await http
                .post(
                  Uri.parse(route['url']! as String),
                  headers: await _getAuthHeaders(),
                  body: jsonEncode(route['body']),
                )
                .timeout(const Duration(seconds: 10));
          }

          print('✅ API 響應狀態碼: ${response.statusCode}');

          if (response.statusCode == 200) {
            final result = jsonDecode(utf8.decode(response.bodyBytes));
            print('✅ 成功！使用端點: ${route['method']} ${route['url']}');
            return result;
          }
        } catch (e) {
          print('❌ 端點 ${i + 1} 失敗: $e');
          continue;
        }
      }

      return {'success': false, 'message': '手機驗證失敗，所有端點都不可用'};
    } catch (e) {
      print('❌ 手機驗證異常: $e');
      return {'success': false, 'message': '網絡錯誤: $e'};
    }
  }
}
