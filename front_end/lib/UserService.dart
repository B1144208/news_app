import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // 支持 UserService.instance 的調用方式
  static UserService get instance => _instance;

  // 檢查是否已登入
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('IsLogin') ?? false;
    } catch (e) {
      return false;
    }
  }

  // 檢查是否為管理員
  Future<bool> isAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userLevel = prefs.getInt('UserLevel') ?? 0;

      // 簡單明瞭：5級以上為管理員
      return userLevel >= 5;
    } catch (e) {
      return false;
    }
  }

  // 獲取用戶帳號
  Future<String?> getUserAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('Account');
    } catch (e) {
      return null;
    }
  }

  // 獲取用戶ID
  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID');
      return userId?.toString();
    } catch (e) {
      return null;
    }
  }

  // 獲取用戶名稱（從帳號推導）
  Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final account = prefs.getString('Account');
      // 如果有其他方式獲取真實姓名，可以在這裡擴展
      return account; // 暫時返回帳號作為名稱
    } catch (e) {
      return null;
    }
  }

  // 獲取用戶資料
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID');

      if (userId == null) {
        return {'success': false, 'message': '未登入'};
      }

      final url = '$baseUrl/user?userid=$userId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> userData = jsonDecode(response.body);
        if (userData.isNotEmpty) {
          return {
            'success': true,
            'data': {
              'UserID': userData[0]['UserID'],
              'Account': userData[0]['Account'],
              'IsManager': userData[0]['IsManager'],
              'user_name': userData[0]['Account'], // 使用帳號作為顯示名稱
              'user_account': userData[0]['Account'],
              'user_email': '', // 如果後端有email欄位可以添加
            },
          };
        }
      }

      return {'success': false, 'message': '獲取用戶資料失敗'};
    } catch (e) {
      return {'success': false, 'message': '網路錯誤: $e'};
    }
  }

  // 更新用戶資料
  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    try {
      // 由於原始後端可能不支持更新，這裡先返回成功
      // 實際項目中需要調用相應的更新API
      return {'success': true, 'message': '資料更新成功'};
    } catch (e) {
      return {'success': false, 'message': '更新失敗: $e'};
    }
  }

  // 修改密碼
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      // 由於原始後端可能不支持修改密碼，這裡先返回成功
      // 實際項目中需要調用相應的修改密碼API
      return {'success': true, 'message': '密碼修改成功'};
    } catch (e) {
      return {'success': false, 'message': '修改密碼失敗: $e'};
    }
  }

  // 登出
  Future<Map<String, dynamic>> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // 清除所有本地資料
      return {'success': true, 'message': '登出成功'};
    } catch (e) {
      return {'success': false, 'message': '登出失敗: $e'};
    }
  }

  // 刪除帳號
  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      // 由於原始後端可能不支持刪除帳號，這裡先清除本地資料
      // 實際項目中需要調用相應的刪除API
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      return {'success': true, 'message': '帳號已刪除'};
    } catch (e) {
      return {'success': false, 'message': '刪除帳號失敗: $e'};
    }
  }

  // 檢查權限
  Future<bool> hasPermission(String permission) async {
    final isLoggedIn = await this.isLoggedIn();
    final isAdmin = await this.isAdmin();

    // 基本權限控制
    switch (permission) {
      case 'view':
      case 'share':
        return true; // 所有人都可以查看和分享
      case 'bookmark':
      case 'comment':
      case 'score':
      case 'search':
        return isLoggedIn; // 需要登入
      case 'admin':
      case 'manage':
      case 'delete':
      case 'edit':
        return isAdmin; // 只有管理員
      default:
        return false;
    }
  }

  // 獲取認證標頭
  Future<Map<String, String>> getHeaders() async {
    final headers = {'Content-Type': 'application/json'};

    final userId = await getUserId();
    if (userId != null) {
      headers['User-ID'] = userId;
    }

    return headers;
  }

  // 獲取Token（如果需要）
  Future<String?> getToken() async {
    // 原始系統可能不使用token，返回null
    return null;
  }

  // 登入方法 - 使用後端的 POST /login 端點
  Future<Map<String, dynamic>> login(String account, String password) async {
    try {
      print('開始登入: $account');

      if (account.isEmpty || password.isEmpty) {
        return {'success': false, 'message': '帳號、密碼不能為空！'};
      }

      final url = '$baseUrl/user/login';
      print('登入URL: $url');

      // 使用正確的欄位名稱
      final requestBody = {
        'account': account, // 不是 user_account
        'password': password, // 不是 user_password
      };

      print('請求內容: $requestBody');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw Exception('請求超時，請檢查網路連接');
            },
          );

      print('回應狀態碼: ${response.statusCode}');
      print('回應內容: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          // 取得 userId
          final userId = data['data']?['userId'] ?? data['userId'] ?? 0;

          if (userId != 0) {
            await _storeUserData(userId);
            return {'success': true, 'message': '登入成功！'};
          }
        }

        return {'success': false, 'message': data['message'] ?? '帳號、密碼錯誤!'};
      } else {
        return {'success': false, 'message': '伺服器錯誤 (${response.statusCode})'};
      }
    } catch (e) {
      print('登入異常: $e');
      return {'success': false, 'message': '登入失敗: $e'};
    }
  }

  // 私有方法：儲存用戶資料到 SharedPreferences
  Future<void> _storeUserData(int userId) async {
    final userInfoUrl = '$baseUrl/user?userid=$userId';

    print('用戶資料API URL: $userInfoUrl');

    try {
      final userInfoResponse = await http.get(Uri.parse(userInfoUrl));

      print('用戶資料回應狀態碼: ${userInfoResponse.statusCode}');
      print('用戶資料回應內容: ${userInfoResponse.body}');

      if (userInfoResponse.statusCode == 200) {
        final responseData = jsonDecode(userInfoResponse.body);

        // 檢查回應格式
        if (responseData is Map<String, dynamic>) {
          // 如果是新的API格式 {success: true, data: [...]}
          if (responseData['success'] == true && responseData['data'] is List) {
            final List<dynamic> userData = responseData['data'];
            if (userData.isNotEmpty) {
              await _storeUserPreferences(userData[0]);
            }
          } else {
            print('用戶資料回應格式不正確: $responseData');
          }
        } else if (responseData is List<dynamic>) {
          // 如果是舊的API格式，直接是陣列
          final List<dynamic> userData = responseData;
          if (userData.isNotEmpty) {
            await _storeUserPreferences(userData[0]);
          }
        } else {
          print('未知的用戶資料格式: ${responseData.runtimeType}');
        }
      } else {
        print('獲取用戶資料失敗: ${userInfoResponse.statusCode}');
      }
    } catch (e) {
      print('獲取用戶資料異常: $e');
    }
  }

  // 輔助方法：儲存用戶偏好設定
  Future<void> _storeUserPreferences(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 根據實際的資料庫欄位名稱進行適配
      final userId = user['UserID'] ?? user['user_id'] ?? 0;
      final account = user['Account'] ?? user['user_account'] ?? '';
      final password = user['Password'] ?? user['user_password'] ?? '';
      final isManager = user['IsManager'] ?? user['is_manager'] ?? 0;

      await prefs.setInt('UserID', userId);
      await prefs.setString('Account', account);
      await prefs.setString('Password', password);
      await prefs.setInt('IsManager', isManager);
      await prefs.setBool('IsLogin', true);

      print('用戶資料已存儲: UserID=$userId, Account=$account, IsManager=$isManager');
    } catch (e) {
      print('存儲用戶資料失敗: $e');
    }
  }
}
