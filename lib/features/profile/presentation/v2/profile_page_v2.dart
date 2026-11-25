import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nguyenanh/core/l10n/language_provider.dart';
import 'package:nguyenanh/core/theme/theme_provider.dart';
import 'package:nguyenanh/core/theme/ui_version_provider.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/application_form/presentation/v2/application_list_page_v2.dart';
import 'package:nguyenanh/features/catalog/presentation/v2/department_screen_v2.dart';
import 'package:nguyenanh/features/catalog/presentation/v2/lot_tag_screen_v2.dart';
import 'package:nguyenanh/features/catalog/presentation/v2/skill_screen_v2.dart';
import 'package:nguyenanh/features/catalog/presentation/v2/user_assignment_screen_v2.dart';
import 'package:nguyenanh/features/catalog/presentation/v2/vehicle_type_screen_v2.dart';
import 'package:nguyenanh/features/catalog/presentation/v2/work_screen_v2.dart';
import 'package:nguyenanh/features/chatbot/presentation/chatbot_provider.dart';
import 'package:nguyenanh/features/meal/presentation/v2/meal_check_page_v2.dart';
import 'package:nguyenanh/features/setup/presentation/selection_entry.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/user_manage/presentation/v2/user_manage_main_page_v2.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/vehicle_maintenance_list_page_v2.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/work_arrangement_page_v2.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Cá nhân" (v2). Same state, permission rules, navigation targets, sheets and logout flow as
/// [ProfilePage] (v1, lib/features/profile/presentation/profile_page.dart) — only the layout changes.
class ProfilePageV2 extends StatefulWidget {
  final VoidCallback onNavigateHome;
  final VoidCallback onNavigateTrips;
  final VoidCallback onLogout;

  const ProfilePageV2({
    super.key,
    required this.onNavigateHome,
    required this.onNavigateTrips,
    required this.onLogout,
  });

  @override
  State<ProfilePageV2> createState() => _ProfilePageV2State();
}

