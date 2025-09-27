import 'package:shared_preferences/shared_preferences.dart';

class PermissionHelper {
  // 檢查本地權限
  static Future<bool> hasPermission(String action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLogin = prefs.getBool('IsLogin') ?? false;
      final isManager = prefs.getInt('IsManager') ?? 0;
      final account = prefs.getString('Account') ?? '';

      // 管理員判斷：後端IsManager為1 或 帳號以admin開頭
      bool isAdmin =
          isManager == 1 || account.toLowerCase().startsWith('admin');

      switch (action) {
        case 'view':
        case 'share':
          return true; // 所有人都可以查看和分享
        case 'bookmark':
        case 'comment':
        case 'score':
        case 'search':
          return isLogin; // 需要登入
        case 'admin':
        case 'manage':
        case 'delete':
        case 'edit':
          return isAdmin; // 只有管理員
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  // 檢查收藏權限
  static Future<bool> canBookmark() async {
    return await hasPermission('bookmark');
  }

  // 檢查評論權限
  static Future<bool> canComment() async {
    return await hasPermission('comment');
  }

  // 檢查評分權限
  static Future<bool> canScore() async {
    return await hasPermission('score');
  }

  // 檢查搜尋權限
  static Future<bool> canSearch() async {
    return await hasPermission('search');
  }

  // 檢查查看權限
  static Future<bool> canView() async {
    return await hasPermission('view');
  }

  // 檢查分享權限
  static Future<bool> canShare() async {
    return await hasPermission('share');
  }

  // 檢查管理員權限
  static Future<bool> canAdmin() async {
    return await hasPermission('admin');
  }

  // 檢查管理權限
  static Future<bool> canManage() async {
    return await hasPermission('manage');
  }

  // 檢查刪除權限
  static Future<bool> canDelete() async {
    return await hasPermission('delete');
  }

  // 檢查編輯權限
  static Future<bool> canEdit() async {
    return await hasPermission('edit');
  }

  // 獲取所有權限狀態
  static Future<Map<String, bool>> getAllPermissions() async {
    return {
      'bookmark': await canBookmark(),
      'comment': await canComment(),
      'score': await canScore(),
      'search': await canSearch(),
      'view': await canView(),
      'share': await canShare(),
      'admin': await canAdmin(),
      'manage': await canManage(),
      'delete': await canDelete(),
      'edit': await canEdit(),
    };
  }

  // 獲取權限不足訊息
  static String getPermissionDeniedMessage(String action) {
    return '您需要登入才能使用 $action 功能';
  }
}
