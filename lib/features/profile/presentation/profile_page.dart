import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/l10n/language_provider.dart';
import 'package:nguyenanh/core/theme/theme_toggle_button.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/features/attendance/presentation/attendance_page.dart';
import 'package:nguyenanh/features/meal/presentation/meal_check_page.dart';
import 'package:nguyenanh/features/setup/presentation/selection_page.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

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
                title: const Text('Tieng Viet (VN)'),
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
                title: const Text('English (EN)'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
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
                'Cài đặt ứng dụng',
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
                title: const Text('Giao diện (Sáng/Tối)'),
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
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          children: [
            // User Profile Section
            Container(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40.r,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: NetworkImage(
                          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=0D8ABC&color=fff',
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
                          ),
                          child: Icon(Icons.edit, color: colorScheme.onPrimary, size: 14.sp),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    l10n.defaultRoleDesc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoBadge(l10n.role, _userRole.toUpperCase(), theme, colorScheme),
                      SizedBox(width: 12.w),
                      _buildInfoBadge(l10n.region, l10n.defaultRegion, theme, colorScheme),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Dashboard Button (Trang chủ)
            _buildListCard(
              context,
              theme,
              colorScheme,
              icon: Icons.home_rounded,
              iconColor: Colors.blue,
              title: l10n.home,
              subtitle: l10n.dashboardDesc,
              onTap: widget.onNavigateHome,
            ),
            SizedBox(height: 16.h),

            // Grid Options
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 16.h,
              crossAxisSpacing: 16.w,
              childAspectRatio: 1.1,
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
                _buildGridCard(
                  context,
                  theme,
                  colorScheme,
                  icon: Icons.event_available_rounded,
                  iconColor: Colors.green,
                  title: l10n.attendance,
                  subtitle: l10n.attendanceDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendancePage())),
                ),
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
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                children: [
                  _buildListTile(context, theme, colorScheme, icon: Icons.help_outline_rounded, title: l10n.helpCenter, onTap: () {}),
                  Divider(height: 1, color: colorScheme.outlineVariant, indent: 48.w),
                  _buildListTile(context, theme, colorScheme, icon: Icons.privacy_tip_outlined, title: l10n.privacyPolicy, onTap: () {}),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Logout Button
            OutlinedButton.icon(
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
              ),
            ),
            SizedBox(height: 32.h),

            // Version text
            Center(
              child: Text(
                'VERSION 1.0.0 • VEHICLE MANAGEMENT',
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

  Widget _buildInfoBadge(String label, String value, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10.sp, color: colorScheme.outline, fontWeight: FontWeight.w600)),
          SizedBox(height: 2.h),
          Text(value, style: TextStyle(fontSize: 14.sp, color: colorScheme.primary, fontWeight: FontWeight.w700)),
        ],
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
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12.r)),
              child: Icon(icon, color: iconColor, size: 24.sp),
            ),
            const Spacer(),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp, color: colorScheme.onSurface)),
            SizedBox(height: 4.h),
            Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11.sp, height: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, ThemeData theme, ColorScheme colorScheme, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface, fontSize: 15.sp)),
      trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.outlineVariant),
      onTap: onTap,
    );
  }
}