class _ProfilePageV2State extends State<ProfilePageV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
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

  // ── v2 presentation only ──────────────────────────────────────────────────
  /// Shows skeleton rows in place of the permission-gated sections until [_loadUserInfo] finishes.
  bool _permsLoading = true;

  /// Display labels for the role chip in the header (same labels as the user list page).
  static const Map<String, String> _roleNames = {
    'admin': 'Quản trị viên',
    'manager': 'Quản lý',
    'dispatcher': 'Điều phối xe',
    'driver': 'Tài xế',
    'user': 'Người dùng',
  };

  @override
  void initState() {
    super.initState();
    _loadUserInfo().whenComplete(() {
      if (mounted) setState(() => _permsLoading = false);
    });
  }

  // ── Logic (verbatim from v1) ──────────────────────────────────────────────

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
          _canVehicleMaintenance = _userRole == 'admin' ||
              myPerms.contains('/vehicle-maintenances') ||
              myPerms.contains('/vehicle-maintenances__view');
          _canAIAssistant = _userRole == 'admin' || myPerms.contains('/ai-assistant');
          _canViewApplications = _userRole == 'admin' ||
              _userRole == 'driver' ||
              myPerms.contains('/applications__view') ||
              myPerms.contains('/work-arrangements/lot-tag-requests__view');
          _canViewTripsTab = _userRole == 'admin' ||
              myPerms.contains('/dashboard__view_trips') ||
              myPerms.contains('/dashboard__view_lot_order') ||
              myPerms.contains('/dashboard__view_lot_order_limit_3');
        });
        debugPrint('[ProfilePage] _canViewTripsTab = $_canViewTripsTab');
      }
    } catch (e, stack) {
      debugPrint('[ProfilePage] Failed to load permissions: $e\n$stack');
    }
  }

  void _showLanguagePicker() {
    // v2 safety: the settings sheet can outlive this page when the "Giao diện mới" switch swaps screens.
    if (!mounted) return;
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final l10n = AppLocalizations.of(context)!;
    final t = FxTokens.of(context);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxSectionHeader(
                  icon: Icons.translate_rounded,
                  tone: FxTokens.blue,
                  title: l10n.selectLanguage,
                  subtitle: 'Áp dụng cho toàn bộ ứng dụng',
                ),
                SizedBox(height: 2.h),
                _LanguageOption(
                  code: 'VI',
                  label: l10n.vietnamese,
                  selected: languageProvider.locale.languageCode == 'vi',
                  onTap: () {
                    languageProvider.setLocale(const Locale('vi'));
                    Navigator.pop(context);
                  },
                ),
                SizedBox(height: 8.h),
                _LanguageOption(
                  code: 'EN',
                  label: l10n.english,
                  selected: languageProvider.locale.languageCode == 'en',
                  onTap: () {
                    languageProvider.setLocale(const Locale('en'));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
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
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
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
      MaterialPageRoute(builder: (_) => const SelectionEntry()),
      (route) => false,
    );
  }

  void _showSettingsPanel() {
    final l10n = AppLocalizations.of(context)!;
    final t = FxTokens.of(context);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxSectionHeader(
                  icon: Icons.tune_rounded,
                  tone: FxTokens.blue,
                  title: l10n.appSettings,
                  subtitle: 'Tuỳ chỉnh trải nghiệm trên thiết bị này',
                ),
                SizedBox(height: 2.h),
                _SheetGroup(
                  children: [
                    Consumer<LanguageProvider>(
                      builder: (context, lang, child) => _SettingRow(
                        icon: Icons.language_rounded,
                        tone: FxTokens.blue,
                        title: l10n.selectLanguage,
                        subtitle: lang.locale.languageCode == 'en' ? l10n.english : l10n.vietnamese,
                        trailing: Icon(Icons.chevron_right_rounded, size: 20.sp, color: FxTokens.of(context).textFaint),
                        onTap: () {
                          Navigator.pop(context);
                          _showLanguagePicker();
                        },
                      ),
                    ),
                    Consumer<ThemeProvider>(
                      builder: (context, theme, child) => _SettingRow(
                        icon: Icons.dark_mode_rounded,
                        tone: FxTokens.indigo,
                        title: l10n.themeMode,
                        subtitle: theme.isDarkMode ? 'Đang bật chế độ tối' : 'Đang dùng chế độ sáng',
                        trailing: Switch(
                          value: theme.isDarkMode,
                          thumbIcon: WidgetStateProperty.resolveWith(
                            (s) => Icon(
                              s.contains(WidgetState.selected) ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              size: 14,
                            ),
                          ),
                          onChanged: (_) => theme.toggleTheme(),
                        ),
                      ),
                    ),
                    Consumer<UiVersionProvider>(
                      builder: (context, ui, child) => _SettingRow(
                        icon: Icons.auto_awesome_rounded,
                        tone: FxTokens.violet,
                        title: 'Giao diện mới',
                        subtitle: ui.isNewUi ? 'Đang dùng giao diện mới' : 'Đang dùng giao diện cũ',
                        trailing: Switch(
                          value: ui.isNewUi,
                          onChanged: (v) => ui.setNewUi(v),
                        ),
                      ),
                    ),
                    if (_canAIAssistant)
                      Consumer<ChatbotProvider>(
                        builder: (context, provider, child) {
                          return _SettingRow(
                            icon: Icons.smart_toy_rounded,
                            tone: FxTokens.cyan,
                            title: 'Bong bóng Trợ lý AI',
                            subtitle: provider.isBubbleVisible ? 'Đang hiển thị trên màn hình' : 'Đang ẩn',
                            trailing: Switch(
                              value: provider.isBubbleVisible,
                              onChanged: (value) {
                                provider.toggleBubbleVisibility();
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    final displayName = _userFullName == 'Người dùng' ? l10n.defaultUser : _userFullName;

    final width = MediaQuery.sizeOf(context).width;
    final side = width > 760 ? (width - 720) / 2 : 14.w;

    final showWork = _canAIAssistant || _canViewTripsTab || _canAttendance;
    final showUtilities = _canMealCheck || _canViewApplications || _canVehicleMaintenance;
    final showCatalog = _userRole == 'admin' ||
        _canViewVehicleTypes ||
        _canViewDepartments ||
        _canViewSkills ||
        _canViewUserAssignments ||
        _canViewWorks ||
        _canViewLotTags;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: side,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.profileTab, style: t.h1.copyWith(fontSize: 19.sp)),
            Text('Tài khoản, tiện ích & cài đặt', style: t.tiny),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(side, 4.h, side, 28.h),
        children: [
          _hero(t, l10n, displayName),
          if (_permsLoading)
            const _SectionSkeleton()
          else ...[
            if (showWork) _workCard(),
            if (showUtilities) _utilitiesCard(),
            if (showCatalog) _catalogCard(),
          ],
          _settingsCard(),
          SizedBox(height: 4.h),
          _logoutButton(t, l10n),
          SizedBox(height: 22.h),
          Center(
            child: Text(
              'VERSION 2.0.0 • NGUYÊN ANH',
              style: t.overline.copyWith(letterSpacing: 1.5, fontFeatures: FxTokens.tabular),
            ),
          ),
        ],
      ),
    );
  }

  // Header: avatar, greeting, name, role + quick language / display shortcuts.
  Widget _hero(FxTokens t, AppLocalizations l10n, String displayName) {
    final roleLabel = _userRole.isEmpty ? null : (_roleNames[_userRole] ?? _userRole.toUpperCase());
    final c1 = t.dark ? Color.lerp(FxTokens.blue, t.bg, 0.35)! : FxTokens.blue;
    final c2 = t.dark ? Color.lerp(FxTokens.indigo, t.bg, 0.35)! : FxTokens.indigo;
    final languageCode = context.watch<LanguageProvider>().locale.languageCode;
    final radius = BorderRadius.circular(FxTokens.rCard);

    Widget circle(double size, double alpha) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
        );

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
        boxShadow: t.dark
            ? null
            : [BoxShadow(color: FxTokens.blue.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(right: -40.w, top: -56.w, child: circle(160.w, 0.08)),
            Positioned(right: 64.w, bottom: -70.w, child: circle(120.w, 0.06)),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _avatar(l10n, displayName),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin chào,',
                              style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.8)),
                            ),
                            SizedBox(height: 2.h),
                            if (displayName.isEmpty)
                              Container(
                                height: 20.h,
                                width: 150.w,
                                margin: EdgeInsets.symmetric(vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                              )
                            else
                              Text(
                                displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                  height: 1.2,
                                ),
                              ),
                            if (roleLabel != null) ...[
                              SizedBox(height: 8.h),
                              _heroChip(
                                _userRole == 'admin' ? Icons.admin_panel_settings_rounded : Icons.badge_outlined,
                                roleLabel,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: _heroTile(
                          icon: Icons.translate_rounded,
                          label: 'Ngôn ngữ',
                          value: languageCode == 'en' ? l10n.english : l10n.vietnamese,
                          onTap: _showLanguagePicker,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _heroTile(
                          icon: t.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          label: 'Chế độ hiển thị',
                          value: t.dark ? 'Tối' : 'Sáng',
                          onTap: _showSettingsPanel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(AppLocalizations l10n, String displayName) {
    final size = 66.w;
    final initials = _initials(displayName);
    final fallback = Container(
      color: Colors.white.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, size: 30.sp, color: Colors.white)
          : Text(initials, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: Colors.white)),
    );

    return GestureDetector(
      onTap: () => _showDevSnackbar(context, l10n),
      child: SizedBox(
        width: size + 2.w,
        height: size + 2.w,
        child: Stack(
          children: [
            Container(
              width: size,
              height: size,
              padding: EdgeInsets.all(2.5.w),
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.4)),
              child: ClipOval(
                child: displayName.isEmpty
                    ? fallback
                    : Image.network(
                        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=0D8ABC&color=fff',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
                        errorBuilder: (context, error, stackTrace) => fallback,
                      ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: FxTokens.indigo.withValues(alpha: 0.3), blurRadius: 6)],
                ),
                child: Icon(Icons.camera_alt_rounded, size: 12.sp, color: FxTokens.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(FxTokens.rPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: Colors.white),
          SizedBox(width: 5.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroTile({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(12.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
          child: Row(
            children: [
              Icon(icon, size: 16.sp, color: Colors.white.withValues(alpha: 0.9)),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.75)),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16.sp, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  // CÔNG VIỆC — AI assistant / trips shortcuts + work arrangement.
  Widget _workCard() {
    final tiles = <Widget>[
      if (_canAIAssistant)
        _FeatureTile(
          icon: Icons.smart_toy_rounded,
          tone: FxTokens.blue,
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
        _FeatureTile(
          icon: Icons.map_rounded,
          tone: FxTokens.emerald,
          title: 'Chuyến đi',
          subtitle: 'Lịch trình di chuyển',
          onTap: widget.onNavigateTrips,
        ),
    ];

    return _MenuGroupCard(
      icon: Icons.business_center_rounded,
      tone: FxTokens.blue,
      title: 'Công việc',
      subtitle: 'Lối tắt cho công việc hằng ngày',
      top: tiles.isEmpty ? null : FxGrid(columns: tiles.length, children: tiles),
      items: [
        if (_canAttendance)
          _MenuItem(
            icon: Icons.calendar_month_rounded,
            tone: FxTokens.indigo,
            title: 'Bố trí công việc',
            subtitle: 'Phân công & chấm công',
            onTap: () => _push(const WorkArrangementPageV2()),
          ),
      ],
    );
  }

  // TIỆN ÍCH
  Widget _utilitiesCard() {
    return _MenuGroupCard(
      icon: Icons.widgets_rounded,
      tone: FxTokens.emerald,
      title: 'Tiện ích',
      subtitle: 'Dịch vụ nội bộ dành cho bạn',
      items: [
        if (_canMealCheck)
          _MenuItem(
            icon: Icons.restaurant_rounded,
            tone: FxTokens.red,
            title: 'Cơm ca',
            subtitle: 'Theo dõi suất cơm ca',
            onTap: () => _push(const MealCheckPageV2()),
          ),
        if (_canViewApplications)
          _MenuItem(
            icon: Icons.description_rounded,
            tone: FxTokens.blue,
            title: 'Đơn từ',
            subtitle: 'Đơn xin bận & trạng thái duyệt',
            onTap: () => _push(const ApplicationListPageV2()),
          ),
        if (_canVehicleMaintenance)
          _MenuItem(
            icon: Icons.directions_car_rounded,
            tone: FxTokens.cyan,
            title: 'Bảo trì xe',
            subtitle: 'Phiếu bảo trì & bảo dưỡng xe',
            onTap: () => _push(const VehicleMaintenanceListPageV2()),
          ),
      ],
    );
  }

  // DANH MỤC (RBAC)
  Widget _catalogCard() {
    final admin = _userRole == 'admin';
    return _MenuGroupCard(
      icon: Icons.folder_copy_rounded,
      tone: FxTokens.violet,
      title: 'Danh mục',
      subtitle: 'Dữ liệu cấu hình dùng chung',
      items: [
        if (admin || _canViewVehicleTypes)
          _MenuItem(
            icon: Icons.layers_rounded,
            tone: FxTokens.blue,
            title: 'Loại phương tiện',
            subtitle: 'Loại xe & ký hiệu',
            onTap: () => _push(const VehicleTypeScreenV2()),
          ),
        if (admin || _canViewDepartments)
          _MenuItem(
            icon: Icons.domain_rounded,
            tone: FxTokens.indigo,
            title: 'Quản lý bộ phận',
            subtitle: 'Phòng ban, bộ phận',
            onTap: () => _push(const DepartmentScreenV2()),
          ),
        if (admin || _canViewSkills)
          _MenuItem(
            icon: Icons.workspace_premium_rounded,
            tone: FxTokens.amber,
            title: 'Quản lý tay nghề',
            subtitle: 'Danh mục tay nghề',
            onTap: () => _push(const SkillScreenV2()),
          ),
        if (admin || _canViewUserAssignments)
          _MenuItem(
            icon: Icons.people_alt_outlined,
            tone: FxTokens.emerald,
            title: 'Danh mục nhân sự',
            subtitle: 'Gán nhân sự theo bộ phận & tay nghề',
            onTap: () => _push(const UserAssignmentScreenV2()),
          ),
        if (admin || _canViewWorks)
          _MenuItem(
            icon: Icons.work_outline_rounded,
            tone: FxTokens.cyan,
            title: 'Quản lý công việc',
            subtitle: 'Danh mục công việc',
            onTap: () => _push(const WorkScreenV2()),
          ),
        if (admin || _canViewLotTags)
          _MenuItem(
            icon: Icons.tag_rounded,
            tone: FxTokens.violet,
            title: 'Tag lốt xe',
            subtitle: 'Nhãn gắn cho lốt xe',
            onTap: () => _push(const LotTagScreenV2()),
          ),
      ],
    );
  }

  // CÀI ĐẶT & HỖ TRỢ
  Widget _settingsCard() {
    return _MenuGroupCard(
      icon: Icons.tune_rounded,
      tone: FxTokens.slate,
      title: 'Cài đặt & hỗ trợ',
      subtitle: 'Tài khoản, ứng dụng và trợ giúp',
      items: [
        if (_canUserManage)
          _MenuItem(
            icon: Icons.manage_accounts_rounded,
            tone: FxTokens.blue,
            title: 'Quản lý người dùng',
            subtitle: 'Tài khoản & phân quyền',
            onTap: () => _push(const UserManageMainPageV2()),
          ),
        _MenuItem(
          icon: Icons.settings_rounded,
          tone: FxTokens.slate,
          title: 'Cài đặt hệ thống',
          subtitle: 'Ngôn ngữ, chế độ hiển thị, giao diện',
          onTap: _showSettingsPanel,
        ),
        _MenuItem(
          icon: Icons.help_outline_rounded,
          tone: FxTokens.emerald,
          title: 'Trung tâm hỗ trợ',
          subtitle: 'nguyenanhgroup.vn',
          external: true,
          onTap: () => _launchUrl('https://nguyenanhgroup.vn/'),
        ),
        _MenuItem(
          icon: Icons.verified_user_outlined,
          tone: FxTokens.amber,
          title: 'Điều khoản',
          subtitle: 'Điều khoản & chính sách sử dụng',
          external: true,
          onTap: () => _launchUrl('https://nguyenanhgroup.vn/'),
        ),
      ],
    );
  }

  Widget _logoutButton(FxTokens t, AppLocalizations l10n) {
    final ink = t.ink(FxTokens.red);
    return FxCard(
      onTap: _handleLogout,
      color: Color.alphaBlend(t.soft(FxTokens.red), t.card),
      borderColor: FxTokens.red.withValues(alpha: t.dark ? 0.35 : 0.22),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, size: 18.sp, color: ink),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              l10n.logOut,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Building blocks (private to this screen) ───────────────────────────────

class _MenuItem {
  final IconData icon;
  final Color tone;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool external;

  const _MenuItem({
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.external = false,
  });
}

/// Card with a section header, an optional block under it, and grouped tappable rows.
class _MenuGroupCard extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String? subtitle;
  final Widget? top;
  final List<_MenuItem> items;

  const _MenuGroupCard({
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    this.top,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: t.divider, indent: 62.w, endIndent: 14.w));
      }
      rows.add(_MenuRow(item: items[i]));
    }

    return FxCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 0),
            child: FxSectionHeader(icon: icon, title: title, subtitle: subtitle, tone: tone),
          ),
          if (top != null) Padding(padding: EdgeInsets.symmetric(horizontal: 14.w), child: top),
          if (rows.isNotEmpty) ...[
            Divider(height: 1, thickness: 1, color: t.divider),
            SizedBox(height: 4.h),
            ...rows,
            SizedBox(height: 4.h),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuItem item;

  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(
          children: [
            FxIconBadge(icon: item.icon, tone: item.tone, size: 36),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.title, style: t.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(item.subtitle!, style: t.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(
              item.external ? Icons.open_in_new_rounded : Icons.chevron_right_rounded,
              size: (item.external ? 16 : 20).sp,
              color: t.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tinted shortcut tile (Trợ lý AI, Chuyến đi).
class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Material(
      color: tone.withValues(alpha: t.dark ? 0.10 : 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        side: BorderSide(color: tone.withValues(alpha: t.dark ? 0.28 : 0.16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  FxIconBadge(icon: icon, tone: tone, size: 36),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 16.sp, color: t.ink(tone)),
                ],
              ),
              SizedBox(height: 12.h),
              Text(title, style: t.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: 2.h),
              Text(subtitle, style: t.tiny, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the permission-gated sections while permissions load.
class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget row() => Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            children: [
              FxSkeleton(height: 36.w, width: 36.w, radius: 11.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FxSkeleton(height: 11.h, width: 140.w, radius: 6),
                    SizedBox(height: 6.h),
                    FxSkeleton(height: 9.h, width: 90.w, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        );

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FxSkeleton(height: 32.w, width: 32.w, radius: 10.r),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FxSkeleton(height: 12.h, width: 110.w, radius: 6),
                    SizedBox(height: 6.h),
                    FxSkeleton(height: 9.h, width: 170.w, radius: 6),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: FxSkeleton(height: 92.h, radius: 14.r)),
              SizedBox(width: 10.w),
              Expanded(child: FxSkeleton(height: 92.h, radius: 14.r)),
            ],
          ),
          SizedBox(height: 8.h),
          row(),
          row(),
          row(),
        ],
      ),
    );
  }
}

/// Rounded group of rows inside a bottom sheet.
class _SheetGroup extends StatelessWidget {
  final List<Widget> children;

  const _SheetGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final radius = BorderRadius.circular(FxTokens.rTile);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, thickness: 1, color: t.border, indent: 60.w));
      items.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(color: t.cardAlt, borderRadius: radius, border: Border.all(color: t.border)),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Row(
          children: [
            FxIconBadge(icon: icon, tone: tone, size: 36),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: t.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    SizedBox(height: 2.h),
                    Text(subtitle!, style: t.tiny, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({required this.code, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Material(
      color: selected ? t.soft(FxTokens.blue) : t.cardAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        side: BorderSide(
          color: selected ? FxTokens.blue.withValues(alpha: 0.45) : t.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? FxTokens.blue : t.card,
                  borderRadius: BorderRadius.circular(10.r),
                  border: selected ? null : Border.all(color: t.border),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: selected ? Colors.white : t.textMuted,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(child: Text(label, style: t.h3, maxLines: 1, overflow: TextOverflow.ellipsis)),
              SizedBox(width: 8.w),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 20.sp,
                color: selected ? t.ink(FxTokens.blue) : t.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
