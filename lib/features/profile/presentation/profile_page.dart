import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/l10n/language_provider.dart';
import 'package:nguyenanh/core/theme/theme_toggle_button.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/work_arrangement_page.dart';
import 'package:nguyenanh/features/meal/presentation/meal_check_page.dart';
import 'package:nguyenanh/features/setup/presentation/selection_page.dart';
import 'package:nguyenanh/features/chatbot/presentation/chatbot_provider.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:nguyenanh/features/user_manage/presentation/user_manage_main_page.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/catalog/presentation/screens/vehicle_type_screen.dart';
import 'package:nguyenanh/features/catalog/presentation/screens/department_screen.dart';
import 'package:nguyenanh/features/catalog/presentation/screens/skill_screen.dart';
import 'package:nguyenanh/features/catalog/presentation/screens/user_assignment_screen.dart';
import 'package:nguyenanh/features/catalog/presentation/screens/work_screen.dart';
import 'package:nguyenanh/features/catalog/presentation/screens/lot_tag_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/screens/vehicle_maintenance_list_page.dart';
import 'package:nguyenanh/features/application_form/presentation/screens/application_list_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback onNavigateHome;
  final VoidCallback onNavigateTrips;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.onNavigateHome,
    required this.onNavigateTrips,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _userFullName = '';
  String _userRole = '';
  final UserManageService _userManageService = UserManageService();
  bool _canMealCheck = false;
  bool _canAttendance = false;
  bool _canUserManage = false;
  bool _canViewVehicleTypes = false;
  bool _canViewDepartments = false;
  bool _canViewSkills = false;
  bool _canViewUserAssignments = false;
  bool _canViewWorks = false;
  bool _canViewLotTags = false;
  bool _canVehicleMaintenance = false;
  bool _canAIAssistant = false;
  bool _canViewApplications = false;
  bool _canViewTripsTab = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userFullName = prefs.getString('user_full_name') ?? 'Người dùng';
      _userRole = (prefs.getString('user_role') ?? 'admin').toLowerCase();
    });

    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      debugPrint('[ProfilePage] Loaded permissions for $_userRole: $myPerms');
      if (mounted) {
        setState(() {
          _canMealCheck = _userRole == 'admin' || myPerms.contains('/meal-check');
          _canAttendance = _userRole == 'admin' || 
                           myPerms.contains('/attendance') || 
                           myPerms.contains('/work-arrangements__view') || 
                           myPerms.contains('/work-attendance__view');
          _canUserManage = _userRole == 'admin' || myPerms.contains('/user-manage__view');
          _canViewVehicleTypes = _userRole == 'admin' || myPerms.contains('/vehicle-types__view');
          _canViewDepartments = _userRole == 'admin' || myPerms.contains('/configuration/departments__view');
          _canViewSkills = _userRole == 'admin' || myPerms.contains('/configuration/skills__view');
          _canViewUserAssignments = _userRole == 'admin' || myPerms.contains('/configuration/user-assignments__view');
          _canViewWorks = _userRole == 'admin' || myPerms.contains('/configuration/works__view');
          _canViewLotTags = _userRole == 'admin' || myPerms.contains('/configuration/lot-tags__view');
          _canVehicleMaintenance = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances') || myPerms.contains('/vehicle-maintenances__view');
          _canAIAssistant = _userRole == 'admin' || myPerms.contains('/ai-assistant');
          _canViewApplications = _userRole == 'admin' || _userRole == 'driver' || myPerms.contains('/applications__view') || myPerms.contains('/work-arrangements/lot-tag-requests__view');
          _canViewTripsTab = _userRole == 'admin' || myPerms.contains('/dashboard__view_lot_order');
        });
        debugPrint('[ProfilePage] _canViewTripsTab = $_canViewTripsTab');
      }
    } catch (e, stack) {
      debugPrint('[ProfilePage] Failed to load permissions: $e\n$stack');
    }
  }

  void _showLanguagePicker() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.selectLanguage,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppSpacing.mdH),
              ListTile(
                title: Text(l10n.vietnamese),
                trailing: languageProvider.locale.languageCode == 'vi'
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.tertiary)
                    : null,
                onTap: () {
                  languageProvider.setLocale(const Locale('vi'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(l10n.english),
                trailing: languageProvider.locale.languageCode == 'en'
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.tertiary)
                    : null,
                onTap: () {
                  languageProvider.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmLogoutTitle),
        content: Text(l10n.confirmLogoutContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.logOut),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    widget.onLogout();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_id');
    await prefs.remove('user_full_name');
    await prefs.remove('user_role');
    await prefs.setBool('is_logged_in', false);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SelectionPage()),
      (route) => false,
    );
  }

  void _showSettingsPanel() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appSettings,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppSpacing.mdH),
              ListTile(
                leading: Icon(Icons.language_rounded, color: colorScheme.primary),
                title: Text(l10n.selectLanguage),
                trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.outlineVariant),
                onTap: () {
                  Navigator.pop(context);
                  _showLanguagePicker();
                },
              ),
              ListTile(
                leading: Icon(Icons.dark_mode_rounded, color: colorScheme.secondary),
                title: Text(l10n.themeMode),
                trailing: const ThemeToggleButton(),
              ),
              if (_canAIAssistant)
                Consumer<ChatbotProvider>(
                  builder: (context, provider, child) {
                    return ListTile(
                      leading: Icon(Icons.smart_toy_rounded, color: Colors.blue),
                      title: const Text('Bong bóng Trợ lý AI'),
                      trailing: Switch(
                        value: provider.isBubbleVisible,
                        onChanged: (value) {
                          provider.toggleBubbleVisibility();
                        },
                        activeColor: colorScheme.primary,
                      ),
                    );
                  },
                ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final displayName = _userFullName == 'Người dùng' ? l10n.defaultUser : _userFullName;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width > 600 ? 40.w : 20.w, vertical: 16.h),
          children: [
            // User Profile Section
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withValues(alpha: 0.5),
                        colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.featureUnderDevelopment),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(40.r),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 36.r,
                              backgroundColor: colorScheme.primary,
                              child: CircleAvatar(
                                radius: 34.r,
                                backgroundColor: colorScheme.surface,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(34.r),
                                  child: Image.network(
                                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=0D8ABC&color=fff',
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      Icons.person_rounded,
                                      size: 36.sp,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: EdgeInsets.all(4.w),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colorScheme.surface, width: 2.w),
                                ),
                                child: Icon(Icons.camera_alt, color: colorScheme.onPrimary, size: 12.sp),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 20.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSurface,
                                fontSize: 22.sp,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // CÔNG VIỆC
            if (_canAIAssistant || _canViewTripsTab) ...[
              Padding(
                padding: EdgeInsets.only(left: 8.w, bottom: 12.h, top: 12.h),
                child: Text(
                  'CÔNG VIỆC',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    mainAxisSpacing: 12.w,
                    crossAxisSpacing: 12.w,
                    childAspectRatio: 1.35,
                    children: [
                      if (_canAIAssistant)
                        _buildGridCard(
                          context,
                          theme,
                          colorScheme,
                          icon: Icons.smart_toy_rounded,
                          iconColor: const Color(0xFF2563EB),
                          title: 'Trợ lý AI',
                          subtitle: 'Hỗ trợ thông minh 24/7',
                          onTap: () {
                            final provider = context.read<ChatbotProvider>();
                            if (!provider.isBubbleVisible) {
                              provider.toggleBubbleVisibility();
                            }
                            provider.openPanel();
                          },
                        ),
                      if (_canViewTripsTab)
                        _buildGridCard(
                          context,
                          theme,
                          colorScheme,
                          icon: Icons.map_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Chuyến đi',
                          subtitle: 'Lịch trình di chuyển',
                          onTap: widget.onNavigateTrips,
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
            if (_canAttendance) ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildGroupedListTile(
                      context,
                      theme,
                      colorScheme,
                      icon: Icons.calendar_month_rounded,
                      iconColor: const Color(0xFF475569),
                      title: 'Bố trí công việc',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkArrangementPage())),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],

            // TIỆN ÍCH
            if (_canMealCheck || _canViewApplications || _canVehicleMaintenance) ...[
              Padding(
                padding: EdgeInsets.only(left: 8.w, bottom: 12.h),
                child: Text(
                  'TIỆN ÍCH',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: () {
                        final list = <Widget>[];
                        if (_canMealCheck) {
                          list.add(_buildGroupedListTile(
                            context,
                            theme,
                            colorScheme,
                            icon: Icons.restaurant_rounded,
                            iconColor: const Color(0xFFEF4444),
                            title: 'Cơm ca',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealCheckPage())),
                          ));
                        }
                        if (_canViewApplications) {
                          if (list.isNotEmpty) list.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56));
                          list.add(_buildGroupedListTile(
                            context,
                            theme,
                            colorScheme,
                            icon: Icons.description_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: 'Đơn từ',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplicationListPage())),
                          ));
                        }
                        if (_canVehicleMaintenance) {
                          if (list.isNotEmpty) list.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56));
                          list.add(_buildGroupedListTile(
                            context,
                            theme,
                            colorScheme,
                            icon: Icons.directions_car_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: 'Bảo trì xe',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleMaintenanceListPage())),
                          ));
                        }
                        return list;
                      }(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],

            // DANH MỤC (RBAC)
            if (_userRole == 'admin' || _canViewVehicleTypes || _canViewDepartments || _canViewSkills || _canViewUserAssignments || _canViewWorks || _canViewLotTags) ...[
              Padding(
                padding: EdgeInsets.only(left: 8.w, bottom: 12.h),
                child: Text(
                  'DANH MỤC',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: () {
                        final list = <Widget>[];
                        if (_userRole == 'admin' || _canViewVehicleTypes) {
                          list.add(_buildListTile(context, theme, colorScheme, icon: Icons.layers_rounded, title: 'Loại phương tiện', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleTypeScreen()))));
                        }
                        if (_userRole == 'admin' || _canViewDepartments) {
                          if (list.isNotEmpty) list.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56));
                          list.add(_buildListTile(context, theme, colorScheme, icon: Icons.domain_rounded, title: 'Quản lý bộ phận', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepartmentScreen()))));
                        }
                        if (_userRole == 'admin' || _canViewSkills) {
                          if (list.isNotEmpty) list.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56));
                          list.add(_buildListTile(context, theme, colorScheme, icon: Icons.workspace_premium_rounded, title: 'Quản lý tay nghề', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillScreen()))));
                        }
                        if (_userRole == 'admin' || _canViewUserAssignments) {
                          if (list.isNotEmpty) list.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56));
                          list.add(_buildListTile(context, theme, colorScheme, icon: Icons.people_alt_outlined, title: 'Danh mục nhân sự', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAssignmentScreen()))));
                        }
                        if (_userRole == 'admin' || _canViewWorks) {
                          if (list.isNotEmpty) list.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56));
                          list.add(_buildListTile(context, theme, colorScheme, icon: Icons.work_outline_rounded, title: 'Quản lý công việc', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkScreen()))));
                        }
                        if (_userRole == 'admin' || _canViewLotTags) {
                          if (list.isNotEmpty) list.add(const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56));
                          list.add(_buildListTile(context, theme, colorScheme, icon: Icons.tag_rounded, title: 'Tag lốt xe', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LotTagScreen()))));
                        }
                        return list;
                      }(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],

            // CÀI ĐẶT & HỖ TRỢ
            Padding(
              padding: EdgeInsets.only(left: 8.w, bottom: 12.h),
              child: Text(
                'CÀI ĐẶT & HỖ TRỢ',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_canUserManage) ...[
                        _buildGroupedListTile(
                          context,
                          theme,
                          colorScheme,
                          icon: Icons.manage_accounts_rounded,
                          iconColor: const Color(0xFF2563EB),
                          title: 'Quản lý người dùng',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManageMainPage())),
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      ],
                      _buildGroupedListTile(
                        context,
                        theme,
                        colorScheme,
                        icon: Icons.settings_rounded,
                        iconColor: const Color(0xFF2563EB),
                        title: 'Cài đặt hệ thống',
                        onTap: _showSettingsPanel,
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      _buildGroupedListTile(
                        context,
                        theme,
                        colorScheme,
                        icon: Icons.help_outline_rounded,
                        iconColor: const Color(0xFF2563EB),
                        title: 'Trung tâm hỗ trợ',
                        onTap: () => _launchUrl('https://nguyenanhgroup.vn/'),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
                      _buildGroupedListTile(
                        context,
                        theme,
                        colorScheme,
                        icon: Icons.verified_user_outlined,
                        iconColor: const Color(0xFF2563EB),
                        title: 'Điều khoản',
                        onTap: () => _launchUrl('https://nguyenanhgroup.vn/'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // Logout Button
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: Icon(Icons.logout_rounded, color: colorScheme.error),
                  label: Text(
                    l10n.logOut,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    side: BorderSide(color: colorScheme.error.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    backgroundColor: colorScheme.error.withOpacity(0.1),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                ),
              ),
            ),
            SizedBox(height: 32.h),

            // Version text
            Center(
              child: Text(
                'VERSION 2.0.0 • NGUYÊN ANH',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }



  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDevSnackbar(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.featureUnderDevelopment),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildListCard(BuildContext context, ThemeData theme, ColorScheme colorScheme, {required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return _buildGroupedListTile(context, theme, colorScheme, icon: icon, iconColor: iconColor, title: title, subtitle: subtitle, onTap: onTap);
  }

  Widget _buildGridCard(BuildContext context, ThemeData theme, ColorScheme colorScheme, {required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24.sp),
            ),
            const Spacer(),
            Text(
              title, 
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: const Color(0xFF1E293B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle, 
              style: TextStyle(color: const Color(0xFF64748B), fontSize: 10.sp, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, ThemeData theme, ColorScheme colorScheme, {required IconData icon, Color? iconColor, required String title, required VoidCallback onTap}) {
    return _buildGroupedListTile(
      context,
      theme,
      colorScheme,
      icon: icon,
      iconColor: iconColor ?? const Color(0xFF3B82F6),
      title: title,
      onTap: onTap,
    );
  }

  Widget _buildGroupedListTile(BuildContext context, ThemeData theme, ColorScheme colorScheme, {required IconData icon, required Color iconColor, required String title, String? subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700, 
                      fontSize: 15.sp, 
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.sp, 
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: const Color(0xFF94A3B8), size: 20.sp),
          ],
        ),
      ),
    );
  }
}
