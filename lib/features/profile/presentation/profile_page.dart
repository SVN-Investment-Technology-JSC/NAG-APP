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
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:nguyenanh/features/user_manage/presentation/user_manage_main_page.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';

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
      _userRole = prefs.getString('user_role') ?? 'Admin';
    });

    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canMealCheck = _userRole == 'admin' || myPerms.contains('/meal-check');
          _canAttendance = _userRole == 'admin' || myPerms.contains('/attendance');
          _canUserManage = _userRole == 'admin' || myPerms.contains('/user-manage__view');
        });
      }
    } catch (_) {}
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
      backgroundColor: colorScheme.surface,
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
            SizedBox(height: 24.h),

            // Dashboard Button (Trang chủ)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _buildListCard(
                  context,
                  theme,
                  colorScheme,
                  icon: Icons.home_rounded,
                  iconColor: Colors.blue,
                  title: l10n.home,
                  subtitle: l10n.dashboardDesc,
                  onTap: widget.onNavigateHome,
                ),
              ),
            ),
            SizedBox(height: 16.h),

            if (_canUserManage) ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _buildListCard(
                    context,
                    theme,
                    colorScheme,
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: Colors.deepPurple,
                    title: 'Quản lý người dùng',
                    subtitle: 'Phân quyền & Tài khoản',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManageMainPage())),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],

            // Grid Options
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              mainAxisSpacing: 16.w,
              crossAxisSpacing: 16.w,
              childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.0 : 1.1,
              children: [
                _buildGridCard(
                  context,
                  theme,
                  colorScheme,
                  icon: Icons.local_shipping_rounded,
                  iconColor: Colors.deepOrange,
                  title: l10n.dailyTrips,
                  subtitle: l10n.tripsDesc,
                  onTap: widget.onNavigateTrips,
                ),
                if (_canAttendance)
                  _buildGridCard(
                    context,
                    theme,
                    colorScheme,
                    icon: Icons.event_available_rounded,
                    iconColor: Colors.green,
                    title: 'Bố trí công việc',
                    subtitle: 'Quản lý công việc và phân công',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkArrangementPage())),
                  ),
                if (_canMealCheck)
                  _buildGridCard(
                    context,
                    theme,
                    colorScheme,
                    icon: Icons.restaurant_rounded,
                    iconColor: Colors.purple,
                    title: l10n.mealCheck,
                    subtitle: l10n.mealDesc,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealCheckPage())),
                  ),
                _buildGridCard(
                  context,
                  theme,
                  colorScheme,
                  icon: Icons.settings_rounded,
                  iconColor: Colors.blue,
                  title: l10n.settings,
                  subtitle: l10n.settingsDesc,
                  onTap: _showSettingsPanel,
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Danh mục Section
            Padding(
              padding: EdgeInsets.only(left: 8.w, bottom: 8.h),
              child: Text(
                'DANH MỤC',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colorScheme.outline,
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      _buildListTile(context, theme, colorScheme, icon: Icons.layers_rounded, title: 'Loại phương tiện', onTap: () => _showDevSnackbar(context, l10n)),
                      Divider(height: 1, color: colorScheme.outlineVariant, indent: 48.w),
                      _buildListTile(context, theme, colorScheme, icon: Icons.domain_rounded, title: 'Quản lý bộ phận', onTap: () => _showDevSnackbar(context, l10n)),
                      Divider(height: 1, color: colorScheme.outlineVariant, indent: 48.w),
                      _buildListTile(context, theme, colorScheme, icon: Icons.workspace_premium_rounded, title: 'Quản lý tay nghề', onTap: () => _showDevSnackbar(context, l10n)),
                      Divider(height: 1, color: colorScheme.outlineVariant, indent: 48.w),
                      _buildListTile(context, theme, colorScheme, icon: Icons.people_alt_outlined, title: 'Danh mục nhân sự', onTap: () => _showDevSnackbar(context, l10n)),
                      Divider(height: 1, color: colorScheme.outlineVariant, indent: 48.w),
                      _buildListTile(context, theme, colorScheme, icon: Icons.work_outline_rounded, title: 'Quản lý công việc', onTap: () => _showDevSnackbar(context, l10n)),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // Support & Legal
            Padding(
              padding: EdgeInsets.only(left: 8.w, bottom: 8.h),
              child: Text(
                l10n.supportLegal,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colorScheme.outline,
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      _buildListTile(context, theme, colorScheme, icon: Icons.help_outline_rounded, title: l10n.helpCenter, onTap: () => _launchUrl('https://nguyenanhgroup.vn/')),
                      Divider(height: 1, color: colorScheme.outlineVariant, indent: 48.w),
                      _buildListTile(context, theme, colorScheme, icon: Icons.privacy_tip_outlined, title: l10n.privacyPolicy, onTap: () => _launchUrl('https://nguyenanhgroup.vn/')),
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
                'VERSION 1.0.0 • NGUYÊN ANH',
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.sp, color: colorScheme.onSurface)),
                  SizedBox(height: 2.h),
                  Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.sp)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, ThemeData theme, ColorScheme colorScheme, {required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10.r)),
              child: Icon(icon, color: iconColor, size: 20.sp),
            ),
            const Spacer(),
            Text(
              title, 
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp, color: colorScheme.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle, 
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10.sp, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, ThemeData theme, ColorScheme colorScheme, {required IconData icon, Color? iconColor, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? colorScheme.onSurfaceVariant),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: iconColor ?? colorScheme.onSurface, fontSize: 15.sp)),
      trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.outlineVariant),
      onTap: onTap,
    );
  }
}
