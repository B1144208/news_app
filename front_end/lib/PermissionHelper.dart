import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionHelper {
  // ===== 權限等級定義 =====
  static const int LEVEL_GUEST = 0; // 訪客
  static const int LEVEL_MEMBER = 1; // 會員
  static const int LEVEL_ADMIN = 5; // 普通管理員
  static const int LEVEL_DATA_ADMIN = 6; // 數據管理員 (manage_data = 1)
  static const int LEVEL_SENIOR_ADMIN = 7; // 高級管理員 (add_manager = 1)
  static const int LEVEL_SUPER_ADMIN = 10; // 超級管理員 (inherited_position = 1)

  // ===== 預留的未來等級（註解說明） =====
  // static const int LEVEL_VIP = 2;           // VIP會員 - 未來可加入付費會員功能
  // static const int LEVEL_AUTHOR = 3;        // 認證作者 - 可發布文章
  // static const int LEVEL_EDITOR = 4;        // 特約編輯 - 可審核文章
  // static const int LEVEL_SECURITY_ADMIN = 8;// 安全管理員 - 管理系統安全
  // static const int LEVEL_SYSTEM_ADMIN = 9;  // 系統管理員 - 管理伺服器
  // static const int LEVEL_DEVELOPER = 11;    // 開發者 - 除錯權限
  // static const int LEVEL_AUDITOR = 12;      // 審計員 - 唯讀查看所有資料

  // ===== 基礎方法 =====

  // 獲取用戶等級
  static Future<int> getUserLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('UserLevel') ?? 0;
  }

  // 檢查是否已登入
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('IsLogin') ?? false;
  }

  // ===== 等級判斷方法 =====

  // 是否為管理員（5級以上）
  static Future<bool> isAdmin() async {
    final level = await getUserLevel();
    return level >= LEVEL_ADMIN;
  }

  // 是否可以管理數據（6級以上）
  static Future<bool> canManageData() async {
    final level = await getUserLevel();
    return level >= LEVEL_DATA_ADMIN;
  }

  // 是否可以添加管理員（7級以上）
  static Future<bool> canAddManager() async {
    final level = await getUserLevel();
    return level >= LEVEL_SENIOR_ADMIN;
  }

  // 是否為超級管理員（10級）
  static Future<bool> isSuperAdmin() async {
    final level = await getUserLevel();
    return level >= LEVEL_SUPER_ADMIN;
  }

  // ===== 權限檢查方法（相容舊版） =====

  static Future<bool> hasPermission(String action) async {
    try {
      final isLogin = await isLoggedIn();
      final level = await getUserLevel();

      switch (action) {
        // === 訪客權限 (Level 0) ===
        case 'view':
        case 'share':
          return true;

        // === 會員權限 (Level 1+) ===
        case 'bookmark':
        case 'comment':
        case 'score':
        case 'search':
          return isLogin && level >= LEVEL_MEMBER;

        // === 普通管理員權限 (Level 5+) ===
        case 'view_all_users': // 查看所有用戶
        case 'moderate_comments': // 審核評論
        case 'basic_reports': // 基礎報表
          return level >= LEVEL_ADMIN;

        // === 數據管理員權限 (Level 6+) ===
        case 'manage': // 管理（相容舊版）
        case 'manage_news': // 新聞管理
        case 'manage_categories': // 分類管理
        case 'edit': // 編輯（相容舊版）
        case 'export_data': // 資料匯出
        case 'import_data': // 資料匯入
        case 'advanced_reports': // 進階報表
          return level >= LEVEL_DATA_ADMIN;

        // === 高級管理員權限 (Level 7+) ===
        case 'manage_users': // 用戶管理
        case 'add_admin': // 添加管理員
        case 'system_settings': // 系統設定
        case 'audit_logs': // 審計日誌
          return level >= LEVEL_SENIOR_ADMIN;

        // === 超級管理員權限 (Level 10) ===
        case 'admin': // 管理員（相容舊版）
        case 'delete': // 刪除（相容舊版）
        case 'inherit_position': // 繼承權限
        case 'delete_users': // 刪除用戶
        case 'add_senior_admin': // 添加高級管理員
        case 'database_backup': // 資料庫備份
        case 'system_maintenance': // 系統維護
          return level >= LEVEL_SUPER_ADMIN;

        // ===== 預留的未來功能權限 =====
        /*
        // VIP會員功能 (Level 2+)
        case 'priority_support':   // 優先客服
        case 'no_ads':            // 無廣告
        case 'exclusive_content': // 專屬內容
          return level >= LEVEL_VIP;
          
        // 認證作者功能 (Level 3+)
        case 'publish_articles':   // 發布文章
        case 'edit_own_articles': // 編輯自己的文章
        case 'view_article_stats':// 查看文章統計
          return level >= LEVEL_AUTHOR;
          
        // 特約編輯功能 (Level 4+)
        case 'review_articles':    // 審核文章
        case 'featured_articles': // 推薦文章
        case 'manage_tags':       // 標籤管理
          return level >= LEVEL_EDITOR;
          
        // 安全管理員功能 (Level 8+)
        case 'security_audit':    // 安全審計
        case 'ip_management':    // IP管理
        case 'risk_control':     // 風控管理
          return level >= LEVEL_SECURITY_ADMIN;
          
        // 系統管理員功能 (Level 9+)
        case 'server_management': // 伺服器管理
        case 'api_management':   // API管理
        case 'performance_monitor': // 效能監控
          return level >= LEVEL_SYSTEM_ADMIN;
        */

        default:
          return false;
      }
    } catch (e) {
      print('權限檢查錯誤: $e');
      return false;
    }
  }

  // ===== 快捷方法（保持相容性） =====

  static Future<bool> canBookmark() async => await hasPermission('bookmark');
  static Future<bool> canComment() async => await hasPermission('comment');
  static Future<bool> canScore() async => await hasPermission('score');
  static Future<bool> canSearch() async => await hasPermission('search');
  static Future<bool> canView() async => await hasPermission('view');
  static Future<bool> canShare() async => await hasPermission('share');
  static Future<bool> canAdmin() async => await hasPermission('admin');
  static Future<bool> canManage() async => await hasPermission('manage');
  static Future<bool> canDelete() async => await hasPermission('delete');
  static Future<bool> canEdit() async => await hasPermission('edit');

  // ===== 權限等級資訊方法 =====

  // 獲取等級名稱
  static String getLevelName(int level) {
    switch (level) {
      case 0:
        return '訪客';
      case 1:
        return '會員';
      case 5:
        return '普通管理員';
      case 6:
        return '數據管理員';
      case 7:
        return '高級管理員';
      case 10:
        return '超級管理員';

      // 預留等級名稱
      // case 2: return 'VIP會員';
      // case 3: return '認證作者';
      // case 4: return '特約編輯';
      // case 8: return '安全管理員';
      // case 9: return '系統管理員';
      // case 11: return '開發者';
      // case 12: return '審計員';

      default:
        if (level > 1 && level < 5) return '會員';
        if (level > 7 && level < 10) return '管理員';
        return '未知等級';
    }
  }

  // 獲取等級顏色
  static Color getLevelColor(int level) {
    switch (level) {
      case 10:
        return Colors.red; // 超級管理員
      case 7:
        return Colors.orange; // 高級管理員
      case 6:
        return Colors.blue; // 數據管理員
      case 5:
        return Colors.green; // 普通管理員
      case 1:
        return Colors.grey; // 會員
      case 0:
        return Colors.grey[400]!; // 訪客

      // 預留等級顏色
      // case 2: return Colors.purple;    // VIP會員
      // case 3: return Colors.teal;      // 認證作者
      // case 4: return Colors.indigo;    // 特約編輯
      // case 8: return Colors.red[700]!; // 安全管理員
      // case 9: return Colors.orange[700]!; // 系統管理員

      default:
        if (level > 5) return Colors.blue[700]!;
        return Colors.grey[600]!;
    }
  }

  // ===== 獲取權限狀態方法 =====

  // 獲取所有權限狀態
  static Future<Map<String, bool>> getAllPermissions() async {
    final level = await getUserLevel();
    final isLogin = await isLoggedIn();

    return {
      // 基礎權限
      'isLoggedIn': isLogin,
      'userLevel': level > 0,

      // 功能權限
      'view': await hasPermission('view'),
      'share': await hasPermission('share'),
      'bookmark': await hasPermission('bookmark'),
      'comment': await hasPermission('comment'),
      'score': await hasPermission('score'),
      'search': await hasPermission('search'),

      // 管理權限
      'isAdmin': level >= LEVEL_ADMIN,
      'canManageData': level >= LEVEL_DATA_ADMIN,
      'canAddManager': level >= LEVEL_SENIOR_ADMIN,
      'isSuperAdmin': level >= LEVEL_SUPER_ADMIN,

      // 詳細權限
      'manage': await hasPermission('manage'),
      'edit': await hasPermission('edit'),
      'delete': await hasPermission('delete'),
    };
  }

  // 獲取用戶完整權限資訊
  static Future<Map<String, dynamic>> getUserPermissionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final level = await getUserLevel();
    final account = prefs.getString('Account') ?? '';
    final userName = prefs.getString('UserName') ?? '';

    return {
      'level': level,
      'levelName': getLevelName(level),
      'account': account,
      'userName': userName,
      'permissions': await getAllPermissions(),
      'canInherit': level >= LEVEL_SUPER_ADMIN, // 是否可以繼承權限
    };
  }

  // ===== 權限訊息方法 =====

  // 獲取權限不足訊息
  static String getPermissionDeniedMessage(String action) {
    switch (action) {
      case 'bookmark':
      case 'comment':
      case 'score':
      case 'search':
        return '您需要登入才能使用此功能';

      case 'manage':
      case 'edit':
        return '需要數據管理員權限（Level 6）';

      case 'manage_users':
      case 'add_admin':
        return '需要高級管理員權限（Level 7）';

      case 'delete':
      case 'inherit_position':
        return '需要超級管理員權限（Level 10）';

      default:
        return '您的權限不足以執行此操作';
    }
  }

  // ===== 未來擴展方法（預留） =====

  /*
  // 檢查付費會員狀態
  static Future<bool> isVIPMember() async {
    final level = await getUserLevel();
    return level >= LEVEL_VIP;
  }
  
  // 檢查作者權限
  static Future<bool> canPublishArticles() async {
    final level = await getUserLevel();
    return level >= LEVEL_AUTHOR;
  }
  
  // 檢查編輯權限
  static Future<bool> canReviewArticles() async {
    final level = await getUserLevel();
    return level >= LEVEL_EDITOR;
  }
  
  // 升級用戶等級（需要後端API支援）
  static Future<bool> upgradeUserLevel(String userId, int newLevel) async {
    // TODO: 實現後端API調用
    return false;
  }
  
  // 繼承超級管理員權限（需要後端API支援）
  static Future<bool> inheritSuperAdmin(String fromUserId, String toUserId) async {
    // TODO: 實現權限繼承邏輯
    return false;
  }
  */
}
