/// Permission catalog of the app — a mirror of the web's permission tree.
///
/// THE WEB IS THE SOURCE OF TRUTH: keep this list identical to `src/config/navigation.tsx` (+ constants/permissions.ts,
/// labels from i18n `Sidebar.*`) of the web frontend: same keys, same groups, same order, same labels.
/// Page key = route; action key = "<page>__<action>"; a page without actions is itself a leaf.
///
/// Only exception (app-only, not on the web, kept on purpose): [kAppOnlyPermissions].
class PermissionNode {
  final String key;
  final String title;
  final List<String> actions;
  final List<PermissionNode> children;

  PermissionNode({
    required this.key,
    required this.title,
    this.actions = const [],
    this.children = const [],
  });
}

/// Permissions that only exist in the mobile app (the web does not know them).
const Set<String> kAppOnlyPermissions = {
  '/dashboard__view_trips',
  '/dashboard__view_lot_order_limit_3',
};

/// Structural keys (pages with actions, groups) — never stored, removed before saving.
const Set<String> kPermissionParentKeys = {
  '/dashboard',
  '/vehicles',
  '/vehicle-maintenances',
  '/stations',
  'reports-group',
  'fleet-monitoring-group',
  '/fleet-monitoring/overview',
  '/fleet-monitoring/fuel',
  '/fleet-monitoring/concrete',
  '/fleet-monitoring/config',
  '/concrete-quality',
  '/operations',
  '/parking-idle-engine',
  'tools-group',
  '/calendar',
  '/work-attendance',
  '/work-arrangements',
  '/work-arrangements/lot-tag-requests',
  'category-group',
  '/vehicle-types',
  '/configuration/departments',
  '/configuration/skills',
  '/configuration/user-assignments',
  '/configuration/works',
  '/configuration/lot-tags',
  'user-manage-group',
  '/user-manage',
  '/role-permissions',
  '/audit-logs',
};

List<PermissionNode> buildPermissionTree() => [
      PermissionNode(
        key: '/dashboard',
        title: 'Bảng điều khiển',
        actions: [
          '/dashboard__view',
          '/dashboard__order_detail',
          '/dashboard__sync_slots',
          '/dashboard__history',
          '/dashboard__checklog',
          '/dashboard__manual_sort',
          '/dashboard__view_map',
          '/dashboard__view_yard_vehicles',
          '/dashboard__view_lot_order',
          '/dashboard__manual_camera_fallback',
          '/dashboard__system_settings',
          // app-only
          '/dashboard__view_trips',
          '/dashboard__view_lot_order_limit_3',
        ],
      ),
      PermissionNode(
        key: '/vehicles',
        title: 'Quản lý phương tiện',
        actions: ['/vehicles__view', '/vehicles__create', '/vehicles__update', '/vehicles__delete'],
      ),
      PermissionNode(
        key: '/vehicle-maintenances',
        title: 'Bảo trì xe',
        actions: [
          '/vehicle-maintenances__view',
          '/vehicle-maintenances__create',
          '/vehicle-maintenances__update',
          '/vehicle-maintenances__delete',
          '/vehicle-maintenances__submit',
          '/vehicle-maintenances__dispatch_review',
          '/vehicle-maintenances__production_approve',
        ],
      ),
      PermissionNode(
        key: '/stations',
        title: 'Quản lý trạm',
        actions: ['/stations__view', '/stations__create', '/stations__update', '/stations__delete'],
      ),
      PermissionNode(
        key: 'reports-group',
        title: 'Báo cáo phân tích',
        children: [
          PermissionNode(key: '/reports/production', title: 'Sản lượng'),
        ],
      ),
      PermissionNode(
        key: 'fleet-monitoring-group',
        title: 'Giám sát xe',
        children: [
          PermissionNode(key: '/fleet-monitoring/overview', title: 'Tổng quan', actions: ['/fleet-monitoring/overview__view']),
          PermissionNode(key: '/fleet-monitoring/fuel', title: 'Nhiên liệu', actions: ['/fleet-monitoring/fuel__view']),
          PermissionNode(
            key: '/fleet-monitoring/concrete',
            title: 'Bê tông thừa',
            actions: ['/fleet-monitoring/concrete__view', '/fleet-monitoring/concrete__review'],
          ),
          PermissionNode(
            key: '/fleet-monitoring/config',
            title: 'Ngưỡng giám sát',
            actions: ['/fleet-monitoring/config__view', '/fleet-monitoring/config__update'],
          ),
        ],
      ),
      PermissionNode(
        key: '/concrete-quality',
        title: 'Giám sát chất lượng bê tông',
        actions: [
          '/concrete-quality__view',
          '/concrete-quality__acknowledge',
          '/concrete-quality__set_spec',
          '/concrete-quality__ai_integration',
        ],
      ),
      PermissionNode(
        key: '/operations',
        title: 'Vận hành',
        actions: ['/operations__view'],
      ),
      PermissionNode(
        key: '/parking-idle-engine',
        title: 'Giám sát nổ máy',
        actions: ['/parking-idle-engine__view', '/parking-idle-engine__settings'],
      ),
      PermissionNode(
        key: 'tools-group',
        title: 'Công cụ',
        children: [
          PermissionNode(key: '/calendar', title: 'Lịch', actions: ['/calendar__view']),
          PermissionNode(key: '/meal-check', title: 'Cơm ca'),
          PermissionNode(key: '/work-attendance', title: 'Công', actions: ['/work-attendance__view', '/work-attendance__update']),
          PermissionNode(key: '/work-arrangements/experiment', title: 'Bố trí CV thử nghiệm'),
          PermissionNode(
            key: '/work-arrangements',
            title: 'Bố trí công việc',
            actions: ['/work-arrangements__view', '/work-arrangements__update'],
          ),
          PermissionNode(
            key: '/work-arrangements/lot-tag-requests',
            title: 'Đơn xin bận',
            actions: [
              '/work-arrangements/lot-tag-requests__view',
              '/work-arrangements/lot-tag-requests__create',
              '/work-arrangements/lot-tag-requests__review',
              '/work-arrangements/lot-tag-requests__cancel',
              '/work-arrangements/lot-tag-requests__delete',
            ],
          ),
        ],
      ),
      PermissionNode(key: '/ai-assistant', title: 'Trợ lý AI'),
      PermissionNode(
        key: 'category-group',
        title: 'Danh mục',
        children: [
          PermissionNode(
            key: '/vehicle-types',
            title: 'Loại phương tiện',
            actions: ['/vehicle-types__view', '/vehicle-types__create', '/vehicle-types__update', '/vehicle-types__delete'],
          ),
          PermissionNode(
            key: '/configuration/departments',
            title: 'Quản lý bộ phận',
            actions: [
              '/configuration/departments__view',
              '/configuration/departments__create',
              '/configuration/departments__update',
              '/configuration/departments__assign_users',
              '/configuration/departments__delete',
            ],
          ),
          PermissionNode(
            key: '/configuration/skills',
            title: 'Quản lý tay nghề',
            actions: [
              '/configuration/skills__view',
              '/configuration/skills__create',
              '/configuration/skills__update',
              '/configuration/skills__delete',
            ],
          ),
          PermissionNode(
            key: '/configuration/user-assignments',
            title: 'Danh mục nhân sự',
            actions: [
              '/configuration/user-assignments__view',
              '/configuration/user-assignments__create',
              '/configuration/user-assignments__update',
              '/configuration/user-assignments__delete',
            ],
          ),
          PermissionNode(
            key: '/configuration/works',
            title: 'Quản lý công việc',
            actions: [
              '/configuration/works__view',
              '/configuration/works__create',
              '/configuration/works__update',
              '/configuration/works__delete',
            ],
          ),
          PermissionNode(
            key: '/configuration/lot-tags',
            title: 'Tag lốt xe',
            actions: [
              '/configuration/lot-tags__view',
              '/configuration/lot-tags__create',
              '/configuration/lot-tags__update',
              '/configuration/lot-tags__delete',
            ],
          ),
        ],
      ),
      PermissionNode(
        key: 'user-manage-group',
        title: 'Quản lý người dùng',
        children: [
          PermissionNode(
            key: '/user-manage',
            title: 'Tất cả người dùng',
            actions: ['/user-manage__view', '/user-manage__create', '/user-manage__update', '/user-manage__delete'],
          ),
          PermissionNode(
            key: '/role-permissions',
            title: 'Phân quyền vai trò',
            actions: ['/role-permissions__view', '/role-permissions__update'],
          ),
          PermissionNode(key: '/audit-logs', title: 'Nhật ký thao tác', actions: ['/audit-logs__view']),
        ],
      ),
    ];

/// Labels of every leaf key (same wording as the web).
const Map<String, String> kPermissionNames = {
  '/dashboard__view': 'Xem thông tin chung',
  '/dashboard__order_detail': 'Xem chi tiết các chuyến xe (đơn hàng)',
  '/dashboard__sync_slots': 'Thao tác đồng bộ lốt xe',
  '/dashboard__history': 'Xem lịch sử lốt xe',
  '/dashboard__checklog': 'Xem nhật ký vận hành',
  '/dashboard__manual_sort': 'Thao tác sắp xếp thứ tự lốt xe',
  '/dashboard__view_map': 'Xem bản đồ',
  '/dashboard__view_yard_vehicles': 'Xem xe trong bãi',
  '/dashboard__view_lot_order': 'Xem thứ tự lốt xe',
  '/dashboard__manual_camera_fallback': 'Thao tác cho xe vào/xuất trạm (camera sự cố)',
  '/dashboard__system_settings': 'Cấu hình vận hành',
  '/dashboard__view_trips': 'Chuyến trong ngày (chỉ app)',
  '/dashboard__view_lot_order_limit_3': 'Xem thứ tự lốt xe — chỉ 3 xe (chỉ app)',

  '/vehicles__view': 'Xem danh sách phương tiện',
  '/vehicles__create': 'Thêm phương tiện',
  '/vehicles__update': 'Sửa phương tiện',
  '/vehicles__delete': 'Xóa phương tiện',

  '/vehicle-maintenances__view': 'Xem dữ liệu bảo trì',
  '/vehicle-maintenances__create': 'Thêm bảo trì',
  '/vehicle-maintenances__update': 'Sửa bảo trì',
  '/vehicle-maintenances__delete': 'Xóa bảo trì',
  '/vehicle-maintenances__submit': 'Gửi phiếu bảo trì',
  '/vehicle-maintenances__dispatch_review': 'Kiểm tra bảo trì',
  '/vehicle-maintenances__production_approve': 'Phê duyệt bảo trì',

  '/stations__view': 'Xem danh sách bãi/trạm',
  '/stations__create': 'Thêm bãi/trạm',
  '/stations__update': 'Sửa bãi/trạm',
  '/stations__delete': 'Xóa bãi/trạm',

  '/reports/production': 'Sản lượng',

  '/fleet-monitoring/overview__view': 'Xem tổng quan nhiên liệu & bê tông mọi xe',
  '/fleet-monitoring/fuel__view': 'Xem giám sát nhiên liệu',
  '/fleet-monitoring/concrete__view': 'Xem giám sát bê tông thừa',
  '/fleet-monitoring/concrete__review': 'Duyệt sự kiện, yêu cầu ảnh/video camera',
  '/fleet-monitoring/config__view': 'Xem ngưỡng giám sát',
  '/fleet-monitoring/config__update': 'Sửa ngưỡng giám sát',

  '/concrete-quality__view': 'Xem giám sát chất lượng bê tông và cảnh báo',
  '/concrete-quality__acknowledge': 'Xác nhận đã xử lý cảnh báo',
  '/concrete-quality__set_spec': 'Chọn mác đang trộn tại trạm',
  '/concrete-quality__ai_integration': 'Tài khoản tích hợp AI: đọc thông tin chuyến, gửi cảnh báo',

  '/operations__view': 'Xem vận hành trạm trộn (sản lượng, mẻ, lệch cân)',

  '/parking-idle-engine__view': 'Xem giám sát nổ máy trong bãi',
  '/parking-idle-engine__settings': 'Cấu hình cảnh báo nổ máy',

  '/calendar__view': 'Xem lịch âm/dương',
  '/meal-check': 'Cơm ca',
  '/work-attendance__view': 'Xem bảng công',
  '/work-attendance__update': 'Cập nhật nghỉ nửa ngày',
  '/work-arrangements/experiment': 'Bố trí CV thử nghiệm',
  '/work-arrangements__view': 'Xem phân công',
  '/work-arrangements__update': 'Cập nhật phân công',
  '/work-arrangements/lot-tag-requests__view': 'Xem đơn xin bận',
  '/work-arrangements/lot-tag-requests__create': 'Tạo đơn xin bận',
  '/work-arrangements/lot-tag-requests__review': 'Duyệt/từ chối đơn xin bận',
  '/work-arrangements/lot-tag-requests__cancel': 'Hủy đơn xin bận',
  '/work-arrangements/lot-tag-requests__delete': 'Xóa đơn xin bận',
  '/ai-assistant': 'Trợ lý AI',

  '/vehicle-types__view': 'Xem danh sách loại phương tiện',
  '/vehicle-types__create': 'Thêm loại phương tiện',
  '/vehicle-types__update': 'Sửa loại phương tiện',
  '/vehicle-types__delete': 'Xóa loại phương tiện',
  '/configuration/departments__view': 'Xem danh sách bộ phận',
  '/configuration/departments__create': 'Thêm bộ phận',
  '/configuration/departments__update': 'Sửa bộ phận',
  '/configuration/departments__assign_users': 'Gán nhân sự vào bộ phận',
  '/configuration/departments__delete': 'Xóa bộ phận',
  '/configuration/skills__view': 'Xem danh sách tay nghề',
  '/configuration/skills__create': 'Thêm tay nghề',
  '/configuration/skills__update': 'Sửa tay nghề',
  '/configuration/skills__delete': 'Xóa tay nghề',
  '/configuration/user-assignments__view': 'Xem danh mục nhân sự',
  '/configuration/user-assignments__create': 'Thêm nhân sự',
  '/configuration/user-assignments__update': 'Sửa nhân sự',
  '/configuration/user-assignments__delete': 'Xóa nhân sự',
  '/configuration/works__view': 'Xem danh sách công việc',
  '/configuration/works__create': 'Thêm công việc',
  '/configuration/works__update': 'Sửa công việc',
  '/configuration/works__delete': 'Xóa công việc',
  '/configuration/lot-tags__view': 'Xem danh sách tag lốt',
  '/configuration/lot-tags__create': 'Thêm tag lốt',
  '/configuration/lot-tags__update': 'Sửa tag lốt',
  '/configuration/lot-tags__delete': 'Xóa tag lốt',

  '/user-manage__view': 'Xem danh sách người dùng',
  '/user-manage__create': 'Thêm người dùng',
  '/user-manage__update': 'Sửa người dùng',
  '/user-manage__delete': 'Xóa người dùng',
  '/role-permissions__view': 'Xem quyền hạn',
  '/role-permissions__update': 'Chỉnh sửa quyền hạn',
  '/audit-logs__view': 'Xem nhật ký thao tác',
};

/// The web's dependency rule (RolePermissionsManager.handleCheck), applied after every change of one role:
///  * granting an action "<page>__x" (other than __view) also grants "<page>__view";
///  * revoking "<page>__view" revokes every "<page>__*" action of that page.
/// [before] = the role's permissions before the change, [after] = after it. Returns the corrected list.
List<String> applyWebPermissionRules(List<String> before, List<String> after) {
  final added = after.where((k) => !before.contains(k)).toList();
  final removed = before.where((k) => !after.contains(k)).toList();
  var out = [...after];
  for (final k in added) {
    if (k.contains('__') && !k.endsWith('__view') && !kAppOnlyPermissions.contains(k)) {
      final view = '${k.split('__').first}__view';
      if (!out.contains(view)) out.add(view);
    }
  }
  for (final k in removed) {
    if (k.endsWith('__view')) {
      final page = k.substring(0, k.length - '__view'.length);
      out = out.where((x) => !x.startsWith('${page}__') || kAppOnlyPermissions.contains(x)).toList();
    }
  }
  return out.toSet().toList();
}
